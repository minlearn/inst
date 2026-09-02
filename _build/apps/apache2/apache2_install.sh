###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get install -y apache2 apache2-utils

mkdir -p /var/www/html/downloads
chown -R www-data:www-data /var/www/html/downloads
chmod 755 /var/www/html/downloads
htpasswd -cb /etc/apache2/.htpasswd "root" "$(openssl rand -base64 3)"
chown root:"www-data" /etc/apache2/.htpasswd
chmod 640 /etc/apache2/.htpasswd


# Configure Apache to serve dir listing
echo "Configuring Apache..."
CONF="/etc/apache2/sites-available/dirlist.conf"
echo "<VirtualHost *:80>
    ServerName localhost:80
    DocumentRoot /var/www/html/downloads

    # downloads 目录索引 + 基本认证
    <Directory /var/www/html/downloads/>
        Options Indexes FollowSymLinks
        AllowOverride None

        # 基本认证配置
        AuthType Basic
        AuthName \"Restricted Downloads\"
        AuthUserFile /etc/apache2/.htpasswd
        Require valid-user
        # 美化目录列表，隐藏某些文件类型（只是隐藏，不阻止直接访问）
        IndexOptions FancyIndexing HTMLTable Charset=UTF-8 SuppressDescription SuppressHTMLPreamble
        IndexIgnore *.php *.env *.log

    </Directory>
</VirtualHost>" | tee $CONF

a2dissite 000-default.conf
a2enmod auth_basic authn_file autoindex
a2ensite dirlist.conf
systemctl restart apache2
echo "Configuring Apache Done..."


cat > /root/pw.sh << 'EOL'
read -p "give a pw:" pw </dev/tty
if [ -n "$pw" ]; then
  htpasswd -b "/etc/apache2/.htpasswd" "root" "$pw"
else
  htpasswd "/etc/apache2/.htpasswd" "root"
fi
EOL
chmod +x /root/pw.sh

echo "finished, please update the password for root user by running /root/pw.sh"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
