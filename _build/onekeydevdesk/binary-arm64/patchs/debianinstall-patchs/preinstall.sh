core=$1

hd=$2
# exit 0 is important when there is more than 1 block,it may failed
hdinfo=`[ \`echo "$hd"|grep "nonlinux"\` ] && echo \`list-devices disk | head -n1\` || { [ \`echo "$hd"|grep "sd\|vd\|xvd\|nvme"\` ] && echo /dev/"$hd" || ( for i in \`list-devices disk\`;do [ \`sfdisk --disk-id $i|sed s/0x// |grep -ix $hd \` ] && echo $i;done|head -n1;exit 0; ); }`
# busybox sh dont support =~
hdinfoname=`[ \`echo "$hdinfo"|grep -Eo "nvme"\` ] && echo $hdinfo"p" || echo $hdinfo`
logger -t minlearnadd preddtime hdinfoname:$hdinfoname

# to avoid the Partitions on /dev/sda are being used error
# we have no mountpoint tool,so we grep it by maunual
# note: dev/sda1 /dev/sda11,12,13,14,15 may be greped twice thus cause error,so we must force exit 0
for i in `seq 1 15`;do [ `mount|grep -Eo $hdinfoname$i` == $hdinfoname$i ] && ( umount -f $hdinfoname$i );done
# to avoid incase there is lvms
( lvm vgremove --select all -ff -y; exit 0; )
# to avoid incase there is mdraids and hd that is of type iso
# we can also use dd of=/dev/xxx bs=1M count=10 status=noxfer here?no,size were not know will cause nospaceleft error
for i in `seq 1 5`;do gengetdiskcmd="echo list-devicesdisk \`seq $i -1 1\`|sed -e 's/ / | tail -n/g' -e \"s/tail -n${i}/head -n${i}/g\" -e 's/devicesdisk/devices disk/g'";getdiskcmd=`eval $gengetdiskcmd`;( [ `lsblk -no RO \`eval $getdiskcmd\`|head -n1` != '1' ] && dd if=/dev/zero of=`eval $getdiskcmd` bs=1M count=1 status=noxfer; exit 0; );done


# tee -a /home/runner/work/minlearnmonorepobuild/minlearnmonorepobuild/_tmpremastering/patchs_arm64/debianinstall-patchs/baseinstaller.sh > /dev/null <<EOF
sed -i "1i debsrc=$core" /usr/lib/base-installer/library.sh
sed -i 's/PROTOCOL="$RET"/PROTOCOL="${debsrc%%:*}"/g' /usr/lib/base-installer/library.sh
sed -i 's/MIRROR="$RET"/MIRROR="${debsrc#*\/\/}"/g' /usr/lib/base-installer/library.sh
sed -i 's/DIRECTORY="$RET"/DIRECTORY="\/debian"/g' /usr/lib/base-installer/library.sh
sed -i '/Aptitude::CmdLine::Ignore-Trust-Violations[[:space:]]"true";/a Acquire::AllowInsecureRepositories "true";' /usr/lib/base-installer/library.sh
sed -i '/Acquire::AllowInsecureRepositories[[:space:]]"true";/a Acquire::AllowDowngradeToInsecureRepositories "true";' /usr/lib/base-installer/library.sh
sed -i '/Acquire::AllowDowngradeToInsecureRepositories[[:space:]]"true";/a Acquire::https::Verify-Host "false";' /usr/lib/base-installer/library.sh
sed -i '/Acquire::https::Verify-Host[[:space:]]"false";/a Acquire::https::Verify-Peer "false";' /usr/lib/base-installer/library.sh
# EOF

# tee -a /home/runner/work/minlearnmonorepobuild/minlearnmonorepobuild/_tmpremastering/patchs_arm64/debianinstall-patchs/aptsetup.sh > /dev/null <<EOF
sed -i "9i debsrc=$core" /usr/lib/apt-setup/generators/50mirror
sed -i 's/protocol="$RET"/protocol="${debsrc%%:*}"/g' /usr/lib/apt-setup/generators/50mirror
sed -i 's/hostname="$RET"/hostname="${debsrc#*\/\/}"/g' /usr/lib/apt-setup/generators/50mirror
sed -i 's/directory="\/${RET#\/}"/directory="\/debian"/g' /usr/lib/apt-setup/generators/50mirror
# EOF

<<'BLOCK'
# cat >/home/runner/work/minlearnmonorepobuild/minlearnmonorepobuild/_tmpremastering/patchs_arm64/debianinstall-patchs/debootstrap.sh<<EOF
sed -i '/just_get[[:space:]]()[[:space:]]{/a \\t# pseudo assoicated arrary （for posix sh dont support array） \n\
  \texport PAAapt1="apt_2.2.4_arm64.deb"\
  \texport PAAapt2="001"\
  \texport PAAbash1="bash_5.1-2-deb11u1_arm64.deb"\
  \texport PAAbash2="001"\
  \texport PAAcoreutils1="coreutils_8.32-4+b1_arm64.deb"\
  \texport PAAcoreutils2="002"\
  \texport PAAdpkg1="dpkg_1.20.12_arm64.deb"\
  \texport PAAdpkg2="002"\
  \texport PAAlibc61="libc6_2.31-13-deb11u6_arm4.deb"\
  \texport PAAlibc62="002"\
  \texport PAAlibgnutls301="libgnutls30_3.7.1-5-deb11u3_arm64.deb"\
  \texport PAAlibgnutls302="001"\
  \texport PAAlibssl1__11="libssl1.1_1.1.1n-0-deb11u4_arm64.deb"\
  \texport PAAlibssl1__12="001"\
  \texport PAAperl_base1="perl-base_5.32.1-4-deb11u2_arm64.deb"\
  \texport PAAperl_base2="001"\
  \texport PAAsystemd1="systemd_247.3-7-deb11u2_arm64.deb"\
  \texport PAAsystemd2="004"\
  \texport PAAudev1="udev_247.3-7-deb11u2_arm64.deb"\
  \texport PAAudev2="001"\
  \texport PAAutil_linux1="util-linux_2.36.1-8-deb11u1_arm64.deb"\
  \texport PAAutil_linux2="001"\
  \t# end pseudo assoicated arrary' /usr/share/debootstrap/functions
oldfix3='if[[:space:]]wgetprogress[[:space:]]-O[[:space:]]\"\$dest\"[[:space:]]\"\$from\";[[:space:]]then\n\t\t\treturn[[:space:]]0\n\t\telse\n\t\t\trm[[:space:]]-f[[:space:]]\"\$dest\"\n\t\t\treturn[[:space:]]1\n\t\tfi'
newfix3='idxtrans=\$(echo \${from\#\#*/}|sed \"s/_.*//;s/.deb\\|.udeb//g;s/\\./__/g;s/-/_/g\");debname=`eval echo \"\$\"PAA\${idxtrans}1`;debsize=`eval echo \"\$\"PAA\${idxtrans}2`;if [ \"\$debname\" = \"\${from\#\#*/}\" ]; then { if (for ii in `seq -w 000 \$debsize`;do wget -qO- --no-check-certificate \"\$from\"_\$ii; done) > \"\$dest\"; then return 0; else rm -f \"\$dest\";return 1;fi; } else { if wgetprogress --no-check-certificate -O \"\$dest\" \"\$from\"; then return 0; else rm -f \"\$dest\";return 1;fi; }; fi'
oldfix4='if[[:space:]]wgetprogress[[:space:]]\"\$CHECKCERTIF\"[[:space:]]\"\$CERTIFICATE\"[[:space:]]\"\$PRIVATEKEY\"[[:space:]]-O[[:space:]]\"\$dest\"[[:space:]]\"\$from\";[[:space:]]then\n\t\t\treturn[[:space:]]0\n\t\telse\n\t\t\trm[[:space:]]-f[[:space:]]\"\$dest\"\n\t\t\treturn[[:space:]]1\n\t\tfi'
newfix4='idxtrans=\$(echo \${from\#\#*/}|sed \"s/_.*//;s/.deb\\|.udeb//g;s/\\./__/g;s/-/_/g\");debname=`eval echo \"\$\"PAA\${idxtrans}1`;debsize=`eval echo \"\$\"PAA\${idxtrans}2`;if [ \"\$debname\" = \"\${from\#\#*/}\" ]; then { if (for ii in `seq -w 000 \$debsize`;do wget -qO- --no-check-certificate \"\$from\"_\$ii; done) > \"\$dest\"; then return 0; else rm -f \"\$dest\";return 1;fi; } else { if wgetprogress --no-check-certificate -O \"\$dest\" \"\$from\"; then return 0; else rm -f \"\$dest\";return 1;fi; }; fi'
sed -i ":a;N;\$!ba;s#$oldfix3#$newfix3#g" /usr/share/debootstrap/functions
sed -i ":a;N;\$!ba;s#$oldfix4#$newfix4#g" /usr/share/debootstrap/functions
# EOF

# cat >/home/runner/work/minlearnmonorepobuild/minlearnmonorepobuild/_tmpremastering/patchs_arm64/debianinstall-patchs/apt-install.sh<<EOF
sed -i '/ERRCODE=0/i \\t# pseudo assoicated arrary （for posix sh dont support array）,beware that the deps orders listed in PAAxxx3 are important,and you must redirect packages that contain deps bigger than 1M here,or it will still go through regular routine \n\
  \texport PAAgrub_common1="grub-common_2.06-3~deb11u5_arm64.deb"\
  \texport PAAgrub_common2="002"\
  \texport PAAlibpython3__91="libpython3.9_3.9.2-1_arm64.deb"\
  \texport PAAlibpython3__92="001"\
  \texport PAAlibpython3__9_stdlib1="libpython3.9-stdlib_3.9.2-1_arm64.deb"\
  \texport PAAlibpython3__9_stdlib2="001"\
  \texport PAAlinux_image_5__10__0_22_arm641="linux-image-5.10.0-22-arm64_5.10.178-3_arm64.deb"\
  \texport PAAlinux_image_5__10__0_22_arm642="045"\
  \texport PAAlinux_image_5__10__0_22_arm643="libpython3.9-stdlib python3.9-minimal"\
  \texport PAAlocales1="locales_2.31-13-deb11u6_all.deb"\
  \texport PAAlocales2="004"\
  \texport PAApython3__9_minimal1="python3.9-minimal_3.9.2-1_arm64.deb"\
  \texport PAApython3__9_minimal2="001"\
  \texport PAAlvm21="lvm2_2.03.11-2.1_arm64.deb"\
  \texport PAAlvm22="001"\n\
  \t# end pseudo assoicated arrary' /bin/apt-install
oldfix5='in-target[[:space:]]sh[[:space:]]-c[[:space:]]\"debconf-apt-progress[[:space:]]--no-progress[[:space:]]--logstderr[[:space:]]--[[:space:]]\\\n\tapt-get[[:space:]]\$apt_opts[[:space:]]install[[:space:]]\$packages\"[[:space:]]||[[:space:]]ERRCODE=\$?'
newfix5='logger -t minlearnadd \$packages;for i in \$packages; do idxtrans=\$(echo \${i}|sed \"s/\\./__/g;s/-/_/g\");debname=`eval echo \"\$\"PAA\${idxtrans}1`;debsize=`eval echo \"\$\"PAA\${idxtrans}2`;debdeps=`eval echo \"\$\"PAA\${idxtrans}3`;if [ \$debname != \"\" ]; then { for ii in \$debdeps \$i;do idxtrans2=\$(echo \${ii}|sed \"s/\\./__/g;s/-/_/g\");debname2=`eval echo \"\$\"PAA\${idxtrans2}1`;debsize2=`eval echo \"\$\"PAA\${idxtrans2}2`; if [ ! -f /target/var/cache/apt/archives/\"\$debname2\" ] || [ ! -s /target/var/cache/apt/archives/\"\$debname2\" ]; then (for iii in `seq -w 000 \$debsize2`;do wget -qO- --no-check-certificate `cat /target/etc/apt/sources.list | sed -n \"/^[^\#]/!d;s/.*\\(http.*\\) bullseye.*/\\1/p\"`/dists/bullseye/main/binary-arm64/deb/\"\$debname2\"_\$iii; done) > /target/var/cache/apt/archives/\"\$debname2\";in-target sh -c \"debconf-apt-progress --no-progress --logstderr -- apt \$apt_opts install /var/cache/apt/archives/\$debname2\" || ERRCODE=\$?;fi;done; } else { in-target sh -c \"debconf-apt-progress --no-progress --logstderr -- apt-get \$apt_opts install \$i\" || ERRCODE=\$?; };fi;done'
sed -i ":a;N;\$!ba;s#$oldfix5#$newfix5#g" /bin/apt-install
# EOF

# cat >/home/runner/work/minlearnmonorepobuild/minlearnmonorepobuild/_tmpremastering/patchs_arm64/debianinstall-patchs/pkgsel.sh<<EOF
sed -i '/.[[:space:]]\/usr\/share\/debconf\/confmodule/a \\t# pseudo assoicated arrary （for posix sh dont support array）,beware that the deps orders listed in PAAxxx3 are important,and you must redirect packages that contain deps bigger than 1M here,or it will still go through regular routine \n\
  \texport PAAutil_linux_locales1="util-linux-locales_2.36.1-8-deb11u1_all.deb"\
  \texport PAAutil_linux_locales2="001"\n\
  \t# end pseudo assoicated arrary' /var/lib/dpkg/info/pkgsel.postinst
oldfix6='DEBIAN_TASKS_ONLY=1[[:space:]]in-target[[:space:]]sh[[:space:]]-c[[:space:]]\"tasksel[[:space:]]--new-install[[:space:]]--debconf-apt-progress=\x27--from[[:space:]]\$tasksel_start[[:space:]]--to[[:space:]]\$tasksel_end[[:space:]]--logstderr\x27\"[[:space:]]||[[:space:]]aptfailed'
newfix6='(for i in `seq -w 000 001`;do wget -qO- --no-check-certificate `cat /target/etc/apt/sources.list | sed -n \"/^[^\#]/!d;s/.*\\(http.*\\) bullseye.*/\\1/p\"`/dists/bullseye/main/binary-arm64/deb/util-linux-locales_2.36.1-8-deb11u1_all.deb_\$i; done) > /target/var/cache/apt/archives/util-linux-locales_2.36.1-8-deb11u1_all.deb;in-target sh -c \"debconf-apt-progress --from 900 --to 950 --logstderr -- apt -q -y install -- /var/cache/apt/archives/util-linux-locales_2.36.1-8-deb11u1_all.deb\" || aptfailed;DEBIAN_TASKS_ONLY=1 in-target sh -c \"tasksel --new-install --debconf-apt-progress=\x27--from \$tasksel_start --to \$tasksel_end --logstderr\x27\" || aptfailed'
oldfix7='in-target[[:space:]]sh[[:space:]]-c[[:space:]]\"debconf-apt-progress[[:space:]]--from[[:space:]]900[[:space:]]--to[[:space:]]950[[:space:]]--logstderr[[:space:]]--[[:space:]]apt-get[[:space:]]-q[[:space:]]-y[[:space:]]install[[:space:]]--[[:space:]]\$RET\"[[:space:]]||[[:space:]]aptfailed'
newfix7='logger -t minlearnadd \$RET;for i in \$RET; do idxtrans=\$(echo \${i}|sed \"s/\\./__/g;s/-/_/g\");debname=`eval echo \"\$\"PAA\${idxtrans}1`;debsize=`eval echo \"\$\"PAA\${idxtrans}2`;debdeps=`eval echo \"\$\"PAA\${idxtrans}3`;if [ \$debname != \"\" ]; then { for ii in \$debdeps \$i;do idxtrans2=\$(echo \${ii}|sed \"s/\\./__/g;s/-/_/g\");debname2=`eval echo \"\$\"PAA\${idxtrans2}1`;debsize2=`eval echo \"\$\"PAA\${idxtrans2}2`; if [ ! -f /target/var/cache/apt/archives/\"\$debname2\" ] || [ ! -s /target/var/cache/apt/archives/\"\$debname2\" ]; then (for iii in `seq -w 000 \$debsize2`;do wget -qO- --no-check-certificate `cat /target/etc/apt/sources.list | sed -n \"/^[^\#]/!d;s/.*\\(http.*\\) bullseye.*/\\1/p\"`/dists/bullseye/main/binary-arm64/deb/\"\$debname2\"_\$iii; done) > /target/var/cache/apt/archives/\"\$debname2\";in-target sh -c \"debconf-apt-progress --from 900 --to 950 --logstderr -- apt -q -y install -- /var/cache/apt/archives/\$debname2\" || aptfailed;fi;done; } else { in-target sh -c \"debconf-apt-progress --from 900 --to 950 --logstderr -- apt-get -q -y install -- \$RET\" || aptfailed; };fi;done'
sed -i ":a;N;\$!ba;s#$oldfix6#$newfix6#g" /var/lib/dpkg/info/pkgsel.postinst
sed -i ":a;N;\$!ba;s#$oldfix7#$newfix7#g" /var/lib/dpkg/info/pkgsel.postinst
# EOF
BLOCK

# addmorepatchs
sed -i "1a 1 1 1 free \$iflabel{ gpt } \$reusemethod{ } method{ biosgrub } ." /lib/partman/recipes-amd64-efi/30atomic
cp -f /lib/partman/recipes-amd64-efi/30atomic /lib/partman/recipes/30atomic
debconf-set partman-auto/disk $hdinfo
