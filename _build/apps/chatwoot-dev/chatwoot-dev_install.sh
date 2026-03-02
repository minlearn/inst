###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg2
echo "Installed Dependencies"

silent apt-get install -y curl git procps postgresql-client libpq-dev
silent apt-get install -y build-essential autoconf bison libssl-dev libyaml-dev \
  libreadline-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev libgmp-dev \
  libdb-dev libsqlite3-dev sqlite3

curl -sL https://deb.nodesource.com/setup_16.x | bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
silent apt-get update -y
silent apt-get install nodejs yarn -y
gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
gpg2 --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
bash -lc 'curl -sSL https://get.rvm.io | bash -s stable'
[ -f /etc/profile.d/rvm.sh ] && source /etc/profile.d/rvm.sh || source "$HOME/.rvm/scripts/rvm"
rvm autolibs disable
rvm install "ruby-3.1.3"
rvm --default use "ruby-3.1.3"

cd /root
git clone https://github.com/chatwoot/chatwoot.git
cd chatwoot
git checkout b1ec67d11020ac52b74fa96af9803abdaa521509

cat > /root/compile.sh << 'EOL'
cd /root/chatwoot

[[ ! -f /usr/bin/mkdir ]] && ln -s /bin/mkdir /usr/bin/mkdir
bundle
sed -i '/"@chatwoot\/prosemirror-schema":/c\    "@chatwoot/prosemirror-schema": "https://github.com/chatwoot/prosemirror-schema.git#1735b80",' package.json
yarn
secret=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 63 ; echo '')
echo $secret > secret.tmp
export NODE_OPTIONS="--max-old-space-size=2048"
SECRET_KEY_BASE=$secret bundle exec rake assets:precompile RAILS_ENV=production
EOL

cat > /root/start.sh << 'EOL'
cd /root/chatwoot

# https://github.com/chatwoot/chatwoot/blob/master/deployment/setup_20.04.sh
if [ ! -f /root/inited ]; then
  secret=$(cat /root/chatwoot/secret.tmp)
  RAILS_ENV=production
  pg_pass="chatwoot"
  read -p "give a dbip(127.0.0.1,10.10.10.x,etc..):" ip
  read -p "give a dbpassword:" pw
  read -p "give a redis server ip:" rip

  cp .env.example .env
  sed -i "/SECRET_KEY_BASE/ s/=.*/=${secret}/" .env
  sed -i "/REDIS_URL/ s/=.*/=redis:\/\/${rip}:6379/" .env
  sed -i "/POSTGRES_HOST/ s/=.*/=${ip}/" .env
  sed -i "/POSTGRES_USERNAME/ s/=.*/=chatwoot/" .env
  sed -i "/POSTGRES_PASSWORD/ s/=.*/=${pg_pass}/" .env
  sed -i "/RAILS_ENV/ s/=.*/=${RAILS_ENV}/" .env
  echo -en "\nINSTALLATION_ENV=linux_script" >> ".env"

  PGPASSWORD="$pw" psql -h $ip -p 5432 -U postgres << EOF
    \set pass `echo $pg_pass`
    CREATE USER chatwoot CREATEDB;
    ALTER USER chatwoot PASSWORD :'pass';
    ALTER ROLE chatwoot SUPERUSER;
    UPDATE pg_database SET datistemplate = FALSE WHERE datname = 'template1';
    DROP DATABASE template1;
    CREATE DATABASE template1 WITH TEMPLATE = template0 ENCODING = 'UNICODE';
    UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template1';
    \c template1
    VACUUM FREEZE;
EOF
  touch /root/inited
fi

# https://github.com/chatwoot/chatwoot/blob/master/deployment/chatwoot-web.1.service
bin/rails server -p 3000 -e production
bundle exec rails db:chatwoot_prepare RAILS_ENV=production
# https://github.com/chatwoot/chatwoot/blob/master/deployment/chatwoot-worker.1.service
RAILS_ENV=production bundle exec sidekiq -C config/sidekiq.yml
EOL

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
