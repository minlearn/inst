###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc gnupg binfmt-support unzip zstd
echo "Installed Dependencies"

ver=4ccf1b29001e922f76b82c7f127b7b94c452edb6
wget -q https://github.com/ryanfortner/box64-debs/raw/$ver/box64.list -O /etc/apt/sources.list.d/box64.list
sed -i s#ryanfortner.github.io/box64-debs#github.com/ryanfortner/box64-debs/raw/$ver#g /etc/apt/sources.list.d/box64.list
wget -qO- https://github.com/ryanfortner/box64-debs/raw/$ver/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg
silent apt-get update -y
silent apt-get install --download-only box64 #-generic-arm

#f33fbe7b0dd8de272c4032d9868f52f84ecf0756
#debfile=$(ls -t /var/cache/apt/archives/box64*.deb | head -n1)
#tmpdir=$(mktemp -d)
#cd "$tmpdir"
#ar x "$debfile"
#unzstd control.tar.zst
#mkdir control_dir
#tar -xf control.tar -C control_dir
#tar -czf control.tar.gz -C control_dir .
#rm control.tar control.tar.zst
#rm -rf control_dir
#unzstd data.tar.zst
#mkdir data_dir
#tar -xf data.tar -C data_dir
#tar -cJf data.tar.xz -C data_dir .
#rm data.tar data.tar.zst
#rm -rf data_dir
#ar rcs box64_fixed.deb debian-binary control.tar.gz data.tar.xz
#dpkg -i box64_fixed.deb

cat <<EOF >/root/test.sh
apt-get install -y -qq gcc-x86-64-linux-gnu
cd /root
echo '#include <stdio.h>
int main() {
    printf("Hello, x86_64 world!");
    return 0;
}' > hello.c
x86_64-linux-gnu-gcc hello.c -o hello_x86_64
box64 ./hello_x86_64
EOF

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
