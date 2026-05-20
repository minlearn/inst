##########

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg
echo "Installed Dependencies"

echo "Installing MongoDB"
wget -qO- https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor >/usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] http://repo.mongodb.org/apt/debian $(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2)/mongodb-org/7.0 main" >/etc/apt/sources.list.d/mongodb-org-7.0.list
silent apt-get update
silent apt-get install -y mongodb-org
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
systemctl enable -q --now mongod.service
echo "Installed MongoDB"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###########
