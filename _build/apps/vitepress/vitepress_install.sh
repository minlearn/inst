###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get install -y git

wget --no-check-certificate https://nodejs.org/dist/v18.20.5/node-v18.20.5-linux-x64.tar.gz -O /tmp/node.tar.gz
tar xzvf /tmp/node.tar.gz --exclude CHANGELOG.md --exclude LICENSE --exclude README.md  -C /usr/local --strip-components=1
rm -rf /tmp/node.tar.gz
npm install -g vitepress@1.6.4 pm2

cat > /root/start.sh << 'EOL'
cd /root
# create vitepress project
# npm create vitepress vitepress-dev --yes

# use self-write manner instead
mkdir vitepress-dev
cat > vitepress-dev/package.json <<'EOF'
{
  "name": "vitepress-dev",
  "type": "module",
  "scripts": {
    "dev": "vitepress dev docs",
    "build": "vitepress build docs",
    "preview": "vitepress preview docs"
  },
  "devDependencies": {
    "vitepress": "^1.6.4",
    "vue": "^3.5.0"
  }
}
EOF
mkdir -p vitepress-dev/docs/.vitepress
cat > vitepress-dev/docs/index.md <<'EOF'
# Hello VitePress
EOF
cat > vitepress-dev/docs/.vitepress/config.js <<'EOF'
import { defineConfig } from 'vitepress'
export default defineConfig({
  title: "vitepress demo",
  vite: {
    server: { host: "0.0.0.0" }
  }
})
EOF

cd vitepress-dev
npm install

pm2 start npm --cwd /root/vitepress-dev --name "vitepress-dev" -- run dev
pm2 save
STARTUP_CMD=$(pm2 startup | grep sudo)
if [ -n "$STARTUP_CMD" ]; then eval $STARTUP_CMD; fi
pm2 save
EOL
chmod +x /root/start.sh

echo "use pm2 logs vitepress-dev to check log"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
