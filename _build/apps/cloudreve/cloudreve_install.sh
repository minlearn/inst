###############################

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

mkdir -p /root/cloudreve
RELEASE=$(wget -q https://github.com/cloudreve/cloudreve/releases/latest -O - | grep "title>Release" | cut -d " " -f 4 | sed 's/^v//')
arch=$([[ "$(arch)" == "aarch64" ]] && echo arm64||echo amd64)
wget -q https://github.com/cloudreve/cloudreve/releases/download/${RELEASE}/cloudreve_${RELEASE}_linux_${arch}.tar.gz
tar zxf cloudreve_${RELEASE}_linux_${arch}.tar.gz -C /root/cloudreve
chmod +x /root/cloudreve/cloudreve

echo "Installing cloudreve"
cat <<EOF >/etc/systemd/system/cloudreve.service
[Unit]
Description=cloudreve netdisk service
After=network.target
After=mysqld.service
Wants=network.target

[Service]
WorkingDirectory=/root/cloudreve
ExecStart=/root/cloudreve/cloudreve -w -c /root/cloudreve/conf.ini
Restart=on-abnormal
RestartSec=5s
KillMode=mixed

#Environment="CR_LICENSE_KEY=xxx"
StandardOutput=/var/log/cloudreve.log
StandardError=syslog

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now cloudreve
echo "Installed cloudreve"

sed -e 's/:5212/:3000/g' -i /root/cloudreve/conf.ini
systemctl restart cloudreve

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############################
