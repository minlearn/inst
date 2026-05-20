
if [[ ! -f /usr/share/keyrings/mysql.gpg ]]; then echo "No ${APP} Installation Found!"; exit; fi
echo "Updating ${APP} LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
echo "Updated Successfully"


