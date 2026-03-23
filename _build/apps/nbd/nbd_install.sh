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

silent apt-get install -y build-essential autoconf automake pkg-config libtool
wget --no-check-certificate https://gitlab.gnome.org/GNOME/libxml2/-/archive/v2.9.10/libxml2-v2.9.10.tar.gz
tar xzf libxml2-v2.9.10.tar.gz
cd libxml2-v2.9.10
silent ./autogen.sh --enable-shared=no --prefix=/usr
export CFLAGS="-fpic"
silent make
silent make install
cd ..
rm -rf libxml2-v2.9.10.tar.gz

wget --no-check-certificate https://gitlab.com/nbdkit/libnbd/-/archive/v1.6.1/libnbd-v1.6.1.tar.gz
tar xzf libnbd-v1.6.1.tar.gz
cd libnbd-v1.6.1
silent autoreconf -i
silent ./configure --prefix=/usr
silent make
silent make install
cd ..
rm -rf libnbd-v1.6.1.tar.gz

silent apt-get install -y libssl-dev
wget --no-check-certificate https://curl.se/download/curl-7.74.0.tar.gz
tar xzf curl-7.74.0.tar.gz
cd curl-7.74.0
silent ./configure --disable-shared --prefix=/usr
silent make
silent make install
cd ..
rm -rf curl-7.74.0.tar.gz

silent apt-get install -y zlib1g-dev
wget --no-check-certificate https://gitlab.com/nbdkit/nbdkit/-/archive/v1.36.0/nbdkit-v1.36.0.tar.gz
tar xzf nbdkit-v1.36.0.tar.gz
cd nbdkit-v1.36.0
silent autoreconf -i
silent ./configure --prefix=/usr
silent make
silent make install
cd ..
rm -rf nbdkit-v1.36.0.tar.gz

echo "Installed"



echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
