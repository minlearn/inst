###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y \
  curl \
  sudo \
  mc \
  gpg
echo "Installed Dependencies"



silent apt-get install -y git
silent apt-get install -y build-essential autoconf libtool pkg-config
silent apt-get install -y libdebconfclient0-dev libdebian-installer4-dev libiw-dev

echo "Installing"

cd /root

# rootskel first
# 1.133
silent git clone https://salsa.debian.org/installer-team/rootskel.git debian-install
silent git -C debian-install checkout 1.133

# debian/0.1.18-17
silent git -C debian-install clone https://salsa.debian.org/debian/bogl.git
silent git -C debian-install/bogl checkout debian/0.1.18-17
# 1.6
silent git -C debian-install clone https://salsa.debian.org/installer-team/bterm-unifont.git
silent git -C debian-install/bterm-unifont checkout 1.6
# 6.3:debian-bullseye
silent git -C debian-install clone https://salsa.debian.org/a11y-team/brltty.git
silent git -C debian-install/brltty checkout debian-bullseye
# debian/1%1.30.1-6
silent git -C debian-install clone https://salsa.debian.org/installer-team/busybox.git
silent git -C debian-install/busybox checkout debian/1%1.30.1-6
# debian/0.52.21-4
silent git -C debian-install clone https://salsa.debian.org/debian/newt.git
silent git -C debian-install/newt checkout debian/0.52.21-4
# debian/2.3.2-5
silent git -C debian-install clone https://salsa.debian.org/debian/slang2.git
silent git -C debian-install/slang2 checkout debian/2.3.2-5
# debian/28-1
silent git -C debian-install clone https://salsa.debian.org/md/kmod.git
silent git -C debian-install/kmod checkout debian/28-1
# debian/0.1-14.2
silent git -C debian-install clone https://salsa.debian.org/debian/libtextwrap.git
silent git -C debian-install/libtextwrap checkout debian/0.1-14.2
# debian/4.8.0-6
silent git -C debian-install clone https://salsa.debian.org/debian/screen.git
silent git -C debian-install/screen checkout debian/4.8.0-6
# debian/247.3-7 # udev
silent git -C debian-install clone https://salsa.debian.org/systemd-team/systemd.git
silent git -C debian-install/systemd checkout debian/247.3-7
# 0.260
silent git -C debian-install clone https://salsa.debian.org/installer-team/cdebconf.git
silent git -C debian-install/cdebconf checkout 0.260
# 1.140
silent git -C debian-install clone https://salsa.debian.org/installer-team/debian-installer-utils.git
silent git -C debian-install/debian-installer-utils checkout 1.140
# 0.121
silent git -C debian-install clone https://salsa.debian.org/installer-team/libdebian-installer.git
silent git -C debian-install/libdebian-installer checkout 0.121
# 1.62
silent git -C debian-install clone https://salsa.debian.org/installer-team/main-menu.git
silent git -C debian-install/main-menu checkout 1.62
# 1.109
silent git -C debian-install clone https://salsa.debian.org/installer-team/preseed.git
silent git -C debian-install/preseed checkout 1.109
# 1.20
silent git -C debian-install clone https://salsa.debian.org/installer-team/udpkg.git
silent git -C debian-install/udpkg checkout 1.20
# 2.78
silent git -C debian-install clone https://salsa.debian.org/installer-team/installation-report.git
silent git -C debian-install/installation-report checkout 2.78

echo "Installed"

find /root/debian-install \( -type d -name .git -prune -o -type f -name .gitignore -o -type f -name .cvsignore \) -exec sh -c 'for i; do echo "del: $i"; rm -rf "$i"; done' sh {} +
tar cpzf debian-installer.tar.gz debian-install

cd /root/debian-install
for i in bogl bterm-unifont brltty busybox newt slang2 kmod libtextwrap screen systemd cdebconf debian-installer-utils main-menu preseed udpkg installation-report; do
  (cd $i && apt-get build-dep -y . && dpkg-buildpackage -us -uc -b)
done

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
