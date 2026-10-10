count=`ping -c 5 8.8.8.8 | grep from* | wc -l`
count6=`ping -c 5 -6 2001:67c:2b0::6|grep from*|wc -l`
pid=`screen -ls|grep -Eo [0-9]*.reboot|grep -Eo [0-9]*`
[ $count -ne 0 -o $count6 -ne 0 ] && kill -9 $pid
