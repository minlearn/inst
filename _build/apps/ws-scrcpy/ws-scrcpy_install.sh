###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get install -y python3 git build-essential make adb

wget --no-check-certificate https://nodejs.org/dist/v18.20.5/node-v18.20.5-linux-x64.tar.gz -O /tmp/node.tar.gz
tar xzvf /tmp/node.tar.gz --exclude CHANGELOG.md --exclude LICENSE --exclude README.md  -C /usr/local --strip-components=1
rm -rf /tmp/node.tar.gz

cat > /root/start.sh << 'EOL'
cd /root

git clone https://github.com/NetrisTV/ws-scrcpy.git
cd ws-scrcpy

sed -i "s/server.listen(port, () => {/server.listen(port, \"0.0.0.0\", () => {/g" src/server/services/HttpServer.ts
npm install
npm run dist:prod

npm install -g pm2
pm2 start /root/ws-scrcpy/dist/index.js
pm2 save
STARTUP_CMD=$(pm2 startup | grep sudo)
if [ -n "$STARTUP_CMD" ]; then eval $STARTUP_CMD; fi
pm2 save
EOL
chmod +x /root/start.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
