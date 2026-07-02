###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg
echo "Installed Dependencies"

echo "Installing Cloudflared"
mkdir -p --mode=0755 /usr/share/keyrings
VERSION="$(awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release)"
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg >/usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $VERSION main" >/etc/apt/sources.list.d/cloudflared.list
silent apt-get update
silent apt-get install -y cloudflared
echo "Installed Cloudflared"

read -r -p "Would you like to configure cloudflared as a tunnel proxy(if no,as a DNS-over-HTTPS proxy)? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  echo "Creating Service"
  cat > /etc/systemd/system/cloudflared.service << 'EOL'
[Unit]
Description=cloudflared tunnel proxy
After=syslog.target network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bash -c "date=$$(echo -n $$(ip addr |grep $$(ip route show |grep -o 'default via [0-9]\\{1,3\\}.[0-9]\\{1,3\\}.[0-9]\\{1,3\\}.[0-9]\\{1,3\\}.*' |head -n1 |sed 's/proto.*\\|onlink.*//g' |awk '{print $$NF}') |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\\{1,3\\}.[0-9]\\{1,3\\}.[0-9]\\{1,3\\}.[0-9]\\{1,3\\}/[0-9]\\{1,2\\}') |cut -d'/' -f1);PATH=/usr/local/bin:$PATH exec /usr/local/bin/cloudflared --no-autoupdate --loglevel error --no-tls-verify --edge-bind-address $${date}  tunnel run --icmpv4-src $${date} --token xxxxxxxxxxxxxxxxx"
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOL
cat > /root/token.sh << 'EOL'
read -p "give a uuid:" token
sed -i s#xxxxxxxxxxxxxxxxx#${token}#g /etc/systemd/system/cloudflared.service
systemctl daemon-reload
systemctl restart cloudflared
EOL
chmod +x /root/token.sh
else
  cat <<EOF >/usr/local/etc/cloudflared/config.yml
proxy-dns: true
proxy-dns-address: 0.0.0.0
proxy-dns-port: 53
proxy-dns-max-upstream-conns: 5
proxy-dns-upstream:
  - https://1.1.1.1/dns-query
  - https://1.0.0.1/dns-query
  #- https://8.8.8.8/dns-query
  #- https://8.8.4.4/dns-query
  #- https://9.9.9.9/dns-query
  #- https://149.112.112.112/dns-query
EOF
  cat <<EOF >/etc/systemd/system/cloudflared.service
[Unit]
Description=cloudflared DNS-over-HTTPS (DoH) proxy
After=syslog.target network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared --config /usr/local/etc/cloudflared/config.yml
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl enable -q --now cloudflared.service
echo "Created Service"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###########
