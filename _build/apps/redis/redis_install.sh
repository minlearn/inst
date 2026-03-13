##########

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc apt-transport-https gpg lsb-release
echo "Installed Dependencies"

echo "Installing Redis"
wget -qO- https://packages.redis.io/gpg | gpg --dearmor >/usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" >/etc/apt/sources.list.d/redis.list
silent apt-get update
silent apt-get install -y redis
sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
systemctl enable -q --now redis-server.service
echo "Installed Redis"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##########