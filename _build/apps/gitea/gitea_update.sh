if [[  ! -f /usr/local/bin/gitea ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
RELEASE=$(wget -q https://github.com/go-gitea/gitea/releases/latest -O - | grep "title>Release" | cut -d " " -f 4 | sed 's/^v//')
echo "Updating $APP to ${RELEASE}"
wget -q https://github.com/go-gitea/gitea/releases/download/v$RELEASE/gitea-$RELEASE-linux-amd64
systemctl stop gitea
rm -rf /usr/local/bin/gitea 
mv gitea* /usr/local/bin/gitea
chmod +x /usr/local/bin/gitea
systemctl start gitea
echo "Updated $APP Successfully"