###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

wget --no-check-certificate https://nodejs.org/dist/v18.20.5/node-v18.20.5-linux-x64.tar.gz -O /tmp/node.tar.gz
tar xzvf /tmp/node.tar.gz --exclude CHANGELOG.md --exclude LICENSE --exclude README.md  -C /usr/local --strip-components=1
rm -rf /tmp/node.tar.gz

silent npm install -g wrangler@3.105.0

mkdir -p /app/discuss/dist
wget --no-check-certificate https://github.com/minlearn/discuss/releases/download/inital/discuss.tar.gz -O /tmp/apps.tar.gz
tar -xzvf /tmp/apps.tar.gz -C /app/discuss/dist ./
rm -rf /tmp/apps.tar.gz
   
cat > /app/discuss/wrangler.toml << 'EOL'
compatibility_date = "2024-03-07"
[[d1_databases]]
binding = "discussdb"
database_name = "discuss_discussdb_development"
database_id = "11111111-1111-1111-1111-111111111111"
[durable_objects]
bindings = [
  { name = "CHAT_ROOM", class_name = "ChatRoom" }
]
[site]
bucket = "./"
EOL

#cat > /lib/systemd/system/discussd1.service << 'EOL'
#[Unit]
#Description=Run once
#After=local-fs.target
#After=network.target

#[Service]
#WorkingDirectory=/app/discuss
#Type=oneshot
#ExecStart=wrangler d1 execute discuss_discussdb_development --file=dist/db.sql --local
#RemainAfterExit=true

#[Install]
#WantedBy=multi-user.target
#EOL

cat > /lib/systemd/system/discuss.service << 'EOL'
[Unit]
Description=this is wrangler service
After=network.target nss-lookup.target
#After=discussd1
Wants=network.target nss-lookup.target
Requires=network.target nss-lookup.target

[Service]
WorkingDirectory=/app/discuss
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=wrangler pages dev ./dist --local --ip 0.0.0.0 --port 3000
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

systemctl enable discuss
systemctl start discuss


read -r -p "Would you like to add nginx and certbot? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then

  sed -e s/0.0.0.0/127.0.0.1/g -i /lib/systemd/system/discuss.service
  systemctl daemon-reload
  systemctl restart discuss

  silent apt-get install -y nginx certbot python3-certbot-nginx
  cat <<'EOF' > /etc/nginx/sites-enabled/default.tpl
server {
    listen 80;
    server_name your-domain.com;

    # 自动证书请求，读取本地文件
    location /.well-known/acme-challenge/ {
        alias /var/www/challenge/;
        try_files $uri =404;
    }

    # WebSocket 代理
    location /api2 {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }

    # 其它请求转发到 wrangler 服务
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF
  cp -f /etc/nginx/sites-enabled/default.tpl /etc/nginx/sites-enabled/default
  systemctl enable -q --now nginx

  cat > certbot.sh << 'EOL'
    read -p "give a domain to configure in nginx:" domain  </dev/tty
    sed -e "s/your-domain.com/$domain/g" -i /etc/nginx/sites-enabled/default
    certbot --nginx --agree-tos --register-unsafely-without-email -d $domain
    systemctl restart nginx
EOL
chmod +x certbot.sh
fi

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############