###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg
echo "Installed Dependencies"

echo "installing x11 supports"
silent apt-get install --no-install-recommends debconf-utils -y
echo keyboard-configuration  keyboard-configuration/unsupported_config_options       boolean true | debconf-set-selections >/dev/null 2>&1; \
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
echo keyboard-configuration  keyboard-configuration/store_defaults_in_debconf_db     boolean true | debconf-set-selections >/dev/null 2>&1

silent apt-get install --no-install-recommends keyboard-configuration xserver-xorg xinit xterm libgtk-3-0 libwebkit2gtk-4.0-37 -y

chmod u+s /usr/lib/xorg/Xorg
touch /home/tdl/.Xauthority /root/.Xauthority

echo "install chrome"
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
silent apt-get update
silent apt-get install google-chrome-stable fonts-wqy-zenhei -y
#silent apt-get install xrdp -y

read -r -p "Would you like to add Kasm? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  echo "Installing kasm"
  silent apt-get install -y \
    gettext \
    ssl-cert \
    libxfont2
	
  wget -q "https://github.com/kasmtech/KasmVNC/releases/download/v1.3.3/kasmvncserver_bullseye_1.3.3_amd64.deb" -O /tmp/kasmvncserver.deb
  silent apt-get install -y /tmp/kasmvncserver.deb
  rm -f /tmp/kasmvncserver.deb

  mkdir -p /usr/share/kasmvnc/www/Downloads
  chown -R 0:0 /usr/share/kasmvnc
  chmod -R og-w /usr/share/kasmvnc
  ln -sf /home/kasm-user/Downloads /usr/share/kasmvnc/www/Downloads/Downloads
  chown -R 1000:0 /usr/share/kasmvnc/www/Downloads

  mkdir -p /root/.vnc
  echo -e 'exec google-chrome --no-sandbox' >> /root/.vnc/xstartup
  chmod +x /root/.vnc/xstartup
  echo -e "root:$(openssl passwd -5 -salt kasm vnc):w" >> /root/.kasmpasswd
  touch /root/.vnc/.de-was-selected
  echo -e 'network:
  protocol: http
  interface: 0.0.0.0
  websocket_port: 5901
  use_ipv4: true
  use_ipv6: true
  ssl:
    require_ssl: false' >> /root/.vnc/kasmvnc.yaml
  cat >/usr/lib/systemd/system/vnc.service<<EOF
[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=forking
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver %i
ExecStop=/usr/bin/vncserver -kill %i

[Install]
WantedBy=default.target
EOF
  systemctl enable -q --now vnc.service

  echo -e 'echo -e "root:$(openssl passwd -5 -salt kasm):w" > /root/.kasmpasswd
systemctl restart vnc' >> /root/ps.sh
  chmod +x /root/ps.sh

  echo "Installed kasm"
else
  cat >/usr/lib/systemd/system/xorg.service<<EOF
[Unit]
Description=X-Window

[Service]
Type=simple
ExecStart=/bin/su --login tdl -c "/usr/bin/startx -- :0 vt1 -ac -nolisten tcp"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

  echo 'exec google-chrome --no-sandbox' > /root/.xinitrc;
  echo 'exec google-chrome --no-sandbox' > /home/tdl/.xinitrc;
  systemctl enable -q --now xorg.service

  echo -e '[Unit]\nDescription=Remote desktop service (VNC)\nRequires=xorg.service\nAfter=xorg.service\n\n[Service]\nType=forking\nExecStart=vncserver :01\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target' > /usr/lib/systemd/system/vnc.service
  systemctl enable -q --now vnc.service
  
fi


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
