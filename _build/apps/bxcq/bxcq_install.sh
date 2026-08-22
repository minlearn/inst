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
wget --no-check-certificate $rlsmirror/bxcqh5.tar.xz -O download/game.tar.xz

BXCQS_DIR=/root/app/bxcq
BXCQC_DIR=/var/www/html


silent apt-get -y install default-mysql-client

# Install Nginx, PHP-FPM, and necessary PHP extensions
echo "Installing Nginx and PHP-FPM..."
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ bullseye main" >> /etc/apt/sources.list
silent apt-get update
silent apt-get install -y nginx php5.6-fpm php5.6-gd php5.6-sqlite3 php5.6-mysql php5.6-mbstring php5.6-xml php5.6-zip

echo "Installing bxcq..."
mkdir -p ${BXCQS_DIR}
tar -xJf download/game.tar.xz -C ${BXCQS_DIR} bxcqh5/libmysqlclient.so.16 bxcqh5/build bxcqh5/Debug bxcqh5/Debug_cross bxcqh5/database --strip-components=1
cp -f ${BXCQS_DIR}/libmysqlclient.so.16 /lib/x86_64-linux-gnu/libmysqlclient.so.16
mkdir -p ${BXCQC_DIR}
tar -xJf download/game.tar.xz -C ${BXCQC_DIR} bxcqh5/html --strip-components=2
chown -R www-data:www-data ${BXCQC_DIR}

# Configure Nginx to serve bxcq
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root ${BXCQC_DIR};
    index index.html index.htm index.php;

    server_name _;

    location / {
      if (!-e \$request_filename) {
        rewrite  ^/(.*)\$  /\$1.php  last;
        break;
      }
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php5.6-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
systemctl restart nginx

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
WorkingDirectory=${BXCQS_DIR}/Debug/Gateway
ExecStart=${BXCQS_DIR}/Debug/Gateway/gateway_r ${BXCQS_DIR}/Debug/Gateway/GateWay.txt
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
read -p "give a dbsrvwithport(127.0.0.1:3306,10.10.10.x:3306,publicip:3306,etc..):" srvport
read -p "give a dbpassword:" pw
read -p "give a srvipwithport:" srv
HOSTNAME=\${srvport%:*}
PORT=\${srvport#*:}
PORT=\${PORT:-3306}
USERNAME="root"
PASSWORD=\${pw/\//\\\/}
SERVERADD=\${srv%:*}
SERVERPRT=\${srv#*:}
SERVERPRT=\${SERVERPRT:-80}

mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "SELECT VERSION();" | grep -q "5.6"
if [ \$? -ne 0 ]; then
  echo "MySQL 版本不是5.6，可能会导致兼容性问题，继续导入"
fi
mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "SHOW VARIABLES LIKE 'lower_case_table_names';" | grep -q "1"
if [ \$? -ne 0 ]; then
  echo "lower_case_table_names值不为1，可能会导致兼容性问题，继续导入"
fi

for db in mir_account mir_actor_cross1 mir_web mir_actor_s1 mir_amdb mir_command mir_log_s1 mir_name
do
  mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} -e "create database \$db DEFAULT CHARACTER SET utf8;"
  mysql -h\${HOSTNAME} -P\${PORT} -u\${USERNAME} -p\${pw} \$db < ${BXCQS_DIR}/database/\$db.sql
done
echo "数据库导入成功"

sed -e s/host=\"127.0.0.1\"/host=\"\${HOSTNAME}\"/g -e s/pass=\"123456\"/pass=\"\${PASSWORD}\"/g -e s/port=3306/port=\${PORT}/g -i ${BXCQS_DIR}/build/AMServer/AMServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -e s/Port\ =\ 3306/Port\ =\ \${PORT}/g -i ${BXCQS_DIR}/build/BackStageServer/BackStageServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -e s/Port\ =\ 3306/Port\ =\ \${PORT}/g -i ${BXCQS_DIR}/build/LoggerServer/LoggerServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -e s/Port\ =\ 3306/Port\ =\ \${PORT}/g -i ${BXCQS_DIR}/build/NameServer/NameServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -e s/Port\ =\ 3306/Port\ =\ \${PORT}/g -i ${BXCQS_DIR}/build/SessionServer/SessionServerLinux.txt

sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -e s/Port\ =\ 3306/Port\ =\ \${PORT}/g -i ${BXCQS_DIR}/Debug/DBServer/DBServerLinux.txt
sed -e s/Host\ =\ \"127.0.0.1\"/Host\ =\"\${HOSTNAME}\"/g -e s/DBPass\ =\ \"123456\"/DBPass\ =\ \"\${PASSWORD}\"/g -e s/Port\ =\ 3306/Port\ =\ \${PORT}/g -i ${BXCQS_DIR}/Debug_cross/DBServer/DBServerLinux.txt


sed -e "s/'db_host' => '127.0.0.1'/'db_host' => '\${HOSTNAME}'/g" -e "s/'db_port' => 3306/'db_port' => \${PORT}/g" -e "s/'db_password' => '123456'/'db_password' => '\${PASSWORD}'/g" -i ${BXCQC_DIR}/config.php


sed -e "s/\$_host = '.*';/\$_host = '\${SERVERADD}';/" -e "s/\$_port = [0-9]\+;/\$_port = \${SERVERPRT};/" -i ${BXCQC_DIR}/config.php
sed -e "s/let host = '.*';/let host = '\${SERVERADD}';/" -e "s/let port = [0-9]\+;/let port = \${SERVERPRT};/" -i ${BXCQC_DIR}/js/index.js
echo "配置文件修改成功"

# fordbserver
mkdir -p /etc/yum/wch
echo "2160299F-7788-4B22-8F7C-9A87827D2B4A" > /etc/yum/wch/88888888888888888
# 禁用开服注册到期时间
sed -i "s/nosetopenday = 365,/nosetopenday = 0,/g" ${BXCQS_DIR}/Debug/LogicServer/data/config/editionConf.config
# for wwwsrv
sed -i "/^this.vUrl=/c\\this.vUrl='\\/s\\/'" ${BXCQC_DIR}/js/lib.min_jocw9Tu2.js
mkdir -p ${BXCQC_DIR}/s
echo '{"code":0}' > ${BXCQC_DIR}/s/index.php
chown -R www-data:www-data ${BXCQC_DIR}/s
echo "重要文件修补成功"

systemctl restart amserver backstageserver loggerserver nameserver sessionserver dbserver gateserver logicserver
touch /root/inited
fi
EOF
chmod +x /root/init.sh

cat <<EOF >/root/cross.sh

/*
合服sql说明:此语句在主服查询运行
# actor_MAIN ：主数据库名称actor_MAIN
# actor_SLAVE ：从数据库名称actor_SLAVE
# 1 ：主服服数1 九零一 起 玩www.9 01 75.com
# 2 ：从服服数2
*/

update actor_SLAVE.actors set serverindex = SLAVE_ID;

use actor_MAIN;

/*
ignore import tables
#accounts
#filternames
#gameserveraddress
#jobcount
#toprank
#zycount
*/

/* drop actorname index */
drop index actor_name on actor_MAIN.actors;

/* begin data import */
insert into actorachieve (select * from actor_SLAVE.actorachieve);
insert into actoractivity (select * from actor_SLAVE.actoractivity);
insert into actoralmirahitem (select * from actor_SLAVE.actoralmirahitem);
insert into actorapplyguildresult (select * from actor_SLAVE.actorapplyguildresult);
insert into actorbagitem (select * from actor_SLAVE.actorbagitem);
insert into actorbinarydata (select * from actor_SLAVE.actorbinarydata);
insert into actordeath (select * from actor_SLAVE.actordeath);
insert into actordeathdrop (select * from actor_SLAVE.actordeathdrop);
insert into actordepotitem (select * from actor_SLAVE.actordepotitem);
insert into actorequipitem (select * from actor_SLAVE.actorequipitem);
insert into actorfriends (select * from actor_SLAVE.actorfriends);
insert into actorgameotherSets (select * from actor_SLAVE.actorgameotherSets);
insert into actorghost (select * from actor_SLAVE.actorghost);
insert into actorguild (select * from actor_SLAVE.actorguild);
insert into actornewtitle (select * from actor_SLAVE.actornewtitle);
insert into actorofflinedata (select * from actor_SLAVE.actorofflinedata);
insert into actorpetitem (select * from actor_SLAVE.actorpetitem);
insert into actorpets (select * from actor_SLAVE.actorpets);
insert into actorrelation (select * from actor_SLAVE.actorrelation);
insert into actors (select * from actor_SLAVE.actors);
insert into actorsoldiersoul (select * from actor_SLAVE.actorsoldiersoul);
insert into actorstaticcount (select * from actor_SLAVE.actorstaticcount);
insert into actorstrengthen (select * from actor_SLAVE.actorstrengthen);
insert into actorvariable (select * from actor_SLAVE.actorvariable);
insert into brothgrouplist (select * from actor_SLAVE.brothgrouplist);
insert into clickcreaterole (select * from actor_SLAVE.clickcreaterole);
insert into combatgame (select * from actor_SLAVE.combatgame);
insert into combatinfo (select * from actor_SLAVE.combatinfo);
insert into combatlog (select * from actor_SLAVE.combatlog);
insert into combatrecord (select * from actor_SLAVE.combatrecord);
insert into consignmentincome (select * from actor_SLAVE.consignmentincome);
insert into consignmentitem (select * from actor_SLAVE.consignmentitem);
insert into createrolesuc (select * from actor_SLAVE.createrolesuc);
insert into entercreaterole (select * from actor_SLAVE.entercreaterole);
insert into entergame (select * from actor_SLAVE.entergame);
insert into enterplatform (select * from actor_SLAVE.enterplatform);
/*insert into feecallback (select * from actor_SLAVE.feecallback);*/
insert into friendchatmsg (select * from actor_SLAVE.friendchatmsg);
insert into friends (select * from actor_SLAVE.friends);
insert into gameserveraddress (select * from actor_SLAVE.gameserveraddress);
insert into gamesetdata (select * from actor_SLAVE.gamesetdata);
insert into goingquest (select * from actor_SLAVE.goingquest);
insert into guildapplylist (select * from actor_SLAVE.guildapplylist);
insert into guildapplyresult (select * from actor_SLAVE.guildapplyresult);
insert into guildevent (select * from actor_SLAVE.guildevent);
insert into guildlist (select * from actor_SLAVE.guildlist);
insert into guildskill (select * from actor_SLAVE.guildskill);
insert into guildstore (select * from actor_SLAVE.guildstore);
insert into guildstorerecord (select * from actor_SLAVE.guildstorerecord);
insert into guildwar (select * from actor_SLAVE.guildwar);
insert into guildwarhistory (select * from actor_SLAVE.guildwarhistory);
insert into offlineachieve (select * from actor_SLAVE.offlineachieve);
insert into periodride (select * from actor_SLAVE.periodride);
insert into petskills (select * from actor_SLAVE.petskills);
insert into repeatquest (select * from actor_SLAVE.repeatquest);
/*insert into servermail (select * from actor_SLAVE.servermail);*/
/*insert into servermailattach (select * from actor_SLAVE.servermailattach);*/
insert into skill (select * from actor_SLAVE.skill);
insert into toprank (select * from actor_SLAVE.toprank);
insert into validate (select * from actor_SLAVE.validate);

insert into actorhallows (select * from actor_SLAVE.actorhallows);
/*insert into actorrebate (select * from actor_SLAVE.actorrebate);*/
insert into actorcustomproperty (select * from actor_SLAVE.actorcustomproperty);

insert into mail(mailid,actorid,srcid,title,content,createdt,state,isdel) (select mailid,actorid,srcid,title,content,createdt,state,isdel from actor_SLAVE.mail);
insert into mailattach(mailid,actorid,type,itemguid,itemidquastrong,itemduration,itemcountflag,iteminlayhole,itemtime,itemreservs,itemsmith1,itemsmith2,itemsmith3,itemsmith4,itemsmith5,itemreservs2,initsmith) (select mailid,actorid,type,itemguid,itemidquastrong,itemduration,itemcountflag,iteminlayhole,itemtime,itemreservs,itemsmith1,itemsmith2,itemsmith3,itemsmith4,itemsmith5,itemreservs2,initsmith from actor_SLAVE.mailattach);
insert into actormsg(actorid,msgtype,msg) (select actorid,msgtype,msg from actor_SLAVE.actormsg);
insert into useritem(accountid,actorid,itemid,bind,strong,quality,itemcount,serverindex,memo,reser1,reser2) (select accountid,actorid,itemid,bind,strong,quality,itemcount,serverindex,memo,reser1,reser2 from actor_SLAVE.useritem where serverindex=SLAVE_ID);
/* end data import */

/* begin role rename */
drop table if exists tmp_charname;
create temporary table tmp_charname (select actorname from actors group by actorname having count(*) >1);
UPDATE actors SET actorname=CONCAT(actorname,'[SLAVE_ID]') WHERE (actorname in (SELECT actorname FROM tmp_charname) and serverindex=SLAVE_ID);
drop table tmp_charname;
/* end role rename */

/* begin guild rename */
drop table if exists tmp_charguildname;
create temporary table tmp_charguildname (select guildname from guildlist group by guildname having count(*) >1);
UPDATE guildlist SET guildname=CONCAT(guildname,'[SLAVE_ID]') WHERE (guildname in (SELECT guildname FROM tmp_charguildname) and serverindex=SLAVE_ID);
drop table tmp_charguildname;
/* end guild rename */

/* begin update server index */
update accountpsw set serverindex = MAIN_ID;
update actors set serverindex = MAIN_ID;
update brothgrouplist set serverindex = MAIN_ID;
update clickcreaterole set serverindex = MAIN_ID;
update consignmentincome set serverindex = MAIN_ID;
update consignmentitem set serverindex = MAIN_ID;
update createrolesuc set serverindex = MAIN_ID;
update entercreaterole set serverindex = MAIN_ID;
update entergame set serverindex = MAIN_ID;
update enterplatform set serverindex = MAIN_ID;
update gameserveraddress set serverindex = MAIN_ID;
update guildlist set serverindex = MAIN_ID;
update jobcount set serverindex = MAIN_ID;
update toprank set serverindex = MAIN_ID;
update useritem set serverindex = MAIN_ID;
update validate set serverindex = MAIN_ID;
update zycount set serverindex = MAIN_ID;
/* end update server index */

/* add actorname index */
ALTER TABLE \`actors\` ADD UNIQUE INDEX \`actor_name\` USING BTREE (\`actorname\`);

update guildlist set signupflag=0;

/* begin clean actors */

/* ignore clean tables
#actorrelation
#brothgrouplist
#combatgame
#combatrecord
#diamond
#friendchatmsg
#friends
#gamesetdata
#periodride
*/

drop table if exists tmp_actorid;
CREATE TEMPORARY TABLE tmp_actorid (\`actorid\` int(10) unsigned not null primary key);
insert into tmp_actorid (select actorid from actors where updatetime < (NOW() - INTERVAL 4 DAY) and level < 70 and circle < 1 and nonbindyuanbao=0 and drawybcount=0);

delete from actorbagitem where actorid in (select actorid from tmp_actorid);
delete from actorbinarydata where actorid in (select actorid from tmp_actorid);
delete from actordepotitem where actorid in (select actorid from tmp_actorid);
delete from actorequipitem where actorid in (select actorid from tmp_actorid);
delete from actorfriends where actorid in (select actorid from tmp_actorid);
delete from actorguild where actorid in (select actorid from tmp_actorid);
delete from mail where actorid in (select actorid from tmp_actorid);
delete from actormsg where actorid in (select actorid from tmp_actorid);
delete from actorpetitem where actorid in (select actorid from tmp_actorid);
delete from actorpets where actorid in (select actorid from tmp_actorid);
delete from actors where actorid in (select actorid from tmp_actorid);
delete from actorvariable where actorid in (select actorid from tmp_actorid);
delete from goingquest where actorid in (select actorid from tmp_actorid);
delete from guildstore where actorid in (select actorid from tmp_actorid);
delete from petskills where actorid in (select actorid from tmp_actorid);
delete from repeatquest where actorid in (select actorid from tmp_actorid);
delete from skill where actorid in (select actorid from tmp_actorid);
delete from useritem where actorid in (select actorid from tmp_actorid);

drop table tmp_actorid;

/* end clean actors */

/* begin clear tables */
delete from guildevent;
delete from toprank;
delete from zycount;
/* end clear tables */

#sed -i s/192.168.1.76/109.238.11.168/g ${BXCQS_DIR}/Debug/LogicServer/CrossSourceServer.config
#sed -i s/192.168.1.76/109.238.11.168/g ${BXCQS_DIR}/Debug/LogicServer/data/config/Cross/CrossSourceServer.config
#sed -i s/192.168.1.76/109.238.11.168/g ${BXCQS_DIR}/Debug/LogicServer_r/data/config/Cross/CrossSourceServer.config
EOF
chmod +x /root/cross.sh

systemctl enable -q --now amserver backstageserver loggerserver nameserver sessionserver dbserver gateserver logicserver


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
