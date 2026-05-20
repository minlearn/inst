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
log-level: error
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
  read -p "give a sub download url with proxies/proxygroups and rules, will use it to fullfil config.yaml:" file
  test -f /root/app/clashmeta/config.yaml.bak || cp /root/app/clashmeta/config.yaml /root/app/clashmeta/config.yaml.bak

  wget -qO- --no-check-certificate $file|sed -n "/^proxies/,/^$/p" >> /root/app/clashmeta/config.yaml
  #raw="$(wget -qO- --no-check-certificate "$file")"
  #VAR="$(awk '/^proxies:/ {flag=1} flag && /^proxy-groups:/ {flag=0} flag {print}' <<<"$raw")"
  #sed -e '/^  auto-detect-interface: true/ {' -e 'r /dev/stdin' -e '}' -i /root/app/clashmeta/config.yaml <<<"$VAR"
  #VAR2="$(awk '/^proxy-groups:/ {pg=1; next} pg && /^ *proxies:/ {inproxies=1; next} pg && inproxies && /^ *- / && $0 !~ /^ *- name:/ {v=$0; sub(/^ *- /,"",v); if (!seen[v]++) print "      - " v; next} pg && inproxies && !/^ *- / {inproxies=0}' <<<"$raw")"
  #new_var2=$(awk -v pat="$(echo "$VAR" | tail -n +2 | awk -F'name:[ ]*' '{if($0 ~ /name:/){split($2,a,",");n=a[1];gsub(/^[ \t]+|[ \t]+$/, "", n);print n}}' | paste -sd'|' -)" 'BEGIN{IGNORECASE=1}{l=$0; sub(/^[ \t-]+/, "", l); if(pat!="" && l~pat) print $0}' <<<"$VAR2")
  #sed -e '/- xxxxxxx/ {' -e 'r /dev/stdin' -e 'd' -e '}' -i /root/app/clashmeta/config.yaml <<<"$new_var2"

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

systemctl enable -q --now clashmeta


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
