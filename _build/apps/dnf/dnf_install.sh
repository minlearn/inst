###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg netcat procps socat net-tools geoip-database
echo "Installed Dependencies"

dpkg --add-architecture i386
silent apt-get update -y
silent apt-get -y install libc6:i386 libstdc++6:i386 zlib1g:i386

if apt list --installed 2>/dev/null | grep -q 'mysql-community-client/.*5\.6\.'; then
    echo "mysql-community-client 5.6 已安装，不装 default-mysql-client,如果继续安装，5.6可能会被mask。"
else
    silent apt-get -y install default-mysql-client
fi

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
wget -q --no-check-certificate $rlsmirror/dnfserver.tar.xz -O download/server.tar.xz

DNFS_DIR=/root/app/dnf
SERVER_GROUP_NAME=cain
SERVER_GROUP_DB=cain
SERVER_GROUP=3
PUBLIC_IP=$(curl -s -m 20 https://ddns.oray.com/checkip | awk '{print $NF}' || echo "127.0.0.1")
MAIN_BRIDGE_IP=127.0.0.1
OPEN_CHANNEL='11,52'
SLIM_SIZE=10

echo "Installing dnf..."
mkdir -p ${DNFS_DIR}
tar -xJf download/server.tar.xz -C ${DNFS_DIR} --strip-components=1
cp ${DNFS_DIR}/libgeoip_compat\(libGeoIP.so.1\).so /usr/lib/i386-linux-gnu/libGeoIP.so.1
cp ${DNFS_DIR}/libgeoip_compat\(libGeoIP.so.1\).so /lib/i386-linux-gnu/libGeoIP.so.1
cp ${DNFS_DIR}/libnxencryption.so /usr/lib/i386-linux-gnu/
cp ${DNFS_DIR}/libnxencryption.so /lib/i386-linux-gnu/


for i in \
  "stun::stun:start_stun.sh"\
  "monitor:dnf_stun:monitor:start_monitor.sh"\
  "manager:dnf_monitor:manager:start_manager.sh"\
  "relay:dnf_manager:relay:start_relay.sh"\
  "bridge:dnf_relay:bridge:start_bridge.sh"\
  "channel:dnf_bridge:channel:start_channel.sh"\
  "dbmw_guild:dnf_channel:dbmw_guild:start_dbmw_guild.sh"\
  "dbmw_mnt:dnf_dbmw_guild:dbmw_mnt:start_dbmw_mnt.sh"\
  "dbmw_stat:dnf_dbmw_mnt:dbmw_stat:start_dbmw_stat.sh"\
  "auction:dnf_dbmw_stat:auction:start_auction.sh"\
  "point:dnf_auction:point:start_point.sh"\
  "guild:dnf_point:guild:start_guild.sh"\
  "statics:dnf_guild:statics:start_statics.sh"\
  "coserver:dnf_statics:coserver:start_coserver.sh"\
  "community:dnf_coserver:community:start_community.sh"\
  "gunnersvr:dnf_community:secsvr/gunnersvr:start_gunnersvr.sh"\
  "secagent:dnf_gunnersvr:secsvr/zergsvr:start_zergsvr_secagent.sh"\
  "zergsvr:dnf_secagent:secsvr/zergsvr:start_zergsvr.sh"\
  "game::game:start_game.sh"\
;do
  name=$(echo $i | cut -d: -f1)
  deps=$(echo $i | cut -d: -f2)
  dir=$(echo $i | cut -d: -f3)
  exec=$(echo $i | cut -d: -f4)

  echo "Creating systemd service for $name"
  cat <<EOF >/lib/systemd/system/dnf_$name.service
[Unit]
Description=$name
After=syslog.target network.target
After=$deps

[Service]
Environment=dm=_r
RestartSec=2s
Type=simple
WorkingDirectory=${DNFS_DIR}/build/$dir
ExecStart=bash $exec
Restart=always

[Install]
WantedBy=multi-user.target
EOF
done
sed -e s/Type=simple/Type=oneshot/g -e s/Restart=always/RemainAfterExit=yes/g -i /lib/systemd/system/dnf_zergsvr.service

cat <<EOF >/lib/systemd/system/mysqlproxy.service
[Unit]
Description=Forward local port 3307 to 3306 (socat)
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:3307,bind=127.0.0.1,range=127.0.0.1/32,reuseaddr,fork TCP:xxxxxx:3306
Restart=on-failure
RestartSec=5
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

sed -i s/xxxxxx/\${HOSTNAME}/g /lib/systemd/system/mysqlproxy.service
systemctl daemon-reload
systemctl restart mysqlproxy

# Wait for Mysql to become available.
sleep 10
until nc -z -v -w30 \${HOSTNAME} 3306 && nc -z -v -w30 -4 localhost 3307; do
  echo "Database @\${HOSTNAME} not yet available or you dont have access to remote 3306 or local 3307. Sleeping..."
  sleep 10
done

mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "SELECT VERSION();" | grep -q "5\.[6-9]\|8\."
if [ \$? -ne 0 ]; then
  echo "MySQL 版本必须 ≥ 5.6"
  exit 1
fi

MAIN_DB_LIST=("d_taiwan" "d_taiwan_secu" "d_technical_report")
SG_DB_LIST=("d_channel_${SERVER_GROUP_DB}" "d_guild" "taiwan_${SERVER_GROUP_DB}" "taiwan_${SERVER_GROUP_DB}_2nd" "taiwan_${SERVER_GROUP_DB}_log" "taiwan_${SERVER_GROUP_DB}_web" "taiwan_${SERVER_GROUP_DB}_auction_gold" "taiwan_${SERVER_GROUP_DB}_auction_cera" "taiwan_login" "taiwan_prod" "taiwan_game_event" "taiwan_se_event" "taiwan_login_play" "taiwan_billing")

GAMEUSERPASSWORD=\${PASSWORD:0:8}
# 创建game用户（兼容>=5.6写法）
# 1.授权来自内网地址和proxy转发地址的访问权限
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "CREATE USER 'game'@'\${HOSTNAME%.*.*}.%.%' IDENTIFIED BY '\$GAMEUSERPASSWORD';"
# 2.为game配置大区主数据库和分组数据库的allowed ips
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "CREATE USER 'game'@'\$(ip route | awk '/default/ { print \$3 }')' IDENTIFIED BY '\$GAMEUSERPASSWORD';"
# 3.授权来自通用客户端IP访问权限
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "CREATE USER 'game'@'%' IDENTIFIED BY '\$GAMEUSERPASSWORD';"
# 为game用户授权访问权限（兼容root不能授权*.*的情形）
for db in "\${MAIN_DB_LIST[@]}" "\${SG_DB_LIST[@]}"; do
  mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "
  GRANT ALL ON \$db.* TO 'game'@'\${HOSTNAME%.*.*}.%.%';
  GRANT ALL ON \$db.* TO 'game'@'\$(ip route | awk '/default/ { print \$3 }')';
  GRANT ALL ON \$db.* TO 'game'@'%';
  "
done
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "FLUSH PRIVILEGES;"

# 循环初始化大区主数据库
for db_name in "\${MAIN_DB_LIST[@]}"
do
    echo "prepare init \$db_name....."
    echo "main db: prepare to init remote mysql service dnf data."
    mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} <<EOFEOF
    CREATE SCHEMA \$db_name DEFAULT CHARACTER SET utf8 ;
    use \$db_name;
    source ${DNFS_DIR}/database/\$db_name.sql;
    flush PRIVILEGES;
EOFEOF
done

# 准备加密的GAME用户密码
DEC_GAME_PWD=\$(echo -n "\$GAMEUSERPASSWORD" | ${DNFS_DIR}/TeaEncrypt) 
# 重置当前大区的主数据库d_taiwan.db_connect表配置
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} <<EOFEOF
use d_taiwan;
update db_connect set db_ip="127.0.0.1", db_port="3307", db_name="d_taiwan", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type = 1;
update db_connect set db_ip="127.0.0.1", db_port="3307", db_name="d_taiwan_secu", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type = 10;
update db_connect set db_ip="127.0.0.1", db_port="3307", db_name="d_technical_report", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type = 15;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="d_guild", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type = 8;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=2;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}_2nd", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=3;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}_log", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=4;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}_web", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=5;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_login", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=6;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_prod", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=7;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_game_event", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=9;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_login_play", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=11;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_${SERVER_GROUP_DB}_auction_gold", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=12;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_se_event", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=13;
update db_connect set db_ip="\${HOSTNAME}", db_port="3306", db_name="taiwan_billing", db_passwd="\$DEC_GAME_PWD" where db_server_group=$SERVER_GROUP and db_type=14;
EOFEOF
# 测试并查询数据库连接设置
mysql -h\${HOSTNAME} -P\${PORT} -ugame -p\${GAMEUSERPASSWORD} <<EOFEOF
select db_name, db_ip, db_port, db_passwd from d_taiwan.db_connect where db_server_group=$SERVER_GROUP;
EOFEOF
echo "main_db: init server group-$SERVER_GROUP($SERVER_GROUP_DB) done."

#修正通用登录器注册
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} <<EOFEOF
use d_taiwan;
ALTER TABLE accounts CHANGE VIP VIP VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_general_ci NULL DEFAULT NULL;
EOFEOF

# 循环初始化大区分组数据库(you can have multiple server-group -> server-> channels, instead of mainserver -> mainchannel)
for db_name in "\${SG_DB_LIST[@]}"
do
    echo "prepare init \$db_name....."
    sql_file=""
    case "\$db_name" in
        # 希洛克数据库特殊，要优先作处理，因为其他组件会提前初始化这个数据库导致其跳过首次初始化
        "taiwan_siroco")
            sql_file="${DNFS_DIR}/database/taiwan_cain.sql"
            ;;
        # 其它普通数据库根据命名规则处理
        "d_channel_$SERVER_GROUP_DB")
            sql_file="${DNFS_DIR}/database/d_channel.sql"
            ;;
        "taiwan_${SERVER_GROUP_DB}")
            sql_file="${DNFS_DIR}/database/taiwan_cain.sql"
            ;;
        "taiwan_${SERVER_GROUP_DB}_2nd")
            sql_file="${DNFS_DIR}/database/taiwan_cain_2nd.sql"
            ;;
        "taiwan_${SERVER_GROUP_DB}_log")
            sql_file="${DNFS_DIR}/database/taiwan_cain_log.sql"
            ;;
        "taiwan_${SERVER_GROUP_DB}_web")
            sql_file="${DNFS_DIR}/database/taiwan_cain_web.sql"
            ;;
        "taiwan_${SERVER_GROUP_DB}_auction_gold")
            sql_file="${DNFS_DIR}/database/taiwan_cain_auction_gold.sql"
            ;;
        "taiwan_${SERVER_GROUP_DB}_auction_cera")
            sql_file="${DNFS_DIR}/database/taiwan_cain_auction_cera.sql"
            ;;
        # 兜底
        *)
            sql_file="${DNFS_DIR}/database/\${db_name}.sql"
            ;;
    esac
    mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} <<EOFEOF
    CREATE SCHEMA \$db_name DEFAULT CHARACTER SET utf8 ;
    use \$db_name;
    source \$sql_file;
    flush PRIVILEGES;
EOFEOF
done
# 重置当前大区的分组数据库taiwan_xxx.game_channel表配置
# mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} <<EOFEOF
# use taiwan_$SERVER_GROUP_DB;
# update game_channel set gc_ip="${PUBLIC_IP}" where gc_type=$SERVER_GROUP;
# EOFEOF
# 测试并查询数据库连接设置
echo "server group db: show db_connect config, server_group is $SERVER_GROUP"
mysql -h\${HOSTNAME} -P\${PORT} -ugame -p\${GAMEUSERPASSWORD} <<EOFEOF
select gc_type, gc_ip, gc_channel from taiwan_$SERVER_GROUP_DB.game_channel where gc_type=$SERVER_GROUP;
EOFEOF

#修正拍卖行，寄售行
for i in \$(seq 0 11); do
dt=\$(date -d "\$i month" +%Y%m)
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} <<EOFEOF
CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_\${dt} LIKE taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_201603;
CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_buyer_\${dt} LIKE taiwan_${SERVER_GROUP_DB}_auction_cera.auction_history_buyer_201603;
CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_\${dt} LIKE taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_201603;
CREATE TABLE IF NOT EXISTS taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_buyer_\${dt} LIKE taiwan_${SERVER_GROUP_DB}_auction_gold.auction_history_buyer_201603;
EOFEOF
done

# generate gamecfg from template
process_sequence=3
for channel_no in \$(echo $OPEN_CHANNEL | tr ',' ' '); do
    if [[ \$channel_no -eq 1 || \$channel_no -eq 6 || \$channel_no -eq 7 || (\$channel_no -ge 11 && \$channel_no -le 39) || (\$channel_no -ge 52 && \$channel_no -le 56) ]]; then
      if [ \$channel_no -ge 11 ] && [ \$channel_no -le 51 ]; then
        process_sequence=3
      else
        process_sequence=5
      fi
      # 对于小于10的频道补0
      if [[ \$channel_no -lt 10 ]];then
        channel_no="0\$channel_no"
      fi
    fi
    channel_name="siroco\$channel_no"
    channels+=("\${channel_name}")
    cp ${DNFS_DIR}/build/game/cfg/server.template ${DNFS_DIR}/build/game/cfg/\$channel_name.cfg
    sed -i "s/CHANNEL_NO/\$channel_no/g" ${DNFS_DIR}/build/game/cfg/\$channel_name.cfg
    sed -i "s/PROCESS_SEQUENCE/\$process_sequence/g" ${DNFS_DIR}/build/game/cfg/\$channel_name.cfg
done
main_name=\${channels[0]}
sed -i "s/MAIN_CHANNEL_NAME/\$main_name/g" ${DNFS_DIR}/build/game/start_game.sh
# Process environment variables in common configuration files.
find ${DNFS_DIR}/build -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/SERVER_GROUP_NAME/$SERVER_GROUP_NAME/g"
find ${DNFS_DIR}/build -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/SERVER_GROUP_DB/$SERVER_GROUP_DB/g"
find ${DNFS_DIR}/build -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/SERVER_GROUP/$SERVER_GROUP/g"
find ${DNFS_DIR}/build -type f -name "*.tbl" -print0 | xargs -0 sed -i "s/SERVER_GROUP/$SERVER_GROUP/g"
find ${DNFS_DIR}/build -type f -name "*.cfg" -exec sh -c 'grep -q 3307 "\$0" || sed -i "s/db_ip = 127.0.0.1/db_ip = \${HOSTNAME}/g" "\$0"' {} \\;
find ${DNFS_DIR}/build -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/GAME_PASSWORD/\$GAMEUSERPASSWORD/g"
find ${DNFS_DIR}/build -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/DEC_GAME_PWD/\$DEC_GAME_PWD/g"
# mainly for channel/gamecfgs
find ${DNFS_DIR}/build -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/MAIN_BRIDGE_IP/$MAIN_BRIDGE_IP/g"
find ${DNFS_DIR}/build -type f -name "*.cfg" -print0 | xargs -0 sed -i "s/PUBLIC_IP/$PUBLIC_IP/g"
find ${DNFS_DIR}/build -type f -name "start_*.sh" -print0 | xargs -0 sed -i "s/SLIM_SIZE/$SLIM_SIZE/g"
find ${DNFS_DIR}/build -type f -name "start_*.sh" -print0 | xargs -0 sed -i "s/MAIN_BRIDGE_IP/$MAIN_BRIDGE_IP/g"
echo "配置文件修改成功"

systemctl daemon-reload
systemctl restart dnf_*
touch /root/inited
fi
EOF
chmod +x /root/init.sh

for svc in /lib/systemd/system/dnf_*.service; do systemctl enable -q --now $(basename "$svc"); done
systemctl enable -q --now mysqlproxy.service

echo "dnf installation completed successfully!"
echo "You login user is game, password is head 8 chars of your mysql root password."


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
