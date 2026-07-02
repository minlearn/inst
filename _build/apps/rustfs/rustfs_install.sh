###############################

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc unzip
echo "Installed Dependencies"

arch=$([[ "$(arch)" == "aarch64" ]] && echo arm64||echo x86_64)
rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
wget -q --no-check-certificate $rlsmirror/rustfs-linux-$arch-musl-latest.zip
unzip rustfs-linux-$arch-musl-latest.zip -d /usr/local/bin/
chmod +x /usr/local/bin/rustfs

echo "Installing rustfs"
cat > /etc/default/rustfs <<EOF
RUSTFS_ADDRESS="0.0.0.0:9000"
RUSTFS_CONSOLE_ADDRESS="0.0.0.0:9001"
RUSTFS_CONSOLE_ENABLE="true"
RUSTFS_ACCESS_KEY="admin"
RUSTFS_SECRET_KEY="12345678"
RUSTFS_VOLUMES="/root/rustfs/data"
RUSTFS_TLS_ENABLE="false"
RUSTFS_OBS_LOGGER_LEVEL=error
RUSTFS_OBS_LOG_DIRECTORY=/root/rustfs/log
EOF

mkdir -p /root/rustfs/log /root/rustfs/data
cat <<EOF >/etc/systemd/system/rustfs.service
[Unit]
Description=rustfs file storage service
After=network.target

[Service]
Type=simple
User=root
EnvironmentFile=/etc/default/rustfs
ExecStart=/usr/local/bin/rustfs \$RUSTFS_VOLUMES
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now rustfs
echo "Installed rustfs"

cat > /root/pw.sh << 'EOL'
read -p "give a pw:" pw </dev/tty
sed -i "/^RUSTFS_SECRET_KEY=/cRUSTFS_SECRET_KEY=$pw" /etc/default/rustfs
systemctl restart rustfs
EOL
chmod +x /root/pw.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############################
