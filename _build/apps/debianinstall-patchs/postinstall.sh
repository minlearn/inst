#!/bin/sh

core=$1
logger -t minlearnadd debmirror info:$core

instctlinfo=$2
CTLPT=`echo "$instctlinfo" | awk -F ':' '{ print $1}'`
CTLIP=`echo "$instctlinfo" | awk -F ':' '{ print $2}'`
logger -t minlearnadd instctl port info:$CTLPT ip info:$CTLIP

instcmdinfo=$3
CMDSTR=`printf "%b" "$instcmdinfo"`
CMDSTR_ORI=`printf "%s" "$instcmdinfo"`
logger -t minlearnadd preddtime CMDSTR:$CMDSTR

sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config
sed -i 's/http:\/\/github/https:\/\/github/g;s/http:\/\/gitee/https:\/\/gitee/g;s/${core}\/debianbase/https:\/\/snapshot.debian.org\/archive\/debian\/20231007T024024Z/g' /target/etc/apt/sources.list

[ "$CTLIP" != '' -a "$CTLPT" != '' ] && [ "$CTLIP" != '0.0.0.0' -o "$CTLPT" != 80 ] && cp /bin/rathole /target/bin/rathole && printf "[client]\n\
remote_addr = \"$CTLIP:2333\"\n\
default_token = \"default_token_if_not_specify\"\n\
heartbeat_timeout = 30\n\
retry_interval = 3\n\
[client.services.$CTLPT]\n\
local_addr = \"127.0.0.1:22\"\n" > /target/etc/rathole.toml && printf "[Unit]\n\
Description=rathole service\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
Restart=always\n\
RestartSec=1\n\
ExecStart=/bin/rathole /etc/rathole.toml\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n" > /target/lib/systemd/system/rathole.service && mkdir -p /target/etc/systemd/system/rathole.wants && ln -s /lib/systemd/system/rathole.service /target/etc/systemd/system/multi-user.target.wants/rathole.service
[ "$CTLIP" != '' -a "$CTLPT" != '' ] && [ $CTLIP = '0.0.0.0' -a $CTLPT = 80 ] && cp /bin/linuxvnc /target/bin/linuxvnc && cp /lib/libvnc*.so* /target/lib && cp -aR /usr/share/novnc /target/usr/share && printf "[Unit]\n\
Description=linuxvnc service\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
Restart=always\n\
RestartSec=1\n\
ExecStart=/bin/linuxvnc 1\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n" > /target/lib/systemd/system/linuxvnc.service && mkdir -p /target/etc/systemd/system/linuxvnc.wants && ln -s /lib/systemd/system/linuxvnc.service /target/etc/systemd/system/multi-user.target.wants/linuxvnc.service

mkdir -p /target/etc/systemd/system/rc-local.wants && ln -s /lib/systemd/system/rc-local.service /target/etc/systemd/system/multi-user.target.wants/rc-local.service
# chroot install a kbd for openvt
apt-install debconf-utils
in-target bash -c 'echo keyboard-configuration  keyboard-configuration/unsupported_config_options       boolean true | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/switch   select  No temporary switch | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/unsupported_config_layout        boolean true | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/layoutcode       string  us | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/compose  select  No compose key | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/modelcode        string  pc105 | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/unsupported_options      boolean true | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/variant  select  English \(US\) | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/unsupported_layout       boolean true | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/model    select  Generic 105-key PC \(intl.\) | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/ctrl_alt_bksp    boolean false | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/layout   select | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/toggle   select  No toggling | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/variantcode      string | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/altgr    select  The default for the keyboard layout | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/xkb-keymap       select  us | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/optionscode      string | debconf-set-selections >/dev/null 2>&1; \
    echo keyboard-configuration  keyboard-configuration/store_defaults_in_debconf_db     boolean true | debconf-set-selections >/dev/null 2>&1'
apt-install kbd
[ "$CMDSTR" != '' -a "$CMDSTR_ORI" != '' ] && echo '#!/bin/bash' > /target/etc/rc.local && printf "%b" \
"systemctl stop getty@tty1.service\n\n" \
"IFS='' read -r -d '' oricmdwrapperfornoesc <<\"EOFF\"\n" \
"$CMDSTR_ORI""\n" \
"systemctl start getty@tty1.service\n" \
"EOFF\n" \
"openvt -f -c 1 -s -- bash -c \"\$oricmdwrapperfornoesc\"" \
"\n\n" \
"mv /etc/rc.local ~/net.txt\n" >> /target/etc/rc.local && chmod +x /target/etc/rc.local

# always ensure safe exit, or it will throw unpected exceptions
exit 0
