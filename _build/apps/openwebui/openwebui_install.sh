###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y \
  curl \
  sudo \
  mc \
  gpg \
  git \
  ffmpeg
echo "Installed Dependencies"

echo "Installing python3"
silent apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libbz2-dev
wget https://www.sqlite.org/2021/sqlite-autoconf-3350100.tar.gz
tar xzf sqlite-autoconf-3350100.tar.gz
cd sqlite-autoconf-3350100
silent ./configure
silent make
silent make install
cd ..
rm -rf sqlite-autoconf-3350100 sqlite-autoconf-3350100.tar.gz
wget https://www.python.org/ftp/python/3.11.1/Python-3.11.1.tgz
tar -xf Python-3.11.1.tgz
cd Python-3.11.1
silent ./configure --enable-optimizations
silent make
silent make install
cd ..
rm -rf Python-3.11.1 Python-3.11.1.tgz
echo "Installed python3"

echo "Installing Python3 Dependencies"
silent apt-get install -y --no-install-recommends \
  python3 \
  python3-pip
echo "Installed Python3 Dependencies"

echo "Setting up Node.js Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
echo "Set up Node.js Repository"

echo "Installing Node.js"
silent apt-get update
silent apt-get install -y nodejs
echo "Installed Node.js"

echo "Installing Open WebUI (Patience)"
silent git clone https://github.com/open-webui/open-webui.git /opt/open-webui
cd /opt/open-webui/backend
silent pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
silent pip3 install -r requirements.txt -U
cd /opt/open-webui
cp .env.example .env
cat <<EOF >/opt/open-webui/.env
ENV=prod
ENABLE_OLLAMA_API=false
OLLAMA_BASE_URL=http://0.0.0.0:11434
EOF
silent npm install
export NODE_OPTIONS="--max-old-space-size=3584"
silent npm run build
echo "Installed Open WebUI"

read -r -p "Would you like to add Ollama? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  echo "Installing Ollama"
  curl -fsSLO https://ollama.com/download/ollama-linux-amd64.tgz
  tar -C /usr -xzf ollama-linux-amd64.tgz
  rm -rf ollama-linux-amd64.tgz
  cat <<EOF >/etc/systemd/system/ollama.service
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=exec
ExecStart=/usr/bin/ollama serve
Environment=HOME=$HOME
Environment=OLLAMA_HOST=0.0.0.0
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable -q --now ollama.service
  sed -i 's/ENABLE_OLLAMA_API=false/ENABLE_OLLAMA_API=true/g' /opt/open-webui/.env
  echo "Installed Ollama"
fi

echo "Creating Service"
cat <<EOF >/etc/systemd/system/open-webui.service
[Unit]
Description=Open WebUI Service
After=network.target

[Service]
Type=exec
WorkingDirectory=/opt/open-webui
EnvironmentFile=/opt/open-webui/.env
ExecStart=/opt/open-webui/backend/start.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now open-webui.service
echo "Created Service"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
