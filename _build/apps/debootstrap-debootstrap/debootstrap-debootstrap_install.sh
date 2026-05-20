###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get -y install debootstrap

cat > /usr/share/debootstrap/scripts/bullseye <<-'EOF'

USER_MIRROR="https://snapshot.debian.org/archive/debian/20231007T024024Z"

mirror_style release
download_style apt
finddebs_style from-indices
variants - custom
keyring /usr/share/keyrings/debian-archive-keyring.gpg

work_out_debs () {
	base="dpkg busybox libc-bin base-files"
}

first_stage_install () {
	extract $base

    # if no bbx and etc/passwd for root, "chroot" need manually set PATH, because no busybox and etc/passwd
	# like this: rootfs_chroot() { PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' chroot "$rootfsDir" "$@" }
	setup_bb_for_chroot () {
		for p in cat chmod chown cp diff echo env grep less ln mkdir mount rm rmdir sed sh sleep sort touch uname mktemp; do ln -s busybox "$TARGET/bin/$p"; done
		echo root:x:0:0:root:/root:/bin/sh > "$TARGET/etc/passwd"
    		printf "root:x:0:\nmail:x:8:\nutmp:x:43:\n" > "$TARGET/etc/group"
	}
	setup_bb_for_chroot

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
	    # in_target to chroot, "$@" to /var/*.deb
		smallyes '' | chroot "$TARGET" sh -c "dpkg --force-depends --install /var/cache/apt/archives/*.deb"
	}

	setup_proc
	in_target /sbin/ldconfig
	DEBIAN_FRONTEND=noninteractive
	DEBCONF_NONINTERACTIVE_SEEN=true
	export DEBIAN_FRONTEND DEBCONF_NONINTERACTIVE_SEEN

	info INSTCORE "Installing core packages..."
	ln -sf mawk "$TARGET/usr/bin/awk"
	x_core_install
	if [ ! -e "$TARGET/etc/localtime" ]; then
		ln -sf /usr/share/zoneinfo/UTC "$TARGET/etc/localtime"
	fi

    echo host > "$TARGET/etc/hostname"
    echo "127.0.0.1 localhost host" > "$TARGET/etc/hosts"

	info BASESUCCESS "Base system installed successfully."
}
EOF
chmod +x /usr/share/debootstrap/scripts/bullseye

cat > /root/start.sh << 'EOL'

repo_url="https://snapshot.debian.org/archive/debian/20231007T024024Z"
sec_repo_url="https://snapshot.debian.org/archive/debian-security/20231007T024024Z"

rootfsDir=debootstrap
# rootfs_chroot() { PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' chroot "$rootfsDir" "$@" }
DIRS_TO_TRIM="/usr/share/man
/var/cache/apt
/var/lib/apt/lists
/usr/share/locale
/var/log
/usr/share/info
/dev
"

cd /root

echo "debootstraping"
rm -rf $rootfsDir
mkdir -p $rootfsDir
# debootstrap first-stage (downloading debs phase) dont support multiplesuits/multipcomponets (just singlemainsuit/multipcomponets)
# but we can divide debootstrap to two explict steps, and apply full-mirror fix and chroot apt-get upgrade after second_stage
# like below (but we dont include apt as base pkg, so those dont work and commented)
# debootstrap --verbose --no-check-gpg --no-check-certificate --variant=custom --foreign amd64 bullseye $rootfsDir $repo_url
# rootfs_chroot bash debootstrap/debootstrap --second-stage
# echo -e "deb ${repo_url} bullseye main" > "$rootfsDir/etc/apt/sources.list"
# echo "deb ${repo_url} bullseye-updates main" >> "$rootfsDir/etc/apt/sources.list"
# echo "deb ${sec_repo_url} bullseye-security main" >> "$rootfsDir/etc/apt/sources.list"
# rootfs_chroot apt-get update
# rootfs_chroot apt-get upgrade -y
debootstrap --verbose --no-check-gpg --no-check-certificate --variant=custom --arch amd64 bullseye $rootfsDir $repo_url
echo "debootstraped"

echo "trimming"
for DIR in $DIRS_TO_TRIM; do
  rm -rf "$rootfsDir/$DIR"/*
done
rm "$rootfsDir/var/cache/ldconfig/aux-cache"
find "$rootfsDir/usr/share/doc" -mindepth 2 -not -name copyright -not -type d -delete
find "$rootfsDir/usr/share/doc" -mindepth 1 -type d -empty -delete
echo "trimmed"

echo "Total size"
du -skh "$rootfsDir"
echo "Largest dirs"
du "$rootfsDir" | sort -n | tail -n 20

EOL
chmod +x /root/start.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
