##################

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

echo "Installing Nginx"
silent apt-get install -y nginx
systemctl enable -q --now nginx
echo "Installed Nginx"

silent apt install -y certbot python3-certbot-nginx

cd /root

cat > certbot.sh << 'EOL'
  read -p "give a domain which is already configured in nginx:" domain  </dev/tty
  certbot --nginx --agree-tos --register-unsafely-without-email -d $domain
  systemctl restart nginx
EOL
chmod +x certbot.sh
cat > certbot-auto.sh << 'EOL'
  certbot renew
  systemctl restart nginx
EOL
chmod +x certbot-auto.sh

read -r -p "Would you like to add a certbot service? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  bash /root/certbot.sh

  cat > /lib/systemd/system/certbot-auto.service << 'EOL'
[Unit]
Description=Auto Certbot for Nginx
[Service]
Type=oneshot
ExecStart=/root/certbot-auto.sh
EOL

  cat > /lib/systemd/system/certbot-auto.timer << 'EOL'
[Unit]
Description=Run certbot-auto service weekly
[Timer]
OnCalendar=weekly
Persistent=true
[Install]
WantedBy=timers.target
EOL

  systemctl enable --now certbot-auto.timer
fi

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############################
