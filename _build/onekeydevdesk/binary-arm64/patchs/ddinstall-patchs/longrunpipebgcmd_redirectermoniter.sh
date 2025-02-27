#!/bin/sh

. /usr/share/debconf/confmodule
debconf-loadtemplate my_script /longrunpipebgcmd_redirectermoniter.templates

cores=$1
TARGETDDURL=`echo "$cores" | awk -F ',' '{ print $1}'`
UNZIP=`echo "$cores" | awk -F ',' '{ print $2}'`

hd=$2
# exit 0 is important when there is more than 1 block,it may failed
hdinfo=`[ \`echo "$hd"|grep "nonlinux"\` ] && echo \`list-devices disk | head -n1\` || ( for i in \`list-devices disk\`;do [ \`sfdisk --disk-id $i|sed s/0x// |grep -ix $hd \` ] && echo $i;done|head -n1;exit 0; )`
# busybox sh dont support =~
hdinfoname=`[ \`echo "$hdinfo"|grep -Eo "nvme"\` ] && echo $hdinfo"p" || echo $hdinfo`
logger -t minlearnadd preddtime hdinfoname:$hdinfoname

nicinfo=$3
MAC1=`[ \`echo "$nicinfo"|grep ":"\` ] && echo \`echo "$nicinfo"|sed -e 's/:/-/g'\` || echo \`ip addr show $nicinfo|grep link/ether | awk '{print $2}'|sed -e 's/:/-/g'\``
logger -t minlearnadd preddtime MAC1:$MAC1

instctlinfo=$4
logger -t minlearnadd instctl info:$instctlinfo

passwordinfo=$5
logger -t minlearnadd password info:$passwordinfo

staticnetinfo=$6
IP=`echo "$staticnetinfo" | awk -F ',' '{ print $1}'`
MASK=`echo "$staticnetinfo" | awk -F ',' '{ print $2}'`
GATE=`echo "$staticnetinfo" | awk -F ',' '{ print $3}'`
IPTYPE=`[ \`echo "$IP"|grep ":"\` ] && echo v6 || echo v4`
logger -t minlearnadd preddtime IP:$IP,MASK:$MASK,GATE:$GATE,IPTYPE:$IPTYPE

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
[ "$UNZIP" == '0' ] && PIPECMDSTR='wget -qO- --no-check-certificate '\"$TARGETDDURL\"' | cat |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
[ "$UNZIP" == '1' ] && PIPECMDSTR='wget -qO- --no-check-certificate '\"$TARGETDDURL\"' | gunzip -dc |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
[ "$UNZIP" == '2' ] && PIPECMDSTR='wget -qO- --no-check-certificate '\"$TARGETDDURL\"' | xzcat |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
[ "$UNZIP" == '3' ] && PIPECMDSTR='wget -qO- --no-check-certificate '\"$TARGETDDURL\"' | tar -I zstd -Ox |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
[ "$UNZIP" == '4' ] && PIPECMDSTR='nbdcopy -- [ nbdkit -r --filter=qcow2dec curl sslverify=false '\"$TARGETDDURL\"' ] - | cat |stdbuf -oL dd of='$hdinfo' bs=10M 2>> /var/log/progress & pid=`expr $! + 0`;echo $pid'
logger -t minlearnadd preddtime PIPECMDSTR:"$PIPECMDSTR"

for step in predd dd postdd; do

    if ! db_progress INFO my_script/progress/$step; then
            db_subst my_script/progress/fallback STEP "$step"
            db_progress INFO my_script/progress/fallback
    fi

    case $step in
        "predd")
           db_progress INFO my_script/progress/predd

           # to avoid the Partitions on /dev/sda are being used error
           # we have no mountpoint tool,so we grep it by maunual
           # note: dev/sda1 /dev/sda11,12,13,14,15 may be greped twice thus cause error,so we must force exit 0
           for i in `seq 1 15`;do [ `mount|grep -Eo $hdinfoname$i` == $hdinfoname$i ] && ( umount -f $hdinfoname$i );done
           # to avoid incase there is lvms
           [ $instctlinfo != 4 ] && ( lvm vgremove --select all -ff -y; exit 0; )
           # to avoid incase there is mdraids and hd that is of type iso
           # we can also use dd of=/dev/xxx bs=1M count=10 status=noxfer here?no,size were not know will cause nospaceleft error
           for i in `seq 1 5`;do gengetdiskcmd="echo list-devicesdisk \`seq $i -1 1\`|sed -e 's/ / | tail -n/g' -e \"s/tail -n${i}/head -n${i}/g\" -e 's/devicesdisk/devices disk/g'";getdiskcmd=`eval $gengetdiskcmd`;( [ $instctlinfo != 4 ] && [ `lsblk -no RO \`eval $getdiskcmd\`|head -n1` != '1' ] && dd if=/dev/zero of=`eval $getdiskcmd` bs=1M count=1 status=noxfer; exit 0; );done
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
               # sleep 3 to let command run for a while,and start a new loop
               sleep 3

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
            # [ $tillnowinfo == $IMGSIZE -a $PCTCOUNT == 100 ] && db_progress SET 100 && break
            # [ $tillnowinfo == `expr 1073741824 \* $imgsizeinfo` ] && db_progress SET 100 && break
            if kill -s 0 $pidinfo; then :; else { db_progress SET 100 && break; }; fi
            # wait $pidinfo;db_progress SET 100 && break
            done
            sleep 3
            ;;

        # autoexp the datapart for linux 83,windows 7
        # when used in di frontend,you should force exit0 and quoted with (),like this: (growpart /dev/sda 3 && e2fsck -fy /dev/sda3;resize2fs /dev/sda3;exit 0;) || (exit 0;)
        "postdd")
            db_progress INFO my_script/progress/postdd
            # postdd only variables,so cant be put in frount as static globals
            layout=`[ \`blkid -s TYPE -o value $hdinfoname"1"\` == linux_raid_member -a \`blkid -s TYPE -o value $hdinfoname"2"\` == linux_raid_member -a \`blkid -s TYPE -o value $hdinfoname"3"\` == linux_raid_member -a \`blkid -s TYPE -o value $hdinfoname"4"\` == vfat ] && ( echo dsm )`
            logger -t minlearnadd postddtime layout:$layout
            part=`fdisk -l $hdinfo 2>/dev/null | grep /dev/ | sed -e /Disk/d -e s/*//g -e /Extended/d | sort -n -k 4 |tail -n 1|grep -Eo $hdinfoname.|grep -Eo [0-9]$`
            # type=`fdisk -l $hdinfo 2>/dev/null | grep /dev/ | sed -e /Disk/d -e s/*//g -e /Extended/d | sort -n -k 4 |tail -n 1|grep -Eo [[:space:]][a-z0-9][a-z0-9]?|tail -n 1|sed s/[[:space:]]//g`
            type=`blkid -s TYPE -o value $hdinfoname$part`
            logger -t minlearnadd postddtime part:$part,type:$type
            [ $type == LVM2_member ] && {
              ( lvm vgchange -ay )
              vg_name=$(lvm pvdisplay "$hdinfoname$part" 2>/dev/null | grep "VG Name" | awk '{print $3}')
              lv_paths=$(lvm lvdisplay "$vg_name" | grep "LV Path" | awk '{print $3}')
              found_lv=""

              for lv in $lv_paths; do
                mount_point=$(mktemp -d)
                mount -t ext4 "$lv" "$mount_point" 2>/dev/null
                if mountpoint -q "$mount_point"; then
                  if find "$mount_point" -name "busybox" -print -quit | grep -q "busybox"; then
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

              logger -t minlearnadd lvm found, postddtime override hdinfoname :$hdinfoname,override type:$type

            }
            [ $type == ext4 -o $type == xfs -o $type == btrfs ] && {
              ( growpart $hdinfo $part && e2fsck -fy $hdinfoname$part )
              ( resize2fs $hdinfoname$part )
              mkdir thebiggestlastospart
              ( mount -t $type $hdinfoname$part thebiggestlastospart )
              # [ -f thebiggestlastospart/etc/cloud/cloud.cfg ] && sed -e "s/disable_root:[[:space:]]*true/disable_root: false/g" -e "s/ssh_pwauth:[[:space:]]*false/ssh_pwauth: true/g" -e "s/disable_root:[[:space:]]*1/disable_root: 0/g" -e "s/ssh_pwauth:[[:space:]]*0/ssh_pwauth: 1/g" -i thebiggestlastospart/etc/cloud/cloud.cfg
              [ -d thebiggestlastospart/etc/cloud ] && touch thebiggestlastospart/etc/cloud/cloud-init.disabled
              [ $staticnetinfo != '' ] && [ -f thebiggestlastospart/etc/network/interfaces ] && sed -i "s/iface eth0 inet dhcp/iface eth0 inet static\n  address $IP\n  netmask $MASK\n  gateway $GATE/g" thebiggestlastospart/etc/network/interfaces
              [ $staticnetinfo != '' ] && [ -f thebiggestlastospart/etc/sysconfig/network-scripts/ifcfg-eth0 ] && MAC11=`echo $MAC1|tr '[a-f]' '[A-F]'` && MAC111=${MAC11//-/:} && sed -e "s/HWADDR=.*/HWADDR=$MAC111/g" -e "s/ONBOOT=no\|ONBOOT=\"no\"/ONBOOT=yes/g" -e "s/BOOTPROTO=dhcp\|BOOTPROTO=\"dhcp\"/BOOTPROTO=static\nIPADDR=$IP\nNETMASK=$MASK\nGATEWAY=$GATE/g" -i thebiggestlastospart/etc/sysconfig/network-scripts/ifcfg-eth0
              [ $staticnetinfo == '' ] && [ -f thebiggestlastospart/etc/netplan/00-installer-config.yaml ] && sed -e "/^    enp*\|^    ens*/c\    eth0:" -i thebiggestlastospart/etc/netplan/00-installer-config.yaml
              [ $staticnetinfo != '' ] && [ -f thebiggestlastospart/etc/netplan/00-installer-config.yaml ] && CIDR11=`echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o ''${MASK}...''|cut -d'/' -f2` && printf "network:\n  version: 2\n  renderer: networkd\n  ethernets:\n    eth0:\n      addresses:\n        - $IP/$CIDR11\n      nameservers:\n        addresses: [1.1.1.1,8.8.8.8]\n      routes:\n        - to: default\n          via: $GATE" > thebiggestlastospart/etc/netplan/00-installer-config.yaml
              [ -f thebiggestlastospart/etc/security/pwquality.conf ] && sed -e "/^#minlen\|^minlen/c\minlen = 1" -i thebiggestlastospart/etc/security/pwquality.conf
              [ -f thebiggestlastospart/etc/security/passwdqc.conf ] && sed -e "/min=/c\min=1,1,1,1,1" -e "s/enforce=everyone/enforce=none/g" -i thebiggestlastospart/etc/security/passwdqc.conf
              [ -f thebiggestlastospart/etc/ssh/sshd_config ] && sed -e "/^#AddressFamily\|^AddressFamily/c\AddressFamily any" -e "/^#Port\|^Port/c\Port 22" -e "s/^#ListenAddress[[:space:]]0.0.0.0\|^ListenAddress[[:space:]]0.0.0.0/ListenAddress 0.0.0.0/g" -e "s/^#ListenAddress[[:space:]]::\|^ListenAddress[[:space:]]::/ListenAddress ::/g" -e "/^#PermitRootLogin\|^PermitRootLogin/c\PermitRootLogin yes" -e "/^#PasswordAuthentication\|^PasswordAuthentication/c\PasswordAuthentication yes" -e "s/^ChallengeResponseAuthentication[[:space:]]no/ChallengeResponseAuthentication yes/g" -i thebiggestlastospart/etc/ssh/sshd_config
              [ -f thebiggestlastospart/etc/ssh/sshd_config.d/50-redhat.conf ] && sed -e "s/^ChallengeResponseAuthentication[[:space:]]no/ChallengeResponseAuthentication yes/g" -i thebiggestlastospart/etc/ssh/sshd_config.d/50-redhat.conf
              # chpasswd is not portable and commonly useable,so passwd
              [ $passwordinfo != 0 ] && chroot thebiggestlastospart sh -c "passwd root << EOD
$passwordinfo
$passwordinfo
EOD" || chroot thebiggestlastospart sh -c "passwd root << EOD
inst.sh
inst.sh
EOD"
              ( umount thebiggestlastospart )
            }
            # [ $layout == dsm ] && {
            # ...
            # }
            [ $type == ntfs ] && {
              # windows large disk may require ntfsfix after growpart and take long while fixing,so we change != to ==,to disable it by default, sure you can also resize it in cmd scripts
              [ $instctlinfo == 1 ] && ( growpart $hdinfo $part )
              # ( ntfsfix $hdinfoname$part )
              [ $instctlinfo == 1 ] && ( ntfsresize -f $hdinfoname$part )
              mkdir thebiggestlastospart
              ( ntfs-3g $hdinfoname$part thebiggestlastospart )
              # force exit 0,the spaces between ; and (/) is important,and you cant use {\} to replace (\),or the script wont go on
              # [ $ISORIPW != 1 ] && [ -f thebiggestlastospart/Windows/System32/config/SAM ] && ( printf '1\nq\ny\n' | chntpw -u Administrator thebiggestlastospart/Windows/System32/config/SAM )
              # conflicted entries needed to be dv ed, or what you edited wont peresit,the we need nv first,if there is alreay a samename value,it doesnt matter
              # [ $ISORIPW != 1 ] && [ -f thebiggestlastospart/Windows/System32/config/SOFTWARE ] && ( printf 'cd Microsoft\Windows NT\CurrentVersion\Winlogon\ndv AutoLogonCount\ndv CachedLogonsCount\ndv ForceAutoLockOnLogon\ndv AutoLogonSID\ndv AutoAdminLogon\ndv DefaultUserName\ndv DefaultPassword\nnv 1 AutoAdminLogon\ned AutoAdminLogon\n1\ncat AutoAdminLogon\nnv 1 DefaultUserName\ned DefaultUserName\nAdministrator\ncat DefaultUserName\nnv 1 DefaultPassword\ned DefaultPassword\n\ncat DefaultPassword\nq\ny\n' | chntpw -e thebiggestlastospart/Windows/System32/config/SOFTWARE )
              # [ $ISORIPW == 1 ] && [ -f thebiggestlastospart/Windows/System32/config/SOFTWARE ] && ( printf "cd Microsoft\Windows NT\CurrentVersion\Winlogon\ndv AutoLogonCount\ndv CachedLogonsCount\ndv ForceAutoLockOnLogon\ndv AutoLogonSID\ndv AutoAdminLogon\ndv DefaultUserName\ndv DefaultPassword\nnv 1 AutoAdminLogon\ned AutoAdminLogon\n1\ncat AutoAdminLogon\nnv 1 DefaultUserName\ned DefaultUserName\nAdministrator\ncat DefaultUserName\nnv 1 DefaultPassword\ned DefaultPassword\n$passwordinfo\ncat DefaultPassword\nq\ny\n" | chntpw -e thebiggestlastospart/Windows/System32/config/SOFTWARE )
              # dirwithspace,we use a simple trick here,or it cant be copied or moved
              ( cd '/thebiggestlastospart/ProgramData/Microsoft/Windows/Start Menu/Programs';cd Start* || cd start*;rm -rf './net.bat' './net.cmd';cd '/thebiggestlastospart/Windows/System32/GroupPolicy';rm -rf './GPT.INI' './GPT.ini' './gpt.INI' './gpt.ini'; cd / )
              # we switch to windows gp,but not above commented chntpw ops
              mkdir -p thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup;> thebiggestlastospart/Windows/System32/GroupPolicy/gpt.ini;> thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/scripts.ini;> thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat;echo -ne "\0133General\0135\r\ngPCFunctionalityVersion\00752\r\ngPCMachineExtensionNames\0075\0133\017342B5FAAE\00556536\005511D2\0055AE5A\00550000F87571E3\0175\017340B6664F\00554972\005511D1\0055A7CA\00550000F87571E3\0175\0135\r\nVersion\00751\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> thebiggestlastospart/Windows/System32/GroupPolicy/gpt.ini;echo -ne "\0133Startup\0135\r\n0CmdLine\0075cloudinit\0056bat\r\n0Parameters\0075" | iconv -f 'UTF-8' -t 'GBK' - >> thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/scripts.ini
              [ $staticnetinfo != '' ] && [ $IPTYPE == 'v4' ] && echo -ne "set\0040\0042interface_name\0075\0042\r\nfor\0040\0057f\0040\0042tokens\00751\0040delims\0075\0054\0042\0040\0045\0045a\0040in\0040\0050\0047getmac\0040\0057v\0040\0057fo\0040csv\0040\0136\0174find\0040\0057i\0040\0042$MAC1\0042\0040\0047\0051\0040do\0040set\0040interface_name\0075\0045\0045\0176a\r\nif\0040defined\0040interface_name\0040netsh\0040interface\0040ip\0040set\0040address\0040name\0075\0042\0045interface_name\0045\0042\0040static\0040$IP\0040$MASK\0040$GATE\r\nif\0040defined\0040interface_name\0040netsh\0040interface\0040ip\0040add\0040dnsservers\0040name\0075\0042\0045interface_name\0045\0042\0040address\00758\00568\00568\00568\0040index\00751\0040validate\0075no\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              [ $staticnetinfo != '' ] && [ $IPTYPE == 'v6' ] && echo -ne "set\0040\0042interface_name\0075\0042\r\nfor\0040\0057f\0040\0042tokens\00751\0040delims\0075\0054\0042\0040\0045\0045a\0040in\0040\0050\0047getmac\0040\0057v\0040\0057fo\0040csv\0040\0136\0174find\0040\0057i\0040\0042$MAC1\0042\0040\0047\0051\0040do\0040set\0040interface_name\0075\0045\0045\0176a\r\nif\0040defined\0040interface_name\0040netsh\0040int\0040ipv6\0040set\0040address\0040\0042\0045interface_name\0045\0042\0040$IP\r\nif\0040defined\0040interface_name\0040netsh\0040int\0040ipv6\0040add\0040route\0040\0072\0072\00570\0040\0042\0045interface_name\0045\0042\0040$GATE\r\nif\0040defined\0040interface_name\0040netsh\0040int\0040ipv6\0040add\0040dnsserver\0040\0042\0045interface_name\0045\0042\00402001\007267c\00722b0\0072\00724\r\nif\0040defined\0040interface_name\0040netsh\0040int\0040ipv6\0040add\0040dnsserver\0040\0042\0045interface_name\0045\0042\00402001\007267c\00722b0\0072\00726\0040index\00752\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              [ $passwordinfo != 0 ] && echo -ne "net\0040user\0040administrator\0040$passwordinfo\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              echo -ne "cd\0040\0057d\0040\0045SystemRoot\0045\0057System32\0057GroupPolicy\0057Machine\0057Scripts\0057Startup\r\nmove\0040\0057y\0040cloudinit\0056bat\0040\0045SystemDrive\0045\0057Users\0057Administrator\0057Desktop\0057net\0056txt\r\n\r\n\r\n" | iconv -f 'UTF-8' -t 'GBK' - >> thebiggestlastospart/Windows/System32/GroupPolicy/Machine/Scripts/Startup/cloudinit.bat
              # [ -d ] before cd cp?
              # ( cd '/thebiggestlastospart/ProgramData/Microsoft/Windows/Start Menu/Programs'; cd Start* || cd start*; cp -f '/cloudinit.txt' './net.bat';cd / )
              ( umount thebiggestlastospart )
            }
            db_progress STOP
            sleep 3
            # if tillnowinfo is 0, there is a exception, hold instead of reboot
            [ `cat /var/log/progress|sed '/^$/!h;$!d;g'|sed 's/bytes \(.*\)//g'` != '0' -a $instctlinfo != 3 ] && reboot
            ;;
    esac

done
