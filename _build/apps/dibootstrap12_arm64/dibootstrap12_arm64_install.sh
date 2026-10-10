############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=http://snapshot.debian.org/archive/debian/20250425T203925Z
echo -e "deb ${debmirror} bookworm main\ndeb ${debmirror} bookworm-updates main\ndeb ${debmirror/debian\//debian-security\/} bookworm-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -o Acquire::Check-Valid-Until=false -y
silent apt-get install -y \
  curl \
  sudo \
  mc \
  gpg
echo "Installed Dependencies"

silent apt-get install -y fakeroot
silent apt-get install -y debhelper apt-utils dctrl-tools
silent apt-get install -y xsltproc docbook-xml docbook-xsl bogl-utils genext2fs genisoimage dosfstools bc xorriso tofrodos mtools unifont unifont-bin pigz librsvg2-bin libgcc-s1-arm64-cross libatomic1-arm64-cross grub-common
silent apt-get install -y qemu-system qemu-efi-aarch64

cd /root
mkdir -p download extracted
silent wget -q https://snapshot.debian.org/archive/debian/20250425T203925Z/pool/main/l/linux/linux-image-6.1.0-32-arm64-unsigned_6.1.129-1_arm64.deb -O download/linux-image-6.1.0-32-arm64-unsigned_6.1.129-1_arm64.deb
silent dpkg -x download/linux-image-6.1.0-32-arm64-unsigned_6.1.129-1_arm64.deb extracted/
silent wget -q https://snapshot.debian.org/archive/debian/20250425T203925Z/pool/main/s/shim-signed/shim-signed_1.44~1+deb12u1+15.8-1~deb12u1_arm64.deb -O download/shim-signed.deb
silent wget -q https://snapshot.debian.org/archive/debian/20250425T203925Z/pool/main/g/grub-efi-arm64-signed/grub-efi-arm64-signed_1+2.06+13+deb12u1_arm64.deb -O download/grub-efi-arm64-signed.deb
silent wget -q https://snapshot.debian.org/archive/debian/20250425T203925Z/pool/main/g/grub2/grub-efi-arm64-bin_2.06-13+deb12u1_arm64.deb -O download/grub-efi-arm64-bin.deb
silent dpkg -x download/shim-signed.deb extracted/
silent dpkg -x download/grub-efi-arm64-signed.deb extracted/
silent dpkg -x download/grub-efi-arm64-bin.deb extracted/
wget --no-check-certificate http://ftp.debian.org/debian/pool/main/d/debian-installer/debian-installer_20230607+deb12u10.tar.xz -O download/debian-installer_20230607+deb12u10.tar.xz

cat > /root/start.sh << 'EOL'
silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

cd /root

rm -rf installer
tar xJf download/debian-installer_20230607+deb12u10.tar.xz

touch installer/build/sources.list.udeb.local
echo 'deb http://snapshot.debian.org/archive/debian/20250425T203925Z bookworm main/debian-installer' > installer/build/sources.list.udeb.local
echo 'deb http://snapshot.debian.org/archive/debian/20250425T203925Z bookworm-updates main/debian-installer' >> installer/build/sources.list.udeb.local
echo 'deb http://snapshot.debian.org/archive/debian-security/20250425T203925Z bookworm-security main/debian-installer' >> installer/build/sources.list.udeb.local
sed -i '/cat > "$APT_CONFIG" <<EOF/a\Acquire::Check-Valid-Until "false";' installer/build/util/get-packages
sed -i 's@arm_grub_efi: \$(TEMP_DTBS)@arm_grub_efi:\n\tmkdir -p \$(TEMP_DTBS)@' installer/build/config/arm.cfg
sed -i 's@/usr/lib/shim/@../../extracted/usr/lib/shim/@' installer/build/util/efi-image 2>/dev/null
sed -i 's@/usr/lib/grub/@../../extracted/usr/lib/grub/@' installer/build/util/efi-image installer/build/util/grub-cpmodules 2>/dev/null
#sed -i 's/linux-image-6\.1\.0-32-arm64 \[arm64\]//' installer/debian/control
sed -i '/^arch_depthcharge:/,/^[^[:space:]]/s/^\t.*/\t@true/' installer/build/config/arm.cfg
sed -i '341s/.*/\ttrue # dpkg-checkbuilddeps skipped/' installer/build/Makefile
sed -i 's@rmdir \$(TREE)/boot/@rm -f \$(TREE)/boot/System.map \&\& rmdir \$(TREE)/boot/@' installer/build/Makefile
sed -i 's@export DRM_DIR := /lib/modules/\$(KERNELVERSION)/kernel/drivers/gpu/drm@export DRM_DIR := ../../extracted/lib/modules/\$(KERNELVERSION)/kernel/drivers/gpu/drm@' installer/build/Makefile
sed -i 's@\$(TREE)\$(DRM_DIR)@\$(TREE)/lib/modules/\$(KERNELVERSION)/kernel/drivers/gpu/drm@g' installer/build/Makefile
sed -i 's@/lib/\$(DEB_HOST_MULTIARCH)/libgcc_s.so.@/usr/aarch64-linux-gnu/lib/libgcc_s.so.@' installer/build/Makefile
sed -i 's@/usr/lib/\$(DEB_HOST_MULTIARCH)/libatomic.so.1\*@/usr/aarch64-linux-gnu/lib/libatomic.so.1*@' installer/build/Makefile
sed -i '/^\$(DEPTHCHARGE):/{
    n
    s/^\t.*/\t@true/
    n
    s/^\t.*/\t@true/
    n
    s/^\t.*/\t@true/
    n
    s/^\t.*/\t@true/
}' installer/build/Makefile

read start end < <(awk '/^# Get a list of all kernel modules matching the kernel version\./ {s=NR} s && /^\.PHONY: pkg-lists\/kernel-module-udebs$/ {e=NR; print s, e; exit}' installer/build/Makefile)
sed -i "${end}a\\
\\
# Create a list of custom mini kernel modules matching the kernel version.（15pkgs）\\
pkg-lists/mini_kernel-module-udebs:\\
\tget-packages udeb update\\
\t> \$@\\
\t\$(foreach m,crc crypto ext4 fat fb i2c input mtd-core nic nic-shared nic-usb nic-wireless scsi-core usb usb-storage, echo \"\$(m)-modules-\$(KERNELVERSION)-\$(KERNEL_FLAVOUR)\" >> \$@;)
" installer/build/Makefile
sed -e '/#include "kernel"/a\#include "mini_kernel-module-udebs"' -e 's/download-installer/# download-installer/g' -e 's/cdebconf-newt-terminal ?/cdebconf-newt-terminal/g' -i installer/build/pkg-lists/netboot/common
sed -e '/.*-modules-.*/d' -e '/netcfg/apartman-auto\n\n#misc\nfdisk-udeb\nparted-udeb\nopenssh-server-udeb' -i installer/build/pkg-lists/netboot/arm64.cfg

echo "Compiling"
(cd installer/build; silent fakeroot make DEB_HOST_ARCH=arm64 KERNELVERSION=6.1.0-32-arm64 KERNEL_FLAVOUR=di DPKG_UNPACK_OPTIONS="--force-architecture --force-overwrite" clean_netboot)
(cd installer/build; silent fakeroot make DEB_HOST_ARCH=arm64 KERNELVERSION=6.1.0-32-arm64 KERNEL_FLAVOUR=di DPKG_UNPACK_OPTIONS="--force-architecture --force-overwrite" pkg-lists/mini_kernel-module-udebs)
(cd installer/build; silent fakeroot make DEB_HOST_ARCH=arm64 KERNELVERSION=6.1.0-32-arm64 KERNEL_FLAVOUR=di DPKG_UNPACK_OPTIONS="--force-architecture --force-overwrite" build_netboot)
tar -C installer/build/tmp/netboot/tree/lib/modules -cpzf installer/build/modules.tar.gz .
tar -C installer/build/tmp/netboot/tree -cpzf installer/build/di.tar.gz --exclude=lib/modules/* ./
echo "Compiled"

EOL
chmod +x /root/start.sh

cat > /root/test.sh << 'EOL'
cd /root

qemu-system-aarch64 -M virt -boot d -cdrom installer/build/dest/netboot/mini.iso -nographic
EOL
chmod +x /root/test.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############
