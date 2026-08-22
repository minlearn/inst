###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc iptables
echo "Installed Dependencies"

silent apt-get install -y fuse3

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
if command -v docker >/dev/null 2>&1; then
  echo "Docker 已安装"
else
  echo "Docker 正在安装"
  wget -q $rlsmirror/docker-24.0.7.tgz -O /tmp/docker-24.0.7.tgz
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

  # docker-compose
  curl -sSL https://github.com/docker/compose/releases/download/2.5.0/docker-compose-linux-x86_64 -o /usr/bin/docker-compose
  chmod +x /usr/bin/docker-compose
fi

cd /root
mkdir -p download
wget --no-check-certificate $rlsmirror/kasm_release_1.16.0.a1d5b7.tar.gz -O download/kasm.tar.gz
wget --no-check-certificate https://kasm-static-content.s3.amazonaws.com/kasm_release_service_images_amd64_1.16.0.a1d5b7.tar.gz -O download/kasm_release_service_images.tar.gz
wget --no-check-certificate https://kasm-static-content.s3.amazonaws.com/kasm_release_workspace_images_amd64_1.16.0.a1d5b7.tar.gz -O download/kasm_release_workspace_images.tar.gz
wget --no-check-certificate https://kasm-static-content.s3.amazonaws.com/kasm_release_plugin_images_amd64_1.16.0.a1d5b7.tar.gz -O download/kasm_release_plugin_images.tar.gz
tar -zxvf download/kasm.tar.gz -C /root

cat <<EOF >/root/install.sh
docker stop `docker ps -a -q`
docker rm `docker ps -a -q`
# 临时放开socket所有读写权限（仅安装期间使用）
chmod 666 /var/run/docker.sock

cd /root
bash kasm_release/install.sh \
--accept-eula \
--role all \
--admin-password "Test123456" \
--user-password "User123456" \
--proxy-port 8443 \
--offline-service download/kasm_release_service_images.tar.gz \
--offline-workspaces download/kasm_release_workspace_images.tar.gz \
--offline-plugin download/kasm_release_plugin_images.tar.gz \
--install-depends \
--skip-v4l2loopback \
--skip-custom-rclone \
--skip-egress

# 恢复安全权限
chmod 660 /var/run/docker.sock
EOF
chmod +x /root/install.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
