###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://archive.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main" > /etc/apt/sources.list # \ndeb ${debmirror}-security bullseye-security main

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get -y install build-essential bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves bison
silent apt-get -y install python3
silent apt-get -y install gcc-aarch64-linux-gnu

cd /root

mkdir -p download
wget --no-check-certificate https://snapshot.debian.org/archive/debian/20250306T150220Z/pool/main/l/linux/linux-source-6.1_6.1.129-1_all.deb -O download/mypackage.deb
wget --no-check-certificate https://snapshot.debian.org/archive/debian/20250306T150220Z/pool/main/l/linux/linux-config-6.1_6.1.129-1_arm64.deb -O download/mypackagecfg.deb

cat > /root/start.sh << 'EOL'
cd /root

echo "Compiling"
rm -rf mypackage
mkdir -p mypackage

ar -p download/mypackage.deb data.tar.xz |xzcat|tar -xf - -C mypackage
ar -p download/mypackagecfg.deb data.tar.xz |xzcat|tar -xf - -C mypackage
tar -C mypackage/usr/src -xJf  mypackage/usr/src/linux-source-6.1.tar.xz
sed -e "s/#define[[:space:]]\+COMMAND_LINE_SIZE[[:space:]]\+2048/#define COMMAND_LINE_SIZE 20480/" -i mypackage/usr/src/linux-source-6.1/arch/arm64/include/uapi/asm/setup.h
xz -dck mypackage/usr/src/linux-config-6.1/config.arm64_none_arm64.xz > mypackage/usr/src/linux-source-6.1/config.arm64_none_arm64
sed -e "s/CONFIG_DEBUG_INFO_BTF=y/CONFIG_DEBUG_INFO_BTF=n/g" -i mypackage/usr/src/linux-source-6.1/config.arm64_none_arm64

# sed -e "s/# CONFIG_IKCONFIG is not set/CONFIG_IKCONFIG=y\nCONFIG_IKCONFIG_PROC=y/g" -i mypackage/usr/src/linux-source-6.1/config.arm64_none_arm64
# sed -e "s/CONFIG_ANDROID_BINDER_IPC=m/CONFIG_ANDROID_BINDER_IPC=y/g" -e "s/# CONFIG_ANDROID_BINDERFS is not set/CONFIG_ANDROID_BINDERFS=y/g" -i mypackage/usr/src/linux-source-6.1/config.arm64_none_arm64

<<'BLOCK'
sed \
-e "s/CONFIG_VIRTIO=m/CONFIG_VIRTIO=y/g" \
-e "s/CONFIG_VIRTIO_PCI=m/CONFIG_VIRTIO_PCI=y/g" \
-e "s/CONFIG_NET_9P=m/CONFIG_NET_9P=y/g" \
-e "s/CONFIG_NET_9P_VIRTIO=m/CONFIG_NET_9P_VIRTIO=y/g" \
-e "s/CONFIG_9P_FS=m/CONFIG_9P_FS=y/g" \
-i mypackage/usr/src/linux-source-6.1/config.arm64_none_arm64
BLOCK

sed \
-e '$a\CONFIG_BUILD_SALT="6.1.0-32-arm64"' \
-e '$a\# CONFIG_MODULE_SIG_ALL is not set' \
-e '$a\CONFIG_MODULE_SIG_KEY=""' \
-e '$a\CONFIG_SYSTEM_TRUSTED_KEYS=""' \
-i mypackage/usr/src/linux-source-6.1/config.arm64_none_arm64

sed \
-e 's/SUBLEVEL = 129/SUBLEVEL = 0/g' \
-e 's/EXTRAVERSION =/EXTRAVERSION = -32-arm64/g' \
-i mypackage/usr/src/linux-source-6.1/Makefile

cd mypackage/usr/src/linux-source-6.1
make mrproper
cp config.arm64_none_arm64 .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j`nproc` Image
cp arch/arm64/boot/Image vmlinuz
echo "Compiled"
EOL
chmod +x /root/start.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
