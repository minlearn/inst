###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

cd /root

mkdir -p download
wget --no-check-certificate https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.9.325.tar.xz -O download/linuxsrc.xz

silent apt-get -y install build-essential bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves bison
silent apt-get -y install python3 git

silent apt-get install -y uthash-dev
git clone https://github.com/jduck/lk-reducer.git
cd lk-reducer
bash compile.sh
cp lk-reducer /usr/local/bin/

cd /root

rm -rf reduced src
mkdir -p reduced src
tar -C src -xJf download/linuxsrc.xz --strip-components=1

# run in host not here lxc containers
# sudo sysctl fs.inotify.max_user_watches=524288

cat > /root/start.sh << 'EOL'

du -hs /root/src

lk-reducer /root/src <<'EOS'
set -euo pipefail
make defconfig
make bzImage
exit
EOS
grep -h ^A /root/src/lk-reducer.out | sort -u | cut -c 3- | grep -v '\./\.git\/' > lk-reducer-keep.out
(cd /root/src; tar cf - -T /root/lk-reducer-keep.out | tar xf - -C /root/reduced/ )
# symbolic links aren't handled properly, so you might want to copy those separately.
# (cd /root/src; find . -type l -print | tar xf - -C /root/reduced/ )

du -hs /root/reduced/

EOL
chmod +x /root/start.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
