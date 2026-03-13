###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get install -y debootstrap debian-archive-keyring jq dpkg-dev gnupg apt-transport-https ca-certificates curl gpg

cat > /usr/share/debootstrap/scripts/bullseye <<-'EOF'

mirror_style release
download_style apt
finddebs_style from-indices
variants - container fakechroot
keyring /usr/share/keyrings/debian-archive-keyring.gpg

if doing_variant fakechroot; then
	test "$FAKECHROOT" = "true" || error 1 FAKECHROOTREQ "This variant requires fakechroot environment to be started"
fi

case $ARCH in
	alpha|ia64) LIBC="libc6.1" ;;
	kfreebsd-*) LIBC="libc0.1" ;;
	hurd-*)     LIBC="libc0.3" ;;
	*)          LIBC="libc6" ;;
esac

work_out_debs () {
    # adduser in case users want to add a user to run as non-root
    # base-files as it has many important files
    # base-passwd to get user account info
    # bash because users will often shell in
    # bsdutils because it has some commands used in postinst
    #  - particularly `logger` for `mysql-server` see
    #    https://github.com/bitnami/minideb/issues/16
    # coreutils for many very common utilities
    # dash for a shell for scripts
    # debian-archive-keyring to verify apt packages
    # diffutils for diff as required for installing the system
    #  (could maybe be removed after, but diffing is pretty common in debugging)
    # dpkg for dpkg
    # findutils for find as required for installing the system
    # grep as it is a very common debugging tool
    # gzip as decompressing zip is super common
    # hostname ?
    # libc-bin for ldconfig
    # login as su maybe used if run as non root (?)
    # lsb-base ?
    # mawk as it is used by dpkg
    # ncurses-base for terminfo files as docker sets TERM=xterm
    #   see https://github.com/bitnami/minideb/issues/17
    # passwd for managing user accounts if run as non-root.
    # sed as a very commonly used tool
    # sysv-rc for update-rc.d, required when installing initscripts in postinsts
    # tar as uncompressing tarballs is super common when installing things.
    # tzdata for handling timezones
    # util-linux for getopt
    # mount is required for mounting /proc during debootstrap
	required="adduser base-files base-passwd bash bsdutils coreutils dash debian-archive-keyring diffutils dpkg findutils grep gzip hostname init-system-helpers libc-bin login lsb-base mawk ncurses-base passwd sed sysv-rc tar tzdata util-linux mount"

	base="apt"

	if doing_variant fakechroot; then
		# ldd.fake needs binutils
		required="$required binutils"
	fi

	case $MIRRORS in
	    https://*)
		base="$base apt-transport-https ca-certificates"
		;;
	esac
}

first_stage_install () {
	extract $required

	mkdir -p "$TARGET/var/lib/dpkg"
	: >"$TARGET/var/lib/dpkg/status"
	: >"$TARGET/var/lib/dpkg/available"

	setup_etc
	if [ ! -e "$TARGET/etc/fstab" ]; then
		echo '# UNCONFIGURED FSTAB FOR BASE SYSTEM' > "$TARGET/etc/fstab"
		chown 0:0 "$TARGET/etc/fstab"; chmod 644 "$TARGET/etc/fstab"
	fi

	setup_devices

	x_feign_install () {
		local pkg="$1"
		local deb="$(debfor $pkg)"
		local ver="$(extract_deb_field "$TARGET/$deb" Version)"

		mkdir -p "$TARGET/var/lib/dpkg/info"

		echo \
"Package: $pkg
Version: $ver
Maintainer: unknown
Status: install ok installed" >> "$TARGET/var/lib/dpkg/status"

		touch "$TARGET/var/lib/dpkg/info/${pkg}.list"
	}

	x_feign_install dpkg
}

second_stage_install () {
	setup_dynamic_devices

	x_core_install () {
		smallyes '' | in_target dpkg --force-depends --install $(debfor "$@")
	}

	p () {
		baseprog="$(($baseprog + ${1:-1}))"
	}

	if doing_variant fakechroot; then
		setup_proc_fakechroot
	else
		setup_proc
		in_target /sbin/ldconfig
	fi

	DEBIAN_FRONTEND=noninteractive
	DEBCONF_NONINTERACTIVE_SEEN=true
	export DEBIAN_FRONTEND DEBCONF_NONINTERACTIVE_SEEN

	baseprog=0
	bases=7

	p; progress $baseprog $bases INSTCORE "Installing core packages" #1
	info INSTCORE "Installing core packages..."

	p; progress $baseprog $bases INSTCORE "Installing core packages" #2
	ln -sf mawk "$TARGET/usr/bin/awk"
	x_core_install base-passwd
	x_core_install base-files
	p; progress $baseprog $bases INSTCORE "Installing core packages" #3
	x_core_install dpkg

	if [ ! -e "$TARGET/etc/localtime" ]; then
		ln -sf /usr/share/zoneinfo/UTC "$TARGET/etc/localtime"
	fi

	if doing_variant fakechroot; then
		install_fakechroot_tools
	fi

	p; progress $baseprog $bases INSTCORE "Installing core packages" #4
	x_core_install $LIBC

	p; progress $baseprog $bases INSTCORE "Installing core packages" #5
	x_core_install perl-base

	p; progress $baseprog $bases INSTCORE "Installing core packages" #6
	rm "$TARGET/usr/bin/awk"
	x_core_install mawk

	p; progress $baseprog $bases INSTCORE "Installing core packages" #7
	if doing_variant -; then
		x_core_install debconf
	fi

	baseprog=0
	bases=$(set -- $required; echo $#)

	info UNPACKREQ "Unpacking required packages..."

	exec 7>&1

	smallyes '' |
		(repeatn 5 in_target_failmsg UNPACK_REQ_FAIL_FIVE "Failure while unpacking required packages.  This will be attempted up to five times." "" \
		dpkg --status-fd 8 --force-depends --unpack $(debfor $required) 8>&1 1>&7 || echo EXITCODE $?) |
		dpkg_progress $baseprog $bases UNPACKREQ "Unpacking required packages" UNPACKING

	info CONFREQ "Configuring required packages..."

	echo \
"#!/bin/sh
exit 101" > "$TARGET/usr/sbin/policy-rc.d"
	chmod 755 "$TARGET/usr/sbin/policy-rc.d"

	mv "$TARGET/sbin/start-stop-daemon" "$TARGET/sbin/start-stop-daemon.REAL"
	echo \
"#!/bin/sh
echo
echo \"Warning: Fake start-stop-daemon called, doing nothing\"" > "$TARGET/sbin/start-stop-daemon"
	chmod 755 "$TARGET/sbin/start-stop-daemon"

	setup_dselect_method apt

	smallyes '' |
		(in_target_failmsg CONF_REQ_FAIL "Failure while configuring required packages." "" \
		dpkg --status-fd 8 --configure --pending --force-configure-any --force-depends 8>&1 1>&7 || echo EXITCODE $?) |
		dpkg_progress $baseprog $bases CONFREQ "Configuring required packages" CONFIGURING

	baseprog=0
	bases="$(set -- $base; echo $#)"

	info UNPACKBASE "Unpacking the base system..."

	setup_available $required $base
	done_predeps=
	while predep=$(get_next_predep); do
		# We have to resolve dependencies of pre-dependencies manually because
		# dpkg --predep-package doesn't handle this.
		predep=$(without "$(without "$(resolve_deps $predep)" "$required")" "$done_predeps")
		# XXX: progress is tricky due to how dpkg_progress works
		# -- cjwatson 2009-07-29
		p; smallyes '' |
		in_target dpkg --force-overwrite --force-confold --skip-same-version --install $(debfor $predep)
		base=$(without "$base" "$predep")
		done_predeps="$done_predeps $predep"
	done

	smallyes '' |
		(repeatn 5 in_target_failmsg INST_BASE_FAIL_FIVE "Failure while installing base packages.  This will be re-attempted up to five times." "" \
		dpkg --status-fd 8 --force-overwrite --force-confold --skip-same-version --unpack $(debfor $base) 8>&1 1>&7 || echo EXITCODE $?) |
		dpkg_progress $baseprog $bases UNPACKBASE "Unpacking base system" UNPACKING

	info CONFBASE "Configuring the base system..."

	smallyes '' |
		(repeatn 5 in_target_failmsg CONF_BASE_FAIL_FIVE "Failure while configuring base packages.  This will be re-attempted up to five times." "" \
		dpkg --status-fd 8 --force-confold --skip-same-version --configure -a 8>&1 1>&7 || echo EXITCODE $?) |
		dpkg_progress $baseprog $bases CONFBASE "Configuring base system" CONFIGURING

	mv "$TARGET/sbin/start-stop-daemon.REAL" "$TARGET/sbin/start-stop-daemon"
	rm -f "$TARGET/usr/sbin/policy-rc.d"

	progress $bases $bases CONFBASE "Configuring base system"
	info BASESUCCESS "Base system installed successfully."
}
EOF
chmod +x /usr/share/debootstrap/scripts/bullseye

cat > /root/start.sh << 'EOL'

ROOT=$(cd "$(dirname "$0")" && TMPDIR="$(pwd)" mktemp -d)

TARGET=${1:?Specify the target filename}
DIST=${2:-stable}
PLATFORM=${3:-$(dpkg --print-architecture)}

LOGFILE=${TARGET}.log

:>"$LOGFILE"
exec >  >(tee -ia "$LOGFILE")
exec 2> >(tee -ia "$LOGFILE" >&2)

DEBOOTSTRAP_DIR="$ROOT"/debootstrap
mkdir -p $DEBOOTSTRAP_DIR
cp -a /usr/share/debootstrap/* "$DEBOOTSTRAP_DIR"
cp -a /usr/share/keyrings/debian-archive-keyring.gpg "$DEBOOTSTRAP_DIR"

KEYRING=$DEBOOTSTRAP_DIR/debian-archive-keyring.gpg

use_qemu_static() {
    [[ "$PLATFORM" == "arm64" && ! ( "$(uname -m)" == *arm* || "$(uname -m)" == *aarch64* ) ]]
}

export DEBIAN_FRONTEND=noninteractive

DIRS_TO_TRIM="/usr/share/man
/var/cache/apt
/var/lib/apt/lists
/usr/share/locale
/var/log
/usr/share/info
/dev
"

debootstrap_arch_args=( )

if use_qemu_static ; then
    debootstrap_arch_args+=( --arch "$PLATFORM" )
fi

rootfsDir="$ROOT"/rootfs
mkdir -p $rootfsDir

# debootstrap first-stage (downloading debs phase) dont support multiplesuits/multipcomponets (just singlemainsuit/multipcomponets)
# but we can divide debootstrap to two explict steps, and apply full-mirror fix and chroot apt-get upgrade after second_stage
repo_url="https://snapshot.debian.org/archive/debian/20231007T024024Z"
sec_repo_url="https://snapshot.debian.org/archive/debian-security/20231007T024024Z"

echo "Building base in $rootfsDir"
DEBOOTSTRAP_DIR="$DEBOOTSTRAP_DIR" debootstrap "${debootstrap_arch_args[@]}"  --keyring "$KEYRING" --variant container --foreign "${DIST}" "$rootfsDir" "$repo_url"

# get path to "chroot" in our current PATH
chrootPath="$(type -P chroot)"
rootfs_chroot() {
    # "chroot" doesn't set PATH, so we need to set it explicitly to something our new debootstrap chroot can use appropriately!
    # set PATH and chroot away!
    PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
            "$chrootPath" "$rootfsDir" "$@"

}

if use_qemu_static ; then
    echo "Setting up qemu static in chroot"
    usr_bin_modification_time=$(stat -c %y "$rootfsDir"/usr/bin)
    if [ -f "/usr/bin/qemu-aarch64-static" ]; then
        find /usr/bin/ -type f -name 'qemu-*-static' -exec cp {} "$rootfsDir"/usr/bin/. \;
    else
        echo "Cannot find aarch64 qemu static. Aborting..." >&2
        exit 1
    fi
    touch -d "$usr_bin_modification_time" "$rootfsDir"/usr/bin
fi

rootfs_chroot bash debootstrap/debootstrap --second-stage

echo -e "deb ${repo_url} $DIST main" > "$rootfsDir/etc/apt/sources.list"
echo "deb ${repo_url} $DIST-updates main" >> "$rootfsDir/etc/apt/sources.list"
echo "deb ${sec_repo_url} $DIST-security main" >> "$rootfsDir/etc/apt/sources.list"


rootfs_chroot apt-get update -o Acquire::Check-Valid-Until=false
rootfs_chroot apt-get upgrade -y -o Dpkg::Options::="--force-confdef"

rootfs_chroot dpkg -l | tee "$TARGET.manifest"

echo "Applying docker-specific tweaks"
# These are copied from the docker contrib/mkimage/debootstrap script.
# Modifications:
#  - remove `strings` check for applying the --force-unsafe-io tweak.
#     This was sometimes wrongly detected as not applying, and we aren't
#     interested in building versions that this guard would apply to,
#     so simply apply the tweak unconditionally.


# prevent init scripts from running during install/update
echo >&2 "+ echo exit 101 > '$rootfsDir/usr/sbin/policy-rc.d'"
cat > "$rootfsDir/usr/sbin/policy-rc.d" <<-'EOF'
	#!/bin/sh
	# For most Docker users, "apt-get install" only happens during "docker build",
	# where starting services doesn't work and often fails in humorous ways. This
	# prevents those failures by stopping the services from attempting to start.
	exit 101
EOF
chmod +x "$rootfsDir/usr/sbin/policy-rc.d"

# prevent upstart scripts from running during install/update
(
	set -x
	rootfs_chroot dpkg-divert --local --rename --add /sbin/initctl
	cp -a "$rootfsDir/usr/sbin/policy-rc.d" "$rootfsDir/sbin/initctl"
	sed -i 's/^exit.*/exit 0/' "$rootfsDir/sbin/initctl"
)

# shrink a little, since apt makes us cache-fat (wheezy: ~157.5MB vs ~120MB)
( set -x; rootfs_chroot apt-get clean )

# this file is one APT creates to make sure we don't "autoremove" our currently
# in-use kernel, which doesn't really apply to debootstraps/Docker images that
# don't even have kernels installed
rm -f "$rootfsDir/etc/apt/apt.conf.d/01autoremove-kernels"

# force dpkg not to call sync() after package extraction (speeding up installs)
echo >&2 "+ echo force-unsafe-io > '$rootfsDir/etc/dpkg/dpkg.cfg.d/docker-apt-speedup'"
cat > "$rootfsDir/etc/dpkg/dpkg.cfg.d/docker-apt-speedup" <<-'EOF'
# For most Docker users, package installs happen during "docker build", which
# doesn't survive power loss and gets restarted clean afterwards anyhow, so
# this minor tweak gives us a nice speedup (much nicer on spinning disks,
# obviously).
force-unsafe-io
EOF

if [ -d "$rootfsDir/etc/apt/apt.conf.d" ]; then
	# _keep_ us lean by effectively running "apt-get clean" after every install
	aptGetClean='"rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true";'
	echo >&2 "+ cat > '$rootfsDir/etc/apt/apt.conf.d/docker-clean'"
	cat > "$rootfsDir/etc/apt/apt.conf.d/docker-clean" <<-EOF
		# Since for most Docker users, package installs happen in "docker build" steps,
		# they essentially become individual layers due to the way Docker handles
		# layering, especially using CoW filesystems.  What this means for us is that
		# the caches that APT keeps end up just wasting space in those layers, making
		# our layers unnecessarily large (especially since we'll normally never use
		# these caches again and will instead just "docker build" again and make a brand
		# new image).
		# Ideally, these would just be invoking "apt-get clean", but in our testing,
		# that ended up being cyclic and we got stuck on APT's lock, so we get this fun
		# creation that's essentially just "apt-get clean".
		DPkg::Post-Invoke { ${aptGetClean} };
		APT::Update::Post-Invoke { ${aptGetClean} };
		Dir::Cache::pkgcache "";
		Dir::Cache::srcpkgcache "";
		# Note that we do realize this isn't the ideal way to do this, and are always
		# open to better suggestions (https://github.com/docker/docker/issues).
	EOF

	# remove apt-cache translations for fast "apt-get update"
	echo >&2 "+ echo Acquire::Languages 'none' > '$rootfsDir/etc/apt/apt.conf.d/docker-no-languages'"
	cat > "$rootfsDir/etc/apt/apt.conf.d/docker-no-languages" <<-'EOF'
		# In Docker, we don't often need the "Translations" files, so we're just wasting
		# time and space by downloading them, and this inhibits that.  For users that do
		# need them, it's a simple matter to delete this file and "apt-get update". :)
		Acquire::Languages "none";
	EOF

	echo >&2 "+ echo Acquire::GzipIndexes 'true' > '$rootfsDir/etc/apt/apt.conf.d/docker-gzip-indexes'"
	cat > "$rootfsDir/etc/apt/apt.conf.d/docker-gzip-indexes" <<-'EOF'
		# Since Docker users using "RUN apt-get update && apt-get install -y ..." in
		# their Dockerfiles don't go delete the lists files afterwards, we want them to
		# be as small as possible on-disk, so we explicitly request "gz" versions and
		# tell Apt to keep them gzipped on-disk.
		# For comparison, an "apt-get update" layer without this on a pristine
		# "debian:wheezy" base image was "29.88 MB", where with this it was only
		# "8.273 MB".
		Acquire::GzipIndexes "true";
		Acquire::CompressionTypes::Order:: "gz";
	EOF

	# update "autoremove" configuration to be aggressive about removing suggests deps that weren't manually installed
	echo >&2 "+ echo Apt::AutoRemove::SuggestsImportant 'false' > '$rootfsDir/etc/apt/apt.conf.d/docker-autoremove-suggests'"
	cat > "$rootfsDir/etc/apt/apt.conf.d/docker-autoremove-suggests" <<-'EOF'
		# Since Docker users are looking for the smallest possible final images, the
		# following emerges as a very common pattern:
		#   RUN apt-get update \
		#       && apt-get install -y <packages> \
		#       && <do some compilation work> \
		#       && apt-get purge -y --auto-remove <packages>
		# By default, APT will actually _keep_ packages installed via Recommends or
		# Depends if another package Suggests them, even and including if the package
		# that originally caused them to be installed is removed.  Setting this to
		# "false" ensures that APT is appropriately aggressive about removing the
		# packages it added.
		# https://aptitude.alioth.debian.org/doc/en/ch02s05s05.html#configApt-AutoRemove-SuggestsImportant
		Apt::AutoRemove::SuggestsImportant "false";
	EOF
fi

cat > "$rootfsDir/usr/sbin/install_packages" <<-'EOF'
#!/bin/sh
set -e
set -u
export DEBIAN_FRONTEND=noninteractive
n=0
max=2
until [ $n -gt $max ]; do
    set +e
    (
      apt-get update -qq &&
      apt-get install -y --no-install-recommends "$@"
    )
    CODE=$?
    set -e
    if [ $CODE -eq 0 ]; then
        break
    fi
    if [ $n -eq $max ]; then
        exit $CODE
    fi
    echo "apt failed, retrying"
    n=$(($n + 1))
done
rm -r /var/lib/apt/lists /var/cache/apt/archives
EOF
chmod 0755 "$rootfsDir/usr/sbin/install_packages"

# Set the password change date to a fixed date, otherwise it defaults to the current
# date, so we get a different image every day. SOURCE_DATE_EPOCH is designed to do this, but
# was only implemented recently, so we can't rely on it for all versions we want to build
# We also have to copy over the backup at /etc/shadow- so that it doesn't change
chroot "$rootfsDir" getent passwd | cut -d: -f1 | xargs -n 1 chroot "$rootfsDir" chage -d 17885 && cp "$rootfsDir/etc/shadow" "$rootfsDir/etc/shadow-"

# Clean /etc/hostname and /etc/resolv.conf as they are based on the current env, so make
# the chroot different. Docker doesn't care about them, as it fills them when starting
# a container
echo "" > "$rootfsDir/etc/resolv.conf"
echo "host" > "$rootfsDir/etc/hostname"

# Capture the most recent date that a package in the image was changed.
# We don't care about the particular date, or which package it comes from,
# we just need a date that isn't very far in the past.

# We get multiple errors like:
# gzip: stdout: Broken pipe
# dpkg-parsechangelog: error: gunzip gave error exit status 1
#
# TODO: Why?
set +o pipefail
BUILD_DATE="$(find "$rootfsDir/usr/share/doc" -name changelog.Debian.gz -print0 | xargs -0 -n1 -I{} dpkg-parsechangelog -SDate -l'{}' | xargs -l -i date --date="{}" +%s | sort -n | tail -n 1)"
set -o pipefail


echo "Trimming down"
for DIR in $DIRS_TO_TRIM; do
  rm -r "${rootfsDir:?rootfsDir cannot be empty}/$DIR"/*
done
# Remove the aux-cache as it isn't reproducible. It doesn't seem to
# cause any problems to remove it.
rm "$rootfsDir/var/cache/ldconfig/aux-cache"
# Remove /usr/share/doc, but leave copyright files to be sure that we
# comply with all licenses.
# `mindepth 2` as we only want to remove files within the per-package
# directories. Crucially some packages use a symlink to another package
# dir (e.g. libgcc1), and we don't want to remove those.
find "$rootfsDir/usr/share/doc" -mindepth 2 -not -name copyright -not -type d -delete
find "$rootfsDir/usr/share/doc" -mindepth 1 -type d -empty -delete
# Set the mtime on all files to be no older than $BUILD_DATE.
# This is required to have the same metadata on files so that the
# same tarball is produced. We assume that it is not important
# that any file have a newer mtime than this.
find "$rootfsDir" -depth -newermt "@$BUILD_DATE" -print0 | xargs -0r touch --no-dereference --date="@$BUILD_DATE"
echo "Total size"
du -skh "$rootfsDir"
echo "Package sizes"
# these aren't shell variables, this is a template, so override sc thinking these are the wrong type of quotes
# shellcheck disable=SC2016
chroot "$rootfsDir" dpkg-query -W -f '${Package} ${Installed-Size}\n'
echo "Largest dirs"
du "$rootfsDir" | sort -n | tail -n 20
echo "Built in $rootfsDir"

if use_qemu_static ; then
    echo "Cleaning up qemu static files from image"
    usr_bin_modification_time=$(stat -c %y "$rootfsDir"/usr/bin)
    rm -rf "$rootfsDir"/usr/bin/qemu-*-static
    touch -d "$usr_bin_modification_time" "$rootfsDir"/usr/bin
fi

tar cpzf "$TARGET" -C "$rootfsDir" ./

echo "Image built at ${TARGET}"

outDir="$rootfsDir"/packages_dump
mkdir -p "$outDir/main" "$outDir/main-updates" "$outDir/main-security"

cat > "$rootfsDir"/1.sh <<-'EOF'
#!/bin/bash
set -e

dumpdir="packages_dump"
urlencode() {
    local string="${1}"
    local encoded=""
    local pos c o
    for ((pos=0 ; pos<${#string} ; pos++)); do
        c=${string:$pos:1}
        case "$c" in
            [a-zA-Z0-9.~_-]) o="${c}" ;;
            *) o=$(printf '%%%02X' "'$c") ;;
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# 1. 分析并输出三列，然后移动文件
dpkg-query -W -f='${Package}\t${Version}\t${Architecture}\n' | while read pkg ver arch; do
  ver_no_epoch=$(echo "$ver" | sed 's/^[0-9]\+://')
  debfile_no_epoch="${pkg}_${ver_no_epoch}_${arch}.deb"
  ver_urlenc="${ver/:/%3a}"
  debfile_epoch_urlenc="${pkg}_${ver_urlenc}_${arch}.deb"
  debpath="/var/cache/apt/archives/${debfile_epoch_urlenc}"

  origin=$(apt-cache policy "$pkg" | grep -E 'http.*main' | head -n1)
  if echo "$origin" | grep -q "security"; then
    repo="main-security"
  elif echo "$origin" | grep -q "updates"; then
    repo="main-updates"
  else
    repo="main"
  fi
  echo -e "${pkg}\t${debfile_no_epoch}\t${repo}"

  if [ -f "$debpath" ]; then
    mv "$debpath" "$dumpdir/$repo/"
  else
    echo "Failed $debfile_epoch_urlenc" && exit 1
  fi

done

apt-get update -o Acquire::Check-Valid-Until=false
apt-get install -y curl xz-utils

arch=$(dpkg --print-architecture)
url_check() {
  http_status=$(curl -o /dev/null -s -w "%{http_code}\n" "$1")
  if [ "$http_status" != 200 -a "$http_status" != 301 -a "$http_status" != 302 -a "$http_status" != 307 -a "$http_status" != 308 ]; then
    echo "1"
  fi
}
extract_mini_release() {
    local input="$1"
    local output="$2"

    awk -v arch="$arch" '
    BEGIN{in_md5=0;in_sha256=0;}
    /^Architectures:/ { print "Architectures: all " arch; next }
    /^Components:/ { print "Components: main"; next }

    /^Origin:/ || /^Label:/ || /^Suite:/ || /^Version:/ || /^Codename:/ ||
    /^Changelogs:/ || /^Date:/ || /^Acquire-By-Hash:/ || /^No-Support-for-Architecture-all:/ ||
    /^Description:/ { print; next }

    /^MD5Sum:/ { print; in_md5=1; next }
    in_md5 && (index($0, "main/binary-" arch "/")>0) { print; next }
    in_md5 && $0 ~ /^[A-Za-z]/ { in_md5=0; }

    /^SHA256:/ { print; in_sha256=1; next }
    in_sha256 && (index($0, "main/binary-" arch "/")>0) { print; next }
    in_sha256 && $0 ~ /^[A-Za-z]/ { in_sha256=0; }
    ' "$input" > "$output"
}
urldecode() {
    local url="$1"
    printf '%b' "${url//%3a/:}"
}
extract_mini_package() {
    local src="$1"
    local dst="$2"
    local repo_dir
    repo_dir=$(dirname "$src")

    > "$dst"

    find "$repo_dir" -type f -name "*.deb" | sort | while read debfile; do
        fname=$(basename "$debfile" .deb)
        pkg=$(echo "$fname" | awk -F'_' '{print $1}')
        ver=$(echo "$fname" | awk -F'_' '{print $2}')
        arch=$(echo "$fname" | awk -F'_' '{print $3}')
        ver_decoded=$(urldecode "$ver")

        # DEBUG
        echo "Searching for: Package=$pkg Version=$ver_decoded Arch=$arch"

        awk -v pkg="$pkg" -v arch="$arch" -v ver="$ver_decoded" '
            BEGIN { RS=""; FS="\n" }
            {
                p=""; v=""; a="";
                for(i=1;i<=NF;i++) {
                    if ($i ~ /^Package:[ ]*/) { p=$i; sub(/^Package:[ ]*/, "", p) }
                    if ($i ~ /^Version:[ ]*/) { v=$i; sub(/^Version:[ ]*/, "", v) }
                    if ($i ~ /^Architecture:[ ]*/) { a=$i; sub(/^Architecture:[ ]*/, "", a) }
                }
                if (p==pkg && a==arch && v==ver) { print; print "" }
            }
        ' "$src" >> "$dst"
    done
}

# 2. 解析 /etc/apt/sources.list，下载 Packages 和 Release 文件到对应子文件夹
grep -E '^deb ' /etc/apt/sources.list | while read line; do
  url=$(echo $line | awk '{print $2}')
  suite=$(echo $line | awk '{print $3}')
  component=$(echo $line | awk '{print $4}')

  # 只处理main相关仓库
  if [ "$component" != "main" ]; then
    continue
  fi
  # 判断repo类型
  if echo $url | grep -q "security" || echo "$suite" | grep -q "security"; then
    repo="main-security"
  elif echo $suite | grep -q "updates"; then
    repo="main-updates"
  else
    repo="main"
  fi

  # binary-arch/package is superset of binary-all/package, so always get binary-arch/package files
  pkgurl="${url}/dists/${suite}/${component}/binary-${arch}/Packages.gz"
  pkgunzip="gzip -dc"
  if [ "$(url_check "$pkgurl")" = "1" ]; then
    pkgurl="${url}/dists/${suite}/${component}/binary-${arch}/Packages.xz"
    pkgunzip="xz -dc"
  fi
  releaseurl="${url}/dists/${suite}/Release"
  curl -sSL "$pkgurl" | $pkgunzip > "$dumpdir/$repo/Packages_ori" || { echo "Failed $pkgurl" && exit 1; }
  extract_mini_package "$dumpdir/$repo/Packages_ori" "$dumpdir/$repo/Packages"
  curl -sSL "$releaseurl" -o "$dumpdir/$repo/Release_ori" || { echo "Failed $releaseurl" && exit 1; }
  extract_mini_release "$dumpdir/$repo/Release_ori" "$dumpdir/$repo/Release"

done
EOF

echo "composite a debmini repo"
rootfs_chroot bash 1.sh
echo "Total size"
du -skh "$outDir"
echo "Built in $outDir"
EOL
chmod +x /root/start.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
