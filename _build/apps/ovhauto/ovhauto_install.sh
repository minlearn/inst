###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
wget --no-check-certificate $rlsmirror/ovhauto.tar.gz -O download/tmp.tar.gz
wget https://github.com/mikefarah/yq/releases/download/v4.43.1/yq_linux_amd64 -O download/yq
cp download/yq /usr/local/bin/yq
chmod +x /usr/local/bin/yq

mkdir -p app/ovhauto
tar -xzvf download/tmp.tar.gz -C app/ovhauto ovhauto

cat > /lib/systemd/system/ovhauto.service << 'EOL'
[Unit]
Description=this is ovhauto service,please change the token then daemon-reload it
After=network.target nss-lookup.target
Wants=network.target nss-lookup.target
Requires=network.target nss-lookup.target

[Service]
Type=simple
ExecStart=/root/app/ovhauto/ovhauto -config /root/app/ovhauto/config.yaml
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOL

#interval: 10                                                   # 任务运行的时间间隔（秒）
#times: 2                                                       # 要抢购的订单数
#required_plan_code: "26skleb01-v1"                             # 必填，curl得出，填错刷不出货
#required_datacenter: ""                                        # 可选，curl得出，填错刷不出货，不填不走具体datacenter
#required_disk: "softraid-2x450nvme"                            # 可选，curl得出，填错刷不出货，不填不走指定disk类型
#required_memory: ""                                            # 可选，curl得出，填错刷不出货
#options:                                                       # 必选，curl结果各项加-planccode，填错加不了购物车
#  - "bandwidth-500-26skle"
#  - "ram-32g-ecc-2400-26skleb01-v1"
#  - "softraid-2x450nvme-26skleb01-v1"
#autopay: true                                                  # 可选，建议开启
#coupon: ""                                                     # 可选，没有码不填
cat > /root/app/ovhauto/config.yaml << 'EOL'
app:
  key: "your_app_key"
  secret: "your_app_secret"
  consumer_key: "your_consumer_key"
  region: "ovh-eu"
  interval: 10
  times: 2
  
telegram:
  token: "your_telegram_bot_token"
  chat_id: "your_telegram_chat_id"
  
server:
  iam: "your_iam_identifier"
  zone: "IE"
  plan_name: "your_plan_name"
  required_plan_code: "required_plan_code"
  required_datacenter: ""
  required_disk: "required_disk"
  required_memory: ""
  options:
  autopay: true
  coupon: ""
EOL

cat > /root/init.sh << 'EOL'
read -p "give a plancode:" PLAN </dev/tty
CONFIG_YAML="/root/app/ovhauto/config.yaml"


# 1. 获取数据
response=$(curl -s -X GET "https://eu.api.ovh.com/1.0/dedicated/server/datacenter/availabilities?planCode=$PLAN")
# 2. 构造unique内存+硬盘组合列表
mapfile -t COMBINATIONS < <(echo "$response" | yq -p=json -o=tsv '.[] | [.memory, .storage] | @tsv' | sort -u)
i=1
for item in "${COMBINATIONS[@]}"; do
    memory="${item%%$'\t'*}"
    storage="${item##*$'\t'}"
    echo "$i) 内存: $memory    硬盘: $storage"
    ((i++))
done
# 3. 用户选择
read -p "请选择一组数字（1~${#COMBINATIONS[@]}）: " idx
idx=$((idx-1))
if [[ $idx -lt 0 || $idx -ge ${#COMBINATIONS[@]} ]]; then
    echo "无效选择"
    exit 1
fi
memory="${COMBINATIONS[$idx]%%$'\t'*}"
storage="${COMBINATIONS[$idx]##*$'\t'}"
# 4. yq原位修改：只写required_disk和options，且options为[内存, 硬盘]
yq -i "
  del(.server.required_memory) |
  .server.required_plan_code = \"$PLAN\" |
  .server.required_disk = \"$storage\" |
  .server.options = [\"$memory-$PLAN\", \"$storage-$PLAN\"]
" "$CONFIG_YAML"
echo "已写入并生效server段：required_plan_code=$PLAN，required_disk=$storage，options=[$memory-$PLAN, $storage-$PLAN]"
echo "以上为默认抢该机型全区指定硬盘款，你可能还需要定制config.yaml,比如用api获取带宽选项加入server.options，改动已有全局app选项，并重启ovhauto。"

systemctl restart ovhauto
EOL
chmod +x /root/init.sh

cat > /root/getplans.sh << 'EOL'
curl -s "https://eu.api.ovh.com/1.0/dedicated/server/datacenter/availabilities" \
| yq -p=json '.[].planCode' | grep '^26sk' | sort -u
EOL
chmod +x /root/getplans.sh


systemctl enable -q --now ovhauto


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
