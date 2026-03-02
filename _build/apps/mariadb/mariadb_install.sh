##################

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

echo "Installing MariaDB"
silent apt-get install -y mariadb-server
sed -i 's/^# *\(port *=.*\)/\1/' /etc/mysql/my.cnf
sed -i 's/^bind-address/#bind-address/g' /etc/mysql/mariadb.conf.d/50-server.cnf
echo "Installed MariaDB"

read -r -p "Would you like to add PhpMyAdmin? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  echo "Installing phpMyAdmin"
  silent apt-get install -y \
    apache2 \
    php \
    php-mysqli \
    php-mbstring \
    php-zip \
    php-gd \
    php-json \
    php-curl 
	
	wget -q "https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz"
	mkdir -p /var/www/html/phpMyAdmin
	tar xf phpMyAdmin-5.2.1-all-languages.tar.gz --strip-components=1 -C /var/www/html/phpMyAdmin
	cp /var/www/html/phpMyAdmin/config.sample.inc.php /var/www/html/phpMyAdmin/config.inc.php
	SECRET=$(openssl rand -base64 24)
	sed -i "s#\$cfg\['blowfish_secret'\] = '';#\$cfg['blowfish_secret'] = '${SECRET}';#" /var/www/html/phpMyAdmin/config.inc.php
	chmod 660 /var/www/html/phpMyAdmin/config.inc.php
	chown -R www-data:www-data /var/www/html/phpMyAdmin
	systemctl restart apache2
  echo "Installed phpMyAdmin"
fi

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############################
