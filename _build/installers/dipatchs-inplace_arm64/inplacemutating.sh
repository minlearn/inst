deepumount(){

  # for inplacedd
  umount -f -l "$remasteringdir/x" >/dev/null 2>&1
  # if in a gui natuils filemanager or sth, x is mounted twice, if this is not unmounted, then losetup -d wont take effect
  [[ -d /media/$(whoami) ]] && ls /media/$(whoami)|while read line;do umount -f -l $line >/dev/null 2>&1;done
  # abspath is needed
  losetup -j "$topdir/$remasteringdir/vm-1010102-disk-0.raw" >/dev/null 2>&1|while read line;do losetup -d `echo $line|awk '{print $1}'|sed 's/://'` >/dev/null 2>&1;done
  [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { if mountpoint -q "$remasteringdir/x";then echo "$remasteringdir/x" still mounted && exit 1;fi; }

}

inplacemutating(){


  [[ "$tmpTARGET" == 'debianct' || "$tmpTARGET" == 'devdeskct' ]] && [[ "$tmpCTVIRTTECH" != '' && "$tmpCTVIRTTECH" == '1' ]] && {


    ### migrate_configuration
    sed -i '/^root:/d' /x/etc/shadow
    grep '^root:' /etc/shadow >> /x/etc/shadow
    # [ -d /root/.ssh ] && cp -a /root/.ssh /x/root/
    [ -d /x/etc/network/ ] || mkdir -p /x/etc/network/
    if [ -f /etc/network/interfaces ] && grep static /etc/network/interfaces > /dev/null ; then
        cp -rf /etc/network/interfaces /x/etc/network/interfaces
    else
        cp -rf $remasteringdir/ctrnet /x/etc/network/interfaces
    fi
    rm /x/etc/resolv.conf
    cp -rf $remasteringdir/ctrdns /x/etc/resolv.conf


    ### replace_os
    mkdir /x/oldroot
    mount --bind / /x/oldroot
    chroot "/x/" /bin/bash -c 'cd /oldroot; '`
        `'rm -rf $(ls /oldroot | grep -vE "(^dev|^proc|^sys|^run|^x)") ; '`
        `'cd /; '`
        `'mv -f $(ls / | grep -vE "(^dev|^proc|^sys|^run|^oldroot)") /oldroot'
    umount /x/oldroot


    ### post_install
    export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
    apt-get install -y -qq openssh-server openssh-client net-tools
    # systemctl disable systemd-networkd.service
    echo PermitRootLogin yes >> /etc/ssh/sshd_config
    rm -rf /x
    sync
  }

  [[ "$tmpTARGET" == 'debianct' || "$tmpTARGET" == 'devdeskct' ]] && [[ "$tmpCTVIRTTECH" != '' && "$tmpCTVIRTTECH" == '2' ]] && {

    tmpDEV=$(mount | grep "$remasteringdir/x" | awk '{print $1}')
    [ -z "$tmpDEV" ] && {

      tmpDEV=`losetup -fP --show $remasteringdir/vm-1010102-disk-0.raw | awk '{print $1}'`
      sleep 2 && echo -en "[ \033[32m tmpdev: $tmpDEV \033[0m ]"
    
      [ -n "$tmpDEV" ] && {

       sleep 2 && echo -en "[ \033[32m tmpmnt: "$remasteringdir/x" \033[0m ]"
       mount "$tmpDEV"p1 "$remasteringdir/x"
      }

      #[ ! -d "$remasteringdir/x" ] && {
      #}
    }

    [[ -f "$remasteringdir/x"/etc/network/interfaces ]] && sed -i "s/iface eth0 inet dhcp/iface eth0 inet static\n  address $IP\n  netmask $MASK\n  gateway $GATE/g" "$remasteringdir/x"/etc/network/interfaces
    [[ -f "$remasteringdir/x"/init ]] && sed -i "s/vda/$DEFAULTHD/g" "$remasteringdir/x"/init
    deepumount

  }


  #[[ "$tmpCTVIRTTECH" != '' && "$tmpCTVIRTTECH" == '1' ]] && echo #rsync -a -v --delete-after --ignore-times --exclude="/dev" --exclude="/proc" --exclude="/sys" --exclude="/x" --exclude="/run" $topdir/$remasteringdir/x/* /
  # we cant echo anything out,or dd will fail,this is strange
  #[[ "$tmpCTVIRTTECH" != '' && "$tmpCTVIRTTECH" == '2' ]] && echo u > /proc/sysrq-trigger && dd if="$topdir/$remasteringdir/vm-1010102-disk-0.raw" of=/dev/"$DEFAULTHD" bs=10M #status=progress
}
