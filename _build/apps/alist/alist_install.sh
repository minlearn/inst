###############################

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

arch=$([[ "$(arch)" == "aarch64" ]] && echo arm64||echo amd64)
rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
wget -q --no-check-certificate $rlsmirror/alist-linux-musl-$arch.tar.gz
tar zxf alist-linux-musl-$arch.tar.gz -C /usr/local/bin/
chmod +x /usr/local/bin/alist

echo "Installing alist"
mkdir -p /root/alist/data
cat <<EOF >/etc/systemd/system/alist.service
[Unit]
Description=Alist file list service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/alist server --data /root/alist/data
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now alist
echo "Installed alist"

sed -e 's/0.0.0.0/127.0.0.1/g' -i /root/alist/data/config.json
systemctl restart alist

cat > /root/pw.sh << 'EOL'
read -p "give a pw:" pw
# this is important for alist to give it a topdir or new pass wont take effect
cd /root/alist
alist admin set $pw
systemctl restart alist
EOL
chmod +x /root/pw.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############################
