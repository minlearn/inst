###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get -y install unzip

cd /root

arch=$([[ "$(arch)" == "aarch64" ]] && echo aarch64||echo x86_64)
mkdir -p download
wget --no-check-certificate https://github.com/rapiz1/rathole/releases/download/v0.4.8/rathole-$arch-unknown-linux-musl.zip -O download/rathole.zip

mkdir -p app/rathole
unzip -q -o -p download/rathole.zip rathole > app/rathole/rathole
chmod +x app/rathole/rathole

echo -e "[server]\n\
bind_addr = \"0.0.0.0:2333\"\n\
default_token = \"default_token_if_not_specify\"\n\
heartbeat_interval = 30\n\
[server.services.10001]\n\
bind_addr = \"0.0.0.0:10001\"\n\
[server.services.22]\n\
bind_addr = \"0.0.0.0:1022\"\n\
[server.services.80]\n\
bind_addr = \"0.0.0.0:1080\"\n\
[server.services.3389]\n\
bind_addr = \"0.0.0.0:13389\"\n\
[server.services.8000]\n\
bind_addr = \"0.0.0.0:18000\"" > app/rathole/rathole.toml

echo -e "[Unit]\n\
Description=rathole service\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
Restart=always\n\
RestartSec=1\n\
ExecStart=/root/app/rathole/rathole /root/app/rathole/rathole.toml\n\
\n\
[Install]\n\
WantedBy=multi-user.target" > /lib/systemd/system/rathole.service

cat > /root/add.sh << 'EOL'
read -p "give a portnum:" num  </dev/tty

LINE_NUMBER=$(grep -n '^\[server.services.22\]' /root/app/rathole/rathole.toml | cut -d: -f1)
sed -i "$((LINE_NUMBER-0))i [server.services.$num]\nbind_addr = \"0.0.0.0:$num\"" /root/app/rathole/rathole.toml

systemctl restart rathole
EOL
chmod +x /root/add.sh

systemctl enable -q --now rathole


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
