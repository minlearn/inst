###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg
echo "Installed Dependencies"

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
wget --no-check-certificate $rlsmirror/server.tar.gz -O download/server.tar.gz
wget --no-check-certificate $rlsmirror/html.tar.xz -O download/html.tar.xz

BXCQS_DIR=/root/app/bxcq
BXCQC_DIR=/var/www/html


silent apt-get -y install default-mysql-client

# Install Apache, PHP, and necessary PHP extensions
echo "Installing Apache and PHP..."
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ bullseye main" >> /etc/apt/sources.list
silent apt-get update
silent apt-get install -y apache2 libapache2-mod-php5.6 php5.6 php5.6-gd php5.6-sqlite3 php5.6-mysql php5.6-mbstring php5.6-xml php5.6-zip

# Enable Apache mods
a2enmod rewrite

echo "Installing bxcq..."
mkdir -p ${BXCQS_DIR}
tar -xzf download/server.tar.gz -C /lib/x86_64-linux-gnu server/libmysqlclient.so.16 --strip-components=1
tar -xzf download/server.tar.gz -C ${BXCQS_DIR} --strip-components=1
mkdir -p ${BXCQC_DIR}
tar -xJf download/html.tar.xz -C ${BXCQC_DIR} --strip-components=1
chown -R www-data:www-data ${BXCQC_DIR}

# Configure Apache to serve bxcq
echo "Configuring Apache..."
BXCQ_CONF="/etc/apache2/sites-available/000-default.conf"
sed -i "/DocumentRoot \/var\/www\/html/a <Directory ${BXCQC_DIR}/>\n    Options FollowSymlinks\n    AllowOverride All\n    Require all granted\n</Directory>" $BXCQ_CONF
a2ensite 000-default.conf
systemctl restart apache2

echo "bxcq installation completed successfully!"
echo "You can access bxcq at: http://${DOMAIN_OR_IP}/"


cat <<EOF >/lib/systemd/system/amserver.service
[Unit]
Description=AMServer
After=syslog.target
After=network.target

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${BXCQS_DIR}/build/AMServer
ExecStart=${BXCQS_DIR}/build/AMServer/amserver_r ${BXCQS_DIR}/build/AMServer/AMServerLinux.txt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/backstageserver.service
[Unit]
Description=BackStageServer
After=amserver
After=amserver

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${BXCQS_DIR}/build/BackStageServer
ExecStart=${BXCQS_DIR}/build/BackStageServer/backstageserver_r ${BXCQS_DIR}/build/BackStageServer/BackStageServerLinux.txt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/loggerserver.service
[Unit]
Description=LoggerServer
After=backstageserver
After=backstageserver

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${BXCQS_DIR}/build/LoggerServer
ExecStart=${BXCQS_DIR}/build/LoggerServer/loggerserver_r ${BXCQS_DIR}/build/LoggerServer/LoggerServerLinux.txt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/nameserver.service
[Unit]
Description=NameServer
After=loggerserver
After=loggerserver

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${BXCQS_DIR}/build/NameServer
ExecStart=${BXCQS_DIR}/build/NameServer/nameserver_r ${BXCQS_DIR}/build/NameServer/NameServerLinux.txt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/sessionserver.service
[Unit]
Description=SessionServer
After=nameserver
After=nameserver

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${BXCQS_DIR}/build/SessionServer
ExecStart=${BXCQS_DIR}/build/SessionServer/sessionserver_r ${BXCQS_DIR}/build/SessionServer/SessionServerLinux.txt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/dbserver.service
[Unit]
Description=DBServer
After=sessionserver
After=sessionserver

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${BXCQS_DIR}/Debug/DBServer
ExecStart=${BXCQS_DIR}/Debug/DBServer/dbserver_r ${BXCQS_DIR}/Debug/DBServer/DBServerLinux.txt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/gateserver.service
[Unit]
Description=GateServer
After=dbserver
After=dbserver

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${BXCQS_DIR}/Debug/GateServer
ExecStart=${BXCQS_DIR}/Debug/GateServer/gateserver_r ${BXCQS_DIR}/Debug/GateServer/GateWay.txt
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/lib/systemd/system/logicserver.service
[Unit]
Description=LogicServer
After=gateserver
After=gateserver

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${BXCQS_DIR}/Debug/LogicServer
ExecStart=${BXCQS_DIR}/Debug/LogicServer/logicserver_r ${BXCQS_DIR}/Debug/LogicServer/LogicServerLinux.txt
Restart=always

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

mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "SELECT VERSION();" | grep -q "5.6"
if [ \$? -ne 0 ]; then
  echo "MySQL 版本不是5.6，脚本退出"
  exit 1
fi

mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database actor_c1001 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database actor_cross1 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database log_s1 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database mmo_account DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database web DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database zgame_amdb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database zgame_command DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database zgame_name DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} actor_c1001 < ${BXCQS_DIR}/database/actor_c1001.sql
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} actor_cross1 < ${BXCQS_DIR}/database/actor_cross1.sql
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} log_s1 < ${BXCQS_DIR}/database/log_s1.sql
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} mmo_account < ${BXCQS_DIR}/database/mmo_account.sql
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} web < ${BXCQS_DIR}/database/web.sql
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} zgame_amdb < ${BXCQS_DIR}/database/zgame_amdb.sql
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} zgame_command < ${BXCQS_DIR}/database/zgame_command.sql
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} zgame_name < ${BXCQS_DIR}/database/zgame_name.sql
echo "数据库导入成功"

sed -e s/host=\"127.0.0.1\"/host=\"\${HOSTNAME}\"/g -e s/pass=\"123456\"/pass=\"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/AMServer/AMServer.txt
sed -e s/host=\"127.0.0.1\"/host=\"\${HOSTNAME}\"/g -e s/pass=\"123456\"/pass=\"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/AMServer/AMServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/BackStageServer/BackStageServer.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/BackStageServer/BackStageServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/LoggerServer/LoggerServer.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/LoggerServer/LoggerServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/NameServer/NameServer.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/NameServer/NameServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/SessionServer/SessionServer.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/build/SessionServer/SessionServerLinux.txt

sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/Debug/DBServer/DBServer.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/Debug/DBServer/DBServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/Debug_cross/DBServer/DBServer.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -i ${BXCQS_DIR}/Debug_cross/DBServer/DBServerLinux.txt

#sed -i s/192.168.1.76/109.238.11.168/g ${BXCQS_DIR}/Debug/LogicServer/CrossSourceServer.config
#sed -i s/192.168.1.76/109.238.11.168/g ${BXCQS_DIR}/Debug/LogicServer/data/config/Cross/CrossSourceServer.config
#sed -i s/192.168.1.76/109.238.11.168/g ${BXCQS_DIR}/Debug/LogicServer_r/data/config/Cross/CrossSourceServer.config

sed -e "s/'DB_HOST'=>'127.0.0.1'/'DB_HOST'=>'\${HOSTNAME}'/g" -e "s/'DB_PSWD'=>'123456'/'DB_PSWD'=>'\${PASSWORD}'/g" -i ${BXCQC_DIR}/login/api/reg.php

read -p "give a cliipwithport:" cli
CLIENT=\$cli

sed -i s/192.168.1.76:81/\${CLIENT}/g ${BXCQC_DIR}/index.js
sed -i s/192.168.1.76:81/\${CLIENT}/g ${BXCQC_DIR}/index1.js
sed -e s/192.168.1.76/\${CLIENT%:*}/g -i ${BXCQC_DIR}/GetServerList.php
echo "配置文件修改成功"

systemctl restart amserver backstageserver loggerserver nameserver sessionserver dbserver gateserver logicserver
touch /root/inited
fi
EOF
chmod +x /root/init.sh

systemctl enable -q --now amserver backstageserver loggerserver nameserver sessionserver dbserver gateserver logicserver


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
