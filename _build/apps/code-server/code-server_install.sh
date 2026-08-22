############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl git
echo "Installed Dependencies"

VERSION=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest |
    grep "tag_name" |
    awk '{print substr($2, 3, length($2)-4) }')

echo "Installing Code-Server v${VERSION}"
curl -fOL https://github.com/coder/code-server/releases/download/v$VERSION/code-server_${VERSION}_amd64.deb &>/dev/null
dpkg -i code-server_${VERSION}_amd64.deb &>/dev/null
rm -rf code-server_${VERSION}_amd64.deb
mkdir -p ~/.config/code-server/
systemctl enable -q --now code-server@$USER
cat <<EOF >~/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8680
auth: none
password: 
cert: false
EOF
systemctl restart code-server@$USER
echo "Installed Code-Server v${VERSION} on $hostname"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############
