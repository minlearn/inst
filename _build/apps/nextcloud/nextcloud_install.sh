###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

NEXTCLOUD_DIR=/var/www/nextcloud

# Install Apache, PHP, and necessary PHP extensions
echo "Installing Apache and PHP..."
silent apt install apache2 libapache2-mod-php php-gd php-json php-sqlite3 php-mysql php-curl php-mbstring php-intl php-imagick php-xml php-zip -y

# Enable Apache mods
a2enmod rewrite headers env dir mime



# Install Nextcloud
echo "Installing Nextcloud..."
mkdir -p ${NEXTCLOUD_DIR}
cd ${NEXTCLOUD_DIR}/..
# php7.4 supports most to nextcloud-25
wget https://download.nextcloud.com/server/releases/latest-25.tar.bz2 -O latest.tar.bz2
tar -xjf latest.tar.bz2 -C ${NEXTCLOUD_DIR} --strip-components=1
rm latest.tar.bz2
chown -R www-data:www-data ${NEXTCLOUD_DIR}
for repo in jimmyl0l3c/cfg_share_links danth/transfer;do
  app=${repo##*/}
  ver=v$(curl -s https://api.github.com/repos/${repo}/releases/latest | grep "tag_name" | cut -d\" -f4 | sed -e "s|v||g")
  wget -qO- https://github.com/${repo}/releases/download/${ver}/${app}.tar.gz | tar -xz -C ${NEXTCLOUD_DIR}/apps
#  sudo -u www-data php ${NEXTCLOUD_DIR}/occ app:enable ${app}
done

# Configure Apache to serve Nextcloud
echo "Configuring Apache..."
NEXTCLOUD_CONF="/etc/apache2/sites-available/nextcloud.conf"
echo "<VirtualHost *:80>
    ServerName localhost:80
    DocumentRoot ${NEXTCLOUD_DIR}
    <Directory ${NEXTCLOUD_DIR}/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews

        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>
</VirtualHost>" | tee $NEXTCLOUD_CONF

a2ensite nextcloud.conf

read -r -p "Would you like to disable the 000-default site? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  a2dissite 000-default.conf
fi

systemctl restart apache2

echo "Nextcloud installation completed successfully!"
echo "You can access Nextcloud at: http://${DOMAIN_OR_IP}/"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
