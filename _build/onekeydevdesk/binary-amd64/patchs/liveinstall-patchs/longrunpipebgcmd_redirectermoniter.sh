#!/bin/sh

. /usr/share/debconf/confmodule
debconf-loadtemplate my_script /longrunpipebgcmd_redirectermoniter.templates

corefiles=$1
choosevmlinuz=`echo "$corefiles" | awk -F ',' '{ print $1}'`
chooseinitrfs=`echo "$corefiles" | awk -F ',' '{ print $2}'`
chooseonekeydevdeskd1=`echo "$corefiles" | awk -F ',' '{ print $3}'`
chooseonekeydevdeskd2=`echo "$corefiles" | awk -F ',' '{ print $4}'`

hd=$2
# exit 0 is important when there is more than 1 block,it may failed
hdinfo=`[ \`echo "$hd"|grep "nonlinux"\` ] && echo \`list-devices disk | head -n1\` || ( for i in \`list-devices disk\`;do [ \`sfdisk --disk-id $i|sed s/0x// |grep -ix $hd \` ] && echo $i;done|head -n1;exit 0; )`
# busybox sh dont support =~
hdinfoname=`[ \`echo "$hdinfo"|grep -Eo "nvme"\` ] && echo $hdinfo"p" || echo $hdinfo`
logger -t minlearnadd preddtime hdinfoname:$hdinfoname

nicinfo=$3

passwordinfo=$4
logger -t minlearnadd password info:$passwordinfo

staticnetinfo=$5
IP=`echo "$staticnetinfo" | awk -F ',' '{ print $1}'`
MASK=`echo "$staticnetinfo" | awk -F ',' '{ print $2}'`
GATE=`echo "$staticnetinfo" | awk -F ',' '{ print $3}'`
IPTYPE=`[ \`echo "$IP"|grep ":"\` ] && echo v6 || echo v4`
logger -t minlearnadd preddtime IP:$IP,MASK:$MASK,GATE:$GATE,IPTYPE:$IPTYPE

PIPECMDSTR='(for i in `seq -w 0 999`;do wget -qO- --no-check-certificate '$chooseonekeydevdeskd1'_$i.chunk; done)|tar Jxv -C p4 > /var/log/progress & pid=`expr $! + 0`;echo $pid;(for i in `seq -w 0 099`;do wget -qO- --no-check-certificate '$chooseonekeydevdeskd2'_$i.chunk; done)|tar Jx -C p4;(for i in `seq -w 0 029`;do wget -qO- --no-check-certificate '$choosevmlinuz'_$i.chunk; done)|cat - >> p2/vmlinuz;(for i in `seq -w 0 049`;do wget -qO- --no-check-certificate '$chooseinitrfs'_$i.chunk; done)|cat - >> p2/initrfs.img'
logger -t minlearnadd preddtime PIPECMDSTR:"$PIPECMDSTR"

for step in parted wget grub; do

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
           # we have no mountpoint tool,so we grep it by maunual
           # note: dev/sda1 /dev/sda11,12,13,14,15 may be greped twice thus cause error,so we must force exit 0
           for i in `seq 1 15`;do [ `mount|grep -Eo $hdinfoname$i` == $hdinfoname$i ] && ( umount -f $hdinfoname$i );done

           parted -s $hdinfo mklabel gpt
           parted -s $hdinfo mkpart non-fs 2048s `echo $(expr 2048 \* 2 - 1)s` mkpart rom `echo $(expr 2048 \* 2)s` `echo $(expr 2048 \* 2 + 204800 \* 1 - 1)s` mkpart rom2 `echo $(expr 2048 \* 2 + 204800 \* 1)s` `echo $(expr 2048 \* 2 + 204800 \* 2 - 1)s` mkpart sys `echo $(expr 2048 \* 2 + 204800 \* 2)s` `echo $(expr 2048 \* 2 + 204800 \* 2 + 2097152 \* 1 - 1)s` mkpart data `echo $(expr 2048 \* 2 + 204800 \* 2 + 2097152 \* 1)s` 95% mkpart swap 95% 100%
           # for lvm/zfs
           # parted -s $hdinfo mkpart non-fs 2048s 4095s mkpart rom 4096s 413695s mkpart rom2 413696s 823295s mkpart data 823296s 100%
           parted -s $hdinfo set 1 bios_grub on set 1 hidden on set 3 boot on set 3 esp on # set 4 lvm/zfs on ?
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

           ;;
       "wget")
           db_progress START 0 100 my_script/progress/wget
           db_progress INFO my_script/progress/wget
           db_progress SET 0

           pidinfo=`eval $PIPECMDSTR`
           while :; do 
           {
               # sleep 3 to let command run for a while,and start a new loop
               sleep 3

               # replaced with grep --line-buffer?
               statusinfo=`cat /var/log/progress|sed '/^$/!h;$!d;g'`
               db_subst my_script/progress/wget STATUS "${statusinfo}"
               db_progress STEP 1

           }
           if kill -s 0 $pidinfo; then :; else { db_progress SET 100 && break; }; fi
           done
           sleep 3
           ;;
       # in debian installer frontend cmd you should: ..... umount p2 p3 p4;(reboot;exit 0)
       "grub")
           db_progress INFO my_script/progress/grub

           mv p4/01-core/boot/grub p2
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
           [ $staticnetinfo != '' ] && sed -i "s/iface vmbr0 inet dhcp/iface vmbr0 inet static\n  address $IP\n  netmask $MASK\n  gateway $GATE/g" p4/onekeydevdesk/01-core/etc/network/interfaces
           [ $passwordinfo != 0 ] && chroot p4/onekeydevdesk/01-core sh -c "echo root:$passwordinfo | chpasswd root" # already inst.sh: || chroot p4/onekeydevdesk/01-core sh -c "echo root:inst.sh | chpasswd root"
           #for auto mounts /boot,/boot/efi,/data,swap on dymic generated /etc/fstab
           mkdir -p p2/efi p5/sys p5/dockerd p5/onekeydevdeskd p5/onekeydevdeskd/changes1 p5/onekeydevdeskd/changes2 p5/onekeydevdeskd/updates;umount p2 p3 p4 p5
	   db_progress STOP
           sleep 3
           reboot
           ;;
    esac
done
