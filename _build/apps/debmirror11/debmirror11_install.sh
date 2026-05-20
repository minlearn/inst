###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bullseye main\ndeb ${debmirror} bullseye-updates main\ndeb ${debmirror}-security bullseye-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get -y install debmirror rsync


cat > /root/sync_full.sh << 'EOL'

host="snapshot.debian.org"
distroots=(
    "bullseye,bullseye-updates,bullseye-backports::archive/debian/20231007T024024Z"
    "bullseye-security::archive/debian-security/20231007T024024Z"
)
arch="amd64,arm64"
section="main,contrib,non-free,main/debian-installer"

cd /root
rm -rf 20231007T024024Z
mkdir -p 20231007T024024Z

echo "Syncing snapshot date: 20231007T024024Z"
# nocleanup is important for a full sync
for distroot in "${distroots[@]}"; do
    IFS='::' read -r dist root <<< "$distroot"
    debmirror \
        --arch="$arch" \
        --dist="$dist" \
        --section="$section" \
        --method=https \
        --host="$host" \
        --root="$root" \
        --nosource \
        --no-check-gpg \
        --progress \
        --nocleanup \
        20231007T024024Z
done
echo "Sync completed for snapshot date: 20231007T024024Z"

EOL
chmod +x /root/sync_full.sh

cat > /root/sync_mini.sh << 'EOL'

host="snapshot.debian.org"
distroots=(
    "bullseye,bullseye-updates::archive/debian/20231007T024024Z"
    "bullseye-security::archive/debian-security/20231007T024024Z"
)
arch="amd64,arm64"
section="main,main/debian-installer"

cd /root
rm -rf 20231007T024024Z
mkdir -p 20231007T024024Z

echo "Syncing snapshot date: 20231007T024024Z"
# nocleanup is important for a full sync
for distroot in "${distroots[@]}"; do
    IFS='::' read -r dist root <<< "$distroot"
    debmirror \
        --arch="$arch" \
        --dist="$dist" \
        --section="$section" \
        --method=https \
        --host="$host" \
        --root="$root" \
        --nosource \
        --no-check-gpg \
        --progress \
        --nocleanup \
        20231007T024024Z
done
echo "Sync completed for snapshot date: 20231007T024024Z"

EOL
chmod +x /root/sync_mini.sh

cat > /root/sync_base_amd64_tar.sh << 'EOL'

host="snapshot.debian.org"
distroots=(
    "bullseye,bullseye-updates::archive/debian/20231007T024024Z"
    "bullseye-security::archive/debian-security/20231007T024024Z"
)
arch="amd64"
section="main,main/debian-installer"

cd /root
rm -rf 20231007T024024Z
mkdir -p 20231007T024024Z

echo "Syncing snapshot date: 20231007T024024Z"
# nocleanup is important for a full sync
for distroot in "${distroots[@]}"; do
    IFS='::' read -r dist root <<< "$distroot"
    debmirror \
        --arch="$arch" \
        --dist="$dist" \
        --section="$section" \
        --method=https \
        --host="$host" \
        --root="$root" \
        --nosource \
        --no-check-gpg \
        --progress \
        --nocleanup \
        20231007T024024Z
done
echo "Sync completed for snapshot date: 20231007T024024Z"

tar --exclude='.temp' --remove-files -cvf 20231007T024024Z.tar 20231007T024024Z
find 20231007T024024Z -type d -empty -delete

EOL
chmod +x /root/sync_base_amd64_tar.sh

cat > /root/sync_base_arm64_tar.sh << 'EOL'

host="snapshot.debian.org"
distroots=(
    "bullseye,bullseye-updates::archive/debian/20231007T024024Z"
    "bullseye-security::archive/debian-security/20231007T024024Z"
)
arch="arm64"
section="main,main/debian-installer"

cd /root
rm -rf 20231007T024024Z
mkdir -p 20231007T024024Z

echo "Syncing snapshot date: 20231007T024024Z"
# nocleanup is important for a full sync
for distroot in "${distroots[@]}"; do
    IFS='::' read -r dist root <<< "$distroot"
    debmirror \
        --arch="$arch" \
        --dist="$dist" \
        --section="$section" \
        --method=https \
        --host="$host" \
        --root="$root" \
        --nosource \
        --no-check-gpg \
        --progress \
        --nocleanup \
        20231007T024024Z
done
echo "Sync completed for snapshot date: 20231007T024024Z"

tar --exclude='.temp' --remove-files -cvf 20231007T024024Z.tar 20231007T024024Z
find 20231007T024024Z -type d -empty -delete

EOL
chmod +x /root/sync_base_arm64_tar.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
