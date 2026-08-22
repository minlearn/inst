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
wget --no-check-certificate https://ftp.gnu.org/pub/gnu/binutils/binutils-2.39.tar.xz -O download/binutils.tar.xz
wget --no-check-certificate https://ftp.gnu.org/pub/gnu/gcc/gcc-12.1.0/gcc-12.1.0.tar.xz -O download/gcc.tar.xz
wget --no-check-certificate https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v10.0.0.tar.bz2 -O download/mingw-w64.tar.bz2
wget --no-check-certificate https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.9.325.tar.xz -O download/linuxsrc.xz
wget --no-check-certificate $rlsmirror/patchs.tar.gz -O download/patchs.tar.gz

silent apt-get -y install build-essential make flex bison git texinfo m4
silent apt-get -y install bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves bison
silent apt-get -y install python3 git

rm -rf src build mingw-cross
mkdir -p src/{binutils,mingw-w64,gcc} build/{binutils,mingw-w64-headers,mingw-w64-crt,gcc,mingw-w64-winpthreads} mingw-cross

tar -C src/binutils -xJf download/binutils.tar.xz --strip-components=1
tar -C src/gcc -xJf download/gcc.tar.xz --strip-components=1
(cd src/gcc;./contrib/download_prerequisites)
tar -C src/mingw-w64 -xjf download/mingw-w64.tar.bz2 --strip-components=1

i686_dwarf2="--disable-sjlj-exceptions --with-dwarf2"
crt_lib="--enable-lib32 --disable-lib64"
host="i686-w64-mingw32"
prefix=/root/mingw-cross
LINKED_RUNTIME="msvcrt"
BUILD="x86_64-pc-linux-gnu"
ENABLE_THREADS="--enable-threads=posix"

export PATH="$prefix/bin:$PATH"

echo "compile Binutils"
cd /root/build/binutils
../../src/binutils/configure --prefix="$prefix" --disable-shared \
--enable-static --with-sysroot="$prefix" --target="$host" \
--disable-multilib --disable-nls --enable-lto --disable-gdb
make -j $(nproc)
make install
echo "compile Binutils done"

echo "compile MinGW-w64 headers"
cd /root/build/mingw-w64-headers
../../src/mingw-w64/mingw-w64-headers/configure --build="$BUILD" \
--host="$host" --prefix="$prefix/$host" \
--with-default-msvcrt=$LINKED_RUNTIME
make -j $(nproc)
make install
echo "compile MinGW-w64 headers done"

echo "compile GCC 1st pass"
cd /root/build/gcc
../../src/gcc/configure --target="$host" --disable-shared \
--enable-static --disable-multilib --prefix="$prefix" \
--enable-languages=c,c++ --disable-nls $ENABLE_THREADS \
$i686_dwarf2
make -j $(nproc) all-gcc
make install-gcc
echo "configuring GCC 1st pass done"

echo "compile MinGW-w64 CRT"
cd /root/build/mingw-w64-crt
../../src/mingw-w64/mingw-w64-crt/configure --build="$BUILD" \
--host="$host" --prefix="$prefix/$host" \
--with-default-msvcrt=$LINKED_RUNTIME \
--with-sysroot="$prefix/$host" $crt_lib
make -j $(nproc)
make install
echo "compile MinGW-w64 CRT done"

echo "compile winpthreads"
cd /root/build/mingw-w64-winpthreads
../../src/mingw-w64/mingw-w64-libraries/winpthreads/configure \
--build="$BUILD" --host="$host" --disable-shared \
--enable-static --prefix="$prefix/$host"
make -j $(nproc)
make install
echo "compile winpthreads done"

echo "compile GCC 2st pass"
cd /root/build/gcc
make -j $(nproc)
make install
echo "compile GCC 2st pass"

echo "complete, to use MinGW-w64 everywhere add /root/mingw-cross/bin"

cat > /root/start.sh << 'EOL'
cd /root

rm -rf build src
mkdir -p build src/kernel

tar -C src/kernel -xJf download/linuxsrc.xz --strip-components=1
tar -C src -zxf download/patchs.tar.gz
(cd src/patchs;./apply_patches.sh ../../src/kernel)


#cp "$TOPDIR/conf/linux-$KERNEL_VERSION-config" "$COLINUX_TARGET_KERNEL_BUILD/.config"

#COLINUX_GCC_GUEST_PATH="$PREFIX/$COLINUX_GCC_GUEST_TARGET/bin"
#export PATH="$PATH:$COLINUX_GCC_GUEST_PATH"
#COLINUX_GCC_GUEST_TARGET="i686-co-linux"
#export CROSS_COMPILE="${COLINUX_GCC_GUEST_TARGET}-"
#CO_VERSION=`cat $TOPDIR/src/colinux/VERSION`
#COMPLETE_KERNEL_NAME=$KERNEL_VERSION-co-$CO_VERSION

export TOPDIR=`pwd`
export PATH="$TOPDIR/mingw/i686/bin:$TOPDIR/mingw/i686/i686-co-linux/bin:$PATH"
# colinux/kernel
export CROSS=i686-w64-mingw32-
export CC=gcc
export LD=ld
export CFLAGS="-I../../ \
            -I../../../linux-4.9.325/include \
            -I../../../linux-4.9.325/arch/x86/include \
            -I../../../linux-4.9.325/arch/x86/include/generated/uapi \
            -I../../../mingw/i686/i686-w64-mingw32/include \
            -I../../../mingw/i686/i686-w64-mingw32/include/ddk \
            -DCO_KERNEL"

echo "Compiling"
cd build
make O=$(pwd) -C ../src -j$(nproc)
make modules modules_install
echo "Compiled"
EOL
chmod +x /root/start.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
