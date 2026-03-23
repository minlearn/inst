###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}

mkdir -p /x
wget --no-check-certificate $rlsmirror/openwrt-22.03.5-x86-64-rootfs.tar.gz -O /tmp/rootfs.tar.gz
tar -xzf /tmp/rootfs.tar.gz -C /x --strip-components=1
rm -rf /tmp/rootfs.tar.gz

VERSION=$(curl -L -H "Accept: application/vnd.github+json"    -H "X-GitHub-Api-Version: 2022-11-28"  https://api.github.com/repos/vernesong/OpenClash/git/refs/tags|grep "\"ref\": \"refs/tags/v"|tail -n 1|grep -Po '(?<=v)[^"]*')
wget --no-check-certificate https://github.com/vernesong/OpenClash/releases/download/v${VERSION}/luci-app-openclash_${VERSION}_all.ipk -O /x/root/openclash.ipk

#ctrnet
#ctrdns

### migrate_configuration
sed -i '/^root:/d' /x/etc/shadow
grep '^root:' /etc/shadow >> /x/etc/shadow
# [ -d /root/.ssh ] && cp -a /root/.ssh /x/root/
#[ -d /x/etc/network/ ] || mkdir -p /x/etc/network/
#if [ -f /etc/network/interfaces ] && grep static /etc/network/interfaces > /dev/null ; then
#  cp -rf /etc/network/interfaces /x/etc/network/interfaces
#else
  #cp -rf $remasteringdir/ctrnet /x/etc/network/interfaces
#fi
#rm /x/etc/resolv.conf
#cp -rf $remasteringdir/ctrdns /x/etc/resolv.conf

echo -e "config interface 'loopback'\noption ifname 'lo'\noption proto 'static'\noption ipaddr '127.0.0.1'\noption netmask '255.0.0.0'\n\n\
  config globals 'globals'\noption ula_prefix 'fdba:b4f6:0744::/48'\n\n\
  config interface 'lan'\noption type 'bridge'\noption ifname 'eth0'\noption proto 'static'\noption ipaddr '10.10.10.253'\noption gateway '10.10.10.254'\noption netmask '255.255.255.0'\noption dns '114.114.114.114 8.8.8.8'\noption ip6assign '60'\n\n\
  #config interface 'wan'\n#option ifname 'eth0'\n#option proto 'static'\n#option ipaddr '10.10.10.100'\n#option netmask '255.255.255.0'" > /x/etc/config/network
echo -e "\n# --- BEGIN PVE ---\n10.10.10.253 owt\n# --- END PVE ---" >> /x/etc/hosts

echo 'net.ipv4.ip_forward = 1' | tee -a /x/etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /x/etc/sysctl.conf

### replace_os
mkdir /x/oldroot
mount --bind / /x/oldroot
chroot "/x/" /bin/sh -c 'cd /oldroot; '`
  `'rm -rf $(ls /oldroot | grep -vE "(^dev|^proc|^sys|^run|^x)") ; '`
  `'cd /; '`
  `'mv -f $(ls / | grep -vE "(^dev|^proc|^sys|^run|^oldroot)") /oldroot'
umount /x/oldroot

### post_install
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"

#opkg update
#opkg remove dnsmasq
#mv /etc/config/dhcp /etc/config/dhcp.bak
#opkg install iptables dnsmasq-full coreutils coreutils-nohup bash curl jsonfilter ca-certificates ipset ip-full iptables-mod-tproxy kmod-tun
#opkg install luci-compat
#opkg install /root/openclash.ipk

#apt-get install -y -qq openssh-server openssh-client net-tools
# systemctl disable systemd-networkd.service
echo PermitRootLogin yes >> /etc/ssh/sshd_config
rm -rf /x
sync

echo "rebooting"
reboot
echo "rebooted"

##############
