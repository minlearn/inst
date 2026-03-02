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
wget --no-check-certificate $rlsmirror/tm.tar.gz -O download/tm.tar.gz

echo "Installing tm"
mkdir -p /usr/lib/x86_64-linux-musl
tar -xzvf download/tm.tar.gz -C /usr/lib/x86_64-linux-musl tm/app/usrlibx86_64-linux-musl/{libz.so.1,libstdc++.so.6,libssl.so.1.1,libgcc_s.so.1,libcrypto.so.1.1} --strip-components=3
tar -xzvf download/tm.tar.gz -C /lib tm/app/lib/ld-musl-x86_64.so.1 --strip-components=3
tar -xzvf download/tm.tar.gz -C /etc tm/app/etc/ld-musl-x86_64.path --strip-components=3
tar -xzvf download/tm.tar.gz -C /usr/local/bin tm/app/Cli --strip-components=2
echo "Installed tm"

cat > /lib/systemd/system/tm.service << 'EOL'
[Unit]
Description=this is Traffmonetizer service,please bash /root/token.sh to change the token
After=network.target nss-lookup.target
Wants=network.target nss-lookup.target
Requires=network.target nss-lookup.target

[Service]
Environment="DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true"
Environment="DOTNET_CLI_TELEMETRY_OPTOUT=1"
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=/bin/bash -c "PATH=/usr/local/bin:$PATH exec /usr/local/bin/Cli start accept --token xxxxxxxxxxxxxxxx --device-name amd-$$[RANDOM%%65535]"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

cat > /root/token.sh << 'EOL'
read -p "give a token:" token </dev/tty
sed -i "s#xxxxxxxxxxxxxxxx#${token}#g" /lib/systemd/system/tm.service
systemctl daemon-reload
systemctl restart tm
EOL
chmod +x /root/token.sh

systemctl enable -q --now tm


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
