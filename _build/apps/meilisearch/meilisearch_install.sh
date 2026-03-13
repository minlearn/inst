###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc jq
echo "Installed Dependencies"

cd /root

arch=$([[ "$(arch)" == "aarch64" ]] && echo aarch64||echo amd64)
mkdir -p download
wget --no-check-certificate https://github.com/meilisearch/meilisearch/releases/download/v1.13.2/meilisearch-linux-$arch -O download/meilisearch

mkdir -p app/meilisearch
cp -f download/meilisearch app/meilisearch/meilisearch
chmod +x app/meilisearch/meilisearch

echo -e "[Unit]\n\
Description=meilisearch service\n\
After=network.target\n\
\n\
[Service]\n\
Type=simple\n\
Restart=always\n\
RestartSec=1\n\
ExecStart=/root/app/meilisearch/meilisearch --http-addr=127.0.0.1:7700 --db-path=/root/app/meilisearch/data.ms --master-key=\"$(openssl rand -base64 32)\"\n\
\n\
[Install]\n\
WantedBy=multi-user.target" > /lib/systemd/system/meilisearch.service

cat > /root/setupclient.sh << 'EOLL'
silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

read -r -p "Would you like to add sample client? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  read -r -p "what will be the default index? <y/N> " index </dev/tty
  echo "Installing apache2"
  silent apt-get install -y apache2

  masterkey=`grep -oP '(?<=--master-key=")[^"]*' /lib/systemd/system/meilisearch.service`
  searchkey=$(curl -X GET "http://localhost:7700/keys" -H "Authorization: Bearer $masterkey" | jq -r '.results[] | select(.name=="Default Search API Key") | .key')
  cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@meilisearch/instant-meilisearch/templates/basic_search.css" />
  </head>
  <body>
    <div class="wrapper">
      <div id="searchbox" focus></div>
      <div id="hits"></div>
    </div>
  </body>
  <script src="https://cdn.jsdelivr.net/npm/@meilisearch/instant-meilisearch/dist/instant-meilisearch.umd.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/instantsearch.js@4"></script>
  <script>
    const search = instantsearch({
      indexName: "iamindex",
      searchClient: instantMeiliSearch(
        "http://localhost:7700",
        "iamsearchkey"
      ).searchClient
      });
      search.addWidgets([
        instantsearch.widgets.searchBox({
          container: "#searchbox"
        }),
        instantsearch.widgets.configure({ hitsPerPage: 8 }),
        instantsearch.widgets.hits({
          container: "#hits",
          templates: {
          item: `
            <div>
            <div class="hit-name">
                  {{#helpers.highlight}}{ "attribute": "title" }{{/helpers.highlight}}
            </div>
            </div>
          `
          }
        })
      ]);
      search.start();
  </script>
</html>
EOF
  sed -e "s/iamsearchkey/$searchkey/g" -e "s/iamindex/$index/g" -i /var/www/html/index.html
  a2ensite 000-default.conf
  systemctl restart apache2
  echo "Installed apache2"
fi

EOLL
chmod +x /root/setupclient.sh

cat > /root/getkeys.sh << 'EOL'
masterkey=$(grep -oP '(?<=--master-key=")[^"]*' /lib/systemd/system/meilisearch.service)
echo "masterkey: $masterkey"

curl_response=$(curl -s -X GET "http://localhost:7700/keys" -H "Authorization: Bearer $masterkey")
#echo "curl_response: $curl_response"
echo "your search/admin/chat keys:"
echo "$curl_response" | jq -r '.results[]? | "\(.name): \(.key)"'

echo "your sample client addr: http://localhost"
EOL
chmod +x /root/getkeys.sh

systemctl enable -q --now meilisearch


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
