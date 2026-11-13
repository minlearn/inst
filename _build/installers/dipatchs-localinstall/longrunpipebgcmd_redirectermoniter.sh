#!/bin/sh

. /usr/share/debconf/confmodule
debconf-loadtemplate my_script /longrunpipebgcmd_redirectermoniter.templates

cores=$1
srchd=`echo "$cores" | awk -F ',' '{ print $1}'`
srchdinfo=`[ \`echo "$srchd"|grep "sd\|vd\|xvd\|nvme"\` ] && echo /dev/"$srchd" || ( for i in \`lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)'  | sed 's|^|/dev/|'\`;do [ \`sfdisk --disk-id $i|sed s/0x// |grep -ix $srchd \` ] && echo $i;done|head -n1;exit 0; )`
srcptinfo=`echo "$cores" | awk -F ',' '{ print $2}'`
filepathinfo=`echo "$cores" | awk -F ',' '{ print $3}'`
filenameinfo=`echo "$cores" | awk -F ',' '{ print $4}'`
unzipinfo=`echo "$cores" | awk -F ',' '{ print $5}'`
logger -t minlearnadd preddtime srchdinfo:$srchdinfo,filepathinfo:$filepathinfo,filenameinfo:$filenameinfo

hd=$2
# exit 0 is important when there is more than 1 block,it may failed
hdinfo=`[ \`echo "$hd"|grep "nonlinux"\` ] && echo \`lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)' | head -n 1 | sed 's|^|/dev/|'\` || { [ \`echo "$hd"|grep "sd\|vd\|xvd\|nvme"\` ] && echo /dev/"$hd" || ( for i in \`lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)'  | sed 's|^|/dev/|'\`;do [ \`sfdisk --disk-id $i|sed s/0x// |grep -ix $hd \` ] && echo $i;done|head -n1;exit 0; ); }`
# busybox sh dont support =~
hdinfoname=`[ \`echo "$hdinfo"|grep -Eo "nvme"\` ] && echo $hdinfo"p" || echo $hdinfo`
logger -t minlearnadd preddtime hdinfoname:$hdinfoname


pass1(){
            mkdir -p /osmnt;if mountpoint -q "/osmnt";then :;else mount -t ext4 "$srchdinfo$srcptinfo" /osmnt; fi

            filesize=$(wc -c < /osmnt/"$filepathinfo"/"$filenameinfo")
            disksize=$(lsblk -b -nr -o SIZE "$srchdinfo" -d)
            ptsize=$(lsblk -b -nr -o SIZE "$srchdinfo$srcptinfo")
            PARTITION_COUNT=$(lsblk -nr -o NAME,TYPE $srchdinfo | awk '$2 == "part" {print $1}'| wc -l)
            if [ $PARTITION_COUNT -gt $srcptinfo ]; then
              for i in `seq $((srcptinfo + 1)) $PARTITION_COUNT`;do
                parted -s $srchdinfo rm $i
              done
            fi
            diskavaliable=$(parted -s $srchdinfo unit b print free | awk '/Free Space$/ {end=$3} END{print end}' | sed 's/B$//')
            #find /osmnt -mindepth 1 ! -path /osmnt/"$filepathinfo"/1.gz ! -path /osmnt/"$filepathinfo" ! -path /osmnt/"$filepathinfo"/* -exec rm -rf {} +
            partavaliable=$(df -B1 | grep $srchdinfo$srcptinfo | awk '{print $4}')
            logger -t pass1 filesize:$filesize byte,disksize:$disksize byte,ptsize:$ptsize byte,diskavaliable:$diskavaliable byte,partavaliable:$partavaliable byte

            if [ $diskavaliable -ge $filesize ]; then
              logger -t pass1 enough
              PIPECMDSTR1='dd if=/osmnt/'$filepathinfo'/'$filenameinfo' of='$hdinfo' bs=512 seek=$((('$disksize' - '$filesize') / 512 )) conv=notrunc 2>> /var/log/progress1 & pid=`expr $! + 0`;echo $pid'
            else
              needborrowsize=$(($filesize - $diskavaliable))
              borrowoffset=$(($ptsize - $needborrowsize))
              logger -t pass1 not enough,need borrow from part:$needborrowsize byte,borrowoffset:$borrowoffset

              if [ $partavaliable -ge $needborrowsize ]; then
                printf "unit\nb\nresizepart\n$srcptinfo\nYes\n$borrowoffset\nYes\nquit" | parted "$srchdinfo" ---pretend-input-tty >/dev/null 2>&1
                logger -t pass1 enough
                PIPECMDSTR1='dd if=/osmnt/'$filepathinfo'/'$filenameinfo' of='$hdinfo' bs=512 seek=$((('$disksize' - '$filesize') / 512 )) conv=notrunc 2>> /var/log/progress1 & pid=`expr $! + 0`;echo $pid'                          
              else
                logger -t pass1 hardly happen
                exit 1
              fi
            fi

            logger -t minlearnadd preddtime PIPECMDSTR1:"$PIPECMDSTR1"
}
for step in pass1 pass2 pass3; do

    if ! db_progress INFO my_script/progress/$step; then
            db_subst my_script/progress/fallback STEP "$step"
            db_progress INFO my_script/progress/fallback
    fi

    case $step in
       "pass1")
           db_progress START 0 100 my_script/progress/pass1
           db_progress INFO my_script/progress/pass1
           db_progress SET 0
           pass1
            pidinfo=`eval "$PIPECMDSTR1"`
            PCTCOUNT="0";
            while :; do 
            {
              # we make sleep longer, to micmic a fake progress
              sleep 10
              statusinfo=`kill -USR1 $pidinfo;cat /var/log/progress1|sed '/^$/!h;$!d;g'`
              db_subst my_script/progress/pass1 STATUS "${statusinfo}"
              tillnowinfo=`echo $statusinfo|sed 's/bytes \(.*\)//g'`
              db_progress STEP 1
            }
            if kill -s 0 $pidinfo; then :; else { db_progress SET 100 && break; }; fi
            done
            sleep 3

            umount -f /osmnt;if mountpoint -q "/osmnt";then echo "still mounted" && exit 1; fi

           ;;

       "pass2")
           db_progress START 0 100 my_script/progress/pass2
           db_progress INFO my_script/progress/pass2
           db_progress SET 0

            offset=$(($disksize - $filesize ))
            chunks=$(($filesize / 1048576 ))


            [ "$unzipinfo" = '1' ] && PIPECMDSTR2='(for i in `seq 0 '$chunks'`; do dd if='$hdinfo' bs=512 skip=$(((($i * 1048576) + '$offset') / 512 )) count='$((1048576 / 512))' 2>/dev/null;done) | gunzip -dc | dd of='$hdinfo' bs=512 2>> /var/log/progress2 & pid=`expr $! + 0`;echo $pid'
            [ "$unzipinfo" = '2' ] && PIPECMDSTR2='(for i in `seq 0 '$chunks'`; do dd if='$hdinfo' bs=512 skip=$(((($i * 1048576) + '$offset') / 512 )) count='$((1048576 / 512))' 2>/dev/null;done) | xzcat | dd of='$hdinfo' bs=512 2>> /var/log/progress2 & pid=`expr $! + 0`;echo $pid'
            logger -t minlearnadd preddtime PIPECMDSTR2:"$PIPECMDSTR2"

            pidinfo=`eval "$PIPECMDSTR2"`
            PCTCOUNT="0";
            while :; do 
            {
              # we make sleep longer, to micmic a fake progress
              sleep 10
              statusinfo=`kill -USR1 $pidinfo;cat /var/log/progress2|sed '/^$/!h;$!d;g'`
              db_subst my_script/progress/pass2 STATUS "${statusinfo}"
              tillnowinfo=`echo $statusinfo|sed 's/bytes \(.*\)//g'`
              db_progress STEP 1
            }
            if kill -s 0 $pidinfo; then :; else { db_progress SET 100 && break; }; fi
            done
            sleep 3

           ;;

       "pass3")
           db_progress INFO my_script/progress/pass3

           reboot
           ;;
           
    esac

done
