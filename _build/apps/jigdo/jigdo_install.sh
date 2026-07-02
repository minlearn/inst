###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

echo "Installing jigdo"
silent apt-get -y install jigdo-file libarchive-tools
echo "Installed jigdo"

cat > /root/get.sh << 'EOL'
  cd /root
  rm -rf debian-11.7.0-amd64-DVD-*.{iso.list,template,jigdo*} .jigdo-lite jigdo-file-cache.db
  printf "http://cdimage.debian.org/cdimage/archive/11.7.0/amd64/jigdo-dvd/debian-11.7.0-amd64-DVD-{`seq -s , 1 19`}.jigdo\n\nhttp://archive.debian.org/debian\nhttp://archive.debian.org/debian-non-US/\n" | nohup jigdo-lite &
EOL
chmod +x /root/get.sh

cat > /root/extract.sh << 'EOL'
  cd /root
  rm -rf extracted
  mkdir -p extracted
  for i in `seq 1 19`;do
    nohup bsdtar -C extracted/ -xvf debian-11.7.0-amd64-DVD-$i.iso &
  done
EOL
chmod +x /root/extract.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
