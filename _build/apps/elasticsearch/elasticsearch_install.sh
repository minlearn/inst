###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl gnupg2 sudo mc jq
echo "Installed Dependencies"

silent apt-get install -y openjdk-11-jdk

echo "Installing elasticsearch"
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic.list > /dev/null
silent apt update -y
silent apt install -y elasticsearch logstash

cat > /etc/elasticsearch/jvm.options.d/heap.size.options << EOF
-Xms512m
-Xmx512m
EOF
sed -e 's/^-Xms.*/-Xms256m/' -e 's/^-Xmx.*/-Xmx256m/' -i /etc/logstash/jvm.options

cat > /etc/elasticsearch/elasticsearch.yml << EOF
cluster.name: es-cluster
node.name: node-1
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node

xpack.security.enabled: false
xpack.security.enrollment.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false

http.cors.enabled: true
http.cors.allow-origin: "*"
EOF

systemctl enable -q --now elasticsearch
echo "Installed elasticsearch"

cat > /root/setupdataclient.sh << 'EOLL'
silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

read -r -p "Would you like to add data and sample client? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  [[ -f /root/data.csv ]] || { echo "No data.csv found in /root, creating sample data..."; echo -e "Title,Content,Permalink\n\"Hello World\",\"This is the first document.\",\"http://example.com/doc1\"\n\"Elasticsearch\",\"Elasticsearch is a search engine based on Lucene.\",\"http://example.com/doc2\"" > /root/data.csv; }

  read -r -p "what will be the default index? (default: articles) " INDEX_NAME </dev/tty
  INDEX_NAME=${INDEX_NAME:-articles}

  cat > /root/csv_to_es.conf << EOF
input {
  stdin { }
}

filter {
  csv {
    separator => ","
    columns => ["Title","Content","Permalink"]
    skip_header => true
    skip_empty_rows => true
  }
  ruby {
    code => '
      \$LOG_COUNTER ||= 0
      \$LOG_COUNTER += 1
      event.set("count", \$LOG_COUNTER)
    '
  }
}

output {
  elasticsearch {
    hosts => ["http://127.0.0.1:9200"]
    index => "$INDEX_NAME"
  }
  stdout {
    codec => line {
      format => "NO.%{count} | Permalink: %{Permalink}"
    }
  }
}
EOF

  cat /root/data.csv | /usr/share/logstash/bin/logstash -f /root/csv_to_es.conf

  echo "Installing apache2"
  silent apt-get install -y apache2

  cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>文章搜索系统</title>
<style>
body{font-family:Microsoft YaHei;margin:30px;background:#f5f5f5}
.container{max-width:1000px;margin:auto;background:white;padding:30px;border-radius:8px}
.search{margin-bottom:20px}
input{width:80%;padding:12px;font-size:16px;border:1px solid #ddd;border-radius:4px}
button{padding:12px 24px;background:#007bff;color:white;border:none;border-radius:4px;cursor:pointer}
.item{padding:15px;border-bottom:1px solid #eee;margin:10px 0}
.title{font-size:18px;font-weight:bold;color:#222}
.content{color:#555;margin:5px 0;line-height:1.6}
a{color:#007bff;text-decoration:none}
</style>
</head>
<body>
<div class="container">
<h2>📄 文章全文搜索系统</h2>
<div class="search">
<input type="text" id="kw" placeholder="输入关键词搜索标题/内容...">
<button onclick="search()">搜索</button>
</div>
<div id="result"></div>
</div>

<script>
const ES_URL = "http://127.0.0.1:9200/$INDEX_NAME/_search";
async function search(){
  const kw = document.getElementById("kw").value.trim();
  const res = document.getElementById("result");
  if(!kw){res.innerHTML=\`<p>请输入关键词</p>\`;return}
  
  const query = {
    query: {
      multi_match: {
        query: kw,
        fields: ["Title","Content"]
      }
    }
  };

  try{
    const resp = await fetch(ES_URL,{
      method:"POST",
      headers:{"Content-Type":"application/json"},
      body:JSON.stringify(query)
    });
    const data = await resp.json();
    let html = \`<p>找到 \${data.hits.total.value} 条结果</p>\`;
    data.hits.hits.forEach(item=>{
      const d = item._source;
      html += \`
      <div class="item">
        <div class="title">\${d.Title}</div>
        <div class="content">\${d.Content.substring(0,150)}...</div>
        <a href="\${d.Permalink}" target="_blank">查看原文</a>
      </div>
      \`;
    });
    res.innerHTML = html;
  }catch(e){
    res.innerHTML = \`<p>连接失败，请检查 ES 服务</p>\`;
  }
}
</script>
</body>
</html>
EOF
  a2ensite 000-default.conf
  systemctl restart apache2
  echo "Installed apache2"
fi

EOLL
chmod +x /root/setupdataclient.sh

cat > /root/clear.sh << 'EOLL'
read -r -p "Would you like to clear all data? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  read -r -p "what is the index to be cleared? (default: articles) " INDEX_NAME </dev/tty
  INDEX_NAME=${INDEX_NAME:-articles}
  curl -s -X POST "http://127.0.0.1:9200/$INDEX_NAME/_delete_by_query" -d '{"query":{"match_all":{}}}'
fi
EOLL
chmod +x /root/clear.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
