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
wget --no-check-certificate https://ftp.gnu.org/pub/gnu/binutils/binutils-2.19.1.tar.bz2 -O download/binutils.tar.bz2
wget --no-check-certificate https://ftp.gnu.org/gnu/gcc/gcc-4.1.2/gcc-4.1.2.tar.bz2 -O download/gcc.tar.bz2
wget --no-check-certificate https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tar.xz -O download/python.xz
wget --no-check-certificate https://www.kernel.org/pub/linux/kernel/v2.6/linux-2.6.33.7.tar.xz -O download/linuxsrc.xz
wget --no-check-certificate http://ftp.funet.fi/pub/mirrors/ftp.easysw.com/pub/fltk/1.1.10/fltk-1.1.10-source.tar.bz2 -O download/fltk.tar.bz2

dpkg --add-architecture i386
silent apt-get update -y
silent apt-get -y install build-essential texinfo
silent apt-get -y install libc6-dev:i386
silent apt-get -y install libssl-dev libbz2-dev libreadline-dev libsqlite3-dev
silent apt-get -y install flex bison libncurses5-dev
silent apt-get -y install git

mkdir -p src/{binutils,gcc,python,linux-2.6.33.7-source,linux-2.6.33.7-source_tobepatch,fltk} build/{binutils,gcc}

tar -C src/binutils -xjf download/binutils.tar.bz2 --strip-components=1
tar -C src/gcc -xjf download/gcc.tar.bz2 --strip-components=1
sed -e 's/struct siginfo/siginfo_t/g' -e 's/struct ucontext/ucontext_t/g' -i src/gcc/gcc/config/i386/linux-unwind.h
tar -C src/python -xJf download/python.xz --strip-components=1
tar -C src/linux-2.6.33.7-source -xJf download/linuxsrc.xz --strip-components=1
tar -C src/linux-2.6.33.7-source_tobepatch -xJf download/linuxsrc.xz --strip-components=1

git clone https://github.com/da-x/colinux

tar -C src/fltk -xjf download/fltk.tar.bz2 --strip-components=1
# patch -p1 < colinux/patch/fltk-1.1.10-linux-patch.diff

# --with-sysroot=/ let compiled gcc toolchain share host system header and library, so we dont need do stage2 build
cd /root/build/binutils
../../src/binutils/configure --target=i686-linux-gnu --prefix=/usr/local/gcc-4.1.2 --program-prefix=i686-linux-gnu- --disable-shared --disable-multilib \
--with-sysroot=/
make CFLAGS="-O2 -Wno-error -fcommon" -j$(nproc)
make install

# --with-sysroot=/ let compiled gcc toolchain share host system header and library, so we dont need do stage2 build
export PATH=/usr/local/gcc-4.1.2/bin:$PATH
cd /root/build/gcc
../../src/gcc/configure --target=i686-linux-gnu --prefix=/usr/local/gcc-4.1.2 --program-prefix=i686-linux-gnu- --disable-shared --disable-multilib \
--with-sysroot=/ \
--enable-languages=c --disable-libsanitizer --disable-libmudflap --disable-libssp
make CFLAGS="-O2 -fgnu89-inline" BOOT_CFLAGS="-O2 -fgnu89-inline" CFLAGS_FOR_TARGET="-g -O2 -I/usr/include -I/usr/include/i386-linux-gnu" -j$(nproc)
PATH=/usr/local/gcc-4.1.2/bin:$PATH make install

cat > /root/hello.c << 'EOL'
#include <stdio.h>
int main() {
    printf("Hello world!\n");
}
EOL
/usr/local/gcc-4.1.2/bin/i686-linux-gnu-gcc -v hello.c -o hello
file hello

cd /root/src/python
./configure
make -j$(nproc)
make install

cd /root/src/fltk
./configure
make -j$(nproc)
make install

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
