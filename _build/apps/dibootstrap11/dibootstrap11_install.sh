############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y \
  curl \
  sudo \
  mc \
  gpg
echo "Installed Dependencies"

silent apt-get install -y debhelper apt-utils dctrl-tools
silent apt-get install -y xsltproc docbook-xsl libbogl-dev genext2fs genisoimage dosfstools bc syslinux syslinux-utils isolinux pxelinux syslinux-common shim-signed grub-efi-amd64-signed xorriso tofrodos mtools bf-utf-source win32-loader librsvg2-bin e2fsprogs fdisk
silent apt-get install -y qemu-system

cd /root
mkdir -p download
wget --no-check-certificate http://ftp.debian.org/debian/pool/main/d/debian-installer/debian-installer_20210731+deb11u8.tar.gz -O download/debian-installer_20210731+deb11u8.tar.gz

cat > /root/start.sh << 'EOL'
silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

cd /root

rm -rf installer
tar xzf download/debian-installer_20210731+deb11u8.tar.gz

touch installer/build/sources.list.udeb.local
echo 'deb https://snapshot.debian.org/archive/debian/20231007T024024Z bullseye main/debian-installer' > installer/build/sources.list.udeb.local
echo 'deb https://snapshot.debian.org/archive/debian/20231007T024024Z bullseye-updates main/debian-installer' >> installer/build/sources.list.udeb.local
echo 'deb https://snapshot.debian.org/archive/debian-security/20231007T024024Z bullseye-security main/debian-installer' >> installer/build/sources.list.udeb.local
sed -i '/cat > "$APT_CONFIG" <<EOF/a\Acquire::Check-Valid-Until "false";' installer/build/util/get-packages

read start end < <(awk '/^# Get a list of all kernel modules matching the kernel version\./ {s=NR} s && /^\.PHONY: pkg-lists\/kernel-module-udebs$/ {e=NR; print s, e; exit}' installer/build/Makefile)
sed -i "${end}a\\
\\
# Create a list of custom mini kernel modules matching the kernel version.（17pkgs）\\
pkg-lists/mini_kernel-module-udebs:\\
\tget-packages udeb update\\
\t> \$@\\
\t\$(foreach m,acpi crc crypto ext4 fat fb i2c input mtd-core nic nic-shared nic-usb nic-wireless rfkill scsi-core usb usb-storage, echo \"\$(m)-modules-\$(KERNELVERSION)-\$(KERNEL_FLAVOUR)\" >> \$@;)
" installer/build/Makefile
sed -e '/#include "kernel"/a\#include "mini_kernel-module-udebs"' -e 's/download-installer/# download-installer/g' -e 's/cdebconf-newt-terminal ?/cdebconf-newt-terminal/g' -i installer/build/pkg-lists/netboot/common
sed -e '/.*-modules-.*/d' -e '/netcfg/apartman-auto\n\n#misc\nfdisk-udeb\nparted-udeb\nopenssh-server-udeb' -i installer/build/pkg-lists/netboot/amd64.cfg

echo "Compiling"
(cd installer/build; silent fakeroot make clean_netboot)
(cd installer/build; silent fakeroot make pkg-lists/mini_kernel-module-udebs)
(cd installer/build; silent fakeroot make build_netboot)
tar -C installer/build/tmp/netboot/tree/lib/modules -cpzf installer/build/modules.tar.gz .
tar -C installer/build/tmp/netboot/tree -cpzf installer/build/di.tar.gz --exclude=lib/modules/* ./
echo "Compiled"

EOL
chmod +x /root/start.sh

cat > /root/test.sh << 'EOL'
cd /root

qemu-system-x86_64 -boot d -cdrom installer/build/dest/netboot/mini.iso
EOL
chmod +x /root/test.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############
