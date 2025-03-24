#!/bin/sh

. /usr/share/debconf/confmodule
debconf-loadtemplate my_script /longrunpipebgcmd_redirectermoniter.templates

coreinfos=$1
DEV=`echo ${coreinfos##10000:}`
SIZE=`fdisk -l ${coreinfos##10000:} 2>/dev/null|grep /dev/|head -n1|awk -F ' ' '{ print $5}'`
logger -t minlearnadd prerestime DEV:$DEV,SIZE:$SIZE

echo '<style>
    body {
        white-space: pre-line;
    }
</style>
<script>
    function scrollToBottom() {
        window.scrollTo(0, document.body.scrollHeight);
    }
    history.scrollRestoration = "manual";
    window.onload = scrollToBottom;

    function printSomething(){
        location.reload();
        setTimeout(printSomething, 3000);
    }
    setTimeout(printSomething, 3000);
</script>' > /var/log/progress
PIPECMDSTR='while true; do { stdbuf -oL dd if='$DEV' bs=10M 2>> /var/log/progress & echo $! > /tmp/foo; } |gzip |nc -l -p 10000; done &'
logger -t minlearnadd prerestime PIPECMDSTR:"$PIPECMDSTR"

for step in preres res postres; do

    if ! db_progress INFO my_script/progress/$step; then
            db_subst my_script/progress/fallback STEP "$step"
            db_progress INFO my_script/progress/fallback
    fi

    case $step in
       "preres")
           db_progress INFO my_script/progress/preres
           ;;

       "res")
           db_progress START 0 100 my_script/progress/res
           db_progress INFO my_script/progress/res
           db_progress SET 0

           eval $PIPECMDSTR
           while :; do 
           {
             # sleep 3 to let command run for a while,and start a new loop
             sleep 3
             pidinfo=`cat /tmp/foo|head -n1`

             # replaced with grep --line-buffer?
             statusinfo=`kill -USR1 $pidinfo;cat /var/log/progress|sed '/^$/!h;$!d;g'`
             tillnowinfo=`echo $statusinfo|sed 's/bytes \(.*\)//g'`

             #its hard to determine pid changes by kill -s ; so just judge if there is connection
             if [ $tillnowinfo != 0 ]; then { db_subst my_script/progress/res STATUS "${statusinfo}";db_progress STEP 1; } else { db_progress SET 0; }; fi
           }
           done

           sleep 3
           # reboot
           ;;

       "postres")
           db_progress INFO my_script/progress/postres
           ;;
           
    esac

done
