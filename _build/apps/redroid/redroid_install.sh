###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc lsof jq iptables
echo "Installed Dependencies"

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}

#get_latest_release() {
#  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
#}
if command -v docker >/dev/null 2>&1; then
  echo "Docker 已安装"
else
  echo "Docker 正在安装"

  #use online install
  #DOCKER_LATEST_VERSION=$(get_latest_release "moby/moby")
  #echo "Installing Docker $DOCKER_LATEST_VERSION"
  #DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
  #mkdir -p $(dirname $DOCKER_CONFIG_PATH)
  #echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
  #silent sh <(curl -sSL https://get.docker.com)
  #systemctl enable -q --now docker

  #pefer offline docker setup
  wget -q $rlsmirror/docker-24.0.7.tgz -O /tmp/docker-24.0.7.tgz
  tar --warning=no-timestamp -xzf /tmp/docker-24.0.7.tgz -C /usr/bin --strip-components=1
  mkdir -p /etc/docker
  echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
  if [ ! -f /etc/systemd/system/docker.service ]; then
cat >/etc/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
After=network.target
[Service]
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF
  fi
  systemctl enable -q --now docker
fi


cd /root
mkdir -p download

echo "Docker data installing"
    if [[ ! -f /root/data/.datainited ]]; then

        #rm -rf /root/data
        mkdir -p /root/data/{nginx/conf.d,redroid,scrcpy-web/apk}
        touch /root/data/redroid/.gitkeep /root/data/scrcpy-web/.gitkeep

        if [[ ! -f /root/data/nginx/conf.d/default.conf ]]; then
            cat > /root/data/nginx/conf.d/default.conf << 'EOF'
upstream backend {
    server scrcpy:8000;
}

server {
    listen 80;
    server_name _;

    #error_log   /home/www/logs/error.log;
    # 1. 静态资源不做任何 LUA 鉴权
    # .wasm is very important here, or scrcpy will be blackscreen
    location ~* \.(js|css|png|jpg|gif|ico|woff2?|wasm)$ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        access_log off;
        expires max;
    }

    # 2. 其余所有请求做 LUA 鉴权
    location / {
        access_by_lua_block {
            local user_udid = {
                admin = { udid = "", pwd = "admin" },
                user1 = { udid = "redroid1:5555", pwd = "user1" },
                user2 = { udid = "redroid2:5555", pwd = "user2" }
                -- 可以继续添加其它用户
            }

            -- 放行 WebSocket 握手，不做任何权限限制
            if ngx.req.get_headers()["Upgrade"] == "websocket" then
                return
            end

            local function parse_token(token)
                if not token then return nil, nil end
                local raw = ngx.decode_base64(token)
                if not raw then return nil, nil end
                local user, udid = raw:match("([^:]+):?(.*)")
                return user, udid
            end

            local token = ngx.var.cookie_token
            local user, udid = parse_token(token)
            if not user then
                local html = [[
                    <meta charset="utf-8">
                    <style>*{ font-size: 1.15em;} </style>
                    <div style="text-align:center; margin-top:150px;">
                        <p>请先登录</p>
                    </div>
                ]]
                ngx.header.content_type = 'text/html; charset=utf-8'
                ngx.say(html)
                return ngx.exit(200)
            end

            local uri = ngx.var.request_uri or ""
            local args = ngx.req.get_uri_args()
            local req_udid = args["udid"]

            -- 限制普通用户只能访问（自己设备）的流页面和proxy-adb
            if user ~= "admin" then
                local userinfo = user_udid[user]
                -- 如果存在udid参数，必须和自己的udid完全一致，否则403
                if req_udid and userinfo and req_udid ~= userinfo.udid then
                    ngx.status = 403
                    ngx.header.content_type = 'text/html; charset=utf-8'
                    ngx.say("<h2 style='text-align:center;margin-top:120px;'>禁止访问！</h2>")
                    return ngx.exit(403)
                end
            end

            -- 只拦截后台主页/列表页（不含action=stream参数），避免普通用户死循环重定向（下面这段可保留）
            if user ~= "admin" and not uri:find("action=stream") then
                local userinfo = user_udid[user]
                if userinfo then
                    local ws_host = ngx.var.host
                    local ws_url = "ws://" .. ws_host .. ":8055/?action=proxy-adb&remote=tcp:8886&udid=" .. ngx.escape_uri(userinfo.udid)
                    local ws_url_enc = ngx.escape_uri(ws_url)
                    return ngx.redirect("/?action=stream&udid=" .. ngx.escape_uri(userinfo.udid) ..
                        "&player=broadway&ws=" .. ws_url_enc)
                else
                    return ngx.exit(403)
                end
            end
            -- admin 或 action=stream 流页面请求直接通过
        }
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_pass http://backend;
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location = /admin {
        access_by_lua_block {
            local user_udid = {
                admin = { udid = "", pwd = "admin" },
                user1 = { udid = "redroid1:5555", pwd = "user1" },
                user2 = { udid = "redroid2:5555", pwd = "user2" }
                -- 可以继续添加其它用户
            }

            if ngx.var.request_method == "POST" then
                ngx.req.read_body()
                local post = ngx.req.get_post_args()
                local user = post["user"]
                local pwd = post["pwd"]
                local userinfo = user_udid[user]
                local is_admin = user == "admin" and userinfo and pwd == userinfo.pwd
                if is_admin then
                    local token = ngx.encode_base64("admin:")
                    local expires = 3600 * 24
                    ngx.header["Set-Cookie"] = "token=" .. token .. "; Path=/; Expires=" .. ngx.cookie_time(ngx.time() + expires)
                    return ngx.redirect("/")
                elseif userinfo and pwd == userinfo.pwd then
                    local token = ngx.encode_base64(user .. ":" .. userinfo.udid)
                    local expires = 3600 * 24
                    ngx.header["Set-Cookie"] = "token=" .. token .. "; Path=/; Expires=" .. ngx.cookie_time(ngx.time() + expires)
                    local ws_host = ngx.var.host
                    local ws_url = "ws://" .. ws_host .. ":8055/?action=proxy-adb&remote=tcp:8886&udid=" .. ngx.escape_uri(userinfo.udid)
                    local ws_url_enc = ngx.escape_uri(ws_url)
                    return ngx.redirect("/?action=stream&udid=" .. ngx.escape_uri(userinfo.udid) ..
                        "&player=broadway&ws=" .. ws_url_enc)
                else
                    local html = [[
                        <meta charset="utf-8">
                        <style>*{ font-size: 1.15em;} </style>
                        <div style="text-align:center; margin-top:150px;">
                            <p>登录失败</p>
                        </div>
                    ]]
                    ngx.header.content_type = 'text/html; charset=utf-8'
                    ngx.say(html)
                    return ngx.exit(200)
                end
            else
                local token = ngx.var.cookie_token
                local function parse_token(token)
                    if not token then return nil, nil end
                    local raw = ngx.decode_base64(token)
                    if not raw then return nil, nil end
                    local user, udid = raw:match("([^:]+):?(.*)")
                    return user, udid
                end
                local user, udid = parse_token(token)
                local userinfo = user_udid[user]
                if user == "admin" then
                    return ngx.redirect("/")
                elseif userinfo then
                    local ws_host = ngx.var.host
                    local ws_url = "ws://" .. ws_host .. ":8055/?action=proxy-adb&remote=tcp:8886&udid=" .. ngx.escape_uri(userinfo.udid)
                    local ws_url_enc = ngx.escape_uri(ws_url)
                    return ngx.redirect("/?action=stream&udid=" .. ngx.escape_uri(userinfo.udid) ..
                        "&player=broadway&ws=" .. ws_url_enc)
                end

                local html = [[
                    <meta charset="utf-8">
                    <style>*{ font-size: 1.15em;} </style>
                    <form method="post" action="/admin" style="text-align:center; margin-top:150px;">
                        <input name="user" size="16" placeholder="用户名"> <input name="pwd" size="16" placeholder="密码" type="password"> <button type="submit">登录</button>
                    </form>
                ]]
                ngx.header.content_type = 'text/html; charset=utf-8'
                ngx.say(html)
                return ngx.exit(200)
            end
        }
    }
}
EOF
        fi

        if [[ ! -f /root/download/via-browser-cn.apk ]]; then
		    wget -q $rlsmirror/via-browser-cn.apk -O /root/download/via-browser-cn.apk
            if [[ ! -f /root/data/scrcpy-web/apk/via-browser-cn.apk ]]; then
		      cp -f /root/download/via-browser-cn.apk /root/data/scrcpy-web/apk/via-browser-cn.apk
			fi
		fi

        touch /root/data/.datainited
    fi


#echo "Docker images installing"
#docker pull imagename:tag && docker save imagename:tag | xz -z -T0 - > imagename.tar.xz
#wget -q $rlsmirror/redroid/redroid12.tar.xz -O download/redroid12.tar.xz
#wget -q $rlsmirror/redroid/scrcpyweb.tar.xz -O download/scrcpyweb.tar.xz
#wget -q $rlsmirror/redroid/openresty.tar.xz -O download/openresty.tar.xz

if docker network ls --filter name=^mynet$ --format '{{.Name}}' | grep -qw mynet; then
  echo "docker 网络已存在"
else
  #docker network rm mynet
  docker network create --ipv6 --subnet "fd00:dead:beef:1::/64" mynet >/dev/null 2>&1
  echo "docker 网络不存在,已创建"
fi

canusefs=0
mkdir -p /dev/binderfs
if mountpoint -q /dev/binderfs || mount -t binder binder /dev/binderfs 2>/dev/null; then
    canusefs=1
    echo "docker 设备已存在ng"

    if [ ! -f /etc/systemd/system/dev-binderfs.mount ]; then
    cat <<EOFF > /etc/systemd/system/dev-binderfs.mount
[Unit]
Description=Android binderfs mount

[Mount]
What=binder
Where=/dev/binderfs
Type=binder

[Install]
WantedBy=multi-user.target
EOFF
    systemctl enable -q dev-binderfs.mount
    fi

else {

all_exist=true
for i in $(seq 1 32); do
  if [ ! -e /dev/binder$i ]; then
    all_exist=false
  fi
done
if $all_exist; then
  echo "docker 设备已存在"
else
  if [ ! -f /etc/modprobe.d/binder.conf ]; then
    echo "options binder_linux devices=$(seq -s, -f 'binder%g' 1 32)" > /etc/modprobe.d/binder.conf
    echo 'binder_linux' > /etc/modules-load.d/binder_linux.conf
    echo 'KERNEL=="binder*", MODE="0666"' > /etc/udev/rules.d/70-binder.rules
  fi
  #rm -f /dev/binder*
  #rmmod binder_linux
  modprobe binder_linux devices=$(seq -s, -f 'binder%g' 1 32)
  chmod 666 /dev/binder*
  echo "docker 设备不全，已补全"
fi

}; fi

<<'BLOCK'
for i in ashmem:61 binder:60 hwbinder:59 vndbinder:58;do
  if [ ! -e /dev/${i%%:*} ]; then
    mknod /dev/${i%%:*} c 10 ${i##*:}
    chmod 777 /dev/${i%%:*}
    #chown root:${i%%:*} /dev/${i%%:*}
  fi
done
BLOCK

# we add this extra anyway
modprobe mac80211_hwsim
if [ ! -f /etc/modules-load.d/mac80211_hwsim.conf ]; then
  echo 'mac80211_hwsim' > /etc/modules-load.d/mac80211_hwsim.conf
fi

cat > add.sh << 'EOF'
cd /root

if ! docker ps -q -f name=^scrcpy$ | grep -q .; then
  echo -e "\n create scrcpy"
  #if [ ! "$(docker images | grep scrcpy-web)" ] && [ -f download/scrcpyweb.tar.xz ]; then xz -dc download/scrcpyweb.tar.xz | docker load; fi
  docker run -itd \
    --name scrcpy \
    --network=mynet \
    --restart=always \
    --privileged \
    -v ./data/scrcpy-web/data:/data \
    -v ./data/scrcpy-web/apk:/apk \
    minlearn/scrcpyweb_fixed:latest
fi

if ! docker ps -q -f name=^nginx$ | grep -q .; then
echo -e "\n create nginx"
#if [ ! "$(docker images | grep openresty)" ] && [ -f download/openresty.tar.xz ]; then xz -dc download/openresty.tar.xz | docker load; fi
docker run -itd \
    --name nginx \
    --network=mynet \
    --restart=always \
    -v ./data/nginx/conf.d:/etc/nginx/conf.d \
    -p 8055:80 \
    openresty/openresty:1.21.4.1-0-alpine
fi

    canusefs=0
if mountpoint -q /dev/binderfs; then
    canusefs=1
    echo "ng found"
fi

leastfilenum=$(comm --nocheck-order -23 <(seq 1 100 | sort -n) <(find data/redroid -regex 'data/redroid/data[0-9]+$' | grep -Eo '[0-9]+$' | sort -n) | head -n1)
free=$(comm --nocheck-order -23 <(seq 1 32 | sort -n) <(for i in $(docker ps -a --filter ancestor=$( [ -z "$1" ] && echo "redroid/redroid:12.0.0-latest" || echo "$1" ) --format '{{.Names}}'); do docker inspect "$i" | jq -r '.[0].Mounts[] | select(.Source|startswith("/dev/binder")) | .Source'; done | grep -o '[0-9]\+' | sort -n -u) | awk '{print "/dev/binder"$1}')

if ! docker ps -q -f name=^redroid"$leastfilenum"$ | grep -q .; then

if [ "$canusefs" == "0" ]; then
  found1=""
  found2=""
  found3=""
  for i in $free; do
    if [ -e $i ] && ! lsof $i >/dev/null 2>&1; then
      if [ -z "$found1" ]; then
        found1="$i"
      elif [ -z "$found2" ]; then
        found2="$i"
      elif [ -z "$found3" ]; then
        found3="$i"
        break
      fi
    fi
  done

  if [ -z "$found1" ] || [ -z "$found2" ] || [ -z "$found3" ]; then
    echo "error: not enough /dev/binder"
    exit 1
  fi
  echo "found: $found1,$found2,$found3"
fi

  echo -e "\n create redroid$leastfilenum"
  #if [ ! "$(docker images | grep redroid)" ] && [ -f download/redroid12.tar.xz ]; then xz -dc download/redroid12.tar.xz | docker load; fi
  docker run -itd \
    --name=redroid"$leastfilenum" \
    --network=mynet \
    --restart=always \
    --privileged \
    --memory-swappiness=0 \
    $( [ "$canusefs" == "0" ] && echo "-v "$found1":/dev/binder -v "$found2":/dev/hwbinder -v "$found3":/dev/vndbinder" ) \
    -v ./data/redroid/data"$leastfilenum":/data \
    $( [ -z "$1" ] && echo "redroid/redroid:12.0.0-latest" || echo "$1" ) \
    androidboot.hardware=mt6891 ro.secure=0 ro.boot.hwc=GLOBAL ro.ril.oem.imei=861503068361145 ro.ril.oem.imei1=861503068361145 ro.ril.oem.imei2=861503068361148 ro.ril.miui.imei0=861503068361148 ro.product.manufacturer=Xiaomi ro.build.product=chopin redroid.width=720 redroid.height=1280 redroid.gpu.mode=guest
fi

sleep 5
echo -e "\n scrcpy adb connect redroid$leastfilenum"
timeout 10s docker exec scrcpy adb connect redroid"$leastfilenum":5555
j=0
while (( j < 20 )); do 
  if ! timeout 10s docker exec scrcpy adb get-state 1>/dev/null 2>&1; then
    echo "Host not ready(modules lost/permisson lost/binder engaged)? try reconnect"
    timeout 10s docker exec scrcpy adb devices | grep -q "^redroid${leastfilenum}:5555" && echo "connected" && break
  else
    if ! timeout 10s docker exec scrcpy adb devices 1>/dev/null 2>&1| grep -q "^redroid${leastfilenum}:5555"; then
      echo "redroid not ready? try reconnect"
      timeout 10s docker exec scrcpy adb devices | grep -q "^redroid${leastfilenum}:5555" && echo "connected" && break
    fi
  fi
  sleep 5
  timeout 10s docker exec scrcpy adb connect redroid"$leastfilenum":5555
  ((j++))
done

sleep 5
echo -e "\n install APK"
for file in `ls ./data/scrcpy-web/apk`
do
    if [[ -f "./data/scrcpy-web/apk/"$file ]]; then
      echo "installing $file"
      docker exec scrcpy adb -s redroid"$leastfilenum" install /apk/$file
    fi
done
EOF
chmod +x ./add.sh

cat > reconnect.sh << 'EOF'
#without -a,only reconnect active
names=$(docker ps --filter ancestor=$( [ -z "$1" ] && echo "redroid/redroid:12.0.0-latest" || echo "$1" ) --format '{{.Names}}')

for i in $names; do
  echo -e "\n scrcpy adb connect $i"
  docker exec scrcpy adb connect "$i":5555
  j=0
  while (( j < 20 )); do 
    if ! docker exec scrcpy adb get-state 1>/dev/null 2>&1; then
      echo "Host not ready(modules lost/permisson lost/binder engaged)? try reconnect"
      docker exec scrcpy adb devices | grep -q "^${i}:5555" && echo "connected" && break
    else
      if ! docker exec scrcpy adb devices 1>/dev/null 2>&1| grep -q "^${i}:5555"; then
        echo "redroid not ready? try reconnect"
        docker exec scrcpy adb devices | grep -q "^${i}:5555" && echo "connected" && break
      fi
    fi
    sleep 5
    docker exec scrcpy adb connect "$i":5555
    ((j++))
  done
done
EOF
chmod +x ./reconnect.sh

cat > pwd.sh << 'EOF'
    read -p "输入要修改的用户名(有admin,user1-user10等): " user </dev/tty
    read -p "输入新密码，不要太复杂: " pass </dev/tty
    if [[ -n $user && -n $pass ]]; then
        sed -i "s/\(${user}[ ]*=[ ]*{[^}]*pwd[ ]*=[ ]*\"\)[^\"]*\"/\1${pass}\"/" /root/data/nginx/conf.d/default.conf
        docker restart nginx
    else
		exit 1
    fi
    echo ""	
EOF
chmod +x ./pwd.sh

cat > clean.sh << 'EOF'
read -r -p "Are you sure to del all? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  names=$(docker ps -a --filter ancestor=$( [ -z "$1" ] && echo "redroid/redroid:12.0.0-latest" || echo "$1" ) --format '{{.Names}}');[ -n "$names" ] && docker stop $names && docker rm $names
  rm -rf data/redroid/data*

  docker restart scrcpy
  docker restart nginx
fi
EOF
chmod +x ./clean.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
