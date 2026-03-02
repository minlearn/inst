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
wget --no-check-certificate https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.9.325.tar.xz -O download/linuxsrc.xz
wget --no-check-certificate $rlsmirror/patchs.tar.gz -O download/patchs.tar.gz

silent apt-get -y install build-essential bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves bison
silent apt-get -y install python3 git

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
