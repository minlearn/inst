###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

get_latest_release() {
  curl -sL https://api.github.com/repos/$1/releases/latest | grep '"tag_name":' | cut -d'"' -f4
}
DOCKER_LATEST_VERSION=$(get_latest_release "moby/moby")

echo "Installing Docker $DOCKER_LATEST_VERSION"
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p $(dirname $DOCKER_CONFIG_PATH)
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
silent sh <(curl -sSL https://get.docker.com)
echo "Installed Docker $DOCKER_LATEST_VERSION"

for i in ashmem:61 binder:60 hwbinder:59 vndbinder:58;do
  if [ ! -e /dev/${i%%:*} ]; then
    mknod /dev/${i%%:*} c 10 ${i##*:}
    chmod 777 /dev/${i%%:*}
    #chown root:${i%%:*} /dev/${i%%:*}
  fi
done

silent apt-get install -y lxc skopeo umoci

#lxc-create -n redroid11 -t oci -- -u docker://docker.io/redroid/redroid:11.0.0-latest
echo "Installing android"
cd /root

silent skopeo copy docker://docker.io/redroid/redroid:11.0.0-latest  oci:redroid:11.0.0-latest
silent umoci unpack --image redroid:11.0.0-latest bundle
rm -rf redroid
wget https://github.com/saltstack/salt/raw/refs/heads/develop/salt/templates/lxc/salt_tarball -O /usr/share/lxc/templates/lxc-salt_tarball
chmod +x /usr/share/lxc/templates/lxc-salt_tarball
sed -e 's/lxc.utsname/lxc.uts.name/g' -e 's/lxc.rootfs/lxc.rootfs.path/g' -e 's/SIGHUP\ SIGINT\ SIGTERM/HUP INT TERM/g' -e 's/tar\ xvf\ \${imgtar}\ -C\ "\${path}"/tar xf \${imgtar} -C "\${path}\/rootfs"/g' -i /usr/share/lxc/templates/lxc-salt_tarball
rm -rf /var/lib/lxc/redroid11
tar -C ./bundle/rootfs -cp . | lxc-create -n redroid11 -t salt_tarball -- --network_link lxcbr0 --imgtar -

mkdir /root/data-redroid11
sed -i '/lxc.include/d' /var/lib/lxc/redroid11/config
<<EOF cat >> /var/lib/lxc/redroid11/config
### hacked
lxc.init.cmd = /init androidboot.hardware=redroid androidboot.redroid_gpu_mode=guest
lxc.apparmor.profile = unconfined
lxc.autodev = 1
lxc.autodev.tmpfs.size = 25000000
lxc.mount.entry = /root/data-redroid11 data none bind 0 0
EOF
rm /var/lib/lxc/redroid11/rootfs/vendor/bin/ipconfigstore
echo "Installed android"

echo 'lxc-start -l debug -o redroid11.log -n redroid11' > start.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
