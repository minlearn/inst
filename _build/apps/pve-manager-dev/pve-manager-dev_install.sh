############

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
silent apt-get install -y build-essential devscripts
silent apt-get install -y cargo dh-cargo

cd /root

# 7.4-3
silent git clone https://git.proxmox.com/git/pve-manager-legacy.git pve-manager
silent git -C pve-manager checkout 9002ab8a0da849a922d48aed7e52f3e3c6d921f4


tar cpzf pve-manager.tar.gz pve-manager


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############
