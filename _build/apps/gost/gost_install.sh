###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

cd /root

arch=$([[ "$(arch)" == "aarch64" ]] && echo _arm64)
rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
[[ ! -f download/tmp.tar.gz ]] && wget --no-check-certificate $rlsmirror/gost$arch.tar.gz -O download/tmp.tar.gz

mkdir -p app/gost
tar -xzvf download/tmp.tar.gz -C app/gost gost # --strip-components=1

cat > /lib/systemd/system/gost.service << 'EOL'
[Unit]
Description=this is gost service,please change the token then daemon-reload it
After=network.target nss-lookup.target
Wants=network.target nss-lookup.target
Requires=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=/root/app/gost/gost -C /root/app/gost/config.yaml
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOL

cat > /root/app/gost/config.yaml << 'EOL'
services:
- name: service-0
  addr: :13389
  handler:
    type: tcp
  listener:
    type: tcp
  forwarder:
    nodes:
    - name: target-0
      addr: xxx.xxx.xxx.xxx:3389
EOL

cat > /root/ip.sh << 'EOL'
read -p "give a ip:" ip </dev/tty
date=xxx.xxx.xxx.xxx
sed -i s#${date}#${ip}#g /root/app/gost/config.yaml
systemctl restart gost
EOL
chmod +x /root/ip.sh


systemctl enable -q --now gost


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
