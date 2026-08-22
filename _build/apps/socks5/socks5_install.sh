###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc jq
echo "Installed Dependencies"

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}


sed -i '/^\*\ *soft\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
sed -i '/^\*\ *hard\ *nofile\ *[[:digit:]]*/d' /etc/security/limits.conf
echo '* soft nofile 65536' >>/etc/security/limits.conf
echo '* hard nofile 65536' >>/etc/security/limits.conf


mkdir -p /app/socks5
wget --no-check-certificate $rlsmirror/xray.tar.gz -O /tmp/tmp.tar.gz
tar -xzvf /tmp/tmp.tar.gz -C /app/socks5 xray --strip-components=1
rm -rf /tmp/tmp.tar.gz

cat > /lib/systemd/system/socks5.service << 'EOL'
[Unit]
Description=Socks Service
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

ExecStart=/app/socks5/xray -c /app/socks5/config.yaml
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOL

cat > /app/socks5/config.yaml << 'EOL'
{
    "log": null,
    "routing": {
        "domainStrategy": "AsIs"
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": "1080",
            "protocol": "socks",
            "settings": {
                "auth": "password",
                "accounts": [
                ],
                "udp": true
            },
            "streamSettings": {
                "network": "tcp"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOL

cat > /root/add.sh << 'EOL'
read -p "请输入格式为 user:pass 的一对值，保证不要有特殊字符或字母: " user_pass </dev/tty
if [[ -z "$user_pass" ]]; then
  echo "输入不能为空，请重新运行脚本并输入有效的值。"
  exit 1
fi
IFS=":" read -r user pass <<< "$user_pass"
if [[ -z "$user" || -z "$pass" ]]; then
  echo "输入格式不正确，请确保以 user:pass 格式提供值。"
  exit 1
fi
input_file="/app/socks5/config.yaml"
first_exist=$(jq '.inbounds[0].settings | has("accounts")' "$input_file")
if [[ "$first_exist" == "false" ]]; then
  tmp_file=$(mktemp)
  jq --arg user "$user" --arg pass "$pass" \
     '.inbounds[0].settings.accounts = [{"user": $user, "pass": $pass}]' \
     "$input_file" > "$tmp_file" || { echo "jq 命令执行失败，请检查 JSON 文件格式和 jq 表达式。";rm -f "$tmp_file";exit 1; }
  mv "$tmp_file" "$input_file"
  echo "新账户已添加到 $input_file"
  systemctl restart socks5
  exit 0
fi
fromsec_exists=$(jq --arg user "$user" \
  '.inbounds[0].settings.accounts[]? | select(.user == $user)' \
  "$input_file")
if [[ -n "$fromsec_exists" ]]; then
  echo "该用户 $user 已经存在，未进行任何更改。"
  exit 0
fi
tmp_file=$(mktemp)
jq --arg user "$user" --arg pass "$pass" \
   '.inbounds[0].settings.accounts += [{"user": $user, "pass": $pass}]' \
   "$input_file" > "$tmp_file" || { echo "jq 命令执行失败，请检查 JSON 文件格式和 jq 表达式。";rm -f "$tmp_file";exit 1; }
mv "$tmp_file" "$input_file"
echo "新账户已添加到 $input_file"
systemctl restart socks5
EOL
chmod +x /root/add.sh


cat > /root/del.sh << 'EOL'
read -p "请输入要删除的 user 名字: " user </dev/tty
input_file="/app/socks5/config.yaml"
exists=$(jq --arg user "$user" \
  '.inbounds[0].settings.accounts[]? | select(.user == $user)' \
  "$input_file")
if [[ -z "$exists" ]]; then
  echo "用户 $user 不存在，无法删除。"
  exit 0
fi
tmp_file=$(mktemp)
jq --arg user "$user" \
   '.inbounds[0].settings.accounts |= map(select(.user != $user))' \
   "$input_file" > "$tmp_file" || { echo "jq 命令执行失败，请检查 JSON 文件格式和 jq 表达式。";rm -f "$tmp_file";exit 1; }
mv "$tmp_file" "$input_file"
echo "用户 $user 已成功从 $input_file 中删除"
systemctl restart socks5
EOL
chmod +x /root/del.sh

systemctl enable -q --now socks5


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
