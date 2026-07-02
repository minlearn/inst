###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get install -y procps debconf-utils
echo iptables-persistent iptables-persistent/autosave_v4 boolean false | debconf-set-selections >/dev/null 2>&1; \
echo iptables-persistent iptables-persistent/autosave_v6 boolean false | debconf-set-selections >/dev/null 2>&1;
silent apt-get install -y iptables-persistent

cd /root

arch=$([[ "$(arch)" == "aarch64" ]] && echo _arm64)
rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
[[ ! -f download/tmp.tar.gz ]] && wget --no-check-certificate $rlsmirror/clashmeta$arch.tar.gz -O download/tmp.tar.gz

mkdir -p app/clashmeta
tar -xzvf download/tmp.tar.gz -C app/clashmeta clashmeta --strip-components=1
chmod +x app/clashmeta/clash-meta

# head only,no proxies/proxygroups and rules
cat > /root/app/clashmeta/config.yaml << 'EOL'
mode: rule
mixed-port: 7890
allow-lan: true
log-level: info
ipv6: true
secret: ''
external-controller: 127.0.0.1:9090
dns:
  enable: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
  - 114.114.114.114
  - 223.5.5.5
  - 8.8.8.8
  fallback: []
tun:
  enable: false
  stack: gvisor
  dns-hijack:
  - any:53
  auto-route: true
  auto-detect-interface: true
EOL

cat > /lib/systemd/system/clashmeta.service << 'EOL'
[Unit]
Description=this is clashmeta service,please init it with the init.sh
After=network.target nss-lookup.target
Wants=network.target nss-lookup.target
Requires=network.target nss-lookup.target

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=/root/app/clashmeta/clash-meta -d /root/app/clashmeta -f /root/app/clashmeta/config.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

cat > /root/init.sh << 'EOL'
test -f /root/inited || {
  echo "选择导入方式："
  echo "1) 订阅URL（自动截取proxies段，沿用订阅自带groups/rules）"
  echo "2) 手动输入单个VMess（自动补齐proxies/proxy-groups/rules顶层）"
  read -p "请选择(1/2): " mode

  test -f /root/app/clashmeta/config.yaml.bak || cp /root/app/clashmeta/config.yaml /root/app/clashmeta/config.yaml.bak

  if [ "$mode" = "1" ]; then
    read -p "输入订阅URL: " file
    wget -qO- --no-check-certificate $file|sed -n "/^proxies/,/^$/p" >> /root/app/clashmeta/config.yaml
    #raw="$(wget -qO- --no-check-certificate "$file")"
    #VAR="$(awk '/^proxies:/ {flag=1} flag && /^proxy-groups:/ {flag=0} flag {print}' <<<"$raw")"
    #sed -e '/^  auto-detect-interface: true/ {' -e 'r /dev/stdin' -e '}' -i /root/app/clashmeta/config.yaml <<<"$VAR"
    #VAR2="$(awk '/^proxy-groups:/ {pg=1; next} pg && /^ *proxies:/ {inproxies=1; next} pg && inproxies && /^ *- / && $0 !~ /^ *- name:/ {v=$0; sub(/^ *- /,"",v); if (!seen[v]++) print "      - " v; next} pg && inproxies && !/^ *- / {inproxies=0}' <<<"$raw")"
    #new_var2=$(awk -v pat="$(echo "$VAR" | tail -n +2 | awk -F'name:[ ]*' '{if($0 ~ /name:/){split($2,a,",");n=a[1];gsub(/^[ \t]+|[ \t]+$/, "", n);print n}}' | paste -sd'|' -)" 'BEGIN{IGNORECASE=1}{l=$0; sub(/^[ \t-]+/, "", l); if(pat!="" && l~pat) print $0}' <<<"$VAR2")
    #sed -e '/- xxxxxxx/ {' -e 'r /dev/stdin' -e 'd' -e '}' -i /root/app/clashmeta/config.yaml <<<"$new_var2"
    #raw="$(wget -qO- --no-check-certificate "$file")"
    #VAR="$(awk '/^proxies:/ {flag=1} flag && /^proxy-groups:/ {flag=0} flag {print}' <<<"$raw")"
    #sed -e '/^  auto-detect-interface: true/ {' -e 'r /dev/stdin' -e '}' -i /root/app/clashmeta/config.yaml <<<"$VAR"
    #VAR2="$(awk '/^proxy-groups:/ {pg=1; next} pg && /^ *proxies:/ {inproxies=1; next} pg && inproxies && /^ *- / && $0 !~ /^ *- name:/ {v=$0; sub(/^ *- /,"",v); if (!seen[v]++) print "      - " v; next} pg && inproxies && !/^ *- / {inproxies=0}' <<<"$raw")"
    #new_var2=$(awk -v pat="$(echo "$VAR" | tail -n +2 | awk -F'name:[ ]*' '{if($0 ~ /name:/){split($2,a,",");n=a[1];gsub(/^[ \t]+|[ \t]+$/, "", n);print n}}' | paste -sd'|' -)" 'BEGIN{IGNORECASE=1}{l=$0; sub(/^[ \t-]+/, "", l); if(pat!="" && l~pat) print $0}' <<<"$VAR2")
    #sed -e '/- xxxxxxx/ {' -e 'r /dev/stdin' -e 'd' -e '}' -i /root/app/clashmeta/config.yaml <<<"$new_var2"
  else
    read -p "VMess server: " server
    read -p "VMess port: " port
    read -p "VMess uuid: " uuid

    # 1. 不存在顶层proxies则新建
    if ! grep -q '^proxies:' /root/app/clashmeta/config.yaml; then
      echo "proxies:" >> /root/app/clashmeta/config.yaml
    fi
    # 追加单条vmess节点（和订阅输出缩进一致）
    cat >> /root/app/clashmeta/config.yaml << EOF
  - name: "manual-vmess"
    type: vmess
    server: $server
    port: $port
    uuid: $uuid
    alterId: 0
    cipher: auto

EOF

    # 2. 不存在proxy-groups则新建基础分组
    if ! grep -q '^proxy-groups:' /root/app/clashmeta/config.yaml; then
      cat >> /root/app/clashmeta/config.yaml << 'EOF'
proxy-groups:
  - name: "Proxy"
    type: select
    proxies:
      - manual-vmess
      - DIRECT

EOF
    else
      # 分组已存在，追加节点到Proxy分组顶部
      sed -i '/  - name: "Proxy"/,/proxies:/ s/      - /      - manual-vmess\n      - /' /root/app/clashmeta/config.yaml
    fi

    # 3. 不存在rules则新建全局匹配规则
    if ! grep -q '^rules:' /root/app/clashmeta/config.yaml; then
      cat >> /root/app/clashmeta/config.yaml << 'EOF'
rules:
  - MATCH,Proxy

EOF
    fi
  fi

  grep -q 'proxies' /root/app/clashmeta/config.yaml && /root/app/clashmeta/clash-meta -d /root/app/clashmeta -t /root/app/clashmeta/config.yaml && touch /root/inited
  systemctl restart clashmeta
}
EOL
chmod +x /root/init.sh

cat > /root/transport.sh << 'EOL'

read -r -p "this will open the transport proxy,are you sure? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then

    grep -q 'redir-port: 7892' /root/app/clashmeta/config.yaml || sed -i ':a;N;$!ba;s/mixed-port:\ 7890/mixed-port:\ 7890\nredir-port:\ 7892/g' /root/app/clashmeta/config.yaml 
    sed -i ':a;N;$!ba;s/dns:\n\ \ enable: false/dns:\n\ \ enable: true\n\ \ listen:\ 0.0.0.0:53/g;s/tun:\n\ \ enable: false/tun:\n\ \ enable: true/g' /root/app/clashmeta/config.yaml
    grep -q 'net.ipv4.ip_forward = 1' /etc/sysctl.conf || {
      echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
      echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
      sysctl -p
    }
    iptables -t nat -N clash >/dev/null 2>&1
    [[ $? == '0' ]] && {
      #iptables -t nat -N clash
      iptables -t nat -A clash -d 0.0.0.0/8 -j RETURN
      iptables -t nat -A clash -d 10.0.0.0/8 -j RETURN
      iptables -t nat -A clash -d 127.0.0.0/8 -j RETURN
      iptables -t nat -A clash -d 169.254.0.0/16 -j RETURN
      iptables -t nat -A clash -d 172.16.0.0/12 -j RETURN
      iptables -t nat -A clash -d 192.168.0.0/16 -j RETURN
      iptables -t nat -A clash -d 224.0.0.0/4 -j RETURN
      iptables -t nat -A clash -d 240.0.0.0/4 -j RETURN
      iptables -t nat -A clash -p tcp -j REDIRECT --to-port 7892
      iptables -t nat -A PREROUTING -p tcp -j clash
      iptables -A INPUT -p udp --dport 53 -j ACCEPT
      # save and show
      netfilter-persistent save
      iptables -t nat -L -v -n
    }
    systemctl restart clashmeta

    echo "now you can use this vm ip as sidecar route gateway"
fi
EOL
chmod +x /root/transport.sh

cat > /root/transport2.sh << 'EOL'

read -r -p "this will open the TPROXY full transparent proxy for port 3389/13389 only,are you sure? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then

    grep -q 'tproxy-port: 7893' /root/app/clashmeta/config.yaml || sed -i ':a;N;$!ba;s/mixed-port:\ 7890/mixed-port:\ 7890\ntproxy-port:\ 7893/g' /root/app/clashmeta/config.yaml
    # 安全清理tun区块，不删除下方proxies/proxy-groups/rules
    sed -i '/^tun:/,/^  auto-detect-interface:/{/^tun:/!d}' /root/app/clashmeta/config.yaml

    grep -q 'net.ipv4.ip_forward = 1' /etc/sysctl.conf || {
      echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
      echo 'net.ipv4.conf.all.route_localnet = 1' | tee -a /etc/sysctl.conf
      sysctl -p
    }

    # 写入tproxy路由表标识
    grep -qx "100 tproxy" /etc/iproute2/rt_tables || echo "100 tproxy" >> /etc/iproute2/rt_tables

    # 持久策略路由到interfaces，网关匹配你机器10.10.10.254
    GW_LINE="gateway 10.10.10.254"
    sed -i '/ip rule add fwmark 100/d' /etc/network/interfaces
    sed -i '/ip rule add fwmark 0x64/d' /etc/network/interfaces
    sed -i '/ip route add local 0.0.0.0/d' /etc/network/interfaces
    sed -i '/pre-down ip rule del fwmark/d' /etc/network/interfaces
    sed -i '/pre-down ip route del local 0.0.0.0/d' /etc/network/interfaces
    # ========== 修复点：新增iptables-restore自动恢复，重启networking不再清空iptables ==========
    sed -i "/$GW_LINE/a\\        post-up iptables-restore /etc/iptables/rules.v4 2>/dev/null || true\\n        post-up ip rule add fwmark 0x64 table tproxy\\n        post-up ip route add local 0.0.0.0/0 dev lo table tproxy\\n        pre-down ip rule del fwmark 0x64 table tproxy || true\\n        pre-down ip route del local 0.0.0.0/0 dev lo table tproxy || true" /etc/network/interfaces

    # 重建iptables tproxy链
    iptables -t mangle -N clash_tproxy >/dev/null 2>&1
    [[ $? == '0' ]] && {
        iptables -t mangle -A clash_tproxy -d 0.0.0.0/8 -j RETURN
        iptables -t mangle -A clash_tproxy -d 10.0.0.0/8 -j RETURN
        iptables -t mangle -A clash_tproxy -d 127.0.0.0/8 -j RETURN
        iptables -t mangle -A clash_tproxy -d 169.254.0.0/16 -j RETURN
        iptables -t mangle -A clash_tproxy -d 172.16.0.0/12 -j RETURN
        iptables -t mangle -A clash_tproxy -d 192.168.0.0/16 -j RETURN
        iptables -t mangle -A clash_tproxy -d 224.0.0.0/4 -j RETURN
        iptables -t mangle -A clash_tproxy -d 240.0.0.0/4 -j RETURN

        # 3389/13389 打十六进制标记0x64（十进制100）
        iptables -t mangle -A clash_tproxy -p tcp --dport 3389 -j MARK --set-mark 0x64
        iptables -t mangle -A clash_tproxy -p tcp --dport 13389 -j MARK --set-mark 0x64

        iptables -t mangle -A PREROUTING -j clash_tproxy
        # 统一匹配0x64，不再用十进制100，标记匹配成功
        iptables -t mangle -A PREROUTING -p tcp -m mark --mark 0x64 -j TPROXY --on-port 7893

        # 放行带标记流量进入本机ClashMeta
        iptables -A INPUT -p tcp -m mark --mark 0x64 -j ACCEPT

        netfilter-persistent save
        iptables -t mangle -L -v -n
    }

    systemctl restart networking
    systemctl restart clashmeta

    echo "TPROXY full transparent gateway ready"
    echo "Only tcp 3389/13389 will be proxyed"
    echo "Fix: MARK unified to 0x64, match ip rule correctly"
    echo "Fix: auto restore iptables rules after networking restart"
fi
EOL
chmod +x /root/transport2.sh

systemctl enable -q --now clashmeta


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############