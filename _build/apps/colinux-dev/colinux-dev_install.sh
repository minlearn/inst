###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
wget --no-check-certificate https://ftp.gnu.org/gnu/gcc/gcc-4.1.2/gcc-4.1.2.tar.bz2 -O download/gcc.tar.bz2
wget --no-check-certificate https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tar.xz -O download/python.xz
wget --no-check-certificate https://www.kernel.org/pub/linux/kernel/v2.6/linux-2.6.33.7.tar.xz -O download/linuxsrc.xz
wget --no-check-certificate http://ftp.funet.fi/pub/mirrors/ftp.easysw.com/pub/fltk/1.1.10/fltk-1.1.10-source.tar.bz2 -O download/fltk.tar.bz2

silent apt-get -y install build-essential libgmp-dev libmpfr-dev libmpc-dev texinfo gcc-multilib g++-multilib libc6-dev-i386
silent apt-get -y install libssl-dev libbz2-dev libreadline-dev libsqlite3-dev
silent apt-get -y install flex bison libncurses5-dev
silent apt-get -y install git

tar xjf download/gcc.tar.bz2
cd gcc-4.1.2
mkdir -p build
cd build
../configure --prefix=/usr/local/gcc-4.1.2 --enable-languages=c --disable-libsanitizer
make -j$(nproc)
make install
cd ../..

tar xJf download/python.xz
cd Python-2.7.18
./configure
make -j$(nproc)
make install
cd ..

mkdir -p linux-2.6.33.7-source linux-2.6.33.7-source_tobepatch
tar -C linux-2.6.33.7-source -xJf download/linuxsrc.xz --strip-components=1
tar -C linux-2.6.33.7-source_tobepatch -xJf download/linuxsrc.xz --strip-components=1

git clone https://github.com/da-x/colinux

tar xjf download/fltk.tar.bz2
cd fltk-1.1.10
patch -p1 < ../colinux/patch/fltk-1.1.10-linux-patch.diff
./configure
make -j$(nproc)
make install
cd ..

cat > /root/start.sh << 'EOL'
cd /root

export PATH=/usr/local/gcc-4.1.2/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/gcc-4.1.2/lib64:$LD_LIBRARY_PATH
export CC=gcc
export CXX=g++
export AR=ar
export LD=ld

cd colinux

echo "Compiling"
./configure --colinux-os=linux --hostkerneldir=/root/linux-2.6.33.7-source
make -j$(nproc)
echo "Compiled"
EOL
chmod +x /root/start.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
