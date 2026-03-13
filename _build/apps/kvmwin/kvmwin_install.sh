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
silent apt-get install p7zip-full libarchive-tools wimtools dos2unix genisoimage -y

cd /root

rlsmirror=${2:-https://github.com/minlearn/inst/releases/download/inital}
mkdir -p download
# ideas from https://github.com/dockur/windows
wget --no-check-certificate -qO- $rlsmirror/win10x64-ltsc.xml | dos2unix > download/10.xml
wget --no-check-certificate $rlsmirror/virtio-win-1.9.45.tar.xz -O download/drivers.txz
# wget --no-check-certificate https://dl.bobpony.com/windows/10/en-us_windows_10_enterprise_ltsc_2021_x64_dvd_d289cf96.iso -O download/10.iso
wget --no-check-certificate $rlsmirror/windows_secure.rom -O download/windows_secure.rom
wget --no-check-certificate $rlsmirror/windows_secure.vars -O download/windows_secure.vars

cat > /root/iso.sh << 'EOL'
read -p "give a win10 iso:" iso </dev/tty
if [[ -z "$iso" ]]; then
  echo "no input,esc."
  exit 1
else
  rm -rf download/10.iso
  wget --no-check-certificate $iso -O download/10.iso
fi
EOL
chmod +x /root/iso.sh

cat > /root/make.sh << 'EOL'
cd /root

read -r -p "this will del all the win asserts,are you sure? <y/N> " prompt </dev/tty
if [[ ${prompt,,} =~ ^(y|yes)$ ]]; then
    rm -rf tmpinstall mywin
    mkdir -p tmpinstall/extracted mywin

    #extractImage
    7z x download/10.iso -otmpinstall/extracted

    # prepareimage->setmachine->if winold add oem folder

    # updateimage begin

    index="1"
    # index 2 is the winpe
    result=$(wimlib-imagex info -xml tmpinstall/extracted/sources/boot.wim | tr -d '\000')
    if [[ "${result^^}" == *"<IMAGE INDEX=\"2\">"* ]]; then
        index="2"
    fi

    # addDrivers tmpinstall/extracted/sources tmpinstall tmpinstall/extracted/sources/boot.wim 2 "$DETECTED"
    mkdir -p tmpinstall/drivers
    target="\$WinPEDriver\$"
    bsdtar -xf download/drivers.txz -C tmpinstall/drivers
    mkdir -p tmpinstall/drivers/$target
    # addDriver win10x64 "tmpinstall/drivers" "\$WinPEDriver\$" "qxl"
    for driver in viofs sriov qxldod viorng viostor viomem NetKVM Balloon vioscsi pvpanic vioinput viogpudo vioserial qemupciserial; do
        mkdir -p tmpinstall/drivers/$target/$driver
        cp -Lr tmpinstall/drivers/$driver/w10/amd64/. tmpinstall/drivers/$target/$driver
    done
    wimlib-imagex update tmpinstall/extracted/sources/boot.wim 2 --command "delete --force --recursive /$target"
    wimlib-imagex update tmpinstall/extracted/sources/boot.wim 2 --command "add tmpinstall/drivers/$target /$target"

    # add oem Folder
    mkdir -p tmpinstall/oem
    target="\$OEM\$/\$1/OEM"
    [ -d oem ] && {
        cp -Lr oem/. tmpinstall/oem
        [ -f tmpinstall/oem/install.bat ] && unix2dos tmpinstall/oem/install.bat
        wimlib-imagex update tmpinstall/extracted/sources/boot.wim 2 --command "add tmpinstall/oem /$target"
    }

    # add attend xml
    cp download/10.xml tmpinstall/10.xml
    # updateXML 10.xml en-us
    wimlib-imagex update tmpinstall/extracted/sources/boot.wim 2 --command "add tmpinstall/10.xml /autounattend.xml"
    wimlib-imagex update tmpinstall/extracted/sources/boot.wim 2 --command "add tmpinstall/10.xml /autounattend.dat"
    # updateimage end

    # buildimage
    genisoimage -o mywin/10-rebuilt.iso -b boot/etfsboot.com -no-emul-boot -c BOOT.CAT -iso-level 4 -J -l -D -N -joliet-long -relaxed-filenames -V "Windows" \
-udf -boot-info-table -eltorito-alt-boot -eltorito-boot efi/microsoft/boot/efisys_noprompt.bin -no-emul-boot -allow-limited-size -quiet tmpinstall/extracted
    cp download/windows_secure.rom download/windows_secure.vars mywin
    qemu-img create -f qcow2 mywin/data.img 40G
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

cpuoptions="host" #"host,kvm=on,l3-cache=on,+hypervisor,migratable=no,-vmx,hv_passthrough"

args=(
-nodefaults
-cpu ${cpuoptions}
-smp 2,sockets=1,dies=1,cores=2,threads=1
-m 2G
-machine type=q35,smm=on,graphics=off,vmport=off,dump-guest-core=off,hpet=off,accel=kvm
-enable-kvm
-global kvm-pit.lost_tick_policy=discard
-smbios type=1,serial=S190058X6803752
-display vnc=:1
-vga virtio
-monitor telnet:localhost:7100,server,nowait,nodelay
-name windows,process=windows,debug-threads=on
-device qemu-xhci,id=xhci,p2=7,p3=7
-device usb-tablet
-netdev user,id=hostnet0,host=20.20.20.1,net=20.20.20.0/24,dhcpstart=20.20.20.21,hostname=QEMU,hostfwd=tcp::22-20.20.20.21:22,hostfwd=tcp::3389-20.20.20.21:3389,hostfwd=tcp::5900-20.20.20.21:5900
-device virtio-net-pci,romfile=,netdev=hostnet0,mac=00:16:CB:BD:8C:9E,id=net0
-drive file=./mywin/10-rebuilt.iso,id=cdrom9,format=raw,cache=unsafe,readonly=on,media=cdrom,if=none
-device ich9-ahci,id=ahci9,addr=0x5
-device ide-cd,drive=cdrom9,bus=ahci9.0,bootindex=9
-drive file=./mywin/data.img,id=data3,format=qcow2,cache=none,aio=native,discard=on,detect-zeroes=on,if=none
-device virtio-blk-pci,drive=data3,bus=pcie.0,addr=0xa,iothread=io2,bootindex=3
-object iothread,id=io2
-rtc base=localtime
-global ICH9-LPC.disable_s3=1 -global ICH9-LPC.disable_s4=1
-global driver=cfi.pflash01,property=secure,value=on
-drive file=./mywin/windows_secure.rom,if=pflash,unit=0,format=raw,readonly=on
-drive file=./mywin/windows_secure.vars,if=pflash,unit=1,format=raw
-object rng-random,id=objrng0,filename=/dev/urandom
-device virtio-rng-pci,rng=objrng0,id=rng0,bus=pcie.0
)

qemu-system-x86_64 "${args[@]}"
EOL
chmod +x /root/start.sh

    cat > /etc/systemd/system/kvm-restore.service << 'EOF'
[Unit]
Description=WIN10 VM

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
