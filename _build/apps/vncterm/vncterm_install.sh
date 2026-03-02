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

echo "Installing"

cd /root

silent apt-get install -y build-essential cmake pkg-config
wget --no-check-certificate https://github.com/LibVNC/libvncserver/archive/refs/tags/LibVNCServer-0.9.13.tar.gz
tar xzf LibVNCServer-0.9.13.tar.gz
cd libvncserver-LibVNCServer-0.9.13
silent cmake .
silent make
silent make install
cd ..
rm -rf LibVNCServer-0.9.13.tar.gz

silent apt-get install -y autoconf
wget --no-check-certificate https://github.com/LibVNC/vncterm/archive/refs/tags/0.9.10.tar.gz
tar xzf 0.9.10.tar.gz
cd vncterm-0.9.10
silent autoreconf -i
silent ./configure
silent make
cd ..
rm -rf 0.9.10.tar.gz

#wget --no-check-certificate https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.tar.gz


echo "Installed"



echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
