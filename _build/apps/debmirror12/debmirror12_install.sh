###############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=http://snapshot.debian.org/archive/debian/20250425T203925Z
echo -e "deb ${debmirror} bookworm main\ndeb ${debmirror} bookworm-updates main\ndeb ${debmirror/debian\//debian-security\/} bookworm-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -o Acquire::Check-Valid-Until=false -y
silent apt-get install -y curl sudo mc
echo "Installed Dependencies"

silent apt-get -y install debmirror rsync


cat > /root/sync_full.sh << 'EOL'

host="snapshot.debian.org"
distroots=(
    "bookworm,bookworm-updates,bookworm-backports::archive/debian/20250425T203925Z"
    "bookworm-security::archive/debian-security/20250425T203925Z"
)
arch="amd64,arm64"
section="main,contrib,non-free,main/debian-installer"

cd /root
rm -rf 20250425T203925Z
mkdir -p 20250425T203925Z

echo "Syncing snapshot date: 20250425T203925Z"
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
        20250425T203925Z
done
echo "Sync completed for snapshot date: 20250425T203925Z"

EOL
chmod +x /root/sync_full.sh

cat > /root/sync_mini.sh << 'EOL'

host="snapshot.debian.org"
distroots=(
    "bookworm,bookworm-updates::archive/debian/20250425T203925Z"
    "bookworm-security::archive/debian-security/20250425T203925Z"
)
arch="amd64,arm64"
section="main,main/debian-installer"

cd /root
rm -rf 20250425T203925Z
mkdir -p 20250425T203925Z

echo "Syncing snapshot date: 20250425T203925Z"
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
        20250425T203925Z
done
echo "Sync completed for snapshot date: 20250425T203925Z"

EOL
chmod +x /root/sync_mini.sh

cat > /root/sync_base_amd64_tar.sh << 'EOL'

host="snapshot.debian.org"
distroots=(
    "bookworm,bookworm-updates::archive/debian/20250425T203925Z"
    "bookworm-security::archive/debian-security/20250425T203925Z"
)
arch="amd64"
section="main,main/debian-installer"

cd /root
rm -rf 20250425T203925Z
mkdir -p 20250425T203925Z

echo "Syncing snapshot date: 20250425T203925Z"
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
        20250425T203925Z
done
echo "Sync completed for snapshot date: 20250425T203925Z"

tar --exclude='.temp' --remove-files -cvf 20250425T203925Z.tar 20250425T203925Z
find 20250425T203925Z -type d -empty -delete

EOL
chmod +x /root/sync_base_amd64_tar.sh

cat > /root/sync_base_arm64_tar.sh << 'EOL'

host="snapshot.debian.org"
distroots=(
    "bookworm,bookworm-updates::archive/debian/20250425T203925Z"
    "bookworm-security::archive/debian-security/20250425T203925Z"
)
arch="arm64"
section="main,main/debian-installer"

cd /root
rm -rf 20250425T203925Z
mkdir -p 20250425T203925Z

echo "Syncing snapshot date: 20250425T203925Z"
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
        20250425T203925Z
done
echo "Sync completed for snapshot date: 20250425T203925Z"

tar --exclude='.temp' --remove-files -cvf 20250425T203925Z.tar 20250425T203925Z
find 20250425T203925Z -type d -empty -delete

EOL
chmod +x /root/sync_base_arm64_tar.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

##############
