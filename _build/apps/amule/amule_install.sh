###############################

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get install -y amule amule-daemon

echo "Installing amule"
cat <<EOF >/etc/systemd/system/amule.service
[Unit]
Description=amule download service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/amuled
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now amule
echo "Installed amule"

# echo -n "123" | md5sum
# 202cb962ac59075b964b07152d234b70
sed -e 's/AcceptExternalConnections=0/AcceptExternalConnections=1/g' \
    -e 's/ECPassword=/ECPassword=202cb962ac59075b964b07152d234b70/g' \
    -e 's/ECAddress=/ECAddress=0.0.0.0/g' \
    -i /root/.aMule/amule.conf
systemctl restart amule

# ed2k://|file|cn_windows_server_2012_r2_with_update_x64_dvd_6052725.iso|5545705472|121EC13B53882E501C1438237E70810D|/
cat > /root/download.sh << 'EOL'
read -p "give a ed2k link:" link </dev/tty
amulecmd -h 127.0.0.1 -p 4712 -P '123' -c "add $link"
EOL
chmod +x /root/download.sh

cat > /root/viewdl.sh << 'EOL'
amulecmd -h 127.0.0.1 -p 4712 -P '123' -c "show dl"
EOL
chmod +x /root/viewdl.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############################
