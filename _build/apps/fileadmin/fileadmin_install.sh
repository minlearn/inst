###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

echo "Installing Nginx and PHP..."
silent apt-get install nginx php-fpm apache2-utils -y

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}

# Install fileadmin
echo "Installing fileadmin..."
rm -rf /var/www/html/*
wget --no-check-certificate $rlsmirror/fileadmin825.php -O /var/www/html/index.php
chown -R www-data:www-data /var/www/html

sed -i '/^\s*index\s/ s/;$/ index.php;/' /etc/nginx/sites-enabled/default
sed -i ':a;N;$!ba;s/\n}/\
    client_max_body_size 100M; \
    location ~ \.php$ {\
        include snippets\/fastcgi-php.conf;\
        fastcgi_pass unix:\/run\/php\/php-fpm.sock;\
    }\n}/' /etc/nginx/sites-enabled/default

ver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION."\n";')
file=/etc/php/${ver}/fpm/php.ini

grep -q '^upload_max_filesize' "$file" \
  && sed -i 's/^upload_max_filesize\s*=.*/upload_max_filesize = 100M/' "$file" \
  || sed -i '/^file_uploads\s*=.*/a upload_max_filesize = 100M' "$file"
grep -q '^post_max_size' "$file" \
  && sed -i 's/^post_max_size\s*=.*/post_max_size = 100M/' "$file" \
  || sed -i '/^file_uploads\s*=.*/a post_max_size = 100M' "$file"
grep -q '^max_file_uploads' "$file" \
  && sed -i 's/^max_file_uploads\s*=.*/max_file_uploads = 100/' "$file" \
  || sed -i '/^file_uploads\s*=.*/a max_file_uploads = 100' "$file"
sed -i 's/^file_uploads\s*=.*/file_uploads = On/' "$file"

systemctl restart nginx php${ver}-fpm

cat > /root/pw.sh << 'EOL'
read -p "give a pw:" pw </dev/tty
SECRET=$(htpasswd -bnBC 10 "" $pw | cut -d: -f2 | sed 's/^\$2b\$/\$2y\$/')
sed -i "s|^\$PASSWORD = '.*'|\$PASSWORD = '$SECRET'|g" /var/www/html/index.php
EOL
chmod +x /root/pw.sh

echo "fileadmin installation completed successfully! default password 123456"
echo "You can access fileadmin at: http://${DOMAIN_OR_IP}/index.php"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
