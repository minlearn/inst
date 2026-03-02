###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg netcat
echo "Installed Dependencies"

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
wget -q --no-check-certificate $rlsmirror/darkstar.tar.gz -O download/server.tar.gz

DRAKS_DIR=/root/app/darkstar

# when build: apt-get install -y --allow-unauthenticated libmysqlclient-dev=5.6.* c autoconf pkg-config build-essential
silent apt-get -y install default-mysql-client libsodium-dev libpgm-dev libnorm-dev zlib1g-dev

echo "Installing darkstar..."
mkdir -p ${DRAKS_DIR}
tar -xzf download/server.tar.gz -C /usr/lib/x86_64-linux-gnu darkstar/libmysqlclient.so.18 --strip-components=1
tar -xzf download/server.tar.gz -C /usr/lib/x86_64-linux-gnu darkstar/liblua5.1.so.0 --strip-components=1
tar -xzf download/server.tar.gz -C /usr/lib/x86_64-linux-gnu darkstar/libzmq.so.5 --strip-components=1
tar -xzf download/server.tar.gz -C ${DRAKS_DIR} --strip-components=1


cat <<EOF >/lib/systemd/system/darkstar-connect.service
[Unit]
Description=Darkstar Final Fantasy XI - DS Connect
Wants=network.target
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
Restart=always
RestartSec=5
WorkingDirectory=${DRAKS_DIR}
ExecStart=${DRAKS_DIR}/bin/dsconnect

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/darkstar-game.service
[Unit]
Description=Darkstar Final Fantasy XI - DS Game
Wants=network.target
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
Restart=always
RestartSec=5
WorkingDirectory=${DRAKS_DIR}
ExecStart=${DRAKS_DIR}/bin/dsgame

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/darkstar-search.service
[Unit]
Description=Darkstar Final Fantasy XI - DS Search
Wants=network.target
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
Restart=always
RestartSec=5
WorkingDirectory=${DRAKS_DIR}
ExecStart=${DRAKS_DIR}/bin/dssearch

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/root/init.sh
#!/bin/bash

if [ -f /root/inited ]; then echo "already inited, del /root/inited to re init"; fi
if [ ! -f /root/inited ]; then
read -p "give a dbip(127.0.0.1,10.10.10.x,publicip,etc..):" ip
read -p "give a dbpassword:" pw
HOSTNAME=\$ip
PORT="3306"
USERNAME="root"
PASSWORD=\${pw/\//\\\/}

# Wait for Mysql to become available.
until nc -z -v -w30 \${HOSTNAME} 3306; do
  echo "Database @\${HOSTNAME} not yet available. Sleeping..."
  sleep 10
done

mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "SELECT VERSION();" | grep -q "5.6"
if [ \$? -ne 0 ]; then
  echo "MySQL 版本不是5.6，脚本退出"
  exit 1
fi

mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database dspdb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

for SQL_FILE in ${DRAKS_DIR}/sql/*.sql
  do
    echo -n "Importing \$SQL_FILE into the database..."
    mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} dspdb < "\$SQL_FILE" && echo "Success"
  done
echo "数据库导入成功"

read -p "give a zone ip(usually the global ip):" zoneip
ZONEIP=\$zoneip

# Update zone settings db.
echo "Using Zone IP: \${ZONEIP}"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} dspdb -e "UPDATE zone_settings SET zoneip = '\${ZONEIP}'"

# Update GM lists db.
# ......

# Process environment variables in the configuration files.
sed -i "s/DRK_DB_HOST/\${HOSTNAME}/g" ${DRAKS_DIR}/conf/*.conf
sed -i "s/DRK_DB_PASSWORD/\${PASSWORD}/g" ${DRAKS_DIR}/conf/*.conf
echo "配置文件修改成功"

systemctl restart darkstar-connect darkstar-game darkstar-search
touch /root/inited
fi
EOF
chmod +x /root/init.sh

systemctl enable -q --now darkstar-connect darkstar-game darkstar-search

echo "darkstar installation completed successfully!"
echo "You can access it at: tcp 54001,54002,54231,53445,54230 udp 54230"


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
