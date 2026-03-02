##############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install sudo lsb-release curl gnupg mc -y
echo "Installed Dependencies"

RELEASE_REPO="mysql-5.6"
RELEASE_LSB="stretch"
# mysql5.7:
# RELEASE_AUTH="mysql_native_password"

echo "Installing MySQL"
curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql | gpg --dearmor  -o /usr/share/keyrings/mysql.gpg
# mysql5.7:
# curl -fsSL https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 | gpg --dearmor  -o /usr/share/keyrings/mysql.gpg
echo "deb [signed-by=/usr/share/keyrings/mysql.gpg] http://repo.mysql.com/apt/debian ${RELEASE_LSB} ${RELEASE_REPO}" >/etc/apt/sources.list.d/mysql.list
echo 'Acquire::AllowInsecureRepositories "true";' > /etc/apt/apt.conf.d/allow-insecure
echo 'Acquire::AllowDowngradeToInsecureRepositories "true";' >> /etc/apt/apt.conf.d/allow-insecure
silent apt-get update
export DEBIAN_FRONTEND=noninteractive
silent apt-get install -y --allow-unauthenticated \
  mysql-community-client=5.6.* \
  mysql-community-server=5.6.*
systemctl enable -q --now mysql
echo "Installed MySQL"

echo "Configure MySQL Server"
ADMIN_PASS="$(openssl rand -base64 18 | cut -c1-13)"
mysql -uroot -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$ADMIN_PASS'); FLUSH PRIVILEGES;"
mysql -uroot -p$ADMIN_PASS -e "CREATE USER 'root'@'10.10.10.%' IDENTIFIED BY '$ADMIN_PASS'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'10.10.10.%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
# mysql5.7:
# mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH $RELEASE_AUTH BY '$ADMIN_PASS'; FLUSH PRIVILEGES;"
# mysql -uroot -p$ADMIN_PASS -e "CREATE USER 'root'@'10.10.10.%' IDENTIFIED WITH $RELEASE_AUTH BY '$ADMIN_PASS'; GRANT ALL PRIVILEGES ON * . * TO 'root'@'10.10.10.%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
echo "" >~/mysql.creds
echo -e "MySQL user: root" >>~/mysql.creds
echo -e "MySQL password: $ADMIN_PASS" >>~/mysql.creds
echo "MySQL Server configured"

echo -e "[mysqld]\nbind-address = 0.0.0.0" >> /etc/mysql/my.cnf
systemctl restart mysql

read -r -p "Would you like to add PhpMyAdmin? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
  echo "deb https://packages.sury.org/php/ bullseye main" >> /etc/apt/sources.list
  silent apt-get install -y \
    apache2 \
    libapache2-mod-php5.6 \
    php5.6 \
    php5.6-mysql \
    php5.6-mbstring \
    php5.6-zip \
    php5.6-gd \
    php5.6-json

  echo "Installing phpMyAdmin"
	wget -q "https://files.phpmyadmin.net/phpMyAdmin/4.4.15/phpMyAdmin-4.4.15-all-languages.tar.gz"
	mkdir -p /var/www/html/phpmyadmin
	tar xf phpMyAdmin-4.4.15-all-languages.tar.gz --strip-components=1 -C /var/www/html/phpmyadmin
	cp /var/www/html/phpmyadmin/config.sample.inc.php /var/www/html/phpmyadmin/config.inc.php
	SECRET=$(openssl rand -base64 24)
	sed -i "s#\$cfg\['blowfish_secret'\] = '';#\$cfg['blowfish_secret'] = '${SECRET}';#" /var/www/html/phpmyadmin/config.inc.php
	chmod 660 /var/www/html/phpmyadmin/config.inc.php
	chown -R www-data:www-data /var/www/html/phpmyadmin
	a2ensite 000-default.conf
	systemctl restart apache2
  echo "Installed phpMyAdmin"
fi

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###########
