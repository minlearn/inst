###############

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


cat > /root/compile.sh << 'EOL'
silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }
echo "Compiling"
cd /root

silent apt-get install -y build-essential cmake nasm
wget --no-check-certificate https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/3.1.0.tar.gz
tar xzf 3.1.0.tar.gz
cd libjpeg-turbo-3.1.0
export CFLAGS="-fpic"
silent cmake -DCMAKE_INSTALL_PREFIX=/usr/local -G"Unix Makefiles"
silent make -j`nproc`
silent make install
cd ..
rm -rf 3.1.0.tar.gz
wget --no-check-certificate https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.2.4.tar.gz
tar xzf libwebp-1.2.4.tar.gz
cd libwebp-1.2.4
silent ./configure --enable-static --disable-shared
silent make -j`nproc`
silent make install
cd ..
rm -rf libwebp-1.2.4.tar.gz

silent apt-get install -y pkg-config zlib1g-dev libpng-dev libfreetype6-dev libssl-dev unzip \
libxcursor-dev libxrandr-dev libxtst-dev libxfixes-dev
wget --no-check-certificate https://github.com/kasmtech/KasmVNC/archive/refs/heads/master.zip
unzip -q master.zip
wget --no-check-certificate https://github.com/kasmtech/noVNC/archive/refs/heads/master.tar.gz -O noVNC-master.tar.gz
tar -C KasmVNC-master/kasmweb -xf noVNC-master.tar.gz --strip-components=1
cd KasmVNC-master
sed -i -e '/find_package(FLTK/s@^@#@' \
	-e '/add_subdirectory(tests/s@^@#@' \
	CMakeLists.txt
silent cmake -D CMAKE_BUILD_TYPE=RelWithDebInfo . -DBUILD_VIEWER:BOOL=OFF \
  -DENABLE_GNUTLS:BOOL=OFF
silent make -j`nproc`
silent make install
cd ..
rm -rf master.zip noVNC-master.tar.gz

silent apt-get install -y autoconf automake gettext xfonts-utils libtool \
xutils-dev libpixman-1-dev libxshmfence-dev libdrm-dev libgl-dev libxkbfile-dev libxfont-dev mesa-common-dev libgbm-dev
wget --no-check-certificate https://www.x.org/archive/individual/xserver/xorg-server-1.19.6.tar.gz
tar -C KasmVNC-master/unix/xserver -xf xorg-server-1.19.6.tar.gz --strip-components=1
cd KasmVNC-master/unix/xserver
silent patch -Np1 -i ../xserver119.patch
silent patch -s -p0 < ../CVE-2022-2320-v1.19.patch
silent autoreconf -i
sed -i 's/LIBGL="gl >= 7.1.0"/LIBGL="gl >= 1.1"/g' configure
silent ./configure \
    --disable-config-hal \
    --disable-config-udev \
    --disable-dmx \
    --disable-dri \
    --disable-dri2 \
    --disable-kdrive \
    --disable-static \
    --disable-xephyr \
    --disable-xinerama \
    --disable-xnest \
    --disable-xorg \
    --disable-xvfb \
    --disable-xwayland \
    --disable-xwin \
    --enable-glx \
    --prefix=/opt/kasmweb \
    --with-default-font-path="/usr/share/fonts/X11/misc,/usr/share/fonts/X11/cyrillic,/usr/share/fonts/X11/100dpi/:unscaled,/usr/share/fonts/X11/75dpi/:unscaled,/usr/share/fonts/X11/Type1,/usr/share/fonts/X11/100dpi,/usr/share/fonts/X11/75dpi,built-ins" \
    --without-dtrace \
    --with-sha1=libcrypto \
    --with-xkb-bin-directory=/usr/bin \
    --with-xkb-output=/var/lib/xkb \
    --with-xkb-path=/usr/share/X11/xkb --enable-dri3
find . -name "Makefile" -exec sed -i 's/-Werror=array-bounds//g' {} \;
sed -e "s/.pixmap_from_fds\ =\ xvnc_pixmap_from_fds,/.pixmap_from_fd = xvnc_pixmap_from_fds,/g" -e "s/.fds_from_pixmap\ =\ xvnc_fds_from_pixmap,/.fd_from_pixmap = xvnc_fds_from_pixmap,/g" -i hw/vnc/dri3.c
sed -e "s/.open_client\ =\ xvnc_dri3_open_client,/\/\/.open_client = xvnc_dri3_open_client,/g" -e "s/.get_formats\ =\ xvnc_get_formats,/\/\/.get_formats = xvnc_get_formats,/g" -e "s/.get_modifiers\ =\ xvnc_get_modifiers,/\/\/.get_modifiers = xvnc_get_modifiers,/g" -e "s/.get_drawable_modifiers\ =\ xvnc_get_drawable_modifiers,/\/\/.get_drawable_modifiers = xvnc_get_drawable_modifiers,/g" -i hw/vnc/dri3.c
silent make -j`nproc` KASMVNC_SRCDIR=$(dirname "$(dirname "$(pwd)")")
mv hw/vnc/Xvnc /usr/local/bin/
cd ../../..
rm -rf xorg-server-1.19.6.tar.gz



echo "Compiled"
EOL
chmod +x /root/compile.sh

cat > /root/install.sh << 'EOL'
silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }
echo "Installing"
cd /root

echo "installing x11 supports"
silent apt-get install --no-install-recommends debconf-utils -y
echo keyboard-configuration  keyboard-configuration/unsupported_config_options       boolean true | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/switch   select  No temporary switch | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/unsupported_config_layout        boolean true | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/layoutcode       string  us | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/compose  select  No compose key | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/modelcode        string  pc105 | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/unsupported_options      boolean true | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/variant  select  English \(US\) | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/unsupported_layout       boolean true | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/model    select  Generic 105-key PC \(intl.\) | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/ctrl_alt_bksp    boolean false | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/layout   select | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/toggle   select  No toggling | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/variantcode      string | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/altgr    select  The default for the keyboard layout | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/xkb-keymap       select  us | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/optionscode      string | debconf-set-selections >/dev/null 2>&1; \
echo keyboard-configuration  keyboard-configuration/store_defaults_in_debconf_db     boolean true | debconf-set-selections >/dev/null 2>&1

silent apt-get install --no-install-recommends keyboard-configuration xserver-xorg xinit xterm libgtk-3-0 libwebkit2gtk-4.0-37 -y

chmod u+s /usr/lib/xorg/Xorg
touch /home/tdl/.Xauthority /root/.Xauthority

silent apt-get install -y ssl-cert xauth x11-xkb-utils xkb-data procps libswitch-perl libyaml-tiny-perl libhash-merge-simple-perl libscalar-list-utils-perl liblist-moreutils-perl libtry-tiny-perl libdatetime-timezone-perl libdatetime-perl libgbm1
wget -q "https://github.com/kasmtech/KasmVNC/releases/download/v1.3.3/kasmvncserver_bullseye_1.3.3_amd64.deb" -O /tmp/kasmvncserver.deb
silent dpkg -x /tmp/kasmvncserver.deb /tmp/
mv /tmp/etc/kasmvnc /etc/
mv /tmp/usr/lib/kasmvncserver /usr/lib/
mv /tmp/usr/share/kasmvnc /usr/share/
mv /tmp/usr/share/perl5/KasmVNC /usr/share/perl5/

mkdir -p /root/.vnc
echo -e 'exec xterm' >> /root/.vnc/xstartup
chmod +x /root/.vnc/xstartup
echo -e "root:$(openssl passwd -5 -salt kasm vnc):w" >> /root/.kasmpasswd
touch /root/.vnc/.de-was-selected
echo -e 'network:
  protocol: http
  interface: 0.0.0.0
  websocket_port: 8444
  use_ipv4: true
  use_ipv6: true
  ssl:
    require_ssl: false' >> /root/.vnc/kasmvnc.yaml

rm -rf /tmp/kasmvncserver.deb /tmp/{etc,usr}

echo "Installed"

EOL
chmod +x /root/install.sh


echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
