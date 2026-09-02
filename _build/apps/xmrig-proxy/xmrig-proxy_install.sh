###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
wget --no-check-certificate $rlsmirror/xmrig-proxy-6.24.0-linux-static-x64.tar.gz -O download/tmp.tar.gz

mkdir -p app/xmrig-proxy
tar -xzvf download/tmp.tar.gz -C app/xmrig-proxy xmrig-proxy-6.24.0 --strip-components=1

cat > /lib/systemd/system/xmrig-proxy.service << 'EOL'
[Unit]
Description=this is xmrig-proxy service,please bash /root/init.sh to update
After=network.target nss-lookup.target
Wants=network.target nss-lookup.target
Requires=network.target nss-lookup.target

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=/bin/bash -c "PATH=/usr/local/bin:$PATH exec /root/app/xmrig-proxy/xmrig-proxy -b 0.0.0.0:443,tls --tls-gen=localhost -o rx.unmineable.com:443 --tls -u SHIB:0x0000000000000000000000000000000000000.proxy -p x -k"
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOL

cat > /root/init.sh << 'EOL'
read -p "give a coin(SHIB/DOGE/...):" coin
read -p "give a user/address(SHIB/DOGE/...):" useraddr
read -p "give a pass:" pass
sed -i "s#-u \([^: ]*\):#-u ${coin}:#g" /lib/systemd/system/xmrig-proxy.service
sed -i "s#\(-u [^: ]*:\)[^ .]*#\1${useraddr}#g" /lib/systemd/system/xmrig-proxy.service
sed -i "s#-p [^ ]*#-p ${pass}#g" /lib/systemd/system/xmrig-proxy.service
systemctl daemon-reload
systemctl restart xmrig-proxy
echo "now you can connect to this proxy, for other pool other than rx.unmineable.com (which incs a separated coin from address), you may need additonal --coin=xxx argument to the service file"
EOL
chmod +x /root/init.sh

systemctl enable -q --now xmrig-proxy

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
