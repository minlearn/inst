###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }

debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

echo deb http://archive.debian.org/debian bullseye-backports main >> /etc/apt/sources.list
silent apt-get update -y
silent apt-get install -t bullseye-backports qemu-system python3 -y
silent apt-get install -y dmg2img

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
# ideas from https://github.com/dockur/macos/blob/master/src/boot.sh
wget --no-check-certificate $rlsmirror/boot.img.gz -O download/boot.img.gz
# from https://raw.githubusercontent.com/kholia/OSX-KVM
wget --no-check-certificate $rlsmirror/OVMF_CODE.fd -O download/OVMF_CODE.fd
wget --no-check-certificate $rlsmirror/OVMF_VARS.fd -O download/OVMF_VARS.fd
wget --no-check-certificate $rlsmirror/fetch-macOS-v2.py -O download/fetch.py

cat > /root/iso.sh << 'EOL'
read -r -p "this will download osx baseimg,are you sure? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
  rm -rf download/com.apple.recovery.boot
  (cd download; python3 fetch.py --action download --board-id Mac-2BD1B31983FE1663; dmg2img -i com.apple.recovery.boot/BaseSystem.dmg com.apple.recovery.boot/BaseSystem.img)
fi
EOL
chmod +x /root/iso.sh

cat > /root/make.sh << 'EOL'
cd /root

read -r -p "this will del all the osx asserts,are you sure? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
    rm -rf myosx
    mkdir -p myosx

    gunzip -k -c download/boot.img.gz > myosx/boot.img
    cp download/OVMF_CODE.fd download/OVMF_VARS.fd download/com.apple.recovery.boot/BaseSystem.img myosx
    echo "creating osxhd ..."
    qemu-img create -f qcow2 myosx/BigSur-HD.qcow2 40G
    echo "creating osxhd done"
fi
EOL
chmod +x /root/make.sh

cat > /root/start.sh << 'EOL'
#!/bin/bash

#done on the host already
#echo 1 > /sys/module/kvm/parameters/ignore_msrs

if [ ! -e /dev/kvm ]; then
   mknod /dev/kvm c 10 232
   chmod 777 /dev/kvm
   chown root:kvm /dev/kvm
fi

if [ $(lscpu | grep "Vendor ID" | awk '{print $3}') == "GenuineIntel" ]; then
  cpuoptions="host,kvm=on,l3-cache=on,+hypervisor,migratable=no,vendor=GenuineIntel,vmware-cpuid-freq=on,-pdpe1gb"
fi
if [ $(lscpu | grep "Vendor ID" | awk '{print $3}') == "AuthenticAMD" ]; then
  cpuoptions="Haswell-noTSX,vendor=GenuineIntel,+invtsc,+hypervisor,kvm=on,vmware-cpuid-freq=on"
fi

args=(
 -nodefaults
 -cpu ${cpuoptions}
 -smp 2,sockets=1,dies=1,cores=2,threads=1
 -m 2G
 -machine type=q35,smm=off,graphics=off,vmport=off,dump-guest-core=off,hpet=off,accel=kvm
 -enable-kvm
 -global kvm-pit.lost_tick_policy=discard
 -uuid 76E01D9D-C0DD-4887-A6E9-D880107AD160
 -display vnc=:1
 -vga vmware
 -monitor telnet:localhost:7100,server,nowait,nodelay
 -name macos,process=macos,debug-threads=on
 -device nec-usb-xhci,id=xhci
 -device usb-kbd,bus=xhci.0
 -global nec-usb-xhci.msi=off
 -device usb-tablet
 -netdev user,id=hostnet0,host=20.20.20.1,net=20.20.20.0/24,dhcpstart=20.20.20.21,hostname=QEMU,hostfwd=tcp::22-20.20.20.21:22,hostfwd=tcp::3389-20.20.20.21:3389,hostfwd=tcp::5900-20.20.20.21:5900
 -device virtio-net-pci,romfile=,netdev=hostnet0,mac=00:16:CB:BD:8C:9E,id=net0
 -device virtio-blk-pci,drive=InstallMedia,bus=pcie.0,addr=0x6
 -drive file=./myosx/BaseSystem.img,id=InstallMedia,format=raw,cache=unsafe,readonly=on,if=none
 -drive file=./myosx/BigSur-HD.qcow2,id=data3,format=qcow2,cache=none,aio=native,discard=on,detect-zeroes=on,if=none
 -device virtio-blk-pci,drive=data3,bus=pcie.0,addr=0xa,iothread=io2,bootindex=3
 -object iothread,id=io2
 -device virtio-blk-pci,drive=OpenCore,bus=pcie.0,addr=0x5,bootindex=9
 -drive file=./myosx/boot.img,id=OpenCore,format=raw,cache=unsafe,readonly=on,if=none
 -smbios type=2
 -rtc base=utc,base=localtime
 -global ICH9-LPC.disable_s3=1
 -global ICH9-LPC.disable_s4=1
 -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off
 -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
 -drive if=pflash,format=raw,readonly=on,file=./myosx/OVMF_CODE.fd
 -drive if=pflash,format=raw,file=./myosx/OVMF_VARS.fd
 -object rng-random,id=objrng0,filename=/dev/urandom
 -device virtio-rng-pci,rng=objrng0,id=rng0,bus=pcie.0,addr=0x1c
 -device virtio-balloon-pci,id=balloon0,bus=pcie.0,addr=0x4
)

qemu-system-x86_64 "${args[@]}"
EOL
chmod +x /root/start.sh

    cat > /etc/systemd/system/kvm-restore.service << 'EOF'
[Unit]
Description=MacOS VM

[Service]
Type=simple
WorkingDirectory=/root
ExecStart=bash /root/start.sh
User=root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# after setup finished, replace -display vnc=:1 with -nographic in start.sh; and use os remote desktop with password protecting
cat > /root/vncoff.sh << 'EOL'
read -r -p "this will turn off vnc,are you sure? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
    sed -e s#-display[[:space:]]vnc=:1#-nographic#g -i /root/start.sh
    systemctl restart kvm-restore
fi
chmod +x /root/vncoff.sh

systemctl enable -q --now kvm-restore.service

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"



##############
