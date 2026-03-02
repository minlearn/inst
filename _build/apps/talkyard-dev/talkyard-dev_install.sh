###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get install -y openjdk-11-jdk postgresql-client git unzip cpp nginx

curl -sL https://deb.nodesource.com/setup_16.x | bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
silent apt-get update -y
silent apt-get install nodejs yarn -y
echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list
echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list
curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | tee /etc/apt/trusted.gpg.d/sbt.asc
silent apt-get update
silent apt-get install sbt

cd /root

git clone https://github.com/debiki/talkyard.git talkyard-v1
cd talkyard-v1
git checkout 9ef9b55d16301fa67087993c83b2a954aae323f4
if [ ! -f Globals.scala.bak ]; then
  cp appsv/server/debiki/Globals.scala Globals.scala.bak
  cat << 'PATCH' | patch appsv/server/debiki/Globals.scala && echo "补丁已应用" || echo "应用失败"
48a49
> import scala.util.{Try, Success, Failure}
1334c1334,1336
<     val elasticSearchHost = "search"
---
>     val elasticSearchHost: String = sys.env.get("ELASTICSEARCH_HOST")
>       .orElse(getStringNoneIfBlank("talkyard.searchhostname"))
>       .getOrElse("search")
1338a1342,1352
> 
>     // 检查 DNS 是否可以解析
>     val canResolveSearchHost: Boolean = Try {
>       jn.InetAddress.getByName(elasticSearchHost)
>       true
>     } match {
>       case Success(_) => true
>       case Failure(ex) =>
>         logger.warn(s"Cannot resolve search host '$elasticSearchHost', search will be DISABLED [TyMSRCHDNS]")
>         false
>     }
1340,1343c1354,1362
<       new es.transport.client.PreBuiltTransportClient(es.common.settings.Settings.EMPTY)
<         .addTransportAddress(
<           new es.common.transport.TransportAddress(
<             jn.InetAddress.getByName(elasticSearchHost), 9300))
---
>       if (canResolveSearchHost) {
>         new es.transport.client.PreBuiltTransportClient(es.common.settings.Settings.EMPTY)
>           .addTransportAddress(
>             new es.common.transport.TransportAddress(
>               jn.InetAddress.getByName(elasticSearchHost), 9300))
>       } else {
>         // DNS 解析失败，创建一个 dummy client
>         new es.transport.client.PreBuiltTransportClient(es.common.settings.Settings.EMPTY)
>       }
1379a1399,1402
>       else if (!canResolveSearchHost) {
>         logger.info(s"Skipping search indexer (search host unresolvable) [TyMNOINDEXER]")
>         None
>       }  
PATCH
fi
find appsv/server -type f -name '*.scala' -print0 | xargs -0 sed -i 's#opt/talkyard#root/talkyard#g'

# https://github.com/debiki/talkyard/blob/main/makefile & https://github.com/debiki/talkyard/blob/main/gulpfile.js
awk '
BEGIN{
  keep["images/web/ty-media"]=1
  keep["modules/ty-test-media"]=1
  keep["modules/ty-translations"]=1
  keep["modules/google-diff-match-patch"]=1
  keep["modules/sanitize-html"]=1
}
(/^\[submodule "/){
  name=$0
  sub(/^\[submodule "/,"",name)
  sub(/"\]$/,"",name)
  in_block=keep[name]
}
in_block{print}
' .gitmodules > .gitmodules.new && mv .gitmodules.new .gitmodules

keep_paths="$({ git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true; } | awk '{print $2}' | sort -u)"
git ls-files --stage | awk '$1=="160000"{print $4}' | sort -u | while IFS= read -r p; do
  [ -z "$p" ] && continue
  printf '%s\n' "$keep_paths" | grep -Fqx -- "$p" && continue
  git submodule deinit -f -- "$p" || true
done

git submodule update --init --recursive

# https://github.com/debiki/talkyard/blob/main/s/impl/build-prod-app-image.sh
cat > /root/recompile.sh << 'EOL'

$1=${1:-full}

if [ -f /root/talkyard/app/conf/app-prod-override.conf ]; then cp /root/talkyard/app/conf/app-prod-override.conf /root/app-prod-override.conf; fi

if [[ $1 == "full" ]]; then
  echo "Running in full mode"

  # full clean
  systemctl stop talkyard
  rm -rf /root/talkyard
  mkdir -p /root/talkyard/{app,web}

  (cd /root/talkyard-v1/images/web;
  yarn)
  (cd /root/talkyard-v1;
  yarn;
  sbt stage;
  cp -aR version.txt target/universal/stage/* /root/talkyard/app/;
  for i in compileServerTypescriptConcatJavascript compileBlogCommentsTypescript-concatScripts compileSwTypescript-concatScripts compileEditorTypescript-concatScripts compileHeadTypescript-concatScripts compileMoreTypescript-concatScripts compileSlimTypescript-concatScripts compileStaffTypescript-concatScripts bundleZxcvbn compile-stylus buildTranslations bundleFonts minifyTranslations minifyScriptsImpl delete-non-gzipped; do npx gulp $i; done;
  cp -aR images/app/assets /root/talkyard/app/;
  cp -aR images/web/assets images/web/fonts images/web/ty-media images/web/html /root/talkyard/web/;
  if [ -f /root/app-prod-override.conf ]; then cp /root/app-prod-override.conf /root/talkyard/app/conf/app-prod-override.conf; systemctl restart talkyard; fi
  )

else
  echo "Running in quick mode"

  # use a simple quicky/dirty way to update the front, since the above is too slow
  (cd /root/talkyard-v1;
  npx gulp compileSlimTypescript-concatScripts compileMoreTypescript-concatScripts;
  cp images/web/assets/v0.2025.007/slim-bundle.js /root/talkyard/web/assets/v0.2025.007/slim-bundle.min.js;
  cp images/web/assets/v0.2025.007/more-bundle.js /root/talkyard/web/assets/v0.2025.007/more-bundle.min.js;
  )
  systemctl restart talkyard

fi

EOL

cat > /root/start.sh << 'EOL'
#!/bin/bash

# https://github.com/debiki/talkyard-prod-one/raw/refs/heads/main/conf/play-framework.conf
echo -en "\ntalkyard.postgresql.host=\"rdb\"" > /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\ntalkyard.postgresql.port=\"5432\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\ntalkyard.postgresql.database=\"talkyard\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\ntalkyard.postgresql.user=\"talkyard\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\ntalkyard.postgresql.password=\"talkyard\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\ntalkyard.redis.host=\"cache\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl

echo -en "\ntalkyard.hostname=\"localhost\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\ntalkyard.searchhostname=\"search\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\ntalkyard.secure=false" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\nplay.http.secret.key=\"change_this\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl
echo -en "\ntalkyard.becomeOwnerEmailAddress=\"xxx@xxx.com\"" >> /root/talkyard/app/conf/app-prod-override.conf.tpl

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
    }

    location / {
        proxy_pass http://app_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

#ihttps://github.com/debiki/talkyard/blob/main/images/rdb/docker-entrypoint-initdb.d/init.sh
if [ ! -f /root/inited ]; then
  read -p "give a postgresql user dbip(127.0.0.1,10.10.10.x,etc..):" ip
  read -p "give a postgresql user dbpassword:" pw
  read -p "give a talkyard user dbpassword:" tpw
  read -p "give a redis server ip:" rip

  cp /root/talkyard/app/conf/app-prod-override.conf.tpl /root/talkyard/app/conf/app-prod-override.conf
  sed -i "/talkyard.postgresql.host=\"/c\talkyard.postgresql.host=\"$ip\"" /root/talkyard/app/conf/app-prod-override.conf
  sed -i "/talkyard.redis.host=\"/c\talkyard.redis.host=\"$rip\"" /root/talkyard/app/conf/app-prod-override.conf
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
  systemctl enable -q --now talkyard

  chmod -R 755 /root/talkyard
  sed -i "s/user www-data;/user root;/g" /etc/nginx/nginx.conf
  cp /root/talkyard/web/nginx.default.tpl /etc/nginx/sites-enabled/default
  systemctl restart nginx

  touch /root/inited
fi

EOL

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
