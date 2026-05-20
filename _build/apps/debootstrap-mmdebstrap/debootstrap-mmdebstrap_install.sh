###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get -y install mmdebstrap


cat > /root/start.sh << 'EOL'
cd /root
rm -rf rootfs

echo "debootstraping"
[[ ! -f mypackage/mypackage.deb || ! -s mypackage/mypackage.deb ]] && {
  rm -rf mypackage/mypackage.deb
  wget -q --no-check-certificate https://snapshot.debian.org/archive/debian/20231007T024024Z/pool/main/c/cdebconf/cdebconf_0.260_amd64.deb -O mypackage.deb
  mkdir -p mypackage/ctl mypackage/dat
  cd mypackage
  ar x ../mypackage.deb
  tar -C ctl -xJf control.tar.xz
  rm -rf control.tar.xz
  tar -C dat -xJf data.tar.xz
  rm -rf data.tar.xz
  #do some mod
  mkdir -p dat/usr/bin
  ln -s /usr/lib/cdebconf/debconf dat/usr/bin/debconf
  ln -s /usr/lib/cdebconf/debconf-copydb dat/usr/bin/debconf-copydb
  ln -s /usr/lib/cdebconf/debconf-dumpdb dat/usr/bin/debconf-dumpdb
  ln -s /usr/lib/cdebconf/debconf-loadtemplate dat/usr/bin/debconf-loadtemplate
  sed -e "s/debconf,\ //g" -e '$a\Breaks: debconf' -i ctl/control
  tar -C ctl -cJf control.tar.xz ./
  tar -C dat -cJf data.tar.xz ./
  ar rcs mypackage.deb debian-binary control.tar.xz data.tar.xz
}

cd /root
mmdebstrap  \
--aptopt='Acquire::Check-Valid-Until "false"' \
--aptopt='Apt::Key::gpgvcommand "/usr/libexec/mmdebstrap/gpgvnoexpkeysig"' \
--dpkgopt='path-exclude=/usr/share/man/*' \
--dpkgopt='path-exclude=/usr/share/locale/*' \
--dpkgopt='path-exclude=/usr/share/doc/*' \
--variant=custom \
--include=dpkg,busybox,libc-bin,base-files \
--include=libdebian-installer4,libnewt0.52,libselinux1,libslang2,libtextwrap1 \
--setup-hook='mkdir -p "$1/bin" "$1/sbin"' \
--setup-hook='for p in awk cat chmod chown cp diff echo env grep less ln mkdir mount rm rmdir sed sh sleep sort touch uname mktemp; do ln -s busybox "$1/bin/$p"; done' \
--setup-hook='echo root:x:0:0:root:/root:/bin/sh > "$1/etc/passwd"' \
--setup-hook='printf "root:x:0:\nmail:x:8:\nutmp:x:43:\n" > "$1/etc/group"' \
--customize-hook='chroot "$1" sh -c "\\
full_bb_bin=\"[ [[ ascii ar arch ash base64 basename bunzip2 bzcat bzip2 cal cat chgrp chvt clear cmp cpio crc32 cttyhack cut deallocvt dirname dmesg dnsdomainname dos2unix dumpkmap dumpleases egrep env expand expr factor fallocate false fatattr fgrep fold free ftpget ftpput grep groups gunzip gzip head hostid hostname id ionice ipcalc kill killall last link ln logger logname lsscsi lzcat lzma lzop md5sum microcom mkdir mkfifo mknod mkpasswd mktemp more mt netstat nl nproc nslookup od openvt paste patch pidof printf pwd realpath renice rev rm rmdir rpm rpm2cpio seq setkeycodes setpriv setsid sh sha1sum sha256sum sha3sum sha512sum shred sleep sort ssl_client stat strings stty sync tac tail taskset tee test tftp time timeout touch tr traceroute true truncate ts tty uname uncompress unexpand uniq unix2dos unlink unlzma unzip uptime usleep uudecode uuencode w watch wc which who whoami xxd yes zcat diff sed cp chmod chown find\";\\
full_bb_sbin=\"acpid adjtimex arp arping blockdev blkdiscard brctl chroot devmem findfs freeramdisk fsfreeze fstrim getty halt httpd hwclock ifconfig init ipneigh klogd linux32 linux64 loadfont loadkmap logread mkdosfs mkswap nameif partprobe pivot_root poweroff rdate reboot route swapoff swapon switch_root syslogd udhcpc udhcpd vconfig watchdog\";\\
busybox --list|while read linetop; do { \\
  echo \$full_bb_bin|sed \"s/\ /\n/g\"|while read line; do \\
    if [ \$linetop == \$line -a ! -f /bin/\$linetop ]; then \\
      ln -s busybox /bin/\$linetop; \\
    fi; \\
  done;\\
  echo \$full_bb_sbin|sed \"s/\ /\n/g\"|while read line; do \\
    if [ \$linetop == \$line -a ! -f /sbin/\$linetop ]; then \\
      ln -s busybox /sbin/\$linetop; \\
    fi; \\
  done; \\
}; done"' \
--customize-hook='cp mypackage/mypackage.deb "$1/var/cache/apt/archives/mypackage.deb" && chroot "$1" dpkg -i /var/cache/apt/archives/mypackage.deb' \
--customize-hook='echo host > "$1/etc/hostname"' \
--customize-hook='echo "127.0.0.1 localhost host" > "$1/etc/hosts"' \
bullseye rootfs.tar.gz "deb https://snapshot.debian.org/archive/debian/20231007T024024Z bullseye main" "deb https://snapshot.debian.org/archive/debian/20231007T024024Z bullseye-updates main" "deb https://snapshot.debian.org/archive/debian-security/20231007T024024Z bullseye-security main"
echo "debootstraped"

echo "Total size"
du -skh "rootfs.tar.gz"
EOL
chmod +x /root/start.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
