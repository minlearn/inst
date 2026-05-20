
#############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg
echo "Installed Dependencies"

echo "Setting up PostgreSQL Repository"
VERSION="$(awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release)"
echo "deb http://apt.postgresql.org/pub/repos/apt ${VERSION}-pgdg main" >/etc/apt/sources.list.d/pgdg.list
curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor --output /etc/apt/trusted.gpg.d/postgresql.gpg
echo "Setup PostgreSQL Repository"

echo "Installing PostgreSQL"
silent apt-get update
silent apt-get install -y postgresql-17 # postgresql/postgresql-18/...

cat <<EOF >/etc/postgresql/17/main/pg_hba.conf
# PostgreSQL Client Authentication Configuration File
local   all             postgres                                peer
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all             all                                     md5
# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             10.10.10.0/24           md5
# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256
#host    all             all             0.0.0.0/0              md5
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
# remote forbidden
# host    all             all             0.0.0.0/0             reject
# host    all             all             ::1/128               reject
EOF

cat <<EOF >/etc/postgresql/17/main/postgresql.conf
# -----------------------------
# PostgreSQL configuration file
# -----------------------------

#------------------------------------------------------------------------------
# FILE LOCATIONS
#------------------------------------------------------------------------------

data_directory = '/var/lib/postgresql/17/main'       
hba_file = '/etc/postgresql/17/main/pg_hba.conf'     
ident_file = '/etc/postgresql/17/main/pg_ident.conf'   
external_pid_file = '/var/run/postgresql/17-main.pid'                   

#------------------------------------------------------------------------------
# CONNECTIONS AND AUTHENTICATION
#------------------------------------------------------------------------------

# - Connection Settings -

listen_addresses = '*'                 
port = 5432                             
max_connections = 100                  
unix_socket_directories = '/var/run/postgresql' 

# - SSL -

ssl = on
ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'

#------------------------------------------------------------------------------
# RESOURCE USAGE (except WAL)
#------------------------------------------------------------------------------

shared_buffers = 128MB                
dynamic_shared_memory_type = posix      

#------------------------------------------------------------------------------
# WRITE-AHEAD LOG
#------------------------------------------------------------------------------

max_wal_size = 1GB
min_wal_size = 80MB

#------------------------------------------------------------------------------
# REPORTING AND LOGGING
#------------------------------------------------------------------------------

# - What to Log -

log_line_prefix = '%m [%p] %q%u@%d '           
log_timezone = 'Etc/UTC'

#------------------------------------------------------------------------------
# PROCESS TITLE
#------------------------------------------------------------------------------

cluster_name = '17/main'                

#------------------------------------------------------------------------------
# CLIENT CONNECTION DEFAULTS
#------------------------------------------------------------------------------

# - Locale and Formatting -

datestyle = 'iso, mdy'
timezone = 'Etc/UTC'
lc_messages = 'C'                      
lc_monetary = 'C'                       
lc_numeric = 'C'                        
lc_time = 'C'                           
default_text_search_config = 'pg_catalog.english'

#------------------------------------------------------------------------------
# CONFIG FILE INCLUDES
#------------------------------------------------------------------------------

include_dir = 'conf.d'                  
EOF

sudo systemctl restart postgresql
echo "Installed PostgreSQL"


ADMIN_PASS="$(openssl rand -base64 18 | cut -c1-13)"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${ADMIN_PASS}';"
if [ $? -ne 0 ]; then
  echo "Failed to set PostgreSQL password."
  exit 1
fi
echo -e "PostgreSQL user: postgres" > ~/postgresql.creds
echo -e "PostgreSQL password: $ADMIN_PASS" >> ~/postgresql.creds

read -r -p "Would you like to add Adminer? <y/N> " prompt </dev/tty
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
  echo "Installing Adminer"
  silent apt install -y adminer
  a2enconf adminer
  systemctl reload apache2
  echo "Installed Adminer"
fi

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

#############
