###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo
echo "Installed Dependencies"

cd /root

arch=$([[ "$(arch)" == "aarch64" ]] && echo _arm64)
rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
[[ ! -f download/tmp.tar.gz ]] && wget --no-check-certificate $rlsmirror/subconverter$arch.tar.gz -O download/tmp.tar.gz

mkdir -p app/subconverter
tar -xzvf download/tmp.tar.gz -C app/subconverter subconverter --strip-components=1

cat > /lib/systemd/system/subconverter.service << 'EOL'
[Unit]
Description=this is subconverter service,please change the token then daemon-reload it
After=network.target nss-lookup.target
Wants=network.target nss-lookup.target
Requires=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=/root/app/subconverter/subconverter
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOL

systemctl enable -q --now subconverter

cat > /root/gen.sh << 'EOL'
read -p "give a converterstr:" str </dev/tty
curl 127.0.0.1:25500/$str
EOL
chmod +x /root/gen.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
