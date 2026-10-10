###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://archive.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main" > /etc/apt/sources.list # \ndeb ${debmirror}-security bullseye-security main

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y \
  curl \
  sudo \
  mc \
  gpg \
  git \
  systemd-timesyncd
echo "Installed Dependencies"

echo "Installing python3"
silent apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev
wget --no-check-certificate https://www.python.org/ftp/python/3.10.16/Python-3.10.16.tgz
tar -xf Python-3.10.16.tgz
cd Python-3.10.16
silent ./configure --enable-optimizations
silent make
silent make install
cd ..
rm -rf Python-3.10.16 Python-3.10.16.tgz
echo "Installed python3"

echo "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
echo "Set up Node.js Repository"

echo "Installing Node.js"
silent apt-get update
silent apt-get install -y nodejs
echo "Installed Node.js"

echo "Installing R20 Quantum Trader (Patience)"
silent git clone https://github.com/555cute/r20-quantum-trader.git /opt/r20-quantum-trader
cd /opt/r20-quantum-trader
sh deploy/install.sh
source .venv/bin/activate
cd /opt/r20-quantum-trader/frontend
silent npm install
silent npm run build
echo "Installed R20 Quantum Trader"

echo "Creating Service"
cat > /etc/systemd/system/r20-restore.service << 'EOF'
[Unit]
Description=R20 Quantum Trader Service

[Service]
Type=simple
WorkingDirectory=/opt/r20-quantum-trader
ExecStart=/bin/bash -c "cd /opt/r20-quantum-trader && source .venv/bin/activate && bash start.sh"
User=root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now r20-restore.service
echo "Created Service"

systemctl enable --now systemd-timesyncd
timedatectl set-ntp true

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
