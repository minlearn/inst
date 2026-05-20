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

curl -fsSL https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg | gpg --dearmor  -o /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
echo "deb http://download.proxmox.com/debian/devel bullseye main" >/etc/apt/sources.list.d/pvedevel.list
echo "deb http://download.proxmox.com/debian/pbs bullseye pbs-no-subscription" >/etc/apt/sources.list.d/pbsnosub.list
silent apt-get update

echo "Installing"

silent apt-get install -y git

cd /root

# 2.4.1-1
silent git clone https://git.proxmox.com/git/proxmox-backup.git
silent git -C proxmox-backup checkout 3da94f2e7429ea1653ed5e61a0f83e67ff02b8be
tar cpzf proxmox-backup.tar.gz proxmox-backup

#######################################

silent apt-get install -y clang debcargo git devscripts
silent apt-get install -y jq

cd proxmox-backup
silent mk-build-deps --install
silent make
cd ..

echo "Installed"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############
