###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

cd /root

silent apt-get -y install build-essential automake pkg-config libssl-dev libcurl4-gnutls-dev libxml2-dev libfuse-dev fuse
silent apt-get -y install ntpdate git

# this is important for cosfs to work well
sudo ntpdate ntp.tencent.com

git clone https://github.com/tencentyun/cosfs.git
cd cosfs
./autogen.sh
./configure
make
sudo make install

# https://cloud.tencent.com/document/product/436/6883
mkdir -p /lhcos-data
echo BucketName-APPID:SecretId:SecretKey > /etc/passwd-cosfs
chmod 640 /etc/passwd-cosfs

# -opublic_bucket=1 is for public bucket
# if your bucket is private, please remove this option and make sure the SecretId and SecretKey have access to the bucket.
# if encounter "io error", please set -oensure_diskfree=1024 larger, or check if your /tmp has enough free space
# because cosfs will use /tmp to store data before uploading to COS.
echo "Creating Service"
cat <<EOF >/etc/systemd/system/lhcos-data.service
[Unit]
Description=Mount COSFS Bucket
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStartPre=/usr/sbin/ntpdate ntp.tencent.com
ExecStart=/usr/local/bin/cosfs sg-xxx:/lhcos-data /lhcos-data \
  -ourl=https://cos.ap-yyy.myqcloud.com \
  -odbglevel=err \
  -oallow_other \
  -opublic_bucket=1 \
  -oensure_diskfree=1024 \
-f
ExecStop=fusermount -u /lhcos-data
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now lhcos-data
echo "Created Service"

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
