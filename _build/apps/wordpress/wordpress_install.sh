###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

WORDPRESS_DIR=/var/www/wordpress

# Install Apache, PHP, and necessary PHP extensions
echo "Installing Apache and PHP..."
silent apt-get install apache2 libapache2-mod-php php-gd php-sqlite3 php-mysql php-mbstring php-xml php-zip -y

# Enable Apache mods
a2enmod rewrite

# Install Wordpress
echo "Installing Wordpress..."
mkdir -p ${WORDPRESS_DIR}
cd ${WORDPRESS_DIR}/..
wget https://wordpress.org/latest.tar.gz -O latest.tar.gz
tar -xzf latest.tar.gz -C ${WORDPRESS_DIR} --strip-components=1
rm latest.tar.gz
chown -R www-data:www-data ${WORDPRESS_DIR}

# Configure Apache to serve Wordpress
echo "Configuring Apache..."
WORDPRESS_CONF="/etc/apache2/sites-available/wordpress.conf"
echo "<VirtualHost *:80>
     ServerName localhost:80
     DocumentRoot ${WORDPRESS_DIR}
     <Directory ${WORDPRESS_DIR}/>
          Options FollowSymlinks
          AllowOverride All
          Require all granted
     </Directory>
    
     <Directory ${WORDPRESS_DIR}/>
            RewriteEngine on
            RewriteBase /
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteRule ^(.*) index.php [PT,L]
    </Directory>
</VirtualHost>" | sudo tee $WORDPRESS_CONF


a2ensite wordpress.conf
a2dissite 000-default.conf
systemctl restart apache2

echo "Wordpress installation completed successfully!"
echo "You can access Wordpress at: http://${DOMAIN_OR_IP}/"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
