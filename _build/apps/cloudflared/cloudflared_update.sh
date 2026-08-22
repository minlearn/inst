
if [[ ! -d /var ]]; then echo "No ${APP} Installation Found!"; exit; fi
echo "Updating $APP LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
echo "Updated $APP LXC"


