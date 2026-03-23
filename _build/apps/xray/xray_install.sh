###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc qrencode jq
echo "Installed Dependencies"

cd /root

arch=$([[ "$(arch)" == "aarch64" ]] && echo _arm64)
rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
[[ ! -f download/tmp.tar.gz ]] && wget --no-check-certificate $rlsmirror/xray$arch.tar.gz -O download/tmp.tar.gz

mkdir -p app/xray
tar -xzvf download/tmp.tar.gz -C app/xray xray --strip-components=1

cat > /lib/systemd/system/xray.service << 'EOL'
[Unit]
Description=this is xray service,please change the token then daemon-reload it
After=network.target nss-lookup.target
Wants=network.target nss-lookup.target
Requires=network.target nss-lookup.target

[Service]
Type=simple
ExecStartPre=/bin/bash -c "date=$$(echo -n $$(ip addr |grep $$(ip route show |grep -o 'default via [0-9]\\{1,3\\}.[0-9]\\{1,3\\}.[0-9]\\{1,3\\}.[0-9]\\{1,3\\}.*' |head -n1 |sed 's/proto.*\\|onlink.*//g' |awk '{print $$NF}') |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\\{1,3\\}.[0-9]\\{1,3\\}.[0-9]\\{1,3\\}.[0-9]\\{1,3\\}/[0-9]\\{1,2\\}') |cut -d'/' -f1);PATH=/usr/local/bin:$PATH exec sed -i s/xxx.xxxxxx.com/$${date}/g /root/app/xray/config.yaml"
ExecStart=/root/app/xray/xray -c /root/app/xray/config.yaml
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOL

cat > /root/app/xray/config.yaml << 'EOL'
{
  "log": null,
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "port": "443",
        "network": "udp",
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "domain": [
          "www.gstatic.com"
        ],
        "outboundTag": "direct"
      },
      {
        "ip": [
          "geoip:cn"
        ],
        "outboundTag": "blocked",
        "type": "field"
      },
      {
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ],
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "vps-outbound-v4",
        "domain": [
          "api.myip.com"
        ]
      },
      {
        "type": "field",
        "outboundTag": "vps-outbound-v6",
        "domain": [
          "api64.ipify.org"
        ]
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "network": "udp,tcp"
      }
    ]
  },
  "dns": null,
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 62789,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "streamSettings": null,
      "tag": "api",
      "sniffing": null
    },
    {
      "listen": null,
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "xxxxxxxxxxxxxxxxx",
            "flow": ""
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "serverName": "localhost",
          "rejectUnknownSni": false,
          "minVersion": "1.2",
          "maxVersion": "1.3",
          "cipherSuites": "",
          "certificates": [
            {
              "ocspStapling": 3600,
              "certificateFile": "/root/app/xray/certs/localhost.crt",
              "keyFile": "/root/app/xray/certs/localhost.key"
            }
          ],
          "alpn": [
            "http/1.1",
            "h2"
          ],
          "settings": [
            {
              "allowInsecure": false,
              "fingerprint": "",
              "serverName": ""
            }
          ]
        },
        "wsSettings": {
          "path": "/mywebsocket",
          "headers": {
            "Host": "xxx.xxxxxx.com"
          }
        }
      },
      "tag": "inbound-443",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "blackhole",
      "tag": "blocked"
    },
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4v6"
      }
    },
    {
      "tag": "vps-outbound-v4",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4v6"
      }
    },
    {
      "tag": "vps-outbound-v6",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv6v4"
      }
    }
  ],
  "transport": null,
  "policy": {
    "system": {
      "statsInboundDownlink": true,
      "statsInboundUplink": true
    },
    "levels": {
      "0": {
        "handshake": 10,
        "connIdle": 100,
        "uplinkOnly": 2,
        "downlinkOnly": 3,
        "bufferSize": 10240
      }
    }
  },
  "api": {
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ],
    "tag": "api"
  },
  "stats": {},
  "reverse": null,
  "fakeDns": null
}
EOL

cat > /root/token.sh << 'EOL'
read -p "give a uuid:" token </dev/tty
sed -i s#xxxxxxxxxxxxxxxxx#${token}#g /root/app/xray/config.yaml
systemctl restart xray
EOL
chmod +x /root/token.sh

cat > /root/ip.sh << 'EOL'
read -p "give a ip:" ip </dev/tty
date=$(echo -n $(ip addr |grep $(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}') |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}') |cut -d'/' -f1)
sed -i s#${date}#${ip}#g /root/app/xray/config.yaml
systemctl restart xray
EOL
chmod +x /root/ip.sh

cat > /root/client.sh << 'EOL'
echo "标准proxies节点（无配置头无规则）:"
jq -r '
  .inbounds[]
  | select(.protocol=="vless")
  | "  - {name: \"" +
      (.streamSettings.tlsSettings.serverName // .streamSettings.wsSettings.headers.Host // "yourip") +
      "\", server: \"" + 
      (.streamSettings.tlsSettings.serverName // .streamSettings.wsSettings.headers.Host // "yourip") +
      "\", port: " + (.port|tostring) +
      ", client-fingerprint: chrome" +
      ", type: vless" +
      ", uuid: " + (.settings.clients[0].id|@sh) +
      ", tls: true, tfo: false, skip-cert-verify: true, network: ws" +
      ", ws-opts: {path: " + (.streamSettings.wsSettings.path|@sh) +
      ", headers: {Host: " + (.streamSettings.wsSettings.headers.Host|@sh) +
      "}}}"
' /root/app/xray/config.yaml
VLESSURL=$(jq -r '
  .inbounds[]
  | select(.protocol=="vless")
  | "vless://" + .settings.clients[0].id + "@" +
    (.streamSettings.tlsSettings.serverName // .streamSettings.wsSettings.headers.Host // "yourip") +
    ":" + (.port|tostring) +
    "?encryption=none&security=tls&type=ws&host=" +
    (.streamSettings.wsSettings.headers.Host) +
    "&path=" + (.streamSettings.wsSettings.path|@uri) +
    "#"+ (.streamSettings.tlsSettings.serverName // .streamSettings.wsSettings.headers.Host // "yourip")
' /root/app/xray/config.yaml)
echo "$VLESSURL" > /root/sub.txt
qrencode -m 2 -t ANSIUTF8 $VLESSURL >> /root/sub.txt
echo ""
echo "标准vless订阅url:" $VLESSURL 
echo "订阅信息及二维码已保存到sub.txt，可用进一步用subconverter等处理"
echo "客户端连接时建议勾选skip-cert-verify之类开关"
EOL
chmod +x /root/client.sh

systemctl enable -q --now xray


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
