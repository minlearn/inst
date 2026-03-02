#!/bin/sh

. /usr/share/debconf/confmodule
debconf-loadtemplate my_script /longrunpipebgcmd_redirectermoniter.templates

corefiles=$1
RLSMIRROR=`echo "$corefiles" | awk -F ',' '{ print $1}'`
TARGETDDURL=`echo "$corefiles" | awk -F ',' '{ print $2}'`
DEBVER=`echo "$corefiles" | awk -F ',' '{ print $3}'`
UNZIP=`echo "$corefiles" | awk -F ',' '{ print $4}'`
codename=`case $DEBVER in 10)echo buster;;11)echo bullseye;;12)echo bookworm;;esac`

hd=$2
# exit 0 is important when there is more than 1 block,it may failed
hdinfo=`[ \`echo "$hd"|grep "nonlinux"\` ] && echo \`lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)' | head -n 1 | sed 's|^|/dev/|'\` || { [ \`echo "$hd"|grep "sd\|vd\|xvd\|nvme"\` ] && echo /dev/"$hd" || ( for i in \`lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)'  | sed 's|^|/dev/|'\`;do [ \`sfdisk --disk-id $i|sed s/0x// |grep -ix $hd \` ] && echo $i;done|head -n1;exit 0; ); }`
# busybox sh dont support =~
hdinfoname=`[ \`echo "$hdinfo"|grep -Eo "nvme"\` ] && echo $hdinfo"p" || echo $hdinfo`
logger -t minlearnadd preddtime hdinfoname:$hdinfoname

nicinfo=$3
NIC1=`[ \`echo "$nicinfo"|grep ":"\` ] && echo \`ip -o link| awk -v mac="$(echo "$nicinfo" | tr 'A-Z' 'a-z')" '($0 ~ mac) {print $2}' |sed 's/://g'\` || echo $nicinfo`
MAC1=`[ \`echo "$nicinfo"|grep ":"\` ] && echo \`echo "$nicinfo"|sed -e 's/:/-/g'\` || echo \`ip addr show $nicinfo|grep link/ether | awk '{print $2}'|sed -e 's/:/-/g'\``
logger -t minlearnadd preddtime NIC1:$NIC1 MAC1:$MAC1

instctlinfo=$4
oldIFS="$IFS"
IFS=","
for v in $instctlinfo; do
  if [ "$v" = "1" ]; then
    CTLDOEXPDISKINFO=1
  elif [ "$v" = "2" ]; then
    CTLNOIJNETCFGINFO=2
  elif [ "$v" = "3" ]; then
    CTLNOREBOOTINFO=3
  elif [ "$v" = "4" ]; then
    CTLNOPRECLEANINFO=4
  elif echo "$v" | grep -q '^[0-9]\+:\([0-9]\+\.\)\{3\}[0-9]\+$'; then
    CTLPT=`echo "$v" | awk -F ':' '{ print $1}'`
    CTLIP=`echo "$v" | awk -F ':' '{ print $2}'`
  fi
done
IFS="$oldIFS"
logger -t minlearnadd instctl doexpandisk info: $CTLDOEXPDISKINFO, noinjectnetcfg info: $CTLNOIJNETCFGINFO, noreboot info: $CTLNOREBOOTINFO, nopreclean info: $CTLNOPRECLEANINFO, port info:$CTLPT ip info:$CTLIP

passwordinfo=$5
logger -t minlearnadd password info:$passwordinfo

netinfo=$6
# dhcp only slipstreamed to targetos, in di initramfs always use fixed static netcfgs because dhcp not smart enough always
ISDHCP=`[ \`echo "$netinfo"|grep -Eo "dhcp"\` ] && echo 1 || echo 0`
staticnetinfo=`echo "$netinfo"|sed s/,dhcp//g`
IP=`[ -n "$staticnetinfo" ] && echo "$staticnetinfo" | awk -F ',' '{ print $1}'`
MASK=`[ -n "$staticnetinfo" ] && echo "$staticnetinfo" | awk -F ',' '{ print $2}'`
GATE=`[ -n "$staticnetinfo" ] && echo "$staticnetinfo" | awk -F ',' '{ print $3}'`
IPTYPE=`[ -n "$IP" ] && [ \`echo "$IP"|grep ":"\` ] && echo v6 || echo v4`
logger -t minlearnadd preddtime IP:$IP,MASK:$MASK,GATE:$GATE,IPTYPE:$IPTYPE,ISDHCP:$ISDHCP

down(){
  mkdir -p p4/down;
  for i in grub-common_2.06-3-deb11u5_arm64.deb grub-efi-arm64-bin_2.06-3-deb11u5_arm64.deb debootstrap-udeb_1.0.123-deb11u1_all.udeb bootstrap-base_1.206_arm64.udeb; do
    wget -q --no-check-certificate "$RLSMIRROR/$i" -O p4/down/$i
  done
}

dobootstrap(){

  mkdir -p p4/boot
  ar -p p4/down/grub-efi-arm64-bin_2.06-3-deb11u5_arm64.deb data.tar.xz |xzcat|tar -xf - -C p4/boot ./usr/lib/grub/ --strip-components=3
  mkdir -p p4/boot/grub/fonts
  ar -p p4/down/grub-common_2.06-3-deb11u5_arm64.deb data.tar.xz |xzcat|tar -xf - -C p4/boot/grub/fonts ./usr/share/grub/unicode.pf2 --strip-components=4
  mv p4/boot/grub p2
  mkdir -p p3/EFI/boot

  ar -p p4/down/debootstrap-udeb_1.0.123-deb11u1_all.udeb data.tar.xz |xzcat|tar -xf - -C / --no-overwrite-dir --keep-directory-symlink --strip-components=1
  ar -p p4/down/bootstrap-base_1.206_arm64.udeb data.tar.xz |xzcat|tar -xf - -C / --no-overwrite-dir --keep-directory-symlink --strip-components=1

  # will hang without below
  export DEBIAN_FRONTEND=noninteractive; unset DEBIAN_HAS_FRONTEND; unset DEBCONF_REDIR; unset DEBCONF_OLD_FD_BASE
  debootstrap --arch=arm64 --include=linux-image-arm64 "$codename" p4 "$TARGETDDURL" #>> /var/log/progress

  # process boot files
  rfsready=""
  if [ -n "$(find p4/boot -maxdepth 1 -type f ! -type l -name 'initrd*' | head -n1)" ]; then
    rfsready="yes"
  fi

  if [ -n "$(find p4/boot -maxdepth 1 -type f ! -type l -name 'vmlinuz*' | head -n1)" ] && [ $rfsready == "yes" ]; then
    # maybe multiple pairs
    for v in p4/boot/vmlinuz*; do
      [ -f "$v" ] || continue
      fname=${v##*/}
      ver=${fname#vmlinuz}
      # match ubt and un-ubts
      if [ -z "$ver" ]; then initrd="p4/boot/initrd"; else initrd="p4/boot/initrd.img$ver"; fi
      if [ -f "$initrd" ]; then
        cp "$v" p2/vmlinuz
        cp "$initrd" p2/initrfs.img
        # first pair found then exit earlier
        break
      fi
    done
  fi

  rm -rf p4/down p4/deboostrap p4/boot
  # make dobootstrap fittable to be a async function
  return 0

}
slipgrubcfgs(){
  cat > p2/grub/grub.cfg <<'EOF'
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
menuentry 'start linux' --unrestricted --class debian --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-BOOTFSUUID' {
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
	linux	/vmlinuz root=UUID=ROOTFSUUID console=ttyS0,115200n8 console=tty0 ro quiet
	initrd	/initrfs.img
}
### END /etc/grub.d/10_linux ###
EOF
  cat > p3/EFI/boot/grub.cfg <<'EOF'
# redirect only the grub files to let two set of grub shedmas coexists
search --label "ROM" --set root
configfile ($root)/grub/grub.cfg
EOF
}
slipmaincfgs() {
  > p4/etc/fstab
  cat >> p4/etc/fstab <<EOF
UUID=BOOTFSUUID /boot ext2 defaults 0 2
UUID=UEFIFSUUID /boot/efi vfat umask=0077 0 1
UUID=ROOTFSUUID / ext4 defaults 0 2
EOF
}

post(){

              therealospath="p4"

              # [ -f $therealospath/etc/cloud/cloud.cfg ] && sed -e "s/disable_root:[[:space:]]*true/disable_root: false/g" -e "s/ssh_pwauth:[[:space:]]*false/ssh_pwauth: true/g" -e "s/disable_root:[[:space:]]*1/disable_root: 0/g" -e "s/ssh_pwauth:[[:space:]]*0/ssh_pwauth: 1/g" -i $therealospath/etc/cloud/cloud.cfg
              [ -d $therealospath/etc/cloud ] && touch $therealospath/etc/cloud/cloud-init.disabled
              rm -rf $therealospath/etc/network/interfaces.d/*
              [ $staticnetinfo != '' -a $ISDHCP != '1' ] && [ -f $therealospath/etc/network/interfaces ] && { grep -q "iface $NIC1 inet" $therealospath/etc/network/interfaces && sed -i "s/iface $NIC1 inet dhcp/iface $NIC1 inet static\n  address $IP\n  netmask $MASK\n  gateway $GATE\n/g" $therealospath/etc/network/interfaces || printf "auto $NIC1\niface $NIC1 inet static\n  address $IP\n  netmask $MASK\n  gateway $GATE\n" >> $therealospath/etc/network/interfaces; }
              [ $ISDHCP = '1' ] && [ -f $therealospath/etc/network/interfaces ] && [ -z "$(sed -n "/iface $NIC1 inet dhcp/p" $therealospath/etc/network/interfaces)" ] && printf "auto $NIC1\niface $NIC1 inet dhcp\n" >> $therealospath/etc/network/interfaces             
              [ $staticnetinfo != '' -a $ISDHCP != '1' ] && [ -f $therealospath/etc/sysconfig/network-scripts/ifcfg-eth0 ] && MAC11=`echo $MAC1|tr '[a-f]' '[A-F]'` && MAC111=${MAC11//-/:} && sed -e "s/HWADDR=.*/HWADDR=$MAC111/g" -e "s/ONBOOT=no\|ONBOOT=\"no\"/ONBOOT=yes/g" -e "s/BOOTPROTO=dhcp\|BOOTPROTO=\"dhcp\"/BOOTPROTO=static\nIPADDR=$IP\nNETMASK=$MASK\nGATEWAY=$GATE/g" -i $therealospath/etc/sysconfig/network-scripts/ifcfg-eth0
              [ $ISDHCP = '1' ] && WORKINGYML=`[ -e $therealospath/etc/netplan ] && find $therealospath/etc/netplan* -maxdepth 1 -mindepth 1 -name *.yaml` && echo "$WORKINGYML" | while read line; do sed -e "/^    enp*\|^    ens*/c\    $NIC1:" -i $line; done
              [ $staticnetinfo != '' -a $ISDHCP != '1' ] && CIDR11=`echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o ''${MASK}...''|cut -d'/' -f2` && WORKINGYML=`[ -e $therealospath/etc/netplan ] && find $therealospath/etc/netplan* -maxdepth 1 -mindepth 1 -name *.yaml` && echo "$WORKINGYML" | while read line; do printf "network:\n  version: 2\n  renderer: networkd\n  ethernets:\n    $NIC1:\n      addresses:\n        - $IP/$CIDR11\n      nameservers:\n        addresses: [1.1.1.1,8.8.8.8]\n      routes:\n        - to: default\n          via: $GATE" > $line; done
              [ -f $therealospath/etc/security/pwquality.conf ] && sed -e "/^#minlen\|^minlen/c\minlen = 1" -i $therealospath/etc/security/pwquality.conf
              [ -f $therealospath/etc/security/pwquality.conf ] && grep -q '^\s*minlen' $therealospath/etc/security/pwquality.conf && sed -i 's/^\s*minlen\s*=.*/minlen = 1/' $therealospath/etc/security/pwquality.conf || echo 'minlen = 1' >> $therealospath/etc/security/pwquality.conf
              [ -f $therealospath/etc/security/passwdqc.conf ] && sed -e "/min=/c\min=1,1,1,1,1" -e "s/enforce=everyone/enforce=none/g" -i $therealospath/etc/security/passwdqc.conf
              [ -f $therealospath/etc/ssh/sshd_config ] && sed -e "/^#AddressFamily\|^AddressFamily/c\AddressFamily any" -e "/^#Port\|^Port/c\Port 22" -e "s/^#ListenAddress[[:space:]]0.0.0.0\|^ListenAddress[[:space:]]0.0.0.0/ListenAddress 0.0.0.0/g" -e "s/^#ListenAddress[[:space:]]::\|^ListenAddress[[:space:]]::/ListenAddress ::/g" -e "/^#PermitRootLogin\|^PermitRootLogin/c\PermitRootLogin yes" -e "/^#PasswordAuthentication\|^PasswordAuthentication/c\PasswordAuthentication yes" -e "s/^ChallengeResponseAuthentication[[:space:]]no/ChallengeResponseAuthentication yes/g" -i $therealospath/etc/ssh/sshd_config
              [ -f $therealospath/etc/ssh/sshd_config.d/50-redhat.conf ] && sed -e "s/^ChallengeResponseAuthentication[[:space:]]no/ChallengeResponseAuthentication yes/g" -i $therealospath/etc/ssh/sshd_config.d/50-redhat.conf
              # chpasswd is not portable and commonly useable,so passwd
              [ $passwordinfo != 0 ] && chroot $therealospath sh -c "passwd root << EOD
$passwordinfo
$passwordinfo
EOD" || chroot $therealospath sh -c "passwd root << EOD
inst.sh
inst.sh
EOD"
            [ "$CTLIP" != '' -a "$CTLPT" != '' ] && [ "$CTLIP" != '0.0.0.0' -o "$CTLPT" != 80 ] && cp /bin/rathole $therealospath/bin/rathole && printf "[client]\n\
remote_addr = \"$CTLIP:2333\"\n\
default_token = \"default_token_if_not_specify\"\n\
heartbeat_timeout = 30\n\
retry_interval = 3\n\
[client.services.$CTLPT]\n\
local_addr = \"127.0.0.1:22\"\n" > $therealospath/etc/rathole.toml && printf "[Unit]\n\
Description=rathole service\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
Restart=always\n\
RestartSec=1\n\
ExecStart=/bin/rathole /etc/rathole.toml\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n" > $therealospath/lib/systemd/system/rathole.service && mkdir -p $therealospath/etc/systemd/system/rathole.wants && ln -s /lib/systemd/system/rathole.service $therealospath/etc/systemd/system/multi-user.target.wants/rathole.service
            [ "$CTLIP" != '' -a "$CTLPT" != '' ] && [ "$CTLIP" = '0.0.0.0' -a "$CTLPT" = 80 ] && cp /bin/linuxvnc $therealospath/bin/linuxvnc && cp /lib/libvnc*.so* $therealospath/lib && cp -aR /usr/share/novnc $therealospath/usr/share && printf "[Unit]\n\
Description=linuxvnc service\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
Restart=always\n\
RestartSec=1\n\
ExecStart=/bin/linuxvnc 1\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n" > $therealospath/lib/systemd/system/linuxvnc.service && mkdir -p $therealospath/etc/systemd/system/linuxvnc.wants && ln -s /lib/systemd/system/linuxvnc.service $therealospath/etc/systemd/system/multi-user.target.wants/linuxvnc.service



              # linux boot postfix, only for uefi, bios mbr were ensured by the img itself
              [ -d /sys/firmware/efi ] && {
                mount -t efivarfs efivarfs /sys/firmware/efi/efivars
                efibootmgr --quiet --remove-dups
                efibootmgr -v | grep 'HD(.*,GPT,' | while read -r line; do if ! lsblk -o PARTUUID | grep -q $(echo "$line" | awk -F ',' '{print $3}'); then efibootmgr --quiet --bootnum $(echo "$line" | awk '{print $1}' | sed -e 's/Boot//' -e 's/\*//') --delete-bootnum; fi; done

                if efi_part=$(lsblk $hdinfo -ro NAME,PARTTYPE,PARTUUID | grep -i "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"); then
                  efi_part_uuid=$(echo "$efi_part" | awk '{print $3}')
                  efi_part_num=$(echo "$efi_part" | awk '{print $1}' | grep -o '[0-9]*' | tail -1)


mkdir -p /fwmnt
mount $hdinfoname$efi_part_num /fwmnt
efi_mount="/fwmnt"
efi_file_path1="EFI\\debian\\shimx64.efi EFI\\ubuntu\\shimx64.efi"
efi_file_path2="EFI\\boot\\bootaa64.efi"


found1=0
for path in $efi_file_path1; do
  real_path="$efi_mount/${path//\\//}"
  if [ -f "$real_path" ]; then
    if ! efibootmgr -v | grep -q -i "HD($efi_part_num,GPT,$efi_part_uuid,.*)/File(\\\\$path)"; then
      efibootmgr --create --disk "$hdinfo" --part "$efi_part_num" --label "$path" --loader "\\$path"
      logger -t minlearnadd create efientry for efi_part_uuid:$efi_part_uuid,efi_part_num:$efi_part_num using efi_file_path:$path
      found1=1
      break
    else
      logger -t minlearnadd efientry already exists for efi_file_path1: $path
      found1=1
      break
    fi
  fi
done

if [ $found1 -eq 0 ]; then
  real_path2="$efi_mount/${efi_file_path2//\\//}"
  if [ -f "$real_path2" ]; then
    if ! efibootmgr -v | grep -q -i "HD($efi_part_num,GPT,$efi_part_uuid,.*)/File(\\\\$efi_file_path2)"; then
      efibootmgr --create --disk "$hdinfo" --part "$efi_part_num" --label "$efi_file_path2" --loader "\\$efi_file_path2"
      logger -t minlearnadd create efientry for efi_part_uuid:$efi_part_uuid,efi_part_num:$efi_part_num using efi_file_path:$efi_file_path2
    else
      logger -t minlearnadd efientry already exists for efi_file_path2: $efi_file_path2
    fi
  else
    logger -t minlearnadd efi_file_path2 file not found: $real_path2
  fi
fi


                fi
              }

              ( umount /fwmnt )
}
for step in parted debootstrap grub; do

    if ! db_progress INFO my_script/progress/$step; then
            db_subst my_script/progress/fallback STEP "$step"
            db_progress INFO my_script/progress/fallback
    fi

    case $step in
       # in debian installer frontend cmd you should force -t ext4 or it cant be mounted
       # dedicated server need ext2 as boot and efi fstype,or it wont boot,so we use ext2 instead of fat32/vfat
       "parted")
           db_progress INFO my_script/progress/parted

           # to avoid the Partitions on /dev/sda are being used error
           # and prevent automount efi to /media/EFI which will cause later efi efientry post process
           # we have no mountpoint tool,so we grep it by maunual
           # note: dev/sda1 /dev/sda11,12,13,14,15 may be greped twice thus cause error,so we must force exit 0
           for i in `seq 1 15`;do [ "$(mount|grep -Eo $hdinfoname$i)" = $hdinfoname$i ] && ( umount -f $hdinfoname$i );done
           [ "$CTLNOPRECLEANINFO" != 4 ] && ( lvm vgremove --select all -ff -y; exit 0; )
           for i in `seq 1 5`;do gengetdiskcmd="lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)'  | sed 's|^|/dev/|' $(printf ' |tail -n%s' $(seq $i -1 1)) | sed -e 's/tail -n${i}/head -n${i}/g'";getdisk=`eval $gengetdiskcmd`;( [ "$CTLNOPRECLEANINFO" != 4 ] && [ `lsblk -no RO $getdisk|head -n1` != '1' ] && dd if=/dev/zero of=$getdisk bs=1M count=1 status=noxfer; exit 0; );done
           sleep 3

           total_s=$(LC_ALL=C fdisk -l $hdinfo 2>/dev/null | grep -m 1 "sectors" | awk '{print $(NF-1)}')
           parted -s $hdinfo mklabel gpt
           parted -s $hdinfo \
             mkpart non-fs 2048s `echo $(expr 2048 \* 2 - 1)s` \
             mkpart rom `echo $(expr 2048 \* 2)s` `echo $(expr 2048 \* 2 + 2048 \* 200 - 1)s` \
             mkpart rom2 `echo $(expr 2048 \* 2 + 2048 \* 200)s` `echo $(expr 2048 \* 2 + 2048 \* 400 - 1)s` \
             mkpart sys `echo $(expr 2048 \* 2 + 2048 \* 400)s` `echo $(expr $total_s - 2048 \* 1024 - 1)s` \
             mkpart swap `echo $(expr $total_s - 2048 \* 1024)s` 100%
           parted -s $hdinfo set 1 bios_grub on set 1 hidden on set 2 boot on set 3 esp on set 5 swap on
           # force fdisk w to noity the kernel (cause problems?), sometimes parted failed on this thus cause not found /dev/sda4 likehood error, we must use fdisk force noity the kernel when after reinit the disk
           ( printf 'w\n' | fdisk $hdinfo >/dev/null 2>&1 )

           mkfs.ext2 $hdinfoname"2" -L "ROM";mkdir p2;mount -t ext2 $hdinfoname"2" p2
           mkfs.fat -F16 $hdinfoname"3" -n "ROM2";mkdir p3;mount -t vfat $hdinfoname"3" p3
           ( mkfs.ext4 $hdinfoname"4" -L "SYS" );mkdir -p p4;mount -t ext4 $hdinfoname"4" p4
           mkswap $hdinfoname"5" -L "SWAP"

           ;;
       "debootstrap")
           db_progress START 0 100 my_script/progress/debootstrap
           db_progress INFO my_script/progress/debootstrap

           db_progress SET 0

           down
           dobootstrap & pid=$!
           while kill -0 $pid 2>/dev/null; do
               sleep 30

               # db_subst need step 1 to show or it wont take effect
               db_subst my_script/progress/debootstrap STATUS "please wait ......"
               db_progress STEP 1
               # end db_subst and step
           done
           db_progress SET 100

           sleep 3
           ;;
       # in debian installer frontend cmd you should: ..... umount p2 p3 p4;(reboot;exit 0)
       "grub")
           db_progress INFO my_script/progress/grub

           #grub
           slipgrubcfgs
           grub-mkimage -C xz -O arm64-efi -o p3/EFI/boot/bootaa64.efi -p "(hd0,gpt2)/grub" -d p2/grub/arm64-efi part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec
           #main
           slipmaincfgs
           bootfsuuid=`blkid -s UUID -o value "$hdinfoname"2`
           uefifsuuid=`blkid -s UUID -o value "$hdinfoname"3`
           rootfsuuid=`blkid -s UUID -o value "$hdinfoname"4`
           sed -e s/BOOTPARTNO/2/g -e s/BOOTFSUUID/$bootfsuuid/g -e s/ROOTFSUUID/$rootfsuuid/g -i p2/grub/grub.cfg
           sed -e s/BOOTFSUUID/$bootfsuuid/g -e s/UEFIFSUUID/$uefifsuuid/g -e s/ROOTFSUUID/$rootfsuuid/g -i p4/etc/fstab

           echo 'nameserver 8.8.8.8' >> p4/etc/resolv.conf
           # we may have no newt for debconf
           sed -i '/file:\|deb-src/d' p4/etc/apt/sources.list
           mount --bind /dev p4/dev
           mount --bind /dev/pts p4/dev/pts
           mount --bind /proc p4/proc
           mount --bind /sys p4/sys
           chroot p4 sh -c "export DEBIAN_FRONTEND=noninteractive; unset DEBIAN_HAS_FRONTEND; unset DEBCONF_REDIR; unset DEBCONF_OLD_FD_BASE; apt-get --fix-broken install -y; apt-get install -y openssh-server"
           # incase sshserver installed but not enabled in iso
           chroot p4 systemctl enable ssh


           # just apt-get installed ssh here, so we dont put postfix in most behind
           post

           sleep 3
           umount p2 p3 p4
           [ "$CTLNOREBOOTINFO" != 3 ] && reboot || UDPKG_QUIET=1 exec udpkg --configure --force-configure di-utils-shell
           ;;
    esac
done
