###############################

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y unzip apache2-utils fuse3
echo "Installed Dependencies"

RELEASE=$(wget -q https://github.com/rclone/rclone/releases/latest -O - | grep "title>Release" | cut -d " " -f 4 | sed 's/^v//')
arch=$([[ "$(arch)" == "aarch64" ]] && echo arm64||echo amd64)
wget -q https://github.com/rclone/rclone/releases/download/v$RELEASE/rclone-v$RELEASE-linux-$arch.zip
unzip rclone-v$RELEASE-linux-$arch.zip
mv rclone-v$RELEASE-linux-$arch/rclone /usr/local/bin/
chmod +x /usr/local/bin/rclone
rm -rf rclone-v$RELEASE-linux-$arch
echo "v2.0.5" > /root/.cache/rclone/webgui/tag
wget https://github.com/rclone/rclone-webui-react/releases/download/v2.0.5/currentbuild.zip -O /root/.cache/rclone/webgui/v2.0.5.zip

echo "Installing rclone"
mkdir -p /etc/rclone
RCLONE_PASSWORD=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
silent htpasswd -cb -B /etc/rclone/login.pwd admin "$RCLONE_PASSWORD"
{
  echo "rclone-Credentials"
  echo "rclone User Name: admin"
  echo "rclone Password: $RCLONE_PASSWORD"
} >>~/rclone.creds
echo "Installed rclone"

echo "Creating Service"
cat <<EOF >/etc/systemd/system/rclone-web.service
[Unit]
Description=Rclone Web GUI
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/rclone rcd --rc-web-gui --rc-web-gui-update=false --rc-web-gui-no-open-browser --rc-addr :3000 --rc-htpasswd /etc/rclone/login.pwd
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now rclone-web
echo "Created Service"


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############################
