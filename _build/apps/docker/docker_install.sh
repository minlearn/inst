###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc  iptables
echo "Installed Dependencies"

arch=$([[ "$(arch)" == "aarch64" ]] && echo _arm64)
rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}

#pefer offline docker setup
wget -q $rlsmirror/docker-24.0.7$arch.tgz -O /tmp/docker-24.0.7.tgz
tar --warning=no-timestamp -xzf /tmp/docker-24.0.7.tgz -C /usr/bin --strip-components=1
mkdir -p /etc/docker
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
if [ ! -f /etc/systemd/system/docker.service ]; then
  cat >/etc/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
After=network.target
[Service]
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF
fi
systemctl enable -q --now docker

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}

#DOCKER_LATEST_VERSION=$(get_latest_release "moby/moby")
#echo "Installing Docker $DOCKER_LATEST_VERSION"
#DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
#mkdir -p $(dirname $DOCKER_CONFIG_PATH)
#echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
#silent sh <(curl -sSL https://get.docker.com)
#systemctl enable -q --now docker
#echo "Installed Docker $DOCKER_LATEST_VERSION"

read -r -p "Would you like to add docker composer? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  DOCKER_COMPOSE_LATEST_VERSION=$(get_latest_release "docker/compose")
  echo "Installing Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
  curl -sSL https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_LATEST_VERSION/docker-compose-linux-aarch64 -o /usr/bin/docker-compose
  chmod +x /usr/bin/docker-compose
  echo "Installed Docker Compose $DOCKER_COMPOSE_LATEST_VERSION"
fi

read -r -p "Would you like to add Portainer? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  PORTAINER_LATEST_VERSION=$(get_latest_release "portainer/portainer")
  echo "Installing Portainer $PORTAINER_LATEST_VERSION"
  docker volume create portainer_data >/dev/null
  silent docker run -d \
    -p 8000:8000 \
    -p 9443:9443 \
    --name=portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  echo "Installed Portainer $PORTAINER_LATEST_VERSION"
else
  read -r -p "Would you like to add the Portainer Agent? <y/N> " prompt </dev/tty
  if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
    PORTAINER_AGENT_LATEST_VERSION=$(get_latest_release "portainer/agent")
    echo "Installing Portainer agent $PORTAINER_AGENT_LATEST_VERSION"
    silent docker run -d \
      -p 9001:9001 \
      --name portainer_agent \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v /var/lib/docker/volumes:/var/lib/docker/volumes \
      portainer/agent
    echo "Installed Portainer Agent $PORTAINER_AGENT_LATEST_VERSION"
  fi
fi

cat > /root/init.sh << 'EOL'
if [[ -n $1 ]]; then
  docker stop `docker ps -a -q  --filter ancestor=$1` && docker rm `docker ps -a -q  --filter ancestor=$1`
  for i in `seq 1 10`; do sleep 5 && docker run -d --restart=always $1;done
fi
EOL
chmod +x /root/init.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"