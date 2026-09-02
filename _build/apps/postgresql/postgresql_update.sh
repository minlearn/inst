
if [[ ! -f /etc/apt/sources.list.d/pgdg.list ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
echo "Updating ${APP} LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
echo "Updated Successfully"

