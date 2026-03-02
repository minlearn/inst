#!/bin/sh

is3rdrescue=$0
printf "\nis3rdrescue: $is3rdrescue\n"


cores=$1
TARGETDDURL=`echo "$cores" | awk -F ',' '{ print $1}'`
UNZIP=`echo "$cores" | awk -F ',' '{ print $2}'`

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
ISORIPW=`[ \`echo "$passwordinfo"|grep -Eo "nat.ee|Teddysun.com|cxthhhhh.com"\` ] && echo 1 || echo 0`
logger -t minlearnadd password info:$passwordinfo,is original password:$ISORIPW

netinfo=$6
# dhcp only slipstreamed to targetos, in di initramfs always use fixed static netcfgs because dhcp not smart enough always
ISDHCP=`[ \`echo "$netinfo"|grep -Eo "dhcp"\` ] && echo 1 || echo 0`
staticnetinfo=`echo "$netinfo"|sed s/,dhcp//g`
IP=`[ -n "$staticnetinfo" ] && echo "$staticnetinfo" | awk -F ',' '{ print $1}'`
MASK=`[ -n "$staticnetinfo" ] && echo "$staticnetinfo" | awk -F ',' '{ print $2}'`
GATE=`[ -n "$staticnetinfo" ] && echo "$staticnetinfo" | awk -F ',' '{ print $3}'`
IPTYPE=`[ -n "$IP" ] && [ \`echo "$IP"|grep ":"\` ] && echo v6 || echo v4`
logger -t minlearnadd preddtime IP:$IP,MASK:$MASK,GATE:$GATE,IPTYPE:$IPTYPE,ISDHCP:$ISDHCP

instcmdinfo=$7
CMDSTR=`printf "%b" "$instcmdinfo"`
CMDSTR_ORI=`printf "%s" "$instcmdinfo"`
logger -t minlearnadd preddtime CMDSTR:$CMDSTR

echo '<style>
    body {
        white-space: pre-line;
    }
</style>
<script>
    function scrollToBottom() {
        window.scrollTo(0, document.body.scrollHeight);
    }
    history.scrollRestoration = "manual";
    window.onload = scrollToBottom;

    function printSomething(){
        location.reload();
        setTimeout(printSomething, 3000);
    }
    setTimeout(printSomething, 3000);
</script>' > /var/log/progress
# for unzip 3, we must use tar as prefix of zstd of it or it wont receive data from stdin
[ "$UNZIP" = '0' ] && PIPECMDSTR='wget -qO- --no-check-certificate '\"$TARGETDDURL\"' | cat |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
[ "$UNZIP" = '1' ] && PIPECMDSTR='wget -qO- --no-check-certificate '\"$TARGETDDURL\"' | gunzip -dc |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
[ "$UNZIP" = '2' ] && PIPECMDSTR='wget -qO- --no-check-certificate '\"$TARGETDDURL\"' | xzcat |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
[ "$UNZIP" = '3' ] && PIPECMDSTR='wget -qO- --no-check-certificate '\"$TARGETDDURL\"' | tar -I zstd -Ox |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
[ "$UNZIP" = '4' ] && PIPECMDSTR='nbdcopy -- [ nbdkit -r --filter=qcow2dec curl sslverify=false '\"$TARGETDDURL\"' ] - | cat |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
logger -t minlearnadd preddtime PIPECMDSTR:"$PIPECMDSTR"


postdd(){
            # postdd only variables,so cant be put in frount as static globals
            layout=`[ "$(blkid -s TYPE -o value "${hdinfoname}1")" = "linux_raid_member" -a "$(blkid -s TYPE -o value "${hdinfoname}2")" = "linux_raid_member" -a "$(blkid -s TYPE -o value "${hdinfoname}3")" = "linux_raid_member" -a "$(blkid -s TYPE -o value "${hdinfoname}4")" = "vfat" -a "$(blkid -s TYPE -o value "${hdinfoname}5")" = "ext2" ] && echo "dsm"`
            logger -t minlearnadd postddtime layout:$layout
            part=`fdisk -l $hdinfo 2>/dev/null | grep /dev/ | sed -e /Disk/d -e s/*//g -e /Extended/d | sort -n -k 4 |tail -n 1|grep -Eo $hdinfoname.|grep -Eo [0-9]$`
            # type=`fdisk -l $hdinfo 2>/dev/null | grep /dev/ | sed -e /Disk/d -e s/*//g -e /Extended/d | sort -n -k 4 |tail -n 1|grep -Eo [[:space:]][a-z0-9][a-z0-9]?|tail -n 1|sed s/[[:space:]]//g`
            type=`blkid -s TYPE -o value $hdinfoname$part`
            therealospath="osmnt"
            logger -t minlearnadd postddtime part:$part,type:$type
            [ "$type" = LVM2_member ] && {
              ( lvm vgchange -ay )
              vg_name=$(lvm pvdisplay "$hdinfoname$part" 2>/dev/null | grep "VG Name" | awk '{print $3}')
              lv_paths=$(lvm lvdisplay "$vg_name" | grep "LV Path" | awk '{print $3}')
              found_lv=""

              for lv in $lv_paths; do
                mount_point=$(mktemp -d)
                mount -t ext4 "$lv" "$mount_point" 2>/dev/null
                if mountpoint -q "$mount_point"; then
                  if find "$mount_point" -name "busybox" -print -quit | grep -q "busybox" || find "$mount_point" -name "sh" -print -quit | grep -q "sh"; then
                    if find "$mount_point" -name "01-core" -print -quit | grep -q "01-core"; then therealospath="osmnt/onekeydevdesk/01-core"; fi
                    found_lv=$lv
                    umount "$mount_point"
                    rmdir "$mount_point"
                    break
                  fi
                  umount "$mount_point"
                fi
                rmdir "$mount_point"
              done

              if [ -n "$found_lv" ]; then
                hdinfoname=$found_lv
                part=""
                type=`blkid -s TYPE -o value $found_lv`
              fi

              logger -t minlearnadd lvm found, postddtime override hdinfoname :$hdinfoname,override type:$type,override therealospath :$therealospath

            } || {
              #fdisk has bugs not showing parts
              #lv_paths=$(LC_ALL=C fdisk -l $hdinfo 2>/dev/null| grep -E 'Linux filesystem|ext4|ext3|ext2' | awk '{print $1}'|sed ':a;N;$!ba;s/\n/ /g')
              lv_paths=$(lsblk -o NAME,FSTYPE -nr $hdinfo| grep -E 'ext4|ext3|ext2'| awk '{print $1}'|sed ':a;N;$!ba;s/\n/ /g')
              found_lv=""

              for lv in $lv_paths; do
                mount_point=$(mktemp -d)
                mount -t ext4 "$lv" "$mount_point" 2>/dev/null
                if mountpoint -q "$mount_point"; then
                  if find "$mount_point" -name "busybox" -print -quit | grep -q "busybox" || find "$mount_point" -name "sh" -print -quit | grep -q "sh"; then
                    if find "$mount_point" -name "01-core" -print -quit | grep -q "01-core"; then therealospath="osmnt/onekeydevdesk/01-core"; fi
                    found_lv=$lv
                    umount "$mount_point"
                    rmdir "$mount_point"
                    break
                  fi
                  umount "$mount_point"
                fi
                rmdir "$mount_point"
              done

              if [ -n "$found_lv" ]; then
                hdinfoname=/dev/`lsblk -no PKNAME $found_lv`
                part=`lsblk -no NAME $found_lv | grep -o '[0-9]*$'`
                type=`blkid -s TYPE -o value $found_lv`
              fi

              logger -t minlearnadd nonlvm found, postddtime override hdinfoname :$hdinfoname,override type:$type,override therealospath :$therealospath              
            }
            [ "$type" = ext4 -o "$type" = xfs -o "$type" = btrfs ] && {
              ( e2fsck -fy $hdinfoname$part && growpart $hdinfo $part )
              ( resize2fs $hdinfoname$part )
              mkdir osmnt
              ( mount -t $type $hdinfoname$part osmnt )
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
              #add Universal Linux Startup Script Mechanism
              [ ! -f $therealospath/etc/rc.local ] && {
                echo "/bin:/usr/bin:/sbin:/usr/sbin:" | while read -r -d ':' part; do
                  part="$therealospath$part"
                  # systemctl
                  if [ -f "$part"/systemctl ] && [ -x "$part"/systemctl ]; then
                    [ ! -f "$therealospath"/lib/systemd/system/rc-local.service ] && {
                    printf "[Unit]\n\
Description=/etc/rc.local Compatibility\n\
ConditionPathExists=/etc/rc.local\n\
After=network.target\n\
\n\
[Service]\n\
Type=forking\n\
ExecStart=/etc/rc.local\n\
TimeoutSec=0\n\
StandardOutput=tty\n\
RemainAfterExit=yes\n\
SysVStartPriority=99\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n" > "$therealospath"/lib/systemd/system/rc-local.service && mkdir -p $therealospath/etc/systemd/system/rc-local.wants && ln -s /lib/systemd/system/rc-local.service $therealospath/etc/systemd/system/multi-user.target.wants/rc-local.service
                    } || {
                      mkdir -p $therealospath/etc/systemd/system/rc-local.wants && ln -s /lib/systemd/system/rc-local.service $therealospath/etc/systemd/system/multi-user.target.wants/rc-local.service
                    }
                  # busybox
                  elif [ -f "$therealospath"/etc/inittab ]; then
                    if ! grep -q "rc.local" "$therealospath"/etc/inittab; then echo "::sysinit:/etc/rc.local" | tee -a /etc/inittab; fi
                    chroot "$therealospath" telinit q
                  # sysv
                  elif [ -d "$therealospath"/etc/init.d ]; then
                    [ ! -f "$therealospath"/etc/init.d/rc.local ] && echo '#!/bin/bash' > "$therealospath"/etc/init.d/rc.local && printf "bash /etc/rc.local &\n\
case \"\$1\" in\n\
start)\n\
  if [ -x /etc/init.d/rc.local ]; then\n\
    echo \"Running rc.local...\"\n\
    /etc/init.d/rc.local\n\
  fi\n\
  ;;\n\
*)\n\
  echo \"Usage: \$0 start\"\n\
  exit 1\n\
  ;;\n\
esac\n\
exit 0\n" >> "$therealospath"/etc/init.d/rc.local
                    chmod +x "$therealospath"/etc/init.d/rc.local
                    chroot "$therealospath" update-rc.d rc.local defaults
                  fi 
                done
              }


              echo '#!/bin/bash' > $therealospath/etc/rc.local && chmod +x $therealospath/etc/rc.local
              [ "$CMDSTR" != '' -a "$CMDSTR_ORI" != '' ] && printf "%b" "$CMDSTR_ORI""\n\n" >> $therealospath/etc/rc.local

              # assume we have a barely network working qcow2 rootfs for realserver from wikihost, not those from offical/ubuntulxdrepo for containers without networking
              # but if the latter,then we use busybox to prepare a minimal network chenism, its hard to use packagemgr tools here to patch the rootfs
              #[ ! -f $therealospath/lib/systemd/system/networking.service ] && [ ! -f $therealospath/etc/init.d/networking ] && {
              #  if [ ! -x $therealospath/bin/busybox ]; then cp /bin/busybox $therealospath/bin/busybox; fi
              #  echo '#!/bin/sh' > $therealospath/ifup_fixed.sh
              #  [ $staticnetinfo != '' -a $ISDHCP != '1' ] && {
              #    echo -e "/bin/busybox ifconfig $NIC1 $IP netmask $MASK up\n/bin/busybox route add default gw $GATE\necho 'nameserver 8.8.8.8' > /etc/resolv.conf" >> $therealospath/ifup_fixed.sh
              #  }
              #  [ $ISDHCP = '1' ] && {
              #    echo -e "/bin/busybox udhcpc -i $NIC1" >> $therealospath/ifup_fixed.sh
              #  }
              #  chmod +x $therealospath/ifup_fixed.sh
              #  echo "/ifup_fixed.sh" >> $therealospath/etc/rc.local
              #}



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
efi_file_path2="EFI\\boot\\bootx64.efi"


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

              ( umount osmnt /fwmnt )
            }
            [ "$layout" = "dsm" ] && {
              mkdir thebootpart
              ( mount -t ext2 $hdinfoname"5" thebootpart )
              [ -f thebootpart/grub/grub.cfg ] && MAC11=`echo $MAC1|tr '[a-f]' '[A-F]'` && MAC111=${MAC11//-/} && sed -i "s/52540066761B/$MAC111/g" thebootpart/grub/grub.cfg
              ( umount thebootpart )
              ( growpart $hdinfo 3 )
            }
            [ "$type" = ntfs ] && {
              # windows large disk may require ntfsfix after growpart and take long while fixing,so we change != to ==,to disable it by default, sure you can also resize it in cmd scripts
              [ "$CTLDOEXPDISKINFO" = 1 ] && ( growpart $hdinfo $part )
              # ( ntfsfix $hdinfoname$part )
              [ "$CTLDOEXPDISKINFO" = 1 ] && ( ntfsresize -f $hdinfoname$part )
              mkdir -p /thebiggestlastospart
              ( ntfs-3g $hdinfoname$part /thebiggestlastospart )
              # force exit 0,the spaces between ; and (/) is important,and you cant use {\} to replace (\),or the script wont go on
              # [ $ISORIPW != 1 ] && [ -f /thebiggestlastospart/Windows/System32/config/SAM ] && ( printf '1\nq\ny\n' | chntpw -u Administrator /thebiggestlastospart/Windows/System32/config/SAM )
              # conflicted entries needed to be dv ed, or what you edited wont peresit,the we need nv first,if there is alreay a samename value,it doesnt matter
              # [ $ISORIPW != 1 ] && [ -f /thebiggestlastospart/Windows/System32/config/SOFTWARE ] && ( printf 'cd Microsoft\Windows NT\CurrentVersion\Winlogon\ndv AutoLogonCount\ndv CachedLogonsCount\ndv ForceAutoLockOnLogon\ndv AutoLogonSID\ndv AutoAdminLogon\ndv DefaultUserName\ndv DefaultPassword\nnv 1 AutoAdminLogon\ned AutoAdminLogon\n1\ncat AutoAdminLogon\nnv 1 DefaultUserName\ned DefaultUserName\nAdministrator\ncat DefaultUserName\nnv 1 DefaultPassword\ned DefaultPassword\n\ncat DefaultPassword\nq\ny\n' | chntpw -e /thebiggestlastospart/Windows/System32/config/SOFTWARE )
              # [ $ISORIPW = 1 ] && [ -f /thebiggestlastospart/Windows/System32/config/SOFTWARE ] && ( printf "cd Microsoft\Windows NT\CurrentVersion\Winlogon\ndv AutoLogonCount\ndv CachedLogonsCount\ndv ForceAutoLockOnLogon\ndv AutoLogonSID\ndv AutoAdminLogon\ndv DefaultUserName\ndv DefaultPassword\nnv 1 AutoAdminLogon\ned AutoAdminLogon\n1\ncat AutoAdminLogon\nnv 1 DefaultUserName\ned DefaultUserName\nAdministrator\ncat DefaultUserName\nnv 1 DefaultPassword\ned DefaultPassword\n$passwordinfo\ncat DefaultPassword\nq\ny\n" | chntpw -e /thebiggestlastospart/Windows/System32/config/SOFTWARE )
              # dirwithspace,we use a simple trick here,or it cant be copied or moved
              ( cd '/thebiggestlastospart/ProgramData/Microsoft/Windows/Start Menu/Programs';cd Start* || cd start*;rm -rf './net.bat' './net.cmd';cd '/thebiggestlastospart/Windows/System32/GroupPolicy';rm -rf './GPT.INI' './GPT.ini' './gpt.INI' './gpt.ini'; cd / )
              # we switch to windows gp,but not above commented chntpw ops
              mkdir -p /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup;> /thebiggestlastospart/Windows/System32/GroupPolicy/gpt.ini;> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/scripts.ini;> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat;printf "%b" "\0133General\0135\r\ngPCFunctionalityVersion\00752\r\ngPCMachineExtensionNames\0075\0133\017342B5FAAE\00556536\005511D2\0055AE5A\00550000F87571E3\0175\017340B6664F\00554972\005511D1\0055A7CA\00550000F87571E3\0175\0135\r\nVersion\00751\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> /thebiggestlastospart/Windows/System32/GroupPolicy/gpt.ini;printf "%b" "\0133Startup\0135\r\n0CmdLine\0075cloudinit\0056bat\r\n0Parameters\0075\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/scripts.ini
              [ $staticnetinfo != '' -a $ISDHCP != '1' ] && [ $IPTYPE = 'v4' ] && printf "%b" "set\0040\0042interface_name\0075\0042\r\nfor\0040\0057f\0040\0042tokens\00751\0040delims\0075\0054\0042\0040\0045\0045a\0040in\0040\0050\0047getmac\0040\0057v\0040\0057fo\0040csv\0040\0136\0174find\0040\0057i\0040\0042$MAC1\0042\0040\0047\0051\0040do\0040set\0040interface_name\0075\0045\0045\0176a\r\nif\0040defined\0040interface_name\0040netsh\0040interface\0040ip\0040set\0040address\0040name\0075\0042\0045interface_name\0045\0042\0040static\0040$IP\0040$MASK\0040$GATE\r\nif\0040defined\0040interface_name\0040netsh\0040interface\0040ip\0040add\0040dnsservers\0040name\0075\0042\0045interface_name\0045\0042\0040address\00758\00568\00568\00568\0040index\00751\0040validate\0075no\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              [ $staticnetinfo != '' -a $ISDHCP != '1' ] && [ $IPTYPE = 'v6' ] && printf "%b" "set\0040\0042interface_name\0075\0042\r\nfor\0040\0057f\0040\0042tokens\00751\0040delims\0075\0054\0042\0040\0045\0045a\0040in\0040\0050\0047getmac\0040\0057v\0040\0057fo\0040csv\0040\0136\0174find\0040\0057i\0040\0042$MAC1\0042\0040\0047\0051\0040do\0040set\0040interface_name\0075\0045\0045\0176a\r\nif\0040defined\0040interface_name\0040netsh\0040int\0040ipv6\0040set\0040address\0040\0042\0045interface_name\0045\0042\0040$IP\r\nif\0040defined\0040interface_name\0040netsh\0040int\0040ipv6\0040add\0040route\0040\0072\0072\00570\0040\0042\0045interface_name\0045\0042\0040$GATE\r\nif\0040defined\0040interface_name\0040netsh\0040int\0040ipv6\0040add\0040dnsserver\0040\0042\0045interface_name\0045\0042\00402001\007267c\00722b0\0072\00724\r\nif\0040defined\0040interface_name\0040netsh\0040int\0040ipv6\0040add\0040dnsserver\0040\0042\0045interface_name\0045\0042\00402001\007267c\00722b0\0072\00726\0040index\00752\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              [ $passwordinfo != 0 ] && printf "%b" "net\0040user\0040administrator\0040$passwordinfo\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              [ "$CTLIP" != '' -a "$CTLPT" != '' ] && cp /bin/rathole.exe /bin/nssm.exe /thebiggestlastospart/Windows && printf "[client]\nremote_addr = \"$CTLIP:2333\"\ndefault_token = \"default_token_if_not_specify\"\nheartbeat_timeout = 30\nretry_interval = 3\n[client.services.$CTLPT]\nlocal_addr = \"127.0.0.1:3389\"\n" > /thebiggestlastospart/Windows/rathole.toml && printf "%b" "nssm\0040install\0040rathole\0040C\0072\0134Windows\0134rathole\0056exe\0040C\0072\0134Windows\0134rathole\0056toml\r\nnet\0040start\0040rathole\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              [ "$CMDSTR" != '' -a "$CMDSTR_ORI" != '' ] && printf "%b" "$CMDSTR_ORI""\r\n\r\n"| iconv -f 'UTF-8' -t 'GBK' >> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              printf "%b" "cd\0040\0057d\0040\0045SystemRoot\0045\0057System32\0057GroupPolicy\0057Machine\0057Scripts\0057Startup\r\nmove\0040\0057y\0040cloudinit\0056bat\0040\0045SystemDrive\0045\0057Users\0057Administrator\0057Desktop\0057net\0056txt\r\n\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> /thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              # [ -d ] before cd cp?
              # ( cd '/thebiggestlastospart/ProgramData/Microsoft/Windows/Start Menu/Programs'; cd Start* || cd start*; cp -f '/cloudinit.txt' './net.bat';cd / )

              # windows boot postfix, only for uefi, bios mbr were ensured by the img itself
              [ -d /sys/firmware/efi ] && [ "${TARGETDDURL%1keydd.gz}" = "$TARGETDDURL" ] && {
                mount -t efivarfs efivarfs /sys/firmware/efi/efivars
                efibootmgr --quiet --remove-dups
                efibootmgr -v | grep 'HD(.*,GPT,' | while read -r line; do if ! lsblk -o PARTUUID | grep -q $(echo "$line" | awk -F ',' '{print $3}'); then efibootmgr --quiet --bootnum $(echo "$line" | awk '{print $1}' | sed -e 's/Boot//' -e 's/\*//') --delete-bootnum; fi; done

                if efi_part=$(lsblk $hdinfo -ro NAME,PARTTYPE,PARTUUID | grep -i "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"); then
                  efi_part_uuid=$(echo "$efi_part" | awk '{print $3}')
                  efi_part_num=$(echo "$efi_part" | awk '{print $1}' | grep -o '[0-9]*' | tail -1)


mkdir -p /fwmnt
mount $hdinfoname$efi_part_num /fwmnt
efi_mount="/fwmnt"
efi_file_path1="EFI\\Microsoft\\Boot\\bootmgfw.efi"
efi_file_path2="EFI\\boot\\bootx64.efi"


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
              ( umount /thebiggestlastospart /fwmnt )
            }

}

if [ "$is3rdrescue" != "/longrunpipefgcmd.sh" ]; then
    echo "Executing logic with Debian Installer..."
    . /usr/share/debconf/confmodule
    debconf-loadtemplate my_script /longrunpipebgcmd_redirectermoniter.templates

for step in predd dd postdd; do

    if ! db_progress INFO my_script/progress/$step; then
            db_subst my_script/progress/fallback STEP "$step"
            db_progress INFO my_script/progress/fallback
    fi

    case $step in
        "predd")
           db_progress INFO my_script/progress/predd

           # to avoid the Partitions on /dev/sda are being used error
           # and prevent automount efi to /media/EFI which will cause later efi efientry post process
           # we have no mountpoint tool,so we grep it by maunual
           # note: dev/sda1 /dev/sda11,12,13,14,15 may be greped twice thus cause error,so we must force exit 0
           for i in `seq 1 15`;do [ "$(mount|grep -Eo $hdinfoname$i)" = $hdinfoname$i ] && ( umount -f $hdinfoname$i );done
           # to avoid incase there is lvms
           [ "$CTLNOPRECLEANINFO" != 4 ] && ( lvm vgremove --select all -ff -y; exit 0; )
           # to avoid incase there is mdraids and hd that is of type iso
           # we can also use dd of=/dev/xxx bs=1M count=10 status=noxfer here?no,size were not know will cause nospaceleft error
           for i in `seq 1 5`;do gengetdiskcmd="lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)'  | sed 's|^|/dev/|' $(printf ' |tail -n%s' $(seq $i -1 1)) | sed -e 's/tail -n${i}/head -n${i}/g'";getdisk=`eval $gengetdiskcmd`;( [ "$CTLNOPRECLEANINFO" != 4 ] && [ `lsblk -no RO $getdisk|head -n1` != '1' ] && dd if=/dev/zero of=$getdisk bs=1M count=1 status=noxfer; exit 0; );done
           sleep 3

           ;;

       "dd")
           db_progress START 0 100 my_script/progress/dd
           db_progress INFO my_script/progress/dd
           db_progress SET 0

           pidinfo=`eval $PIPECMDSTR`
           # in ash,we use [] not [[]]
           [ -z $pidinfo ] && db_subst my_script/progress/dd STATUS "img link cant be dd,please force a restart"
           [ -z $imgsizeinfo ] && db_subst my_script/progress/dd STATUS "img size cant be retrived,force it to 20G" && imgsizeinfo=20

	   PCTCOUNT="0";
           while :; do 
           {
               # we make sleep longer, to micmic a fake progress
               sleep 10

               # replaced with grep --line-buffer?
               statusinfo=`kill -USR1 $pidinfo;cat /var/log/progress|sed '/^$/!h;$!d;g'`
               db_subst my_script/progress/dd STATUS "${statusinfo}"

               tillnowinfo=`echo $statusinfo|sed 's/bytes \(.*\)//g'`
               # 214748364 is result of (totalimgsize 21474836480 divide 100)
               # PCTSTEP=`expr $tillnowinfo / 214748364 - $PCTCOUNT`
               db_progress STEP 1
               # db_progress STEP "$PCTSTEP"
               # PCTCOUNT=`expr $PCTCOUNT + $PCTSTEP`
            }
            # [ $tillnowinfo = $IMGSIZE -a $PCTCOUNT = 100 ] && db_progress SET 100 && break
            # [ $tillnowinfo = `expr 1073741824 \* $imgsizeinfo` ] && db_progress SET 100 && break
            if kill -s 0 $pidinfo; then :; else { db_progress SET 100 && break; }; fi
            # wait $pidinfo;db_progress SET 100 && break
            done
            sleep 3
            ;;

        # autoexp the datapart for linux 83,windows 7
        # when used in di frontend,you should force exit0 and quoted with (),like this: (growpart /dev/sda 3 && e2fsck -fy /dev/sda3;resize2fs /dev/sda3;exit 0;) || (exit 0;)
        "postdd")
            db_progress INFO my_script/progress/postdd
            postdd

            db_progress STOP
            sleep 3
            # if tillnowinfo is 0, there is a exception, hold instead of reboot
            [ `cat /var/log/progress|sed '/^$/!h;$!d;g'|sed 's/bytes \(.*\)//g'` != '0' -a "$CTLNOREBOOTINFO" != 3 ] && reboot || UDPKG_QUIET=1 exec udpkg --configure --force-configure di-utils-shell
            ;;
    esac

done

else
    echo "Executing logic without Debian Installer..."

           for i in `seq 1 15`;do [ "$(mount|grep -Eo $hdinfoname$i)" = $hdinfoname$i ] && ( umount -f $hdinfoname$i );done
           [ "$CTLNOPRECLEANINFO" != 4 ] && ( lvm vgremove --select all -ff -y; exit 0; )
           for i in `seq 1 5`;do gengetdiskcmd="lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)'  | sed 's|^|/dev/|' $(printf ' |tail -n%s' $(seq $i -1 1)) | sed -e 's/tail -n${i}/head -n${i}/g'";getdisk=`eval $gengetdiskcmd`;( [ "$CTLNOPRECLEANINFO" != 4 ] && [ `lsblk -no RO $getdisk|head -n1` != '1' ] && dd if=/dev/zero of=$getdisk bs=1M count=1 status=noxfer; exit 0; );done
           sleep 3

            eval "${PIPECMDSTR%%bs=10M*}bs=10M status=progress"
            postdd
            sleep 3

fi

