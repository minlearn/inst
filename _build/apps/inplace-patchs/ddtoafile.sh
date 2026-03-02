
slipgrubcfgs(){
  # some dedicated servers need by-uuid but not by-devicename,so we use the regluar one
  # and in orcarm platform, in case there is a no suitable video mode found error
  cat > $chrootdir/boot/grub/grub.cfg <<'EOF'
### BEGIN /etc/grub.d/00_header ###
if [ -s $prefix/grubenv ]; then
  set have_grubenv=true
  load_env
fi
if [ "${next_entry}" ] ; then
   set default="${next_entry}"
   set next_entry=
   save_env next_entry
   set boot_once=true
else
   set default="0"
fi

if [ x"${feature_menuentry_id}" = xy ]; then
  menuentry_id_option="--id"
else
  menuentry_id_option=""
fi

export menuentry_id_option

if [ "${prev_saved_entry}" ]; then
  set saved_entry="${prev_saved_entry}"
  save_env saved_entry
  set prev_saved_entry=
  save_env prev_saved_entry
  set boot_once=true
fi

function savedefault {
  if [ -z "${boot_once}" ]; then
    saved_entry="${chosen}"
    save_env saved_entry
  fi
}
function load_video {
  if [ x$feature_all_video_module = xy ]; then
    insmod all_video
  else
    insmod efi_gop
    insmod efi_uga
    insmod ieee1275_fb
    insmod vbe
    insmod vga
    insmod video_bochs
    insmod video_cirrus
  fi
}
## added to template 00_header
# load common disk partation and file system
function load_sas {
  insmod part_gpt
  insmod part_msdos
  insmod exfat
  insmod ext2
  insmod fat
  insmod iso9660
  insmod btrfs
  insmod lvm
  insmod dm_nv
  insmod mdraid09_be
  insmod mdraid09
  insmod mdraid1x
  insmod raid5rec
  insmod raid6rec
}
#Set superuser and password
set superusers=admin
password_pbkdf2 admin grub.pbkdf2.sha512.10000.7E4B108C243BC281A5D40E3694F70B15FB7765487E0711BAD442657AB0D1094233ABA74A75DBBA3CA49FD4A658FF59A95E4C822790D17B3C290887E8B6D02842.E23AB60D6CAF38CFC75D1C65E8A817088883AF0A6C6A3864CAD6D2DF2AB15303A0AF981B9003B67FECEF1CA2BCB2F577B1B06881067B08315813FF3129C818DC
## end added to template 00_header

if [ x$feature_default_font_path = xy ] ; then
   font=unicode
else
  load_sas
  set root=(hd0,gptBOOTPARTNO)
  if [ x$feature_platform_search_hint = xy ]; then
    search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gptBOOTPARTNO --hint-efi=hd0,gptBOOTPARTNO --hint-baremetal=ahci0,gptBOOTPARTNO BOOTFSUUID
  else
    search --no-floppy --fs-uuid --set=root BOOTFSUUID
  fi
  font="/usr/share/grub/unicode.pf2"
fi

if loadfont $font ; then
  set gfxmode=auto
  load_video
  insmod gfxterm
  set locale_dir=$prefix/locale
  set lang=en_US
  insmod gettext
fi
terminal_output gfxterm
if [ "${recordfail}" = 1 ] ; then
  set timeout=30
else
  if [ x$feature_timeout_style = xy ] ; then
    set timeout_style=menu
    set timeout=5
  # Fallback normal timeout code in case the timeout_style feature is
  # unavailable.
  else
    set timeout=5
  fi
fi
### END /etc/grub.d/00_header ###

### BEGIN /etc/grub.d/05_debian_theme ###
load_sas
set root=(hd0,gptBOOTPARTNO)
if [ x$feature_platform_search_hint = xy ]; then
  search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gptBOOTPARTNO --hint-efi=hd0,gptBOOTPARTNO --hint-baremetal=ahci0,gptBOOTPARTNO BOOTFSUUID
else
  search --no-floppy --fs-uuid --set=root BOOTFSUUID
fi
insmod png
if background_image /usr/share/desktop-base/futureprototype-theme/grub/grub-4x3.png; then
  set color_normal=white/black
  set color_highlight=black/white
else
  set menu_color_normal=cyan/blue
  set menu_color_highlight=white/blue
fi
### END /etc/grub.d/05_debian_theme ###

### BEGIN /etc/grub.d/10_linux ###
function gfxmode {
	set gfxpayload="${1}"
}
set linux_gfx_mode=
export linux_gfx_mode
menuentry 'start devdeskos' --unrestricted --class debian --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-BOOTFSUUID' {
	load_video
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	load_sas
	set root=(hd0,gptBOOTPARTNO)
	if [ x$feature_platform_search_hint = xy ]; then
	  search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gptBOOTPARTNO --hint-efi=hd0,gptBOOTPARTNO --hint-baremetal=ahci0,gptBOOTPARTNO BOOTFSUUID
	else
	  search --no-floppy --fs-uuid --set=root BOOTFSUUID
	fi
	echo	'Loading ...'
	linux	/vmlinuz root=UUID=ROOTFSUUID console=ttyS0,115200n8 console=tty0 net.ifnames=0 biosdevname=0 live=core slax.flags=perch cgroup_enable=memory cgroup_memory=1 swapaccount=1 ro quiet
	initrd	/initrfs.img
}
menuentry 'start devdeskos (gui)' --unrestricted --class debian --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-BOOTFSUUID' {
	load_video
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	load_sas
	set root=(hd0,gptBOOTPARTNO)
	if [ x$feature_platform_search_hint = xy ]; then
	  search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gptBOOTPARTNO --hint-efi=hd0,gptBOOTPARTNO --hint-baremetal=ahci0,gptBOOTPARTNO BOOTFSUUID
	else
	  search --no-floppy --fs-uuid --set=root BOOTFSUUID
	fi
	echo	'Loading ...'
	linux	/vmlinuz root=UUID=ROOTFSUUID console=ttyS0,115200n8 console=tty0 net.ifnames=0 biosdevname=0 live=gui slax.flags=perch cgroup_enable=memory cgroup_memory=1 swapaccount=1 ro quiet
	initrd	/initrfs.img
}
submenu 'start devdeskos recovery' --users admin $menuentry_id_option 'gnulinux-advanced-BOOTFSUUID' {
	echo "dangerous area,please be clear what you are doing before 100s auto enter,or press esc to quick confirm..."
	echo
	echo
	if sleep --interruptible 100 ; then
	  set timeout=0
	fi
	menuentry 'reinstall devdeskos' --class debian --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-5.10.0-22-amd64-advanced-BOOTFSUUID' {
		load_video
		insmod gzio
		if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
		load_sas
		set root=(hd0,gptBOOTPARTNO)
		if [ x$feature_platform_search_hint = xy ]; then
		  search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gptBOOTPARTNO --hint-efi=hd0,gptBOOTPARTNO --hint-baremetal=ahci0,gptBOOTPARTNO  BOOTFSUUID
		else
		  search --no-floppy --fs-uuid --set=root BOOTFSUUID
		fi
		echo	'Loading ...'
		linux	/vmlinuz root=UUID=ROOTFSUUID console=ttyS0,115200n8 console=tty0 net.ifnames=0 biosdevname=0 debian-installer/framebuffer=false DEBIAN_FRONTEND=text auto=true hostname=debian domain= -- quiet
		initrd	/initrfs.img
	}
	menuentry 'erase data volume' --class debian --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-5.10.0-22-amd64-recovery-BOOTFSUUID' {
		load_video
		insmod gzio
		if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
		load_sas
		set root=(hd0,gptBOOTPARTNO)
		if [ x$feature_platform_search_hint = xy ]; then
		  search --no-floppy --fs-uuid --set=root --hint-bios=hd0,gptBOOTPARTNO --hint-efi=hd0,gptBOOTPARTNO --hint-baremetal=ahci0,gptBOOTPARTNO BOOTFSUUID
		else
		  search --no-floppy --fs-uuid --set=root BOOTFSUUID
		fi
		echo	'Loading ...'
		linux	/vmlinuz root=UUID=ROOTFSUUID ro single
		initrd	/initrfs.img
	}
}
### END /etc/grub.d/10_linux ###
EOF

  cat > $chrootdir/boot/EFI/boot/grub.cfg <<'EOF'
# redirect only the grub files to let two set of grub shedmas coexists
search --label "ROM" --set root
configfile ($root)/grub/grub.cfg
EOF
}
sliplinuxlive(){
           # slip begin

  sed -e "/esac/i\\\t\\tlive=*)\n\t\t\tinit=/init-live\${i#live=} ;;" -i p4/extracted/init

  cat > p4/extracted/init-livecore <<'EOF'
#!/bin/sh
# Initial script for Linux Live Kit
# Author: Tomas M <http://www.linux-live.org/>

export PATH=.:/:/usr/sbin:/usr/bin:/sbin:/bin

. /lib/debian-live/config
. /lib/debian-live/livekitlib

transfer_initramfs

exp=1
expfull=01-core

MEMORY=/run/memory
CHANGES=$MEMORY/changes$exp
UNION=$MEMORY/union
SYSMNT=$MEMORY/sys
DATAMNT=$MEMORY/data
BUNDLES=$MEMORY/bundles
# you can also use a separated datavol holding changes,add here the logics instead of use above intree memory/changes,and patch the persistent_changes to mount it
# MEMORY2=/data
# CHANGES2=$MEMORY2/changes


header "$LIVEKITNAME init <https://minlearn.org/1kdd/>"

init_proc_sysfs

debug_start
                                                                                                                                                       debug_shell
# load some modules manually first, then modprobe everything we have
init_devs
init_aufs
init_zram

# modprobe all devices excluding network drivers
modprobe_everything
#modprobe_everything -v /drivers/net/

# find data dir with filesystem bundles
SYS="$(find_data 5 "$SYSMNT" "$LIVEKITNAME" "01-core")"
check_data_found "$SYS"
# infact we can directly calc the next volname based on sysmnt to dertermin the data dir here, hence reducing boot time
DATA="$(find_data 5 "$DATAMNT" "$LIVEKITNAME"d "changes1")"
check_data_found "$DATA"
                                                                                                                                                      debug_shell
# setup persistent changes, if possible
persistent_changes "$DATA" "$CHANGES"
                                                                                                                                                      debug_shell
# copy to RAM if needed
DATA="$(copy_to_ram "$DATA" "$CHANGES")"
                                                                                                                                                      debug_shell
# init aufs union
init_union "$CHANGES" "$UNION" "$exp"
                                                                                                                                                      debug_shell
# only for aufs,just comment
# add data to union
# mount -o remount,add:1:"$DATA/01-core" aufs "$UNION"
# union_append_bundles "$DATA" "$BUNDLES" "$UNION"
                                                                                                                                                      debug_shell
# rootcopy
#copy_rootcopy_content /initrd "$UNION"
# mount -o remount,add:1:/initrd aufs "$UNION"

# create fstab
fstab_create "$UNION" "$DATAMNT"
                                                                                                                                                      debug_shell
header "$LIVEKITNAME init done, starting os"
change_root "$UNION"

header "!!ERROR occured, you shouldn't be here.!!"
/bin/sh
EOF
  cat > p4/extracted/init-livegui <<'EOF'
#!/bin/sh
# Initial script for Linux Live Kit
# Author: Tomas M <http://www.linux-live.org/>

export PATH=.:/:/usr/sbin:/usr/bin:/sbin:/bin

. /lib/debian-live/config
. /lib/debian-live/livekitlib

transfer_initramfs

exp=2
expfull=02-gui

MEMORY=/run/memory
CHANGES=$MEMORY/changes$exp
UNION=$MEMORY/union
SYSMNT=$MEMORY/sys
DATAMNT=$MEMORY/data
BUNDLES=$MEMORY/bundles
# you can also use a separated datavol holding changes,add here the logics instead of use above intree memory/changes,and patch the persistent_changes to mount it
# MEMORY2=/data
# CHANGES2=$MEMORY2/changes


header "$LIVEKITNAME init <https://minlearn.org/1kdd/>"

init_proc_sysfs

debug_start
                                                                                                                                                       debug_shell
# load some modules manually first, then modprobe everything we have
init_devs
init_aufs
init_zram

# modprobe all devices excluding network drivers
modprobe_everything
#modprobe_everything -v /drivers/net/

# find data dir with filesystem bundles
SYS="$(find_data 5 "$SYSMNT" "$LIVEKITNAME" "01-core")"
check_data_found "$SYS"
# infact we can directly calc the next volname based on sysmnt to dertermin the data dir here, hence reducing boot time
DATA="$(find_data 5 "$DATAMNT" "$LIVEKITNAME"d "changes1")"
check_data_found "$DATA"
                                                                                                                                                      debug_shell
# setup persistent changes, if possible
persistent_changes "$DATA" "$CHANGES"
                                                                                                                                                      debug_shell
# copy to RAM if needed
DATA="$(copy_to_ram "$DATA" "$CHANGES")"
                                                                                                                                                      debug_shell
# init aufs union
init_union "$CHANGES" "$UNION" "$exp"
                                                                                                                                                      debug_shell
# only for aufs,just comment
# add data to union
# mount -o remount,add:1:"$DATA/01-core" aufs "$UNION"
# union_append_bundles "$DATA" "$BUNDLES" "$UNION"
                                                                                                                                                      debug_shell
# rootcopy
#copy_rootcopy_content /initrd "$UNION"
# mount -o remount,add:1:/initrd aufs "$UNION"

# create fstab
fstab_create "$UNION" "$DATAMNT"
                                                                                                                                                      debug_shell
header "$LIVEKITNAME init done, starting os"
change_root "$UNION"

header "!!ERROR occured, you shouldn't be here.!!"
/bin/sh
EOF
  # cp -aR /home/runner/work/minlearnmonorepobuild/minlearnmonorepobuild/p/inst/lib-debian-live/debian-live lib
  mkdir -p p4/extracted/lib/debian-live/
  cat > p4/extracted/lib/debian-live/config <<'EOF'
#!/bin/bash
# This is a config file for Linux Live Kit build script.
# You shouldn't need to change anything expect LIVEKITNAME

# Live Kit Name. Defaults to 'linux';
# This will be the name of the directory created on your CD/USB, which
# will contain everything including boot files and such.
# For example, Slax changes it to 'slax'
# Must not contain any spaces.
# If you change it, you must run ./tools/isolinux.bin.update script
# in order to update isolinux.bin for CD booting.
# If you do not need booting from CD (eg you're booting only from USB)
# then you can ignore recompiling isolinux.bin, just rename LIVEKITNAME
# and you're done.
LIVEKITNAME="onekeydevdesk"

# Kernel file, will be copied to your Live Kit
# Your kernel must support aufs and squashfs. Debian Jessie's kernel is ready
# out of the box.
VMLINUZ=/vmlinuz

# Kernel version. Change it to "3.2.28" for example, if you are building
# Live Kit with a different kernel than the one you are actually running
KERNEL=$(uname -r)

# List of directories for root filesystem
# No subdirectories are allowed, no slashes,
# so You can't use /var/tmp here for example
# Exclude directories like proc sys tmp
MKMOD="bin etc home lib lib64 opt root sbin srv usr var"

# If you require network support in initrd, for example to boot over
# PXE or to load data using 'from' boot parameter from a http server,
# you will need network modules included in your initrd.
# This is disabled by default since most people won't need it.
# To enable, set to true
NETWORK=false

# Temporary directory to store livekit filesystem
LIVEKITDATA=/tmp/$LIVEKITNAME-data-$$

# Bundle extension, for example 'sb' for .sb extension
BEXT=ldeb

# Directory with kernel .ko modules, can be different in some distros
LMK="lib/modules/$KERNEL"
EOF
  cat > p4/extracted/lib/debian-live/livekitlib <<'EOF'
#!/bin/sh

# Functions library :: for Linux Live Kit scripts
# Author: Tomas M. <http://www.linux-live.org>
#

# =================================================================
# debug and output functions
# =================================================================

debug_start()
{
   if grep -q debug /proc/cmdline; then
      DEBUG_IS_ENABLED=1
      set -x
   else
      DEBUG_IS_ENABLED=
   fi
}

debug_log()
{
   if [ "$DEBUG_IS_ENABLED" ]; then
      echo "- debug: $*" >&2
      log "- debug: $*"
   fi
}

# header
# $1 = text to show
#
header()
{
   echo "[0;1m""$@""[0;0m"
}


# echo green star
#
echo_green_star()
{
   echo -ne "[0;32m""* ""[0;39m"
}

# log - store given text in /var/log/livedbg
log()
{
   echo "$@" 2>/dev/null >>/var/log/livedbg
}

echolog()
{
   echo "$@"
   log "$@"
}


# show information about the debug shell
show_debug_banner()
{
   echo
   echo "====="
   echo ": Debugging started. Here is the root shell for you."
   echo ": Type your desired commands or hit Ctrl+D to continue booting."
   echo
}


# debug_shell
# executed when debug boot parameter is present
#
debug_shell()
{
   if [ "$DEBUG_IS_ENABLED" ]; then
      show_debug_banner
      setsid sh -c 'exec sh < /dev/tty1 >/dev/tty1 2>&1'
      echo
   fi
}

fatal()
{
   echolog
   header "Fatal error occured - $1"
   echolog "Something went wrong and we can't continue. This should never happen."
   echolog "Please reboot your computer with Ctrl+Alt+Delete ..."
   echolog
   setsid sh -c 'exec sh < /dev/tty1 >/dev/tty1 2>&1'
}


# get value of commandline parameter $1
# $1 = parameter to search for
#
cmdline_value()
{
   cat /proc/cmdline | egrep -o "(^|[[:space:]])$1=[^[:space:]]+" | tr -d " " | cut -d "=" -f 2- | tail -n 1
}


# test if the script is started by root user. If not, exit
#
allow_only_root()
{
  if [ "0$UID" -ne 0 ]; then
     echo "Only root can run $(basename $0)"; exit 1
  fi
}


# Create bundle
# call mksquashfs with apropriate arguments
# $1 = directory which will be compressed to squashfs bundle
# $2 = output file
# $3..$9 = optional arguments like -keep-as-directory or -b 123456789
#
create_bundle()
{
   debug_log "create_module" "$*"
   rm -f "$2" # overwrite, never append to existing file
   mksquashfs "$1" "$2" -comp xz -b 1024K -always-use-fragments $3 $4 $5 $6 $7 $8 $9>/dev/null
}


# Move entire initramfs tree to tmpfs mount.
# It's a bit tricky but is necessray to enable pivot_root
# even for initramfs boot image
#
transfer_initramfs()
{
   if [ ! -r /lib/initramfs_escaped ]; then
      echo "switch root from initramfs to ramfs"
      SWITCH=/m # one letter directory
      mkdir -p $SWITCH
      mount -t tmpfs -o size="100%" tmpfs $SWITCH

      #cp -a /??* $SWITCH 2>/dev/null # only copy two-and-more-letter directories
      mkdir -p $SWITCH/dev $SWITCH/proc $SWITCH/run $SWITCH/tmp $SWITCH/sys # $SWITCH/initrd
      cp -a /bin /etc /lib /lib64 /media /mnt /sbin /usr /var /init* $SWITCH # only copy two-and-more-letter directories
      cp /dev/null $SWITCH/dev
      mknod -m666 $SWITCH/dev/console c 5 1
      # mv /initrd/* $SWITCH/initrd

      cd $SWITCH
      echo "This file indicates that we successfully escaped initramfs" > $SWITCH/lib/initramfs_escaped
      # exec switch_root . /bin/sh
      exec switch_root -c /dev/console . $0
   fi
}


# mount virtual filesystems like proc etc
#
init_proc_sysfs()
{
   debug_log "init_proc_sysfs" "$*"
   mkdir -p /proc /sys /etc $MEMORY
   mount -n -t proc proc /proc
   echo "0" >/proc/sys/kernel/printk
   mount -n -t sysfs sysfs /sys
   mount -n -o remount,rw rootfs /
   ln -sf /proc/mounts /etc/mtab
}


# modprobe all modules found in initial ramdisk
# $1 = -e for match, -v for negative match
# $2 = regex pattern
#
modprobe_everything()
{
   debug_log "modprobe_everything" "$*"

   echo_green_star >&2
   echo "Probing for hardware" >&2

   # find /lib/modules/ | fgrep .ko | egrep $1 $2 | sed -r "s:^.*/|[.]ko\$::g" | xargs -n 1 modprobe 2>/dev/null
   find /lib/modules/ | fgrep .ko | sed -r "s:^.*/|[.]ko\$::g" | sed "s/.ko//g" | xargs -n 1 modprobe 2>/dev/null
   refresh_devs
}


refresh_devs()
{
   debug_log "refresh_devs" "$*"
   #if [ -r /proc/sys/kernel/hotplug ]; then
   #   echo /sbin/mdev > /proc/sys/kernel/hotplug
   #fi
   #mdev -s
   /lib/debian-installer/start-udev
}


# make sure some devices are there
init_devs()
{
   debug_log "init_devs" "$*"
   modprobe zram 2>/dev/null
   modprobe loop 2>/dev/null
   modprobe squashfs 2>/dev/null
   modprobe fuse 2>/dev/null
   refresh_devs
}


# Activate zram (auto-compression of RAM)
# Compressed RAM consumes 1/2 or even 1/4 of original size
# Setup static size of 500MB
#
init_zram()
{
   debug_log "init_zram" "$*"
   echo_green_star
   echo "Setting dynamic RAM compression using ZRAM if available"
   if [ -r /sys/block/zram0/disksize ]; then
      echo 536870912 > /sys/block/zram0/disksize # 512MB
      mkswap /dev/zram0 >/dev/null
      swapon /dev/zram0
      echo 100 > /proc/sys/vm/swappiness
   fi
}


# load the AUFS kernel module if needed
#
init_aufs()
{
   debug_log "init_aufs" "$*"
   # TODO maybe check here if aufs support is working at all
   # and produce useful error message if user has no aufs
   modprobe overlay 2>/dev/null
   refresh_devs
}


# Setup empty union
# $1 = changes directory (ramfs or persistent changes)
# $2 = union directory where to mount the union
# $3 = coreonly,corewithgui?
#
init_union()
{
   debug_log "init_union" "$*"

   echo_green_star
   echo "Setting up union using AUFS"
   mkdir -p "$1/changes" "$1/workdir"
   mkdir -p "$2"
   # the lowerdirs order is important
   mount -t overlay overlay -o lowerdir=$(if [ $3 == 2 ]; then echo -n $SYS/02-gui:; fi)$SYS/01-core,upperdir=$1/changes,workdir=$1/workdir $2
}


# Return device mounted for given directory
# $1 = directory
#
mounted_device()
{
   debug_log "mounted_device" "$*"

   local MNT TARGET
   MNT="$1"
   while [ "$MNT" != "/" -a "$MNT" != "." -a "$MNT" != "" ]; do
      TARGET="$(grep -F " $MNT " /proc/mounts | cut -d " " -f 1)"
      if [ "$TARGET" != "" ]; then
         echo "$TARGET"
         return
      fi
      MNT="$(dirname "$MNT")"
   done
}


# Return mounted dir for given directory
# $1 = directory
#
mounted_dir()
{
   debug_log "mounted_dir" "$*"

   local MNT
   MNT="$1"
   while [ "$MNT" != "/" -a "$MNT" != "." -a "$MNT" != "" ]; do
      if mountpoint -q "$MNT" 2>/dev/null; then
         echo "$MNT"
         return
      fi
      MNT="$(dirname "$MNT")"
   done
}


# Get device tag.
# $1 = device
# $2 = tag name, such as TYPE, LABEL, UUID, etc
#
device_tag()
{
   blkid -s $2 "$1" | sed -r "s/^[^=]+=//" | tr -d '"'
}


# Make sure to mount FAT12/16/32 using vfat
# in order to support long filenames
# $1 = device
# $2 = prefix to add, like -t
#
device_bestfs()
{
   debug_log "device_bestfs" "$*"
   local FS

   FS="$(device_tag "$1" TYPE | tr [A-Z] [a-z])"
   if [ "$FS" = "msdos" -o "$FS" = "fat" -o "$FS" = "vfat" ]; then
      FS="vfat"
   elif [ "$FS" = "ntfs" ]; then
      FS="ntfs-3g"
   fi

   if [ "$2" != "" ]; then
      echo -n "$2"
   fi

   echo "$FS"
}


# Filesystem options for initial mount
# $1.. = filesystem
#
fs_options()
{
   debug_log "fs_options" "$*"

   if [ "$1" != "ntfs-3g" ]; then
      echo -n "-t $1 "
   fi

   echo -n "-o rw"

   if [ "$1" = "vfat" ]; then
      echo ",check=s,shortname=mixed,iocharset=utf8"
   fi
}


# Mount command for given filesystem
# $1.. = filesystem
#
mount_command()
{
   debug_log "mount_command" "$*"

   if [ "$1" = "ntfs-3g" ]; then
      echo "@mount.ntfs-3g"
   else
      echo "mount"
   fi
}


# echo first network device known at the moment of calling, eg. eth0
#
network_device()
{
   debug_log "network_device" "$*"
   cat /proc/net/dev | grep : | grep -v lo: | cut -d : -f 1 | tr -d " " | head -n 1
}


# Modprobe network kernel modules until a working driver is found.
# These drivers are (or used to be) probed in Slackware's initrd.
# The function returns the first device found, yet it doesn't have
# to be a working one, eg. if the computer has two network interfaces
# and ethernet cable is plugged only to one of them.
#
init_network_dev()
{
   debug_log "init_network_dev" "$*"
   local MODULE ETH

   for MODULE in 3c59x acenic e1000 e1000e e100 epic100 hp100 ne2k-pci \
   pcnet32 8139too 8139cp tulip via-rhine r8169 atl1e yellowfin tg3 \
   dl2k ns83820 atl1 b44 bnx2 skge sky2 tulip forcedeth sb1000 sis900; do
      modprobe $MODULE 2>/dev/null
      ETH="$(network_device)"
      if [ "$ETH" != "" ]; then
         echo $ETH
         return 0
      fi
      rmmod $MODULE 2>/dev/null
   done

   # If we are here, none of the above specified modules worked.
   # As a last chance, try to modprobe everything else
   modprobe_everything -e /drivers/net/
   echo $(network_device)
}


# Initialize network IP address
# either static from ip=bootparameter, or from DHCP
#
init_network_ip()
{
   debug_log "init_network_ip" "$*"
   local IP ETH SCRIPT CLIENT SERVER GW MASK

   SCRIPT=/tmp/dhcpscript
   ETH=$(init_network_dev)
   IP=$(cmdline_value ip)

   echo "* Setting up network" >&2

   if [ "$IP" != "" ]; then
      # set IP address as given by boot paramter
      echo "$IP" | while IFS=":" read CLIENT SERVER GW MASK; do
         ifconfig $ETH "$CLIENT" netmask "$MASK"
         route add default gw "$GW"
         echo nameserver "$GW" >> /etc/resolv.conf
         echo nameserver "$SERVER" >> /etc/resolv.conf
      done
   else
      # if client ip is unknown, try to get a DHCP lease
      ifconfig $ETH up
      echo -e '#!/bin/sh\nif [ "$1" != "bound" ]; then exit; fi\nifconfig $interface $ip netmask $subnet\nroute add default gw $router\necho nameserver $dns >>/etc/resolv.conf' >$SCRIPT
      chmod a+x $SCRIPT
      udhcpc -i $ETH -n -s $SCRIPT -q >/dev/null
   fi
}


# Mount data from http using httpfs
# $1 = from URL
# $2 = target
mount_data_http()
{
   debug_log "mount_data_http" "$*"
   local CACHE

   echo_green_star >&2
   echo "Load data from $1" >&2

   CACHE=$(cmdline_value cache | sed -r "s/[^0-9]//g" | sed -r "s/^0+//g")
   if [ "$CACHE" != "" ]; then
      CACHE="-C /tmp/httpfs.cache -S "$(($CACHE*1024*1024))
   fi

   init_network_ip

   if [ "$(network_device)" != "" ]; then
      echo "* Mounting remote file..." >&2
      mkdir -p "$2"
      @mount.httpfs2 -r 9999 -t 5 $CACHE -c /dev/null "$1" "$2" -o ro >/dev/null 2>/dev/null
      mount -o loop "$2"/* "$2" # self mount
      echo "$2/$LIVEKITNAME"
   fi
}


# stdin = files to get
# $1 = server
# $2 = destination directory
#
tftp_mget()
{
   while read FNAME; do
      echo "* $FNAME ..." >&2
      tftp -b 1486 -g -r "$FNAME" -l "$2/$FNAME" "$1"
   done
}


# Download data from tftp
# $1 = target (store downloaded files there)
#
download_data_pxe()
{
   debug_log "download_data_pxe" "$*"
   local IP CMD CLIENT SERVER GW MASK PORT PROTOCOL JOBS

   mkdir -p "$1/$LIVEKITNAME"
   IP="$(cmdline_value ip)"

   echo "$IP" | while IFS=":" read CLIENT SERVER GW MASK PORT; do
      echo_green_star >&2
      echo "Contacting PXE server $SERVER" >&2

      if [ "$PORT" = "" ]; then PORT="7529"; fi

      init_network_ip

      echo "* Downloading PXE file list" >&2

      PROTOCOL=http
      wget -q -O "$1/PXEFILELIST" "http://$SERVER:$PORT/PXEFILELIST?$(uname -r):$(uname -m)"
      if [ $? -ne 0 ]; then
         echo "Error downloading from http://$SERVER:$PORT, trying TFTP" >&2
         PROTOCOL=tftp
         echo PXEFILELIST | tftp_mget "$SERVER" "$1"
      fi

      echo "* Downloading files from the list" >&2

      if [ "$PROTOCOL" = "http" ]; then
         cat "$1/PXEFILELIST" | while read FILE; do
            wget -O "$1/$LIVEKITNAME/$FILE" "http://$SERVER:$PORT/$FILE"
         done
      else
         JOBS=3
         for i in $(seq 1 $JOBS); do
            awk "NR % $JOBS == $i-1" "$1/PXEFILELIST" | tftp_mget "$SERVER" "$1/$LIVEKITNAME" &
         done
         wait
      fi
   done

   echo "$1/$LIVEKITNAME"
}


# Find LIVEKIT data by mounting all devices
# If found, keep mounted, else unmount
# $1 = data directory target (mount here)
# $2 = src (from)
# $3 = src (container dir)
#
find_data_try()
{
   debug_log "find_data_try" "$*"

   local DEVICE FS FROM OPTIONS MOUNT

   mkdir -p "$1"
   blkid | sort | cut -d: -f 1 | grep -E -v "/loop|/ram|/zram" | while read DEVICE; do
      FROM="$2"
      FS="$(device_bestfs "$DEVICE")"
      OPTIONS="$(fs_options $FS)"
      MOUNT="$(mount_command $FS)"

      $MOUNT "$DEVICE" "$1" $OPTIONS 2>/dev/null

      # fix-arounds for zfs
      # mount -t zfs -o zfsutils zpool/root "$1" 2>/dev/null

      # if the FROM parameter is actual file, mount it again as loop (eg. iso)
      if [ -f "$1/$FROM" ]; then
         mkdir -p "$1/../iso"
         mount -o loop,ro "$1/$FROM" "$1/../iso" 2>/dev/null
         FROM="../iso/$LIVEKITNAME"
      fi

      # search for bundles in the mounted directory
      if [ "$(find "$1/$FROM" -maxdepth 1 -name "$3" 2>/dev/null)" != "" -o "$(find "$1/$FROM" -maxdepth 1 -name "*.$BEXT" 2>/dev/null)" != "" ]; then
         # we found at least one bundle/module here
         echo "$1/$FROM" | tr -s "/" | sed -r "s:/[^/]+/[.][.]/:/:g"
         return
      fi

      # unmount twice, since there could be mounted ISO as loop too. If not, it doesn't hurt
      umount "$1" 2>/dev/null
      umount "$1" 2>/dev/null
   done
}


# Retry finding LIVEKIT data several times,
# until timeouted or until data is found
# $1 = timeout
# $2 = data directory target (mount here)
# $3 = src (from)
# $4 = src (container dir)
#
find_data()
{
   debug_log "find_data" "$*"

   local DATA FROM

   # FROM="$(cmdline_value from)"
   FROM="$3"

   # boot parameter specified as from=http://server.com/file.iso
   if [ "$(echo $FROM | grep 'http://')" != "" ]; then
      mount_data_http "$FROM" "$2"
      return
   fi

   # if we got IP address as boot parameter, it means we booted over PXE
   if [ "$(cmdline_value ip)" != "" ]; then
      download_data_pxe "$2"
      return
   fi

   # if [ "$FROM" = "" ]; then FROM="$LIVEKITNAME"d; fi

   echo_green_star >&2
   echo -n "Looking for $LIVEKITNAME data in /$FROM .." | tr -s "/" >&2
   for timeout in $(seq 1 $1); do
      echo -n "." >&2
      refresh_devs
      DATA="$(find_data_try "$2" "$FROM" "$4")"
      if [ "$DATA" != "" ]; then
         echo "" >&2
         echo "* Found on $(mounted_device "$2")" >&2
         echo "$DATA"
         return
      fi
      sleep 1
   done
   echo "" >&2
}


# Check if data is found and exists
# $1 = data directory
#
check_data_found()
{
   if [ "$1" = "" -o ! -d "$1" ]; then
      fatal "Could not locate $LIVEKITNAME data";
   fi
}


# Activate persistent changes
# $1 = data directory
# $2 = target changes directory
#
persistent_changes()
{
   debug_log "persistent_changes" "$*"

   local CHANGES T1 T2 EXISTS

   CHANGES="$1/$(basename "$2")"
   T1="$CHANGES/.empty"
   T2="$T1"2

   # you can also use a separated datavol holding changes,add here the logics instead of use above intree memory/changes
   # a trick to fix blkid dont contain thindm bug
   # mount /dev/cl/data "$1" 2>/dev/null

   # Setup the directory anyway, it will be used in all cases
   mkdir -p "$2"

   # If persistent changes are not requested, end here
   if grep -vq perch /proc/cmdline; then
      return
   fi

   # check if changes directory exists and is writable
   touch "$T1" 2>/dev/null && rm -f "$T1" 2>/dev/null

   # if not, simply return back
   if [ $? -ne 0 ]; then
      echo "* Persistent changes not writable or not used"
      return
   fi

   echo_green_star
   echo "Testing persistent changes for posix compatibility"
   touch "$T1" && ln -sf "$T1" "$T2" 2>/dev/null && \
   chmod +x "$T1" 2>/dev/null && test -x "$T1" && \
   chmod -x "$T1" 2>/dev/null && test ! -x "$T1" && \
   rm "$T1" "$T2" 2>/dev/null

   if [ $? -eq 0 ]; then
      echo "* Activating native persistent changes"
      mount --bind "$CHANGES" "$2"
      return
   fi

   if [ -e "$CHANGES/changes.dat" ]; then
      echo "* Restoring persistent changes"
      EXISTS="true"
   else
      echo "* Creating new persistent changes"
      EXISTS=""
   fi

   @mount.dynfilefs "$CHANGES/changes.dat" 4000 "$2"
   if [ ! "$EXISTS" ]; then
      mke2fs -F "$2/loop.fs" >/dev/null 2>&1
   fi
   mount -o loop,sync "$2/loop.fs" "$2"

   # if test failed at any point, we may have temp files left behind
   rm "$T1" "$T2" 2>/dev/null
   rmdir "$2/lost+found" 2>/dev/null
}


# copy content of rootcopy directory to union
# $1 = data directory
# $2 = union directory
copy_rootcopy_content()
{
   debug_log "copy_rootcopy_content" "$*"

   #if [ "$(ls -1 "$1/rootcopy/" 2>/dev/null)" != "" ]; then
   if [ "$(ls -1 "$1" 2>/dev/null)" != "" ]; then
      echo_green_star
      echo "Copying content of rootcopy directory..."
      #cp -a "$1"/rootcopy/* "$2"
      cp -a "$1"/* "$2"
      rm -rf "$1"/*
   fi
}


# Copy data to RAM if requested
# $1 = live data directory
# $2 = changes directory
#
copy_to_ram()
{
   debug_log "copy_to_ram" "$*"

   local MDIR MDEV RAM CHANGES

   if grep -vq toram /proc/cmdline; then
      echo "$1"
      return
   fi

   echo "* Copying $LIVEKITNAME data to RAM..." >&2
   RAM="$(dirname "$2")"/toram
   mkdir  -p "$RAM"
   cp -a "$1"/* "$RAM"
   echo "$RAM"

   MDIR="$(mounted_dir "$1")"
   MDEV="$(mounted_device "$1")"
   MDEV="$(losetup $MDEV 2>/dev/null | cut -d " " -f 3)"
   umount "$MDIR" 2>/dev/null

   if [ "$MDEV" ]; then # iso was mounted here, try to unmount the FS it resides on too
      MDEV="$(mounted_device "$MDEV")"
      umount "$MDEV" 2>/dev/null
   fi
}


# load filter
#
filter_load()
{
   local FILTER
   FILTER=$(cmdline_value load)
   if [ "$FILTER" = "" ]; then
      cat -
   else
      cat - | egrep "$FILTER"
   fi
}


# noload filter
#
filter_noload()
{
   local FILTER
   FILTER=$(cmdline_value noload)
   if [ "$FILTER" = "" ]; then
      cat -
   else
      cat - | egrep -v "$FILTER"
   fi
}

# sort modules by number even if they are in subdirectory
#
sortmod()
{
   cat - | sed -r "s,(.*/(.*)),\\2:\\1," | sort -n | cut -d : -f 2-
}


# Mount squashfs filesystem bundles
# and add them to union
# $1 = directory where to search for bundles
# $2 = directory where to mount bundles
# $3 = directory where union is mounted
#
union_append_bundles()
{
   debug_log "union_append_bundles" "$*"

   local BUN

   echo_green_star
   echo "Adding bundles to union"
   ( ls -1 "$1" | sort -n ; cd "$1" ; find modules/ 2>/dev/null | sortmod | filter_load) | grep '[.]'$BEXT'$' | filter_noload | while read BUNDLE; do
      echo "* $BUNDLE"
      BUN="$(basename "$BUNDLE")"
      mkdir -p "$2/$BUN"
      mount -o loop,ro -t squashfs "$1/$BUNDLE" "$2/$BUN"
      mount -o remount,add:1:"$2/$BUN" aufs "$3"
   done
}


# Create empty fstab properly
# $1 = root directory
# $2 = directory where boot disk is mounted
#
fstab_create()
{
   debug_log "fstab_create" "$*"

   local FSTAB DEVICE FS LABEL BOOTDEVICE OPTS

   FSTAB="$1/etc/fstab"
   echo overlay / overlay defaults 0 0 > $FSTAB
   echo proc /proc proc defaults 0 0 >> $FSTAB
   echo sysfs /sys sysfs defaults 0 0 >> $FSTAB
   echo devpts /dev/pts devpts gid=5,mode=620 0 0 >> $FSTAB
   echo tmpfs /dev/shm tmpfs defaults 0 0 >> $FSTAB

   # ln -s /run/initramfs/lib/modules chrootdir/lib/modules should be correct to ensure here working
   # /boot use ro mount opts instead defaults to avoid possiable demage,but it will cause dd script cant remaster grubcfg file
   # mnt /data and swap will cause udev timeout and depend warn,so we comment and meant to fix it later

   ext2partno=$(blkid -t LABEL='ROM' -o device)
   if [ "$ext2partno" != "" ];then echo $ext2partno /boot ext2 defaults 0 2 >> $FSTAB;fi
   vfatpartno=$(blkid -t LABEL='ROM2' -o device)
   if [ "$vfatpartno" != "" ];then echo $vfatpartno /boot/efi vfat umask=0077 0 0 >> $FSTAB;fi
   syspartno=$(blkid -t LABEL='SYS' -o device)
   if [ "$syspartno" != "" ];then echo $syspartno /data/sys ext4 errors=remount-ro 0 1 >> $FSTAB;fi
   datapartno=$(blkid -t LABEL='DATA' -o device)
   if [ "$datapartno" != "" ];then echo $datapartno /data ext4 errors=remount-ro 0 1 >> $FSTAB;fi
   swappartno=$(blkid -t LABEL='SWAP' -o device)
   if [ "$swappartno" != "" ];then echo $swappartno none swap sw 0 0 >> $FSTAB;fi

   # forlvm
   # datapartno=\"\/dev\/mapper\/cl-root\"\n   if [ \"$datapartno\" != \"\" ];then echo $datapartno /data ext4 errors=remount-ro 0 1 >> $FSTAB;fi\n   swappartno=\"\/dev\/mapper\/cl-swap\"\n   if [ \"$swappartno\" != \"\" ];then echo $swappartno none swap sw 0 0 >> $FSTAB;fi
   # forzfs
   # datapartno=\"zpool\/root\"\n   if [ \"$datapartno\" != \"\" ];then echo $datapartno /data zfs zfsutil 0 1 >> $FSTAB;fi\n   swappartno=\"\/dev\/zpool\/swap\"\n   if [ \"$swappartno\" != \"\" ];then echo $swappartno none swap sw 0 0 >> $FSTAB;fi

   if grep -vq automount /proc/cmdline; then
      return
   fi

   BOOTDEVICE=$(df "$2" | tail -n 1 | cut -d " " -f 1)

   echo >> $FSTAB

   blkid | grep -v "^/dev/loop" | grep -v "^/dev/zram" | cut -d: -f 1 | while read DEVICE; do
      FS="$(device_bestfs $DEVICE)"
      LABEL="$(basename $DEVICE)"
      OPTS="defaults,noatime,nofail,x-systemd.device-timeout=10"

      if [ "$FS" != "" -a "$FS" != "swap" -a "$FS" != "squashfs" -a "$DEVICE" != "$BOOTDEVICE" ]; then
         mkdir -p "$1/media/$LABEL"
         echo "$DEVICE" "/media/$LABEL" $FS $OPTS 0 0 >> $FSTAB
      fi
   done
}


# Change root and execute init
# $1 = where to change root
#
change_root()
{
   debug_log "change_root" "$*"

   # if we are booting over httpfs, we need to copyup some files so they are
   # accessible on union without any further lookup down, else httpfs locks
   if [ "$(network_device)" != "" ]; then
      touch "/run/net.up.flag"
      touch "$1/etc/resolv.conf"
      touch "$1/etc/hosts"
      touch "$1/etc/gai.conf"
   fi

   umount /proc
   umount /sys

   cd "$1"

   # make sure important device files and directories are in union
   mkdir -p boot dev proc sys tmp media mnt run
   chmod 1777 tmp

   # because we plan to use di as initramfs+ctrlikerootfs for devdeskos, and wont use systemd/udev to popout dev nodes again in new rootfs, so just bind currents from before pivot_root, yet this cause no conflicts
   # if you use a rootfs with systemd/udev already included, dont use mount bind /dev dev for pivoted_rootfs
   mount --bind /dev dev
   #if [ ! -e dev/console ]; then mknod dev/console c 5 1; fi
   #if [ ! -e dev/tty ]; then mknod dev/tty c 5 0; fi
   #if [ ! -e dev/tty0 ]; then mknod dev/tty0 c 4 0; fi
   #if [ ! -e dev/tty1 ]; then mknod dev/tty1 c 4 1; fi
   #if [ ! -e dev/null ]; then mknod dev/null c 1 3; fi
   if [ ! -e sbin/fsck.aufs ]; then ln -s /bin/true sbin/fsck.aufs; fi

   # find chroot and init
   if [ -x bin/chroot -o -L bin/chroot ]; then  CHROOT=bin/chroot; fi
   if [ -x sbin/chroot -o -L sbin/chroot ]; then  CHROOT=sbin/chroot; fi
   if [ -x usr/bin/chroot -o -L usr/bin/chroot ]; then  CHROOT=usr/bin/chroot; fi
   if [ -x usr/sbin/chroot -o -L usr/sbin/chroot ]; then CHROOT=usr/sbin/chroot; fi
   if [ "$CHROOT" = "" ]; then fatal "Can't find executable chroot command"; fi

   if [ -x init -o -L init ]; then INIT=init; fi
   if [ -x bin/init -o -L bin/init ]; then INIT=bin/init; fi
   if [ -x sbin/init -o -L sbin/init  ]; then INIT=sbin/init; fi
   if [ "$INIT" = "" ]; then fatal "Can't find executable init command"; fi

   mkdir -p run
   mount -t tmpfs tmpfs run
   mkdir -p run/initramfs
   mount -n -o remount,ro overlay .

   #mount --bind / run/initramfs
   pivot_root . run/initramfs
   exec $CHROOT . $INIT < dev/console > dev/console 2>&1
}
EOF
  cat > p4/extracted/lib/debian-live/shutdown <<'EOF'
#!/bin/sh
# Shutdown script for initramfs. It's automatically started by
# systemd (if you use it) on shutdown, no need for any tweaks.
# Purpose of this script is to unmount everything cleanly.
#
# Author: Tomas M <http://www.linux-live.org/>
#

. /lib/config
. /lib/livekitlib

debug_start

debug_log "Entering shutdown procedures of Linux Live Kit"
debug_log "Called with arguments: " "$*"

# if debug is enabled, run shell now
debug_shell

detach_free_loops()
{
   losetup -a | cut -d : -f 1 | xargs -r -n 1 losetup -d
}

# $1=dir
umount_all()
{
   tac /proc/mounts | cut -d " " -f 2 | grep ^$1 | while read LINE; do
      umount $LINE 2>/dev/null
   done
}

# Update devs so we are aware of all active /dev/loop* files.
# Detach loop devices which are no longer used
debug_log "- Detaching loops"
mdev -s
detach_free_loops

# do it the dirty way, simply try to umount everything to get rid of most mounts
debug_log "- Unmounting submounts of union"
umount_all /oldroot

# free aufs of /run mount, and umount aufs
debug_log "- Unmounting union itself"
mkdir /run2
mount --move /oldroot/run /run2
umount /oldroot

# remember from which device we are started, so we can eject it later
DEVICE="$(cat /proc/mounts | grep /memory/data | grep /dev/ | cut -d " " -f 1)"

debug_log "- going through several cycles of umounts to clear everything left"
umount_all /run2
detach_free_loops
umount_all /run2
detach_free_loops
umount_all /run2

# eject cdrom device if we were running from it
for i in $(cat /proc/sys/dev/cdrom/info | grep name); do
   if [ "$DEVICE" = "/dev/$i" ]; then
      echo "[  OK  ] Attemptiong to eject /dev/$i..."
      eject /dev/$i
      echo "[  OK  ] CD/DVD tray will close in 6 seconds..."
      sleep 6
      eject -t /dev/$i
   fi
done

debug_shell

debug_log $1 -f
$1 -f

debug_log reboot -f
reboot -f

echo We should never reach so far. Something is totally fucked up.
echo Here you have a shell, to experiment with the universe.
/bin/sh
EOF
  chmod +x p4/extracted/init-livecore p4/extracted/init-livegui  p4/extracted/lib/debian-live/shutdown



  # sed -i '/modprobe[[:space:]]fuse[[:space:]]2>\/dev\/null/a    modprobe kvm 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]fuse[[:space:]]2>\/dev\/null/a    modprobe dm-mod 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  # sed -i '/modprobe[[:space:]]dm-mod[[:space:]]2>\/dev\/null/a    modprobe zfs 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]dm-mod[[:space:]]2>\/dev\/null/a    modprobe nls_ascii 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]nls_ascii[[:space:]]2>\/dev\/null/a    modprobe ahci 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]ahci[[:space:]]2>\/dev\/null/a    modprobe tun 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]tun[[:space:]]2>\/dev\/null/a    modprobe bridge 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]bridge[[:space:]]2>\/dev\/null/a    modprobe veth 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]veth[[:space:]]2>\/dev\/null/a    modprobe iptable_nat 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]iptable_nat[[:space:]]2>\/dev\/null/a    modprobe xt_MASQUERADE 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]xt_MASQUERADE[[:space:]]2>\/dev\/null/a    modprobe iptable_raw 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]iptable_raw[[:space:]]2>\/dev\/null/a    modprobe xt_CT 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]xt_CT[[:space:]]2>\/dev\/null/a    modprobe xt_nat 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]xt_nat[[:space:]]2>\/dev\/null/a    modprobe ipt_tcp 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]ipt_tcp[[:space:]]2>\/dev\/null/a    modprobe xt_tcpudp 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]xt_tcpudp[[:space:]]2>\/dev\/null/a    modprobe iptable_filter 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]iptable_filter[[:space:]]2>\/dev\/null/a    modprobe tcp_bbr 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]tcp_bbr[[:space:]]2>\/dev\/null/a    modprobe br_netfilter 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]br_netfilter[[:space:]]2>\/dev\/null/a    modprobe nfnetlink 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]nfnetlink[[:space:]]2>\/dev\/null/a    modprobe nf_conntrack_netlink 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]nf_conntrack_netlink[[:space:]]2>\/dev\/null/a    modprobe xt_addrtype 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]xt_addrtype[[:space:]]2>\/dev\/null/a    modprobe xt_conntrack 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]xt_conntrack[[:space:]]2>\/dev\/null/a    modprobe overlay 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]overlay[[:space:]]2>\/dev\/null/a    modprobe sunrpc 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]sunrpc[[:space:]]2>\/dev\/null/a    modprobe softdog 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i 's/init_zram/# init_zram/g' p4/extracted/init-livecore
  sed -i 's/init_zram/# init_zram/g' p4/extracted/init-livegui
  sed -i '/modprobe[[:space:]]softdog[[:space:]]2>\/dev\/null/a    modprobe ashmem_linux 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
  sed -i '/modprobe[[:space:]]ashmem_linux[[:space:]]2>\/dev\/null/a    modprobe binder_linux devices=binder,hwbinder,vndbinder 2>/dev/null' p4/extracted/lib/debian-live/livekitlib
           # slip end
}
ddtoafile(){

  tmpMNT="$topdir/mnt"
  tmpDEV=$(mount | grep "$tmpMNT" | awk '{print $1}')

  sleep 2s && echo -en "\n - clearing the scaffold image file: ..."

  umount -f -l "$tmpMNT"_p2 "$tmpMNT"_p3 >/dev/null 2>&1
  if mountpoint -q "$tmpMNT"_p2;then echo "$tmpMNT"_p2 still mounted && exit 1;fi
  if mountpoint -q "$tmpMNT"_p3;then echo "$tmpMNT"_p3 still mounted && exit 1;fi
  losetup -j "$topdir/imgscafford"|while read line;do sudo losetup -d `echo $line|awk '{print $1}'|sed 's/://'`;done
  losetup -j "$topdir/imgscafford (deleted)"|while read line;do sudo losetup -d `echo $line|awk '{print $1}'|sed 's/://'`;done
  rm -rf $topdir/imgscafford "$tmpMNT"_p2 "$tmpMNT"_p3

  sleep 2s && echo -en "\n - preparing the scaffold image file: ..."

  [ -z "$tmpDEV" ] && {

    dd if=/dev/zero of=$topdir/imgscafford bs=512 seek=`expr 2048 \* 1024 \* $custIMGSIZE` count=0 >/dev/null 2>&1
    tmpDEV=`losetup -fP --show $topdir/imgscafford | awk '{print $1}'`
    sleep 2s && echo -en "[ \033[32m dev:$tmpDEV \033[0m ]"
    
    [ -n "$tmpDEV" ] && {

#########edtion1
      # we must guarantee the 200m as fat32(not fat16) tagged and formatted both in mbr or gpt,or the linuxlive wont recongize it
      parted -s "$tmpDEV" mklabel gpt >/dev/null 2>&1 && \
      parted -s "$tmpDEV" \
      mkpart non-fs 2048s `echo $(expr 2048 \* 2 - 1)s` \
      mkpart rom    `echo $(expr 2048 \* 2)s` `echo $(expr 2048 \* 2 + 2048 \* 100 - 1)s` \
      mkpart rom2   `echo $(expr 2048 \* 2 + 2048 \* 100)s` `echo $(expr 2048 \* 2 + 2048 \* 200 - 1)s` \
      mkpart sys    `echo $(expr 2048 \* 2 + 2048 \* 200)s` `echo $(expr 2048 \* 2 + 2048 \* 200 + 2048 \* 1024 \* 1 - 1)s` \
      mkpart data   `echo $(expr 2048 \* 2 + 2048 \* 200 + 2048 \* 1024 \* 1)s` 95% \
      mkpart swap   95% 100% >/dev/null 2>&1 && \
      parted -s "$tmpDEV" set 1 bios_grub on set 1 hidden on set 2 boot on set 3 esp on >/dev/null 2>&1 && \
      mkfs.ext2 "$tmpDEV"p2 -L "ROM" >/dev/null 2>&1 && \
      mkfs.fat -F16 "$tmpDEV"p3 -n "ROM2" >/dev/null 2>&1 && \
      mkfs.ext4 "$tmpDEV"p4 -L "SYS" >/dev/null 2>&1 && \
      mkfs.ext4 "$tmpDEV"p5 -L "DATA" >/dev/null 2>&1 && \
      mkswap "$tmpDEV"p6 -L "SWAP" >/dev/null 2>&1
#########edtion2
           parted -s $hdinfo mklabel gpt
           parted -s $hdinfo mkpart non-fs 2048s `echo $(expr 2048 \* 2 - 1)s` mkpart rom `echo $(expr 2048 \* 2)s` `echo $(expr 2048 \* 2 + 2048 \* 100 - 1)s` mkpart rom2 `echo $(expr 2048 \* 2 + 2048 \* 100)s` `echo $(expr 2048 \* 2 + 2048 \* 200 - 1)s` mkpart sys `echo $(expr 2048 \* 2 + 2048 \* 200)s` `echo $(expr 2048 \* 2 + 2048 \* 200 + 2048 \* 1024 \* 1 - 1)s` mkpart data `echo $(expr 2048 \* 2 + 2048 \* 200 + 2048 \* 1024 \* 1)s` 95% mkpart swap 95% 100%
           # for lvm/zfs
           # parted -s $hdinfo mkpart non-fs 2048s 4095s mkpart rom 4096s 413695s mkpart rom2 413696s 823295s mkpart data 823296s 100%
           parted -s $hdinfo set 1 bios_grub on set 1 hidden on set 2 boot on set 3 esp on # set 4 lvm/zfs on ?
           # force fdisk w to noity the kernel (cause problems?), sometimes parted failed on this thus cause not found /dev/sda4 likehood error, we must use fdisk force noity the kernel when after reinit the disk
           ( printf 'w\n' | fdisk $hdinfo >/dev/null 2>&1 )
           # for lvm
           # ( lvm vgremove -y cl;vgcreate -y cl $hdinfoname"4";lvcreate -y cl --size +1G --name swap;lvcreate cl --type thin-pool --thinpool tpool --extents 100%FREE;thinsize=`expr \`vgdisplay cl|grep 'Alloc PE'|awk '{print $7}'|awk -F '.' '{print $1}'|grep -Eo [0-9].*\` - 1`;lvcreate cl --type thin --thinpool tpool --virtualsize $thinsize"G" --name root;lvcreate cl --type thin --thinpool tpool --virtualsize $thinsize"G" --name data )
           # forzfs
           # ( zpool destroy -f zpool;zpool create -o ashift=12 -m none -d -f zpool $hdinfoname"4";zfs set primarycache=metadata copies=1 compression=on checksum=on zpool;zfs create -b 4096 -V 1G -o logbias=throughput -o sync=always -o primarycache=metadata zpool/swap;zfs create -o mountpoint=none zpool/root;zfs create -o mountpoint=none zpool/data )

           mkfs.ext2 $hdinfoname"2" -L "ROM";mkdir p2;mount -t ext2 $hdinfoname"2" p2
           # this mustbe a fat16 not 32,or some machine firmware wont recongize it
           mkfs.fat -F16 $hdinfoname"3" -n "ROM2";mkdir p3;mount -t vfat $hdinfoname"3" p3
           ( mkfs.ext4 $hdinfoname"4" -L "SYS";mkfs.ext4 $hdinfoname"5" -L "DATA";mkswap $hdinfoname"6" -L "SWAP" );mkdir -p p4 p5;mount -t ext4 $hdinfoname"4" p4;mount -t ext4 $hdinfoname"5" p5
           # forlvm
           # ( mkswap /dev/cl/swap;mkfs.ext4 /dev/cl/root -L "ROOT";mkfs.ext4 /dev/cl/data -L "DATA" );mkdir -p p4;mount -t ext4 /dev/cl/root p4
           # forzfs
           # ( mkswap /dev/zd0 );mkdir -p p4;mount -t zfs -o zfsutils zpool/root p4
    }

    [ ! -d "$tmpMNT" ] && \
      mkdir -p "$tmpMNT"_p2 "$tmpMNT"_p3 "$tmpMNT"_p4 "$tmpMNT"_p5 && \
      mount "$tmpDEV"p2 "$tmpMNT"_p2 && mount "$tmpDEV"p3 "$tmpMNT"_p3 && mount "$tmpDEV"p4 "$tmpMNT"_p4 && mount "$tmpDEV"p5 "$tmpMNT"_p5
      sleep 2s && echo -en "[ \033[32m mnts: ""$tmpMNT"_p2" ""$tmpMNT"_p3" ""$tmpMNT"_p4" ""$tmpMNT"_p5" \033[0m ]"
  }

  sleep 2s && echo -en "\n - processing the scaffold image file: ..."

  ######edition1
  cat $topdir/$downdir/vmlinuz >> "$tmpMNT"_p2/vmlinuz
  cat $topdir/$downdir/initrfs.img >> "$tmpMNT"_p2/initrfs.img
  cat $topdir/$downdir/x.xz|tar Jx -C "$tmpMNT"_p4

  #mv "$tmpMNT"_p4/01-core/boot/grub "$tmpMNT"_p2
  #mv "$tmpMNT"_p4/01-core/boot/EFI "$tmpMNT"_p3
  chrootdir=$topdir/$remasteringdir/onekeydevdeskd/01-core

  mkdir -p $chrootdir/boot/grub $chrootdir/boot/EFI/boot

  ar -p $topdir/$downdir/debianbase/dists/bullseye/main/binary-amd64/deb/grub-pc-bin_2.06-3~deb11u5_amd64.deb data.tar.xz |xzcat|tar -xf - -C $chrootdir/boot ./usr/lib/grub/ --strip-components=3
  ar -p $topdir/$downdir/debianbase/dists/bullseye/main/binary-amd64/deb/grub-efi-amd64-bin_2.06-3~deb11u5_amd64.deb data.tar.xz |xzcat|tar -xf - -C $chrootdir/boot ./usr/lib/grub/ --strip-components=3

  mkdir -p $chrootdir/boot/grub/fonts
  ar -p $topdir/$downdir/debianbase/dists/bullseye/main/binary-amd64/deb/grub-common_2.06-3~deb11u5_amd64.deb data.tar.xz |xzcat|tar -xf - -C $chrootdir/boot/grub/fonts ./usr/share/grub/unicode.pf2 --strip-components=4
  slipgrubcfgs

  mkdir -p "$tmpMNT"_p4/onekeydevdesk
  mv "$tmpMNT"_p4/01-core "$tmpMNT"_p4/02-gui "$tmpMNT"_p4/onekeydevdesk

  [[ $tmpHOSTARCH == '0' ]] && grub-mkimage -C xz -O i386-pc -o "$tmpMNT"_p2/grub/i386-pc/core.img -p "(hd0,gpt2)/grub" -d "$tmpMNT"_p2/grub/i386-pc biosdisk part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec
  [[ $tmpHOSTARCH == '0' ]] && "$tmpMNT"_p2/grub/i386-pc/grub-bios-setup -d "$tmpMNT"_p2/grub/i386-pc -b boot.img -c core.img "$tmpDEV"
  [[ $tmpHOSTARCH == '0' ]] && grub-mkimage -C xz -O x86_64-efi -o "$tmpMNT"_p3/EFI/boot/bootx64.efi -p "(hd0,gpt2)/grub" -d "$tmpMNT"_p2/grub/x86_64-efi part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec || grub-mkimage -C xz -O arm64-efi -o "$tmpMNT"_p3/EFI/boot/bootaa64.efi -p "(hd0,gpt2)/grub" -d "$tmpMNT"_p2/grub/arm64-efi part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec

  bootfsuuid=`blkid -s UUID -o value "$tmpDEV"p2`
  rootfsuuid=`blkid -s UUID -o value "$tmpDEV"p5`
  # dont -e s/ROOTFSUUID/$rootfsuuid/g or the grubmenu wont show
  sed -e s/BOOTPARTNO/2/g -e s/BOOTFSUUID/$bootfsuuid/g -e s/ROOTFSUUID/$rootfsuuid/g -i "$tmpMNT"_p2/grub/grub.cfg
  #sed -e s/BOOTFSUUID/$bootfsuuid/g -e s/UEFIFSUUID/$uefifsuuid/g -e s/SWAPFSUUID/$swapfsuuid/g -e s/ROOTFSUUID/$rootfsuuid/g -i $remasteringdir/fstab
  mkdir -p "$tmpMNT"_p2/efi "$tmpMNT"_p5/sys "$tmpMNT"_p5/dockerd "$tmpMNT"_p5/onekeydevdeskd "$tmpMNT"_p5/onekeydevdeskd/changes1 "$tmpMNT"_p5/onekeydevdeskd/changes2 "$tmpMNT"_p5/onekeydevdeskd/updates
  mkdir -p "$tmpMNT"_p4/onekeydevdesk/01-core/var/lib/lxcfs "$tmpMNT"_p4/onekeydevdesk/01-core/var/lib/dhcp "$tmpMNT"_p4/onekeydevdesk/01-core/var/lib/rrdcached/db

  ######edition2
  #choosevmlinuz=`echo "$corefiles" | awk -F ',' '{ print $1}'`
  #chooseinitrfs=`echo "$corefiles" | awk -F ',' '{ print $2}'`
  #chooseonekeydevdeskd1=`echo "$corefiles" | awk -F ',' '{ print $3}'`
  #chooseonekeydevdeskd2=`echo "$corefiles" | awk -F ',' '{ print $4}'`
  #(for i in `seq -w 0 999`;do wget -qO- --no-check-certificate '$chooseonekeydevdeskd1'_$i.chunk; done)|tar Jxv -C p4 > /var/log/progress & pid=`expr $! + 0`;echo $pid;(for i in `seq -w 0 099`;do wget -qO- --no-check-certificate '$chooseonekeydevdeskd2'_$i.chunk; done)|tar Jx -C p4;(for i in `seq -w 0 029`;do wget -qO- --no-check-certificate '$choosevmlinuz'_$i.chunk; done)|cat - >> p4/vmlinuz;(for i in `seq -w 0 049`;do wget -qO- --no-check-certificate '$chooseinitrfs'_$i.chunk; done)|cat - >> p4/initrfs.img
           mkdir -p p4/extracted
           (cd p4/extracted;xz -d -q -c ../../p4/initrfs.img | cpio -idm;rm -rf ../../p4/initrfs.img)
           #sliplinuxlive
           (cd p4/extracted;find . -print | cpio -o -H newc --quiet | xz -f --extreme --check=crc32 > ../../p4/initrfs.img)
           rm -rf p4/extracted

           mv p4/vmlinuz p4/initrfs.img p4/01-core/boot/grub p2
           mv p4/01-core/boot/EFI p3 
           mkdir -p p4/onekeydevdesk
           mv p4/01-core p4/02-gui p4/onekeydevdesk

           [ "$(arch)" != "aarch64" ] && grub-mkimage -C xz -O i386-pc -o p2/grub/i386-pc/core.img -p "(hd0,gpt2)/grub" -d p2/grub/i386-pc biosdisk part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec
           [ "$(arch)" != "aarch64" ] && grub-bios-setup -d p2/grub/i386-pc -b boot.img -c core.img $hdinfo
           [ "$(arch)" != "aarch64" ] && grub-mkimage -C xz -O x86_64-efi -o p3/EFI/boot/bootx64.efi -p "(hd0,gpt2)/grub" -d p2/grub/x86_64-efi part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec || grub-mkimage -C xz -O arm64-efi -o p3/EFI/boot/bootaa64.efi -p "(hd0,gpt2)/grub" -d p2/grub/arm64-efi part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec
           bootfsuuid=`blkid -s UUID -o value $hdinfoname"2"`
           rootfsuuid=`echo $hdinfoname"5"`
           # forlvm
           # rootfsuuid="\/dev\/mapper\/cl-root"
           # forzfs
           # rootfsuuid="zpool\/root"
           sed -e s/BOOTPARTNO/2/g -e s/BOOTFSUUID/$bootfsuuid/g -e s#UUID=ROOTFSUUID#$rootfsuuid#g -i p2/grub/grub.cfg
           #for auto mounts /boot,/boot/efi,/data,swap on dymic generated /etc/fstab
           mkdir -p p2/efi p5/sys p5/dockerd p5/onekeydevdeskd p5/onekeydevdeskd/changes1 p5/onekeydevdeskd/changes2 p5/onekeydevdeskd/updates
           mkdir -p p4/onekeydevdesk/01-core/var/lib/lxcfs p4/onekeydevdesk/01-core/var/lib/dhcp p4/onekeydevdesk/01-core/var/lib/rrdcached/db
           umount p2 p3 p4 p5
  > $topdir/start.txt
  tee -a $topdir/start.txt > /dev/null <<EOF
#for linux
# -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS.fd
qemu-system-x86_64 -accel kvm -accel tcg -machine q35 -smp 2 -m 1G \\
-vga std -usbdevice tablet -usbdevice keyboard -drive "file=./imgscafford,format=raw" -net nic,model=virtio-net-pci -net user \\
-boot order=c,menu=on

#for osx
# -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS.fd
qemu-system-x86_64 -accel hvf -accel tcg -machine q35 -smp 2 -m 1G \\
-vga std -usbdevice tablet -usbdevice keyboard -drive "file=./imgscafford,format=raw" -net nic,model=virtio-net-pci -net vmnet-shared \\
-boot order=c,menu=on

#for win
# -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS.fd
"C:\Program Files\qemu\qemu-system-x86_64" -accel whpx -accel tcg -machine q35 -smp 2 -m 1G ^
-vga std -usbdevice tablet -usbdevice keyboard -drive "file=./imgscafford,format=raw" -net nic,model=virtio-net-pci -net user ^
-boot order=c,menu=on
EOF

}
