############

silent() { "$@" >/dev/null 2>&1 || { echo "Error running: $*"; echo "sth error"; exit 1; }; }


debmirror=${1:-http://deb.debian.org/debian}
echo -e "deb ${debmirror} bookworm main\ndeb ${debmirror} bookworm-updates main\ndeb ${debmirror}-security bookworm-security main" > /etc/apt/sources.list

echo "Installing Dependencies"
silent apt-get update -y
silent apt-get install -y \
  curl \
  sudo \
  mc \
  gpg
echo "Installed Dependencies"

cat > /root/getsnapshot.sh << 'EOL'
#!/bin/bash

# iso release date
COMPARE_TS="2025-04-09T18:00:00Z"
compare_epoch=$(date -d "$COMPARE_TS" +"%s")

PACKAGES_URL="https://mirrors.ustc.edu.cn/proxmox/debian/pve/dists/bookworm/pve-no-subscription/binary-amd64/Packages"

: > pkg_names.txt

wget -q -O - "$PACKAGES_URL" \
| awk '
    /^Package:/ {pkg=$2}
    /^Version:/ {ver=$2}
    /^Filename:/ {file=$2; print pkg "|" ver "|" file}
' \
| sort -u \
| awk -F'|' '{print $1}' \
| sort | uniq \
| grep -Ev '(-dbgsym|-dev|-doc)$' \
| while read pkgname; do
    # 获取该包所有版本（不落地文件，直接管道处理），版本降序
    wget -q -O - "$PACKAGES_URL" \
    | awk -v name="$pkgname" '
        /^Package:/ {pkg=$2}
        /^Version:/ {ver=$2}
        /^Filename:/ {file=$2; print pkg "|" ver "|" file}
    ' \
    | awk -F'|' -v name="$pkgname" '$1==name' \
    | sort -t'|' -k2,2r \
    | while IFS="|" read -r pkg ver pool_path; do
        deb_dir=$(dirname "$pool_path")
        deb_file=$(basename "$pool_path")
        base="${deb_file%.deb}"
        base="${base%_*}"
        changelog_file="${base}.changelog"
        changelog_url="https://mirrors.ustc.edu.cn/proxmox/debian/pve/${deb_dir}/${changelog_file}"
        changelog=$(wget -q -O - "$changelog_url")
        changelog_line=$(echo "$changelog" | grep "Proxmox Support Team <support@proxmox.com>" | head -n 1)
        changelog_date=$(echo "$changelog_line" | awk -F'  ' '{print $NF}')
        file_epoch=""
        if [[ -n "$changelog_date" ]]; then
            date_str=$(echo "$changelog_date" | sed 's/+.*//')
            file_epoch=$(date -d "$date_str" +"%s" 2>/dev/null)
        fi
        if [[ -n "$file_epoch" ]] && [[ "$file_epoch" -lt "$compare_epoch" ]]; then
            echo "$pkgname=$ver"
            echo "$pkgname=$ver" >> pkg_names.txt
            break
        fi
    done
done
EOL
chmod +x /root/getsnapshot.sh

cat > /root/start.sh << 'EOL'
#!/bin/bash

curl -fsSL https://mirrors.ustc.edu.cn/proxmox/debian/proxmox-release-bookworm.gpg | gpg --dearmor  -o /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
#echo "deb https://mirrors.ustc.edu.cn/proxmox/debian/devel bookworm main" >/etc/apt/sources.list.d/pvedevel.list
echo "deb https://mirrors.ustc.edu.cn/proxmox/debian/pve bookworm pve-no-subscription" >/etc/apt/sources.list.d/pvenosub.list
apt-get update

echo "Installing"


cd /root

# 你的目标包名列表(24)
TARGETS="libproxmox-acme-perl libproxmox-rs-perl libpve-access-control libpve-apiclient-perl libpve-cluster-api-perl libpve-cluster-perl libpve-common-perl libpve-guest-common-perl libpve-http-server-perl libpve-rs-perl libpve-storage-perl libpve-u2f-server-perl librados2-perl proxmox-archive-keyring proxmox-ve proxmox-widget-toolkit pve-cluster pve-container pve-docs pve-firewall pve-ha-manager pve-i18n pve-manager qemu-server"

# 生成所有命中的 包名=版本 列表
pkgs_to_install=$(awk -F'=' '
    BEGIN {
        split("'"$TARGETS"'", t, " ");
        for(i in t) targets[t[i]]=1
    }
    targets[$1]
' pkg_names.txt)

if [[ -n "$pkgs_to_install" ]]; then
    echo "$pkgs_to_install"
    sudo apt-get install --no-install-recommends $pkgs_to_install
else
    echo "未找到匹配的包，无需安装。"
fi


echo "Installed"
EOL
chmod +x /root/start.sh

echo "Cleaning up"
silent apt-get -y autoremove
silent apt-get -y autoclean
echo "Cleaned"

###############
