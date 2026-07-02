###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

ver=$(curl -L -H "Accept: application/vnd.github+json"    -H "X-GitHub-Api-Version: 2022-11-28"  https://api.github.com/repos/golang/go/git/refs/tags|grep "\"ref\": \"refs/tags/go"|tail -n 1|sed -n 's/.*\go\(.*\)\",.*/\1/p')
wget --no-check-certificate https://go.dev/dl/go$ver.linux-amd64.tar.gz -O /tmp/tmp.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/tmp.tar.gz
rm -rf /tmp/tmp.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.profile
source /root/.profile

go version

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
