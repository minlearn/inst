###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get install -y openjdk-11-jdk postgresql-client nginx redis

echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list
echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list
curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | tee /etc/apt/trusted.gpg.d/sbt.asc
silent apt-get update
silent apt-get install sbt -y

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
wget --no-check-certificate ${rlsmirror}/discuss-ty.tar.gz -O download/talkyard.tar.gz

mkdir -p /root/talkyard
tar -xzf download/talkyard.tar.gz -C /root/talkyard

cat > /root/start.sh << 'EOL'
#!/bin/bash

# https://github.com/debiki/talkyard-prod-one/raw/refs/heads/main/conf/play-framework.conf
echo "talkyard.ssr=false" > /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.postgresql.host=\"rdb\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.postgresql.port=\"5432\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.postgresql.database=\"talkyard\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.postgresql.user=\"talkyard\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.postgresql.password=\"talkyard\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.redis.host=\"cache\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl

echo "talkyard.hostname=\"localhost\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.searchhostname=\"search\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.secure=false" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "play.http.secret.key=\"change_this\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo "talkyard.becomeOwnerEmailAddress=\"xxx@xxx.com\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl

# https://github.com/debiki/talkyard/blob/main/images/web/server-locations.conf
tee /root/talkyard/web/nginx.default.tpl > /dev/null << 'EOF'
upstream app_backend {
    server localhost:9000;
}

map $uri $asset_uri {
    ~^(.*)\.min\.js$   $1.js;
    ~^(.*)\.min\.css$  $1.css;
    default            $uri;
}

server {
    listen 80 default_server;
    server_name _;
    client_max_body_size 25m;
    root /root/talkyard/web/html;

    location ~ ^/-/u/(?<pubSiteId>[^/][^/]+)/(?<hashPath>.*)$ {
      limit_except GET OPTIONS {
        deny all;
      }
      auth_request /_auth_upload/;
      error_page 403 /403-upload-not-found.html;
      alias /root/talkyard/uploads/public/$hashPath;
    }

    location /_auth_upload/ {
      internal;
      proxy_pass              http://app_backend/-/_int_req/may-download-file/$pubSiteId/$hashPath;
      proxy_pass_request_body off;
      proxy_set_header        Content-Length "";
      proxy_set_header        X-Original-URI $request_uri;
    }

    location /-/assets/ {
        alias /root/talkyard/web/assets/;
        try_files $uri $uri.gz $asset_uri $asset_uri.gz =404;
    }

    location /-/fonts/ {
        alias /root/talkyard/web/fonts/;
    }

    location /-/media/ {
        alias /root/talkyard/web/ty-media/;
    }

    location = /-/websocket {
        proxy_pass http://app_backend/-/websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        # websocket直连、不缓存、必透传
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location / {
        proxy_pass http://app_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        #所有动态页面：强制不缓存、透传 Cookie
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "-1";
    }
}
EOF

#ihttps://github.com/debiki/talkyard/blob/main/images/rdb/docker-entrypoint-initdb.d/init.sh
if [ ! -f /root/inited ]; then
  read -p "give a postgresql host ip(127.0.0.1,10.10.10.x,etc..):" ip
  read -p "give a postgresql admin password:" pw
  read -p "give a talkyard user dbpassword:" tpw

  cp /root/talkyard/app/conf/app-prod-override.conf.tpl /root/talkyard/app/conf/app-prod-override.conf
  sed -i "/talkyard.postgresql.host=\"/c\talkyard.postgresql.host=\"$ip\"" /root/talkyard/app/conf/app-prod-override.conf
  sed -i "/talkyard.postgresql.password=\"/c\talkyard.postgresql.password=\"$tpw\"" /root/talkyard/app/conf/app-prod-override.conf
  sed -i "/talkyard.redis.host=\"/c\talkyard.redis.host=\"localhost\"" /root/talkyard/app/conf/app-prod-override.conf
  sed -i "/play.http.secret.key=\"/c\play.http.secret.key=\"key-1111111111111111111111111111111111111111111\"" /root/talkyard/app/conf/app-prod-override.conf

  PGPASSWORD="$pw" psql -h $ip -p 5432 -U postgres << EOF
    DROP DATABASE IF EXISTS talkyard;
    CREATE ROLE talkyard WITH LOGIN PASSWORD '$tpw';
    CREATE DATABASE talkyard OWNER talkyard;
    GRANT ALL PRIVILEGES ON DATABASE talkyard TO talkyard;
EOF

  # https://github.com/debiki/talkyard/blob/main/images/app/Dockerfile.prod
  tee /etc/systemd/system/talkyard.service > /dev/null << 'EOF'
[Unit]
Description=Talkyard Application Server
After=network.target postgresql.service

[Service]
Type=simple
Restart=always
RestartSec=10
User=root
WorkingDirectory=/root/talkyard
Environment="PLAY_HEAP_MEMORY_MB=1024"
ExecStartPre=-/bin/rm -f /root/talkyard/app/RUNNING_PID
ExecStart=/root/talkyard/app/bin/talkyard-server \
  -J-Xms${PLAY_HEAP_MEMORY_MB}m \
  -J-Xmx${PLAY_HEAP_MEMORY_MB}m \
  -Dhttp.port=9000 \
  -Dhttp.address=127.0.0.1 \
  -Dlogback.configurationFile=/root/talkyard/app/conf/logback-prod.xml \
  -Dconfig.file=/root/talkyard/app/conf/app-prod.conf

[Install]
WantedBy=multi-user.target
EOF
  systemctl start redis
  systemctl enable -q --now talkyard

  chmod -R 755 /root/talkyard
  sed -i "s/user www-data;/user root;/g" /etc/nginx/nginx.conf
  cp /root/talkyard/web/nginx.default.tpl /etc/nginx/sites-enabled/default
  systemctl restart nginx

  touch /root/inited
fi

EOL

chmod +x /root/start.sh

cat > /root/up.sh << 'EOL'
  if [ -f /root/talkyard/app/conf/app-prod-override.conf ]; then cp /root/talkyard/app/conf/app-prod-override.conf /root/app-prod-override.conf; fi

  echo "Running in update mode"

  systemctl stop talkyard redis
  rm -rf /root/talkyard/* talkyard.tar.gz
  read -p "give a talkyard.tar.gz url:" url </dev/tty
  wget --no-check-certificate $url -O talkyard.tar.gz
  tar -xzvf talkyard.tar.gz -C /root/talkyard/
  if [ -f /root/app-prod-override.conf ]; then cp /root/app-prod-override.conf /root/talkyard/app/conf/app-prod-override.conf; systemctl restart talkyard; fi
  systemctl restart redis
EOL

chmod +x /root/up.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
