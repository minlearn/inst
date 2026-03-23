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

silent apt-get install -y build-essential libdebconfclient0-dev libdebian-installer4-dev libiw-dev
wget --no-check-certificate https://salsa.debian.org/installer-team/netcfg/-/archive/1.160/netcfg-1.160.tar.gz
tar xzf netcfg-1.160.tar.gz
cd netcfg-1.160
silent make
cd ..
rm -rf netcfg-1.160.tar.gz

wget --no-check-certificate https://salsa.debian.org/installer-team/choose-mirror/-/archive/buster/choose-mirror-buster.tar.gz
tar xzf choose-mirror-buster.tar.gz
cd choose-mirror-buster
silent make
cd ..
rm -rf choose-mirror-buster.tar.gz

echo "Installed"



echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
