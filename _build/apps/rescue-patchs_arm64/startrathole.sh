echo -e "[client]\nremote_addr = \"$1:2333\"\ndefault_token = \"default_token_if_not_specify\"\nheartbeat_timeout = 30\nretry_interval = 3\n[client.services.80]\nlocal_addr = \"127.0.0.1:80\"\n[client.services.22]\nlocal_addr = \"127.0.0.1:22\"\n[client.services.8000]\nlocal_addr = \"127.0.0.1:8000\"" > /etc/rathole.toml
screen -dmS rathole /bin/rathole /etc/rathole.toml
