#!/usr/bin/env bash

## build and deploy your cloud hyper/cde/lang with one keystoke
## Free,Written By MoeClub.org and linux-live.org,moded and enhanced by minlearn (https://github.com/minlearn/inst/) for 1, ddprogress fix in raw/native bash 2, onekeydevdesk remastering and installing (both local install and cloud wgetdd/ncdd) as its recovery 3, and for self-contained git mirror/image hosting (both debian and system img) 4, and for multiple machine type and models supports.
## meant to work/tested under debian family linux with bash > 4, ubuntu less than 20.04
## usage: build.sh [[-b 0 ] -h 0[,az...]|az|sr|ks|orc|mbp -a 0|1|0,1 -g 0|1|2|0,1,2] -t debianbase|onekeydevdesk|devdeskos[,+lxcxxx/++lxcxxx...]|lxcxxx [-d/-c 1] # no+ lxcxxx: pure standalone pack mode,+: mergemode into 01-core,++: packmode into 01-core
## usage: wget -qO- https://github.com/minlearn/inst/raw/master/inst.sh | bash [ -s - [-t debian | your .gz http/https location | nc://:port:ip:blkname for ncrev | nc://:port:blkname for ncsend ] [-d]]
## for win,download and install cygwin installler and grub2win installer and setup them

#[[ ! "$(bash --version | head -n 1 | grep -o '[1-9]'| head -n 1)" -ge '4' ]] && echo "Error:bash must be at least 4!" && exit 1
[[ "$(uname -a)" =~ "inux" && "$(uname -a)" =~ "entos" ]] && echo "requires debian or ubuntu" && exit 1
#[[ "$(uname -a)" =~ "inux" && "$(uname -a)" =~ "ebian" && $(echo $(lsb_release -sr) | awk -F '.' '{print($1)}') -ge '11' ]] && echo "requires debian 10 or below,ubt 18 or below" && exit 1
#[[ "$(uname -a)" =~ "inux" && "$(uname -a)" =~ "buntu" && $(echo $(lsb_release -sr) | awk -F '.' '{print($1)}') -ge '20' ]] && echo "requires debian 10 or below,ubt 18 or below" && exit 1
# [[ ! "$(uname -a)" =~ "inux" ]] && echo "unsupported os" && exit 1

[[ "$(uname)" == "Darwin" ]] && tmptmpBUILD='1'
[[ -f /cygdrive/c/cygwin64/bin/uname && ( "$(/cygdrive/c/cygwin64/bin/uname -o)" == "Cygwin" || "$(/cygdrive/c/cygwin64/bin/uname -o)" == "Msys") ]] && tmptmpBUILD='11'
[[ "$(command -v systemd-detect-virt)" && "$(systemd-detect-virt)" == "openvz" ]] && tmptmpCTVIRTTECH='1'

# for wget -qO- xxx| bash -s - subsitute manner
[[ "$tmptmpBUILD" != "1" && "$tmptmpBUILD" != "11" ]] && [ "$(id -u)" != 0 ] && exec sudo bash -c "`cat -`" -a "$@"
# for bash <(wget -qO- xxx) -t subsitute manner we should:
# [ "$(id -u)" != 0 ] && exec sudo bash -c "`cat "$0"`" -a "$@"
[[ "$tmptmpBUILD" != "1" && "$tmptmpBUILD" != "11" ]] && [[ "$EUID" -ne '0' ]] && echo "Error:This script must be run as root!" && exit 1

# =================================================================
# globals
# =================================================================

forcemaintainmode='0'                             # 0:all put in maintain,1,just devdeskos in maintain

export autoDEBMIRROR0=https://github.com/minlearn/inst/raw/master
export autoDEBMIRROR1=https://gitee.com/minlearn/inst/raw/master
export FORCEDEBMIRROR=''                          # force apply a fixed mirror/targetddurl selection to force override autoselectdebmirror results based on -t -m args given
export tmpTARGETMODE='0'                          # 0:WGETDD INSTMODE ONLY 1:CLOUDDDINSTALL+BUILD MIXTURE,2,3,nc install mode,defaultly it sholudbe 0, 4 inplace dd mode for debianctmu(lxcct,or kvmct) or debiandemu
export tmpTARGET=''                               # dummy(for -d only),debianbase,onekeydevdesk,devdeskos,lxcdebtpl,lxcdebiantpl,qemudebtpl,qemudebiantpl,devdeskosfull,debian,debian10restore,debianct,debiandemu,debianctmu

# part I: settings related instmode,most usually are auto informed,not customable
export setNet='0'                                 # auto informed by judging if forcenetcfgstring are feed
export AutoNet=''                                 # auto informed by judging ifsetnet and if netcfgfile has the static keyword, has value 1,2
export FORCE1STNICNAME=''                         # sometimes 1stnicnames are fixed,we force set this to avoid exceptions
export FORCENETCFGSTR=''                          # sometimes gateway and defroute and not in the same subnet,they shoud be manual explict set, azure use the hostname and dsm use the mac
export FORCEPASSWORD='0'                          # this password can be password to be embeded into target, or password that is originally embeded into the src (windows os) image,0: auto
export FORCENETCFGV6ONLY=''                       # force ipv6only stack probe in netcfg overall possiblities
export FORCEMIRRORIMGSIZE=''                      # force apply a fixed mirror/targetddimgsize to force checktargeturl results based on -s args given
export FORCEMIRRORIMGNOSEG=''                     # force apply the imgfile in both debmirrorsrc and imgmirrorsrc as non-seg git repo style,set to 1 to use common one-piece style
export FORCE1STHDNAME=''                          # sometimes 1sthdname that being installed to are fixed,we force set this to avoid exceptions
export FORCEGRUBTYPE=''                           # do we use this?
export FORCEINSTCTL='0'                           # instcontrol,0:auto(with autohdexp,autonetcfginject,autoreboot),1:pure dd,without auto hd exp,2:pure dd,without networkcfg injection,3:hold without reboot,4: without pre clean just umount
export tmpINSTSERIAL='0'                          # 0 with serial console output support
export tmpINSTSSHONLY='0'

# part II: customables related with buildmode,initrfs,01-core,clients,lxcapps
export tmpBUILD='0'                               # 0:linux,1:unix,osx,2,lxc
export tmpBUILDGENE='0'                           # 0:biosmbr,1:biosgpt,2:uefigpt,used both in buildtime(0or1or2,0and1and2) and insttime(0or1or2)
export tmpBUILDPUTPVEINIFS='0'                    # put pve building prodcure inside initramfs? defaultly no
export tmpHOST=''                                 # (blank)0,az,servarica(sr),(kimsurf/ovh/sys)ks,orc,bwg10g512m,mbp,pd
export tmpHOSTMODEL='0'                           # 0:kvm,1:hv,2:xen,>2:bearmetal,auto informed,not customable,0:awlays bothmode,1-98:instonlymode,99,mixed build mode
export HOSTMODLIST='0'
export tmpHOSTARCH='0'                            # 0,x86-64,1,arm64,used both in buildtime（0or1singlearchonlymode，0and1fullarchmode） and insttime（0or1singlearchonlymode）
export tmpCTVIRTTECH='0'                          # 0,no virt tech,1,lxc,2,kvm
export custIMGSIZE='10'
export custUSRANDPASS='tdl'
export tmpTGTNICNAME='eth0'
export tmpTGTNICIP='111.111.111.111'              # pve only,input target nic public ip(127.0.0.1 and 127.0.1.1 forbidden,enter to use defaults 111.111.111.111)
export tmpWIFICONNECT='CMCC-xxx,11111111,wlan0'   # input target wifi connecting settings(in valid hotspotname,hotspotpasswd,wifinicname form,passwd 8-63 long,enter to leave blank)
export GENCLIENTS='y'                             # linux,win,osx
export GENCLIENTSWINOSX='n'
export PACKCLIENTS='n'
export tmpEBDCLIENTURL='xxx.com'                  # input target ip or domain that will be embeded into client
export GENCONTAINERS=''                           # list for mergemode into 01-core
export PACKCONTAINERS=''                          # list packmode into 01-core

# part III: debug and ci/cd extra addons, debug and ci cant coexists in a single subtitute
export tmpDEBUG='0'                               # 0,debug=manualmode in instmode, or special initramfsgen and localinst boot test in buildmode
export tmpDRYRUNREMASTER='0'                      # 0,use dryrunmode,wont mod grub? exists but dreprecated, we use ctlc sigint to do it
export tmpINSTWITHMANUAL='0'                      # 0,enter manual mode, for debugging purpose,will force reboot to a network-console
export tmpBUILDINSTTEST='0'                       # inst test after initramfs gened
export tmpBUILDADDONS='0'                         # full build mode,with split post addon actions,0，no addons,1,normal buildaddons for 1keyddbuild 2,buildaddons for lxc*build standalone

# =================================================================
# Below are function libs
# =================================================================

function prehint0(){

  [ -d /sys/firmware/efi ] && echo -n u, || echo -n b,;
  [[ "$tmptmpBUILD" != "11" && "$tmptmpBUILD" != "1" ]] && { [[ "$(find /sys/class/net/ -type l ! -lname '*/devices/virtual/net/*' |  wc -l)" -lt 2 ]] && echo -n "i:1," || echo -n "i:>1,"; } || echo -n "i:d,"
  [[ "$tmptmpBUILD" != "11" && "$tmptmpBUILD" != "1" ]] && { [[ "$(lsblk -e 7 -e 11 -d | tail -n+2 | wc -l)" -lt 2 ]] && echo -n "p:1" || echo -n "p:>1"; } || echo -n "p:d"

}

function prehint4(){

  [[ "$tmptmpBUILD" != "1" && "$tmptmpBUILD" != "11" && "$tmptmpCTVIRTTECH" != "1" ]] && {
    DEFAULTWORKINGNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    [[ -z "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGNIC="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; };
    [[ -n "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGIPSUBV4="$(ip addr |grep ''${DEFAULTWORKINGNIC}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";[[ -z "$DEFAULTWORKINGIPSUBV4" ]] && DEFAULTWORKINGIPSUBV4="$(ip addr |grep ''${DEFAULTWORKINGNIC}'' |grep 'global' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')"; };
    DEFAULTWORKINGGATEV4="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";
    [[ -n "$DEFAULTWORKINGIPSUBV4" ]] && [[ -n "$DEFAULTWORKINGGATEV4" ]] && echo -n $DEFAULTWORKINGIPSUBV4,$DEFAULTWORKINGGATEV4 || echo -n 'no default working ipv4';
  };

  [[ "$tmptmpBUILD" != "1" && "$tmptmpCTVIRTTECH" != "11" && "$tmptmpCTVIRTTECH" == "1" ]] && {
    DEFAULTWORKINGNIC="$(awk '$2 == 00000000 { print $1 }' /proc/net/route)";
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGIPSUBV4="$(ip addr show dev ''${DEFAULTWORKINGNIC}'' | sed -nE '/global/s/.*inet (.+) brd.*$/\1/p' | head -n 1)";
    DEFAULTWORKINGGATEV4="locallink";
    [[ -n "$DEFAULTWORKINGIPSUBV4" ]] && [[ -n "$DEFAULTWORKINGGATEV4" ]] && echo -n $DEFAULTWORKINGIPSUBV4,$DEFAULTWORKINGGATEV4 || echo -n 'no default working ipv4';
  };

  [[ "$tmptmpBUILD" == "11" ]] && {
    DEFAULTWORKINGNICIDX="$(netsh int ipv4 show route | grep --text -F '0.0.0.0/0' | awk '$6 ~ /\./ {print $5}')";
    [[ -z "$DEFAULTWORKINGNICIDX" ]] && { DEFAULTWORKINGNICIDX="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')"; };
    [[ -n "$DEFAULTWORKINGNICIDX" ]] && DEFAULTWORKINGIPV4=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`;
    DEFAULTWORKINGGATEV4=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`;
    DEFAULTWORKINGMASKV4=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'" get IPSubnet /format:list|sed 's/\r//g'|sed 's/IPSubnet={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`;
    [[ -n "$DEFAULTWORKINGIPV4" ]] && [[ -n "$DEFAULTWORKINGGATEV4" ]] && echo -n $DEFAULTWORKINGIPV4,$DEFAULTWORKINGGATEV4 || echo -n 'no default working ipv4';
  };

  [[ "$tmptmpBUILD" == "1" ]] && {
    DEFAULTWORKINGNIC="$(netstat -nr -f inet|grep default|awk '{print $4}')";
    [[ -z "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGNIC="$(netstat -nr -f inet6|grep default|awk '{print $4}' |head -n1)"; };
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGIPSUBV4="$(ifconfig ''${DEFAULTWORKINGNIC}'' |grep -Fv inet6|grep inet|awk '{print $2}')";
    DEFAULTWORKINGGATEV4="$(netstat -nr -f inet|grep default|grep ''${DEFAULTWORKINGNIC}'' |awk '{print $2}')";
    [[ -n "$DEFAULTWORKINGIPSUBV4" ]] && [[ -n "$DEFAULTWORKINGGATEV4" ]] && echo -n $DEFAULTWORKINGIPSUBV4,$DEFAULTWORKINGGATEV4 || echo -n 'no default working ipv4';
  };

}

function prehint61(){

  [[ "$tmptmpBUILD" != "1" && "$tmptmpBUILD" != "11" ]] && {
    DEFAULTWORKINGNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    [[ -z "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGNIC="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; };
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGIPSUBV6="$(ip -6 -brief address show scope global|grep ''${DEFAULTWORKINGNIC}'' |awk -F ' ' '{ print $3}')";
    [[ -n "$DEFAULTWORKINGIPSUBV6" ]] && echo -n $DEFAULTWORKINGIPSUBV6 || echo -n 'no default working v6ip';
  };

  [[ "$tmptmpBUILD" == "11" ]] && {
    DEFAULTWORKINGNICIDX="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')";
    [[ -n "$DEFAULTWORKINGNICIDX" ]] && DEFAULTWORKINGIPV6=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f2)`;
    [[ -n "$DEFAULTWORKINGIPV6" ]] && echo -n $DEFAULTWORKINGIPV6 || echo -n 'no default working v6ip';
  };

  [[ "$tmptmpBUILD" == "1" ]] && {
    DEFAULTWORKINGNIC="$(netstat -nr -f inet6|grep default|awk '{print $4}' |head -n1)";
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGIPSUBV6="$(ifconfig ''${DEFAULTWORKINGNIC}'' |grep inet6|head -n1|awk '{print $2}'|sed 's/%.*//g')";
    [[ -n "$DEFAULTWORKINGIPSUBV6" ]] && echo -n $DEFAULTWORKINGIPSUBV6 || echo -n 'no default working v6ip';
  };

}

function prehint62(){

  [[ "$tmptmpBUILD" != "1" && "$tmptmpBUILD" != "11" ]] && {
    DEFAULTWORKINGNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    [[ -z "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGNIC="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; };
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGGATEV6="$(ip -6 -brief route show default|grep ''${DEFAULTWORKINGNIC}'' |awk -F ' ' '{ print $3}')";
    [[ -n "$DEFAULTWORKINGGATEV6" ]] && echo -n $DEFAULTWORKINGGATEV6 || echo -n 'no default working v6gate';
  };

  [[ "$tmptmpBUILD" == "11" ]] && {
    DEFAULTWORKINGNICIDX="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')";
    [[ -n "$DEFAULTWORKINGNICIDX" ]] && DEFAULTWORKINGGATEV6=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f2)`;
    [[ -n "$DEFAULTWORKINGGATEV6" ]] && echo -n $DEFAULTWORKINGGATEV6 || echo -n 'no default working v6gate';
  };

  [[ "$tmptmpBUILD" == "1" ]] && {
    DEFAULTWORKINGNIC="$(netstat -nr -f inet6|grep default|awk '{print $4}' |head -n1)";
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGGATEV6="$(netstat -nr -f inet6|grep default|grep ''${DEFAULTWORKINGNIC}'' |awk '{ print $2}'|sed 's/%.*//g')";
    [[ -n "$DEFAULTWORKINGGATEV6" ]] && echo -n $DEFAULTWORKINGGATEV6 || echo -n 'no default working v6gate';
  };

}

function Outbanner(){

  [[ "$1" == 'wizardmode' ]] && echo -e "
`printf "#%0.s" {1..78}`

 Usage): wget -qO- inst.sh|bash  | \033[1;31m!!THIS SCIRPT MAY WIPE ALL DATA!!\033[0m \033[32m`[[ "$tmpTARGETMODE" != '1' && "$tmpBUILD" != '1' ]] && echo -n $(wget --no-check-certificate --no-verbose --content-on-error=on --timeout=1 --tries=2 -qO- 'https://counter.minlearn.org/api/dsrkafuu:demo'|grep -Eo [0-9]*[0-9])`\033[0m
 -----------------------------   | home): https://minlearn.org
  -t) target *  -m) debmirror    | repo): https://github.com/minlearn
  -n) staticnet -i) forcenic     | 
  -w) password  -p) forcehd      | [`prehint0`][`prehint4`]
  -o) postdd    -6) forceipv6    | [`prehint61`]
  -d) debug                      | [`prehint62`]

`printf "#%0.s" {1..78}`
"

}

function CheckDependence(){

  [[ "$tmpBUILD" == "11" || "$tmpBUILD" == "1" ]] && echo -en "[ \033[32m non linux,assume preinstalled \033[0m ]" && return;

  FullDependence='0';
  lostdeplist="";
  lostpkglist="";

  for BIN_DEP in `[[ "$tmpBUILD" -ne '0' ]] && echo "$1" |sed 's/,/\n/g' || echo "$1" |sed 's/,/\'$'\n''/g'`
    do
      if [[ -n "$BIN_DEP" ]]; then
        Founded='1';
        for BIN_PATH in `[[ "$tmpBUILD" -ne '0' ]] && echo "$PATH" |sed 's/:/\n/g' || echo "$PATH" |sed 's/:/\'$'\n''/g'`
          do
            ls $BIN_PATH/$BIN_DEP >/dev/null 2>&1;
            if [ $? == '0' ]; then
              Founded='0';
              break;
            fi
          done
        # detailed log under buildmode
        [[ "$tmpTARGET" == 'devdeskos' && "$tmpTARGETMODE" == '1' && "$tmpBUILD" != '1' ]]  && echo -en "\033[s[ \033[32m ${BIN_DEP:0:10}";
        if [ "$Founded" == '0' ]; then
          [[ "$tmpTARGET" == 'devdeskos' && "$tmpTARGETMODE" == '1' && "$tmpBUILD" != '1' ]]  && echo -en ",ok  \033[0m ]\033[u";
          :;
        else
          FullDependence='1';
          [[ "$tmpTARGET" == 'devdeskos' && "$tmpTARGETMODE" == '1' && "$tmpBUILD" != '1' ]]  && echo -en ",\033[31m miss \033[0m] ";
          # simple log under instmode
          #[[ "$tmpTARGETMODE" == '0' ]] && echo -en "[ \033[32m $BIN_DEP,\033[31m miss \033[0m] ";
          lostdeplist+=" $BIN_DEP";
        fi
      fi
  done

  [[ $lostdeplist =~ "sudo" ]] && lostpkglist+=" sudo"; \
  [[ $lostdeplist =~ "curl" ]] && lostpkglist+=" curl"; \
  [[ $lostdeplist =~ "ar" ]] && lostpkglist+=" binutils"; \
  [[ $lostdeplist =~ "cpio" ]] && lostpkglist+=" cpio"; \
  [[ $lostdeplist =~ "xzcat" ]] && lostpkglist+=" xz-utils"; \
  [[ $lostdeplist =~ "md5sum" || $lostdeplist =~ "sha1sum" || $lostdeplist =~ "sha256sum" || $lostdeplist =~ "df" ]] && lostpkglist+=" coreutils"; \
  [[ $lostdeplist =~ "losetup" ]] && lostpkglist+=" util-linux"; \
  [[ $lostdeplist =~ "fdisk" ]] && lostpkglist+=" fdisk"; \
  [[ $lostdeplist =~ "parted" ]] && lostpkglist+=" parted"; \
  [[ $lostdeplist =~ "mkfs.fat" ]] && lostpkglist+=" dosfstools"; \
  [[ $lostdeplist =~ "squashfs" ]] && lostpkglist+=" squashfs-tools"; \
  [[ $lostdeplist =~ "sqlite3" ]] && lostpkglist+=" sqlite3"; \
  [[ $lostdeplist =~ "unzip" ]] && lostpkglist+=" unzip"; \
  [[ $lostdeplist =~ "zip" ]] && lostpkglist+=" zip"; \
  [[ $lostdeplist =~ "7z" ]] && lostpkglist+=" p7zip"; \
  [[ $lostdeplist =~ "openssl" ]] && lostpkglist+=" openssl"; \
  [[ $lostdeplist =~ "virt-what" ]] && lostpkglist+=" virt-what"; \
  [[ $lostdeplist =~ "rsync" ]] && lostpkglist+=" rsync";

  [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ ! -f /usr/sbin/grub-reboot && ! -f /usr/sbin/grub2-reboot ]] && FullDependence='1' && lostdeplist+="grub2-common"  && lostpkglist+=" grub2-common"
  [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ "$FORCENETCFGV6ONLY" == '1' ]] && [[ ! -f /usr/bin/subnetcalc ]] && FullDependence='1' && lostdeplist+="subnetcalc"  && lostpkglist+=" subnetcalc"
  # [[ "$tmpBUILDGENE" == '1' && "$tmpTARGET" == 'devdeskos' && "$tmpTARGETMODE" == '1' ]] && [[ ! -f /usr/lib/grub/x86_64-efi/acpi.mod ]] && FullDependence='1' && lostdeplist+="grub-efi" && lostpkglist+=" grub-efi"

  if [ "$FullDependence" == '1' ]; then
    echo -en "[ \033[32m deps missing! perform autoinstall \033[0m ] ";
    apt-get update --allow-releaseinfo-change --allow-unauthenticated --allow-insecure-repositories -y -qq  >/dev/null 2>&1
    # use reinstall but not install, cause some pkgs maybe already there, but indeedly broken in bin/deps level(the bin were wrong delt)
    # dont use apt-get update && apt-get reinstall here,cause apt-get update may fail but actually run
    apt-get reinstall --no-install-recommends -y -qq `echo -n "$lostpkglist"` >/dev/null 2>&1
    [[ $? == '0' ]] && echo -en "[ \033[32m done. \033[0m ]" || { echo;echo -en "\033[31m $lostdeplist missing !error happen while autoinstall! please fix to run 'apt-get update && apt-get install $lostpkglist ' to install them\033[0m";exit 1; }
  else
    # simple log under instmode
    [[ "$tmpTARGETMODE" != '1' ]] && echo -en "[ \033[32m all,ok \033[0m ]";
  fi
}

function test_mirror() {

  SAMPLES=3
  BYTES=511999 #1mb
  TIMEOUT=1
  TESTFILE="/_build/1mtest"

  for s in $(seq 1 $SAMPLES) ; do
    # CheckPass1
    downloaded=$(curl -k -L -r 0-$BYTES --max-time $TIMEOUT --silent --output /dev/null --write-out %{size_download} ${1}${TESTFILE})
    if [ "$downloaded" == "0" ] ; then
      break
    else
      # CheckPass2
      time=$(curl -k -L -r 0-$BYTES --max-time $TIMEOUT --silent --output /dev/null --write-out %{time_total} ${1}${TESTFILE})
      echo $time
    fi
  done

}

function mean() {
  len=$#
  echo $* | tr " " "\n" | sort -n | head -n $(((len+1)/2)) | tail -n 1
}

osxbash_set_avar() { eval "$1_$2=\$3"; }
_get_avar() { eval "_AVAR=\$$1_$2"; }
osxbash_get_avar() { _get_avar "$@" && printf "%s\n" "$_AVAR"; }

function SelectDEBMirror(){

  [ $# -ge 1 ] || exit 1

  [[ "$tmpBUILD" != "1" ]] && {
  declare -A MirrorTocheck
  MirrorTocheck=(["Debian0"]="" ["Debian1"]="" ["Debian2"]="")
  
  echo "$1" |sed 's/\ //g' |grep -q '^http://\|^https://\|^ftp://' && MirrorTocheck[Debian0]=$(echo "$1" |sed 's/\ //g');
  echo "$2" |sed 's/\ //g' |grep -q '^http://\|^https://\|^ftp://' && MirrorTocheck[Debian1]=$(echo "$2" |sed 's/\ //g');
  #echo "$3" |sed 's/\ //g' |grep -q '^http://\|^https://\|^ftp://' && MirrorTocheck[Debian2]=$(echo "$3" |sed 's/\ //g');


  for mirror in `[[ "$tmpBUILD" -ne '0' ]] && echo "${!MirrorTocheck[@]}" |sed 's/\ /\n/g' |sort -n |grep "^Debian" || echo "${!MirrorTocheck[@]}" |sed 's/\ /\'$'\n''/g' |sort -n |grep "^Debian"`
    do
      CurMirror="${MirrorTocheck[$mirror]}"

      [ -n "$CurMirror" ] || continue

      mean=$(mean $(test_mirror $CurMirror))
      if [ "$mean" != "-nan" -a "$mean" != "" ] ; then
        printf '%-60s %.5f\\n' $CurMirror $mean
      # else
        # printf '%-60s failed, ignoring\\n' $CurMirror 1>&2
      fi

    done
  }

  [[ "$tmpBUILD" == "1" ]] && {
  osxbash_set_avar MirrorTocheck 1 $1
  osxbash_set_avar MirrorTocheck 2 $2
  osxbash_set_avar MirrorTocheck 3 $3
  for mirror in 1 2 3;do
  CurMirror=`osxbash_get_avar MirrorTocheck "$mirror"`
  [ -n "$CurMirror" ] || continue
  mean=$(mean $(test_mirror $CurMirror))
      if [ "$mean" != "-nan" -a "$mean" != "" ] ; then
        printf '%-60s %.5f\\n' $CurMirror $mean
      # else
        # printf '%-60s failed, ignoring\\n' $CurMirror 1>&2
      fi
    done
  }

}


function CheckTargeturl(){

  IMGSIZE=''
  UNZIP=''

  # $1 is always given as a effective url,no need to valicated anymore,just curl its header
  IMGHEADERCHECK="$(curl -k -IsL "$1")";

  # check imagesize
  #[[ -n "$IMGSIZE" && -z "$FORCEMIRRORIMGSIZE" ]] && TARGETDDIMGSIZE=$IMGSIZE
  #[[ -n "$IMGSIZE" && -n "$FORCEMIRRORIMGSIZE" ]] && TARGETDDIMGSIZE=$FORCEMIRRORIMGSIZE
  #IMGSIZE="$(echo "$IMGHEADERCHECK" | grep 'Content-Length'|awk '{print $2}')" || IMGSIZE=20
  IMGSIZE=20
  [[ "$IMGSIZE" == '' ]] && echo -en " \033[31m Didnt got img size,or img too small,is there sth wrong? exit! \033[0m " && exit 1;

  [[ "$tmpTARGET" =~ ":10000" ]] && IMGTYPECHECK="nc" || IMGTYPECHECK="$(echo "$IMGHEADERCHECK"|grep -E -o '200|302'|head -n 1)";

  [[ "$IMGTYPECHECK" != '' ]] && {
    [[ "$tmpTARGETMODE" == '4' && "$tmpBUILD" != '1' ]] && [[ "$tmpTARGET" == "debianct" || "$tmpTARGET" == "debianctmu" ]] && [[ "$IMGTYPECHECK" == '200' || "$IMGTYPECHECK" == '302' ]] && UNZIP='2' && { sleep 3 && echo -en "[ \033[32m inbuilt \033[0m ]"; }
    [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ "$tmpTARGET" == "devdeskos" || "$tmpTARGET" == "debian10r" ]] && [[ "$IMGTYPECHECK" == '200' || "$IMGTYPECHECK" == '302' ]] && sleep 3 && UNZIP='2' && echo -en "[ \033[32m inbuilt \033[0m ]"
    [[ "$tmpTARGETMODE" == '0' && "$IMGTYPECHECK" == 'nc' ]] && sleep 3 && UNZIP='1' && echo -en "[ \033[32m nc \033[0m ]"
    [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ "$tmpTARGET" != "devdeskos" && "$tmpTARGET" != "debian10r" ]] && [[ "$IMGTYPECHECK" == '200' || "$IMGTYPECHECK" == '302' ]] && {
      # begin pass1:check imagetype
      IMGTYPECHECKPASS_DRTREF="$(echo "$IMGHEADERCHECK"|grep -E -o 'github|raw|qcow2|gzip|x-gzip|x-xz|zstd'|head -n 1)";
      # github tricks,cause it has raw word in its typecheck info
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'github' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m github \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'raw' ]] && UNZIP='0' && sleep 3 && echo -en "[ \033[32m raw \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'gzip' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m gzip \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'x-gzip' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m x-gzip \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'gunzip' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m gunzip \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'x-xz' ]] && UNZIP='2' && sleep 3 && echo -en "[ \033[32m xz \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'zstd' ]] && UNZIP='3' && sleep 3 && echo -en "[ \033[32m zstd \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'qcow2' ]] && UNZIP='4' && sleep 3 && echo -en "[ \033[32m qcow2 \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == '' || "$UNZIP" == '' ]] && {
        # begin pass2:simply check ext
        EXTCHECKPASS="$([[ $1 =~ '.' ]] && echo ${1##*.})"
        [[ "$EXTCHECKPASS" == '' ]] && { UNZIP='0' && sleep 3 && echo -en "[ \033[32m noext \033[0m ]"; } || { [[ "$EXTCHECKPASS" == 'raw' ]] && UNZIP='0' && sleep 3 && echo -en "[ \033[32m raw \033[0m ]";[[ "$EXTCHECKPASS" == 'gz' || "$EXTCHECKPASS" == 'gzip' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m gzip \033[0m ]";[[ "$EXTCHECKPASS" == 'xz' ]] && UNZIP='2' && sleep 3 && echo -en "[ \033[32m xz \033[0m ]";[[ "$EXTCHECKPASS" == 'zstd' ]] && UNZIP='3' && sleep 3 && echo -en "[ \033[32m zstd \033[0m ]";[[ "$EXTCHECKPASS" == 'qcow2' || "$EXTCHECKPASS" == 'img' ]] && UNZIP='4' && sleep 3 && echo -en "[ \033[32m qcow2 \033[0m ]"; }
      }
      #after 2 passe,no need to check IMGTYPECHECKPASS_DRTREF anymore
      # IMGTYPECHECKPASS_DRTREF forced to 1 level only which may fail,we simply failover it as a warning instead of a error
      # inbuilt targets has fixed unzip but non inbuilt ones dont,we simply failover to unzip 1 instead of a error
      [[ "$UNZIP" == '' ]] && UNZIP='1' && echo -en "[ \033[32m failover \033[0m ]";
    }
  }

  [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ "$IMGTYPECHECK" == '' ]] && echo -en " \033[31m targeturl broken, will exit! \033[0m " && { [[ "$tmpTARGET" == "debian10r" ]] && echo -en " \033[31m debian10r image src may in maintain mode for 10-60m! \033[0m " && forcemaintainmode='1';exit 1; }
  

}


ipNum()
{
  local IFS='.';
  read ip1 ip2 ip3 ip4 <<<"$1";
  echo $((ip1*(1<<24)+ip2*(1<<16)+ip3*(1<<8)+ip4));
}

SelectMax(){
  ii=0;
  for IPITEM in `route -n |awk -v OUT=$1 '{print $OUT}' |grep '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'`
    do
      NumTMP="$(ipNum $IPITEM)";
      eval "arrayNum[$ii]='$NumTMP,$IPITEM'";
      ii=$[$ii+1];
    done
  echo ${arrayNum[@]} |sed 's/\s/\n/g' |sort -n -k 1 -t ',' |tail -n1 |cut -d',' -f2;
}

prefixlen2subnetmask(){

  echo `subnetcalc $TMPIPSUBV6 2>/dev/null  |grep  Netmask|cut -d "=" -f 2|sed 's/ //g'`

}

parsenetcfg(){

  # never use
  interface=''

  # 1): setnet=1
  # 2): setnet!=1 and netcfgfile containes static (autonet=1=still static)
  # 3): setnet!=1 and netcfgfile dont containes static (autonet=2=dhcp)

  [[ -n "$FORCENETCFGSTR" || "$FORCENETCFGV6ONLY" == '1' || ( "$tmpBUILD" == '11' || "$tmpBUILD" == '1' ) || "$tmpCTVIRTTECH" == '1' ]] && setNet='1';

  # networkmanager
  [[ "$setNet" != '1' ]] && [[ -f '/etc/network/interfaces' ]] && {
    [[ -z "$(sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='2' || AutoNet='1';[[ -n "$(sed -n '/iface.*inet manual/p' /etc/network/interfaces)" ]] && [[ -n "$(sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='2'
    
    [[ -d /etc/network/interfaces.d ]] && {
      ICFGN="$(find /etc/network/interfaces.d -type f -name '*' |wc -l)" || ICFGN='0';
      [[ "$ICFGN" -ne '0' ]] && {
        for NetCFG in `ls -1 /etc/network/interfaces.d/*`
          do 
            [[ -z "$(cat $NetCFG | sed -n '/iface.*inet static/p')" ]] && AutoNet='2' || AutoNet='1';[[ -n "$(cat $NetCFG | sed -n '/iface.*inet manual/p' /etc/network/interfaces)" ]] && [[ -n "$(cat $NetCFG | sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='2'
            [[ "$AutoNet" -eq '0' ]] && break;
          done
      }
    }
  }

  # netplan
  [[ "$setNet" != '1' ]] && [[ -f '/etc/netplan/00-installer-config.yaml' ]] && {
    [[ -z "$(sed -n '/dhcp4: false\|- \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}.../p' /etc/netplan/00-installer-config.yaml)" ]] && AutoNet='2' || AutoNet='1'
  }

  # we have force1stnicname
  if [[ -n "$FORCE1STNICNAME"  ]]; then
    IFETH=`[[ \`echo $FORCE1STNICNAME|grep -Eo ":"\` ]] && echo $FORCE1STNICNAME || echo \`ip addr show $FORCE1STNICNAME|grep link/ether | awk '{print $2}'\``
    IFETHMAC=`echo $IFETH`
  else
    #IFETH="auto"

    # no more auto, alwaysly force1stnicname and force mac
    DEFAULTNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    FORCE1STNICNAME=`echo \`ip addr show $DEFAULTNIC|grep link/ether | awk '{print $2}'\``
    IFETH=`echo $FORCE1STNICNAME`
    IFETHMAC=`echo $IFETH`
  fi

  # for printing a default nicname,when -n given,has actual effect for setnet!=1,has no effect for setnet=1
  [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" && "$tmpCTVIRTTECH" != "1" ]] && {
    DEFAULTNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    [[ -z "$DEFAULTNIC" ]] && { DEFAULTNIC="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; }
    # [[ -z "$DEFAULTNIC" ]] || { echo "Error! get default nic failed";exit 1; }
  }

  [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" && "$tmpCTVIRTTECH" == "1" ]] && {
    DEFAULTNIC="$(awk '$2 == 00000000 { print $1 }' /proc/net/route)";
    # [[ -z "$DEFAULTNIC" ]] || { echo "Error! get default nic failed";exit 1; }
  }

  # for win we force 1stnicname alwaysly, and defaultnic=forcenic, allinone
  if [[ "$tmpBUILD" == '11' && -z "$FORCE1STNICNAME" ]]; then
    FORCE1STNICIDX="$(netsh int ipv4 show route | grep --text -F '0.0.0.0/0' | awk '$6 ~ /\./ {print $5}')";[[ -z "$FORCE1STNICIDX" ]] && { FORCE1STNICIDX="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')";FORCE1STNICNAME=`echo $(wmic nicconfig where "InterfaceIndex='$FORCE1STNICIDX'" get MACAddress /format:list|sed 's/\r//g'|sed 's/MACAddress=//g')`; } || { FORCE1STNICNAME=`echo $(wmic nicconfig where "InterfaceIndex='$FORCE1STNICIDX'" get MACAddress /format:list|sed 's/\r//g'|sed 's/MACAddress=//g')`; }
    DEFAULTNIC="$FORCE1STNICIDX";
    IFETH=`echo $FORCE1STNICNAME`
    IFETHMAC=`echo $IFETH`
  fi
  if [[ "$tmpBUILD" == '1' && -z "$FORCE1STNICNAME" ]]; then
    DEFAULTNIC="$(netstat -nr -f inet|grep default|awk '{print $4}')";[[ -z "$DEFAULTNIC" ]] && { DEFAULTNIC="$(netstat -nr -f inet6|grep default|awk '{print $4}' |head -n1)"; }
    FORCE1STNICNAME=`echo $(ifconfig ''${DEFAULTNIC}'' | awk '/ether/{print $2}')`
    IFETH=`echo $FORCE1STNICNAME`
    IFETHMAC=`echo $IFETH`
  fi

  [[ "$setNet" == '1' ]] && {

    # FORCENETCFGSTR=10.211.55.105/24,10.211.55.1
    # FORCENETCFGSTR=10.211.55.105,255.255.255.0,10.211.55.1
    # FORCENETCFGSTR=fdb2:2c26:f4e4:0:a756:35e5:2cab:4463/64,fe80::21c:42ff:fe00:18
    # FORCENETCFGSTR=fdb2:2c26:f4e4:0:1270:98bd:5b9:eda7,ffff:ffff:ffff:ffff::,fe80::21c:42ff:fe00:18

    [[ `echo "$FORCENETCFGSTR" | grep -Eo ,|wc -l` == 1 ]] && { 
    FIPSUB=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $1}'`;
    FIP="$(echo -n "$FIPSUB" |cut -d'/' -f1)";
    FCIDR="/$(echo -n "$FIPSUB" |cut -d'/' -f2)";
    [[ `echo $FIP|grep -Eo ":"` ]] && FMASK=`echo \`subnetcalc $FIPSUB 2>/dev/null  |grep  Netmask|cut -d "=" -f 2|sed 's/ //g'\`` || FMASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${FCIDR}'' |cut -d'/' -f1)";
    FGATE=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $2}'`;
    [[ `echo $FIP|grep -Eo ":"` && -f /etc/resolv.conf ]] && { [[ ! -f /etc/resolv.conf.old ]] && { cp -f /etc/resolv.conf /etc/resolv.conf.old && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf; } || { cp -f /etc/resolv.conf /etc/resolv.conf.bak && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf; }; } || { [[ -f /etc/resolv.conf.old ]] && cp -f /etc/resolv.conf.old /etc/resolv.conf; }
    }
    [[ `echo "$FORCENETCFGSTR" | grep -Eo ,|wc -l` == 2 ]] && { 
    #NAME=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $1}' | awk -F ':' '{ print $2}'`
    FIP=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $1}'`
    #CIDR=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $3}' | awk -F ':' '{ print $2}'`
    #MAC=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $4}' | awk -F ':' '{ print $2}'`
    FMASK=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $2}'`
    FGATE=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $3}'`
    [[ `echo $FIP|grep -Eo ":"` && -f /etc/resolv.conf ]] && { [[ ! -f /etc/resolv.conf.old ]] && { cp -f /etc/resolv.conf /etc/resolv.conf.old && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf; } || { cp -f /etc/resolv.conf /etc/resolv.conf.bak && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf; }; } || { [[ -f /etc/resolv.conf.old ]] && cp -f /etc/resolv.conf.old /etc/resolv.conf; }
    #STATICROUTE=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $7}' | awk -F ':' '{ print $2}'`
    #DNS1=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $8}' | awk -F ':' '{ print $2}'`
    #DNS2=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $9}' | awk -F ':' '{ print $2}'`
    }

    # force ipv6 also force ipv6 staticnetcfg
    [[ "$FORCENETCFGV6ONLY" == '1' && -z "$FORCENETCFGSTR" ]] && { [[ -n "$DEFAULTNIC" ]] && TMPIPSUBV6="$(ip -6 -brief address show scope global|grep ''${DEFAULTNIC}'' |awk -F ' ' '{ print $3}')";
    FIP="$(echo -n "$TMPIPSUBV6" |cut -d'/' -f1)";
    TMPCIDRV6="$(echo -n "$TMPIPSUBV6" |cut -d'/' -f2)";
    FGATE="$(ip -6 -brief route show default|grep ''${DEFAULTNIC}'' |awk -F ' ' '{ print $3}')";
    [[ -n "$TMPCIDRV6" ]] && FMASK="$(prefixlen2subnetmask)"; } && FORCENETCFGSTR="$FIP,$FMASK,$FGATE" && { [[ -f /etc/resolv.conf && ! -f /etc/resolv.conf.old ]] && { cp -f /etc/resolv.conf /etc/resolv.conf.old && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf; } || { cp -f /etc/resolv.conf /etc/resolv.conf.bak && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf; }; }

    # force ct will force staticnetcfg
    [[ "$tmpCTVIRTTECH" == '1' && -z "$FORCENETCFGSTR" ]] && { [[ -n "$DEFAULTNIC" ]] && TMPIPSUBV4="$(ip addr show dev ''${DEFAULTNIC}'' | sed -nE '/global/s/.*inet (.+) brd.*$/\1/p' | head -n 1)";
    FIP="$(echo -n "$TMPIPSUBV4" |cut -d'/' -f1)";
    TMPCIDRV4="$(echo -n "$TMPIPSUBV4" |grep -o '/[0-9]\{1,2\}')";
    FGATE="locallink";
    [[ -n "$TMPCIDRV4" ]] && FMASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${TMPCIDRV4}'' |cut -d'/' -f1)"; } && { FORCENETCFGSTR="$FIP,$FMASK,$FGATE";echo -e "auto lo\niface lo inet loopback\n\nauto $DEFAULTNIC\niface $DEFAULTNIC inet static\naddress $TMPIPSUBV4\nup route add $(ip route show default 0.0.0.0/0 | sed -E 's/^(.*dev [^ ]+).*$/\1/')\n\nhostname $(hostname)" >/dev/null 2>&1 >> $remasteringdir/ctrnet;echo -e "nameserver 8.8.8.8\nnameserver 2001:4860:4860::8888" >/dev/null 2>&1 >> $remasteringdir/ctrdns; }

    # win force v4v6 FORCENETCFGSTR too
    [[ "$tmpBUILD" == '11' && -z "$FORCENETCFGSTR" ]] && { [[ -n "$DEFAULTNIC" ]] && FIP=`echo $(wmic nicconfig where "InterfaceIndex='$FORCE1STNICIDX'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`;
    FGATE=`echo $(wmic nicconfig where "InterfaceIndex='$FORCE1STNICIDX'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`;
    FMASK=`echo $(wmic nicconfig where "InterfaceIndex='$FORCE1STNICIDX'" get IPSubnet /format:list|sed 's/\r//g'|sed 's/IPSubnet={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`; } && FORCENETCFGSTR="$FIP,$FMASK,$FGATE"
    [[ "$tmpBUILD" == '11' && -n "$FORCENETCFGSTR" ]] && { FORCENETCFGSTR="$FIP,$FMASK,$FGATE"; }
    [[ "$tmpBUILD" == '1' && -z "$FORCENETCFGSTR" ]] && { [[ -n "$DEFAULTNIC" ]] && FIP=`echo $(ifconfig ''${DEFAULTNIC}'' |grep -Fv inet6|grep inet|awk '{print $2}')`;
    FGATE=`echo $(netstat -nr -f inet|grep default|grep ''${DEFAULTNIC}'' |awk '{print $2}')`;
    FMASKTMP=`echo $(ifconfig ''${DEFAULTNIC}''|grep netmask|awk '{print $4}'|sed s/0x//g)`
    FMASK=`printf '%d.%d.%d.%d\n' $(echo ''${FMASKTMP}'' | sed 's/../0x& /g')`; } && FORCENETCFGSTR="$FIP,$FMASK,$FGATE"
    [[ "$tmpBUILD" == '1' && -n "$FORCENETCFGSTR" ]] && { FORCENETCFGSTR="$FIP,$FMASK,$FGATE"; }

  }

  [[ "$setNet" != '1' ]] && {

    [[ -n "$DEFAULTNIC" ]] && { IPSUBV4="$(ip addr |grep ''${DEFAULTNIC}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";[[ -z "$IPSUBV4" ]] && IPSUBV4="$(ip addr |grep ''${DEFAULTWORKINGNIC}'' |grep 'global' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')"; };
    IPV4="$(echo -n "$IPSUBV4" |cut -d'/' -f1)";
    CIDRV4="$(echo -n "$IPSUBV4" |grep -o '/[0-9]\{1,2\}')";
    GATEV4="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";
    [[ -n "$CIDRV4" ]] && MASKV4="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${CIDRV4}'' |cut -d'/' -f1)";
    #[[ -n "$GATEV4" ]] && [[ -n "$MASKV4" ]] && [[ -n "$IPV4" ]] || {
      # echo "\`ip command\` Failed to get gatev4,maskv4,ipv4 settings, will try using \`route command\`."
      #[[ -z $IPV4 ]] && IPV4="$(ifconfig |grep 'Bcast' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1)";
      #[[ -z $GATEV4 ]] && GATEV4="$(SelectMax 2)";
      #[[ -z $MASKV4 ]] && MASKV4="$(SelectMax 3)";
    #}
    [[ -n "$DEFAULTNIC" ]] && IPSUBV6="$(ip -6 -brief address show scope global|grep ''${DEFAULTNIC}'' |awk -F ' ' '{ print $3}')";
    IPV6="$(echo -n "$IPSUBV6" |cut -d'/' -f1)";
    CIDRV6="$(echo -n "$IPSUBV6" |cut -d'/' -f2)";
    GATEV6="$(ip -6 -brief route show default|grep ''${DEFAULTNIC}'' |awk -F ' ' '{ print $3}')";
    # the subnetcalc deps didnt be called yet ?
    [[ -n "$CIDRV6" ]] && MASKV6="$(prefixlen2subnetmask)"

    # if not force ipv6 stack probe, try non-force auto ipv6/ipv4 stack probe methods,ipv4 always has priority over ipv6 by default
    [[ "$FORCENETCFGV6ONLY" != '1' ]] && {
      [[ -n "$GATEV4" && -n "$MASKV4" && -n "$IPV4" ]] && { IP=$IPV4;MASK=$MASKV4;GATE=$GATEV4;[[ -f /etc/resolv.conf.old ]] && cp -f /etc/resolv.conf.old /etc/resolv.conf; } || {
        # if reach || here,there maybe no ipv4 stacks
        [[ -n "$GATEV6" && -n "$MASKV6" && -n "$IPV6" ]] && { IP=$IPV6;MASK=$MASKV6;GATE=$GATEV6;[[ -f /etc/resolv.conf && ! -f /etc/resolv.conf.old ]] && { cp -f /etc/resolv.conf /etc/resolv.conf.old && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf; } || { cp -f /etc/resolv.conf /etc/resolv.conf.bak && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf; }; } # || exit 1;
        # if reach && here,there may still be useful ipv6 stacks
      }
      # final give up both stack(there maybe no any ipstacks)
      [[ -n "$GATE" && -n "$MASK" && -n "$IP" ]] || {
        echo "Error! get netcfg auto ipv4/ipv6 stack settings failed. please speficty static netcfg settings";
        exit 1;
      }
    }


  }

  # buildmode, set auto net hints
  [[ "$FORCE1STNICNAME" == "" && "$setNet" == '1' && "$AutoNet" != '1' && "$AutoNet" != '2' ]] && echo -en "[ \033[32m force,static \033[0m ]" && echo -en "[ \033[32m $DEFAULTNIC:$FIP,$FMASK,$FGATE \033[0m ]"
  [[ "$FORCE1STNICNAME" != "" && "$setNet" == '1' && "$AutoNet" != '1' && "$AutoNet" != '2' ]] && echo -en "[ \033[32m force,static \033[0m ]" && echo -en "[ \033[32m `[[ "$tmpBUILD" == '11' || "$tmpBUILD" == '1' ]] && echo $DEFAULTNIC:$FIP,$FMASK,$FGATE || echo $FORCE1STNICNAME:$FIP,$FMASK,$FGATE` \033[0m ]"
  [[ "$setNet" != '1' && "$AutoNet" != '1' && "$AutoNet" == '2' ]] && echo -en "[ \033[32m auto,dhcp \033[0m ]" && echo -en "[ \033[32m $DEFAULTNIC:$IP,$MASK,$GATE \033[0m ]"
  [[ "$setNet" != '1' && "$AutoNet" == '1' && "$AutoNet" != '2' ]] && echo -en "[ \033[32m auto,static \033[0m ]" && echo -en "[ \033[32m $DEFAULTNIC:$IP,$MASK,$GATE \033[0m ]"

}

parsediskcfg(){


  #maybe we can force bootdir and efi bootorder here, just in the plan

  [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && [[ ! -d /boot ]] && echo -ne "Error! \nNo boot directory mounted.\n" && exit 1;
  [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && [[ -z `find /boot -name grub.cfg -o -name grub.conf` ]] && echo -ne "Error! \nNo grubcfg files in the boot directory.\n" && exit 1;

  # try lookingfor the full working grub(file+dir+ver); simple case : only one grub gen(bios) and grub cfg
  if [[ "$tmpBUILDGENE" != "2" ]] && [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]]; then
     WORKINGGRUB=`find /boot/grub* -maxdepth 1 -mindepth 1 -name grub.cfg -o -name grub.conf`
     [[ -z "$GRUBDIR" ]] && [[ `echo $WORKINGGRUB|wc -l` == 1 ]] && GRUBTYPE='0' && GRUBDIR=${WORKINGGRUB%/*}/ && GRUBFILE=${WORKINGGRUB##*/}
  fi
  # try lookingfor the full working grub(file+dir+ver); complicated cases : one(efi) or two grub gen(bios and efi) coexists and one or two grub cfgs
  if [[ "$tmpBUILDGENE" == "2" ]] && [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]]; then
    WORKINGGRUB=`find /boot -name grub.cfg -o -name grub.conf`
    # we must use echo "$WORKINGGRUB" but not $WORKINGGRUB or lines will be ingored
    [[ -z "$GRUBDIR" ]] && [[ `echo "$WORKINGGRUB"|wc -l` == 1 ]] && GRUBTYPE='1' && GRUBDIR=${WORKINGGRUB%/*}/ && GRUBFILE=${WORKINGGRUB##*/};
    # we must use grep -vq && but not grep -q ||,or ...
    # it seems that grep -vq are not portable(results may vary though under same stuation)
    [[ -z "$GRUBDIR" ]] && [[ `echo "$WORKINGGRUB"|wc -l` == 2 ]] && GRUBTYPE='2' && echo "$WORKINGGRUB" | while read line; do cat $line | grep -Eo -q configfile || { GRUBDIR=${line%/*}/;GRUBFILE=${line##*/}; };done
  fi
  if [[ "$tmpBUILD" == "11" ]] && [[ "$tmpTARGETMODE" != "1" ]]; then
    GRUBTYPE='11' && GRUBDIR=/cygdrive/c/grub2/ && GRUBFILE=grub.cfg
  fi
  if [[ "$tmpBUILD" == "1" ]] && [[ "$tmpTARGETMODE" != "1" ]]; then
    GRUBTYPE='10' && GRUBDIR=$topdir/$remasteringdir/boot
  fi
  # if above both failed,force a brute way
  [ -z "$GRUBDIR" -o -z "$GRUBFILE" ] && GRUBDIR='' && GRUBFILE='' && {
    [[ -f '/boot/grub/grub.cfg' ]] && GRUBTYPE='0' && GRUBDIR='/boot/grub' && GRUBFILE='grub.cfg';
    [[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub2/grub.cfg' ]] && GRUBTYPE='0' && GRUBDIR='/boot/grub2' && GRUBFILE='grub.cfg';
    [[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub/grub.conf' ]] && GRUBTYPE='3' && GRUBDIR='/boot/grub' && GRUBFILE='grub.conf';
  }

  [[ "$tmpBUILD" != "1" ]] && {
  # all failed,so we give up
  [ -z "$GRUBDIR" -o -z "$GRUBFILE" ] && echo -ne "Error! \nNo working grub.\n" && exit 1;


  [[ ! -f $GRUBDIR/$GRUBFILE ]] && echo "Error! No working grub file $GRUBFILE. " && exit 1;

  [[ ! -f $GRUBDIR/$GRUBFILE.old ]] && [[ -f $GRUBDIR/$GRUBFILE.bak ]] && mv -f $GRUBDIR/$GRUBFILE.bak $GRUBDIR/$GRUBFILE.old;
  mv -f $GRUBDIR/$GRUBFILE $GRUBDIR/$GRUBFILE.bak;
  [[ -f $GRUBDIR/$GRUBFILE.old ]] && cat $GRUBDIR/$GRUBFILE.old >$GRUBDIR/$GRUBFILE || cat $GRUBDIR/$GRUBFILE.bak >$GRUBDIR/$GRUBFILE;
  }

  # the final boot dir will inst to
  [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" || "$tmpBUILDINSTTEST" == '1' ]] && insttotmp=`df -P "$GRUBDIR"/"$GRUBFILE" | grep /dev/`
  [[ "$tmpBUILDGENE" != "2" ]] && [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" || "$tmpBUILDINSTTEST" == '1' ]] && instto="/boot"

  [[ "$tmpBUILDGENE" == "2" ]] && [[ "$GRUBTYPE" == "1" ]] && [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" || "$tmpBUILDINSTTEST" == '1' ]] && [[ `find /boot/efi -name grub.cfg -o -name grub.conf|wc -l` == 1 ]] && instto=${insttotmp##*[[:space:]]}
  [[ "$tmpBUILDGENE" == "2" ]] && [[ "$GRUBTYPE" == "1" ]] && [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" || "$tmpBUILDINSTTEST" == '1' ]] && [[ `find /boot/efi -name grub.cfg -o -name grub.conf|wc -l` == 0 ]] && instto="/boot"

  [[ "$tmpBUILDGENE" == "2" ]] && [[ "$GRUBTYPE" == "2" ]] && [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" || "$tmpBUILDINSTTEST" == '1' ]] && instto="$GRUBDIR"
  [[ "$tmpBUILD" == "11" || "$tmpBUILD" == "1" ]] && instto="$GRUBDIR"
  # force anyway
  [[ "$instto" == "" ]] && [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" || "$tmpBUILDINSTTEST" == '1' ]] && instto="/boot"


  [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && {
    [[ "$FORCE1STHDNAME" != '' ]] && {
      defaulthd="$FORCE1STHDNAME";
      defaulthdid=$(fdisk -l /dev/$defaulthd 2>/dev/null| grep 'Disk identifier' | awk '{print $NF}' | sed 's/0x//');
      [[ "$tmpTARGETMODE" != "1" ]] && { [ -z  "$defaulthdid" ] && echo -ne "Error! \nselected defaulthd has a invalid id.\n" && exit 1; }

      echo -en "[ \033[32m force \033[0m ] [ \033[32m $defaulthd,$instto \033[0m ]";
    } || {
      mapper=$(df -P $instto |  grep -Eo  '/dev/[^ ]*')
      # in case this is a raid ($instto accross much disk),we should add head -n1
      defaulthd=$(lsblk -rn --inverse $mapper | grep -w disk | awk '{print $1}' | sort -u| head -n1)
      defaulthdid=$(fdisk -l /dev/$defaulthd 2>/dev/null| grep 'Disk identifier' | awk '{print $NF}' | sed 's/0x//')
      [[ "$tmpTARGETMODE" != "1" ]] && { [ -z "$instto" -o -z "$defaulthd" ] && echo -ne "Error! \nCant select defaulthd.\n" && exit 1; }

      echo -en "[ \033[32m auto \033[0m ] [ \033[32m $defaulthd,$instto \033[0m ]";
    } 
  } || echo -en "[ \033[32m non linux \033[0m ]"

}

preparepreseed(){

  #never use
  [[ -n "$custWORD" ]] && myPASSWORD="$(openssl passwd -1 "$custWORD")";
  [[ -z "$myPASSWORD" ]] && myPASSWORD='$1$4BJZaD0A$y1QykUnJ6mXprENfwpseH0';

  > $topdir/$remasteringdir/initramfs/preseed.cfg # $topdir/$remasteringdir/initramfs_arm64/preseed.cfg
  tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
#pass the lowmem note,but still it may have problems
d-i debian-installer/language string en
d-i debian-installer/country string US
d-i debian-installer/locale string en_US.UTF-8
d-i lowmem/low note
# $([[ "$tmpINSTEMBEDVNC" != '1' ]] && echo d-i debian-installer/framebuffer boolean false) is not needed,we also mentioned and moved it to bootcode before
d-i debian-installer/framebuffer boolean false
d-i console-setup/layoutcode string us
d-i keyboard-configuration/xkb-keymap string us
d-i hw-detect/load_firmware boolean true
d-i netcfg/choose_interface select $IFETH
d-i netcfg/disable_autoconfig boolean true
d-i netcfg/dhcp_failed note
d-i netcfg/dhcp_options select Configure network manually
# d-i netcfg/get_ipaddress string $custIPADDR
d-i netcfg/get_ipaddress string $([[ "$setNet" == '1' && "$FORCENETCFGSTR" != '' ]] && echo "$FIP" || echo "$IP")
d-i netcfg/get_netmask string $([[ "$setNet" == '1' && "$FORCENETCFGSTR" != '' ]] && echo "$FMASK" || echo "$MASK")
d-i netcfg/get_gateway string $([[ "$setNet" == '1' && "$FORCENETCFGSTR" != '' ]] && echo "$FGATE" || echo "$GATE")
d-i netcfg/get_nameservers string 1.1.1.1 8.8.8.8 2001:67c:2b0::4 2001:67c:2b0::6
d-i netcfg/no_default_route boolean true
d-i netcfg/confirm_static boolean true
d-i mirror/country string manual
#d-i mirror/http/hostname string $IP
d-i mirror/http/hostname string $DEBMIRROR
d-i mirror/http/directory string /_build/debianbase
d-i mirror/http/proxy string
d-i apt-setup/services-select multiselect
d-i debian-installer/allow_unauthenticated boolean true
d-i debian-installer/allow_unauthenticated_ssl boolean true
d-i passwd/root-login boolean ture
d-i passwd/make-user boolean false
d-i passwd/root-password-crypted password $([[ "$FORCEPASSWORD" != '' && "$FORCEPASSWORD" != '0' ]] && echo $(openssl passwd -1 "$FORCEPASSWORD") || echo $(openssl passwd -1 "inst.sh"))
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false
d-i clock-setup/utc boolean true
d-i time/zone string US/Eastern
d-i clock-setup/ntp boolean true
EOF


  [[ "$tmpTARGETMODE" == '0' && "$tmpTARGET" == 'debian' ]] && tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
# we mixed the efi and bios togeth in 30atomic
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
d-i preseed/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 10800" )
d-i partman/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "count=\`ping -c 5 8.8.8.8 | grep from* | wc -l\`;count6=\`ping -c 5 -6 2001:67c:2b0::6|grep from*|wc -l\`;pid=\`screen -ls|grep -Eo [0-9]*.reboot|grep -Eo [0-9]*\`;[ \$count -ne 0 -o \$count6 -ne 0 ] && kill -9 \$pid;" )anna-install parted-udeb fdisk-udeb;$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "anna-install network-console;sed -e s/network-console/sh/g -e s/installer/sshd/g -e s/x//g -i /etc/passwd;ssh-keygen -b 2048 -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key -q;sed -i \"s/PermitEmptyPasswords no/PermitEmptyPasswords yes/g\" /etc/ssh/sshd_config;/usr/sbin/sshd;" )chmod 755 -R /usr/lib/debianinstall-patchs/preinstall.sh;/usr/lib/debianinstall-patchs/preinstall.sh "$TARGETDDURL" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && echo "$defaulthdid" || echo "nonlinux" )

d-i partman-auto/method string lvm
d-i partman-auto/choose_recipe select atomic

d-i partman-partitioning/choose_label string gpt
d-i partman-partitioning/default_label string gpt
d-i partman-partitioning/confirm_write_new_label boolean true

d-i partman-md/device_remove_md boolean true
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-auto-lvm/guided_size string max
d-i partman-auto-lvm/new_vg_name string cl
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true

d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i base-installer/kernel/image string linux-image-5.10.0-22-$([[ "$tmpHOSTARCH" != '1' ]] && echo amd || echo arm)64

tasksel tasksel/first multiselect minimal
d-i pkgsel/update-policy select none
d-i pkgsel/include string openssh-server
d-i pkgsel/upgrade select none

popularity-contest popularity-contest/participate boolean false

d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default
d-i grub-installer/force-efi-extra-removable boolean true

d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/reboot boolean true
# sometimes https were auto-transed to http, we should adjust it backed
d-i preseed/late_command string sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config;sed -i "s#http://github#https://github#g;s#http://gitee#https://gitee#g;s#$DEBMIRROR/debianbase#http://deb.debian.org/debian#g" /target/etc/apt/sources.list
EOF

  # both inst and buildmode share PIPECMSTR defines but without forcenetcfgstr and force github mirror for buildmode
  # we use both ext2/fat16 duplicated parts cause some machine only regnoice ext2(the ones boot with its own grub instead of on disk grubs)but not fat16
  [[ "$tmpTARGET" == devdeskos* ]] && {
    choosevmlinuz=$TARGETDDURL/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64)
    chooseinitrfs=$TARGETDDURL/initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).img
    chooseonekeydevdeskd1=$TARGETDDURL/onekeydevdeskd-01core$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).xz
    chooseonekeydevdeskd2=$TARGETDDURL/onekeydevdeskd-02gui$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).xz
  }

  # we meant to use live-installer but it is too complicated so we turn to parted
  # there is only grub-efi on arm64,shall we separate preseed?
  # we must put force1sthdname before forcenetcfgstr,because argpositiion 1,2,3,4 is always there(fixedly appear) but 5 not(if not forced,it dont occpy a pos),we pust fixed ones piorr in front
  [[ "$tmpTARGETMODE" == '0' && "$tmpTARGET" == devdeskos* ]] && tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
# in debian installer, some machine dhcp mode are not clever enough, so just force autonet 1 and 2 both static
d-i preseed/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 10800" )
d-i partman/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "count=\`ping -c 5 8.8.8.8 | grep from* | wc -l\`;count6=\`ping -c 5 -6 2001:67c:2b0::6|grep from*|wc -l\`;pid=\`screen -ls|grep -Eo [0-9]*.reboot|grep -Eo [0-9]*\`;[ \$count -ne 0 -o \$count6 -ne 0 ] && kill -9 \$pid;" )anna-install parted-udeb fdisk-udeb;$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "anna-install network-console;sed -e s/network-console/sh/g -e s/installer/sshd/g -e s/x//g -i /etc/passwd;ssh-keygen -b 2048 -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key -q;sed -i \"s/PermitEmptyPasswords no/PermitEmptyPasswords yes/g\" /etc/ssh/sshd_config;/usr/sbin/sshd;" )chmod 755 /usr/lib/liveinstall-patchs/longrunpipebgcmd_redirectermoniter.sh;/usr/lib/liveinstall-patchs/longrunpipebgcmd_redirectermoniter.sh "$choosevmlinuz,$chooseinitrfs,$chooseonekeydevdeskd1,$chooseonekeydevdeskd2" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && echo "$defaulthdid" || echo "nonlinux" ) $([[ "$FORCE1STNICNAME" != '' ]] && echo "$IFETHMAC" || echo "\"\$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print \$NF}')\"") $([[ "$FORCEPASSWORD" != '' ]] && echo "$FORCEPASSWORD") $([ "$setNet" == '1' -a "$FORCENETCFGSTR" != '' ] && echo "$FIP,$FMASK,$FGATE";[ "$AutoNet" == '1' -o "$AutoNet" == '2' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE")
EOF




  # azure hd need bs=10M or it will fail
  [[ "$tmpTARGET" != 'debian10r' ]] && [[ "$UNZIP" == '0' ]] && PIPECMDSTR='wget -qO- --no-check-certificate '$TARGETDDURL' |stdbuf -oL dd of=$(list-devices disk |head -n1) bs=10M 2> /var/log/progress & pid=`expr $! + 0`;echo $pid';

  [[ "$tmpTARGET" == 'debian10r' ]] && [[ "$UNZIP" == '2' ]] && [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && PIPECMDSTR='(for i in `seq -w 000 699`;do wget -qO- --no-check-certificate '$TARGETDDURL'_$i; done) |tar JOx |stdbuf -oL dd of='$defaulthdid' bs=10M 2> /var/log/progress & pid=`expr $! + 0`;echo $pid' || PIPECMDSTR='(for i in `seq -w 000 699`;do wget -qO- --no-check-certificate '$TARGETDDURL'_$i; done) |tar JOx |stdbuf -oL dd of=nonlinux bs=10M 2> /var/log/progress & pid=`expr $! + 0`;echo $pid';


  # we must put force1sthdname before forcenetcfgstr,because argpositiion 1,2,3,4,5 is always there(fixedly appear) but 6 not(if not forced,it dont occpy a pos),we pust fixed ones piorr in front
  [[ "$tmpTARGETMODE" == '0' ]] && [[ "$tmpTARGET" != 'debian' && "$tmpTARGET" != devdeskos* && "$tmpTARGET" != dummy ]] && tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
# anna-install wget-udeb here?
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
# in debian installer, some machine dhcp mode are not clever enough, so just force autonet 1 and 2 both static
d-i preseed/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 10800" )
d-i partman/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "count=\`ping -c 5 8.8.8.8 | grep from* | wc -l\`;count6=\`ping -c 5 -6 2001:67c:2b0::6|grep from*|wc -l\`;pid=\`screen -ls|grep -Eo [0-9]*.reboot|grep -Eo [0-9]*\`;[ \$count -ne 0 -o \$count6 -ne 0 ] && kill -9 \$pid;" )anna-install fdisk-udeb;$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "anna-install network-console;sed -e s/network-console/sh/g -e s/installer/sshd/g -e s/x//g -i /etc/passwd;ssh-keygen -b 2048 -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key -q;sed -i \"s/PermitEmptyPasswords no/PermitEmptyPasswords yes/g\" /etc/ssh/sshd_config;/usr/sbin/sshd;" )chmod 755 /usr/lib/ddinstall-patchs/longrunpipebgcmd_redirectermoniter.sh;/usr/lib/ddinstall-patchs/longrunpipebgcmd_redirectermoniter.sh "$TARGETDDURL,$UNZIP" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && echo "$defaulthdid" || echo "nonlinux" ) $([[ "$FORCE1STNICNAME" != '' ]] && echo "$IFETHMAC" || echo "\"\$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print \$NF}')\"") $([[ "$FORCEINSTCTL" != '' ]] && echo "$FORCEINSTCTL") $([[ "$FORCEPASSWORD" != '' ]] && echo "$FORCEPASSWORD") $([ "$setNet" == '1' -a "$FORCENETCFGSTR" != '' ] && echo "$FIP,$FMASK,$FGATE";[ "$AutoNet" == '1' -o "$AutoNet" == '2' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE")
EOF

  [[ "$tmpTARGETMODE" == '2' ]] && [[ "${tmpTARGET:0:11}" == '10000:/dev/' ]] && tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
d-i preseed/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 10800" )
d-i partman/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "count=\`ping -c 5 8.8.8.8 | grep from* | wc -l\`;count6=\`ping -c 5 -6 2001:67c:2b0::6|grep from*|wc -l\`;pid=\`screen -ls|grep -Eo [0-9]*.reboot|grep -Eo [0-9]*\`;[ \$count -ne 0 -o \$count6 -ne 0 ] && kill -9 \$pid;" )anna-install fdisk-udeb;$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "anna-install network-console;sed -e s/network-console/sh/g -e s/installer/sshd/g -e s/x//g -i /etc/passwd;ssh-keygen -b 2048 -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key -q;sed -i \"s/PermitEmptyPasswords no/PermitEmptyPasswords yes/g\" /etc/ssh/sshd_config;/usr/sbin/sshd;" )chmod 755 /usr/lib/ncrestore-patchs/longrunpipebgcmd_redirectermoniter.sh;/usr/lib/ncrestore-patchs/longrunpipebgcmd_redirectermoniter.sh "$tmpTARGET"
EOF

  # important for submenu in typing dummy
  [[ "$tmpTARGETMODE" == '0' && "$tmpTARGET" == 'dummy' ]] && tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
#debian d-i has a bug cuasing bgcmd not running,so we use screen
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
d-i preseed/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 10800" )
d-i partman/early_command string $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo "count=\`ping -c 5 8.8.8.8 | grep from* | wc -l\`;count6=\`ping -c 5 -6 2001:67c:2b0::6|grep from*|wc -l\`;pid=\`screen -ls|grep -Eo [0-9]*.reboot|grep -Eo [0-9]*\`;[ \$count -ne 0 -o \$count6 -ne 0 ] && kill -9 \$pid;" )anna-install fdisk-udeb parted-udeb network-console;sed -e s/network-console/sh/g -e s/installer/sshd/g -e s/x//g -i /etc/passwd;ssh-keygen -b 2048 -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key -q;sed -i "s/PermitEmptyPasswords no/PermitEmptyPasswords yes/g" /etc/ssh/sshd_config;/usr/sbin/sshd;start-shell di-utils-shell/do-shell /bin/sh
EOF

  [[ "$tmpTARGETMODE" == '4' ]] && {
    #dont use onthefly
    #ONTHEFLYPIPECMDSTR='wget -qO- --no-check-certificate '$TARGETDDURL' | dd of=$(list-devices disk |head -n1) bs=10M status=progress';
    # we must pre calc below before inplace dd
    DEFAULTHD=`lsblk -e 7 -e 11 -d | tail -n+2 | cut -d" " -f1 |head -n 1`
  }

  [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { [[ "$(find /sys/class/net/ -type l ! -lname '*/devices/virtual/net/*' |  wc -l)" -lt 2 ]] && echo -en "[ \033[32m single nic: use $DEFAULTNIC \033[0m ]" || echo -en "[ \033[32m multiple eth: use $DEFAULTNIC \033[0m ]"; } || echo -en "[ \033[32m non linux: use $DEFAULTNIC \033[0m ]"
  [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { [[ "$(lsblk -e 7 -e 11 -d | tail -n+2 | wc -l)" -lt 2 ]] && echo -en "[ \033[32m single hd: use $defaulthd \033[0m ]" || echo -en "[ \033[32m multiple hd:  use $defaulthd  \033[0m ]"; } || echo -en "[ \033[32m non linux: use sysvol \033[0m ]"

  #if multiple hd force 1sthdname where /boot is
  #if multiple eth force 1stethname where ip is

}


patchpreseed(){

  # in debian installer, some machine dhcp mode are not clever enough, so just leave it force, force, force
  # [[ "$AutoNet" == '2' ]] && {
  #   [[ "$tmpBUILD" != "1" ]] && sed -e '/netcfg\/disable_autoconfig/d' -e '/netcfg\/dhcp_options/d' -e '/netcfg\/get_nameserver/ !{/netcfg\/get_.*/d}' -e '/netcfg\/confirm_static/d' -i $topdir/$remasteringdir/initramfs/preseed.cfg || sed -e '/netcfg\/disable_autoconfig/d' -e '/netcfg\/dhcp_options/d' -e '/netcfg\/get_nameserver/ !{/netcfg\/get_.*/d}' -e '/netcfg\/confirm_static/d' -i "" $topdir/$remasteringdir/initramfs/preseed.cfg
  #   [[ "$tmpBUILD" != "1" ]] && sed -e '/netcfg\/disable_autoconfig/d' -e '/netcfg\/dhcp_options/d' -e '/netcfg\/get_nameserver/ !{/netcfg\/get_.*/d}' -e '/netcfg\/confirm_static/d' -i $topdir/$remasteringdir/initramfs_arm64/preseed.cfg || sed -e '/netcfg\/disable_autoconfig/d' -e '/netcfg\/dhcp_options/d' -e '/netcfg\/get_nameserver/ !{/netcfg\/get_.*/d}' -e '/netcfg\/confirm_static/d' -i "" $topdir/$remasteringdir/initramfs_arm64/preseed.cfg
  # }

  #[[ "$GRUBPATCH" == '1' ]] && {
  #  sed -i 's/^d-i\ grub-installer\/bootdev\ string\ default//g' $topdir/$remasteringdir/initramfs/preseed.cfg
  #}
  #[[ "$GRUBPATCH" == '0' ]] && {
  #  sed -i 's/debconf-set\ grub-installer\/bootdev.*\"\;//g' $topdir/$remasteringdir/initramfs/preseed.cfg
  #}
  # vncserver need this?
  #[[ "$GRUBPATCH" == '0' ]] && {
  #  sed -i 's/debconf-set\ grub-installer\/bootdev.*\"\;//g' /tmp/boot/preseed.cfg
  #}

  [[ "$tmpBUILD" != "1" ]] && sed -e '/user-setup\/allow-password-weak/d' -e '/user-setup\/encrypt-home/d' -i $topdir/$remasteringdir/initramfs/preseed.cfg || sed -e '/user-setup\/allow-password-weak/d' -e '/user-setup\/encrypt-home/d' -i "" $topdir/$remasteringdir/initramfs/preseed.cfg
  [[ "$tmpBUILD" != "1" ]] && sed -e '/user-setup\/allow-password-weak/d' -e '/user-setup\/encrypt-home/d' -i $topdir/$remasteringdir/initramfs_arm64/preseed.cfg || sed -e '/user-setup\/allow-password-weak/d' -e '/user-setup\/encrypt-home/d' -i "" $topdir/$remasteringdir/initramfs_arm64/preseed.cfg
  #sed -i '/pkgsel\/update-policy/d' $topdir/$remasteringdir/initramfs/preseed.cfg
  #sed -i 's/umount\ \/media.*true\;\ //g' $topdir/$remasteringdir/initramfs/preseed.cfg

}


download_file() {
  local url="$1"
  local file="$2"
  # 3,4 optional
  local seg="$3"
  local code="$4"


  local retry=0
  local quiet=0

  verify_file() {

    if [ -s "$file" ]; then
      if [ -n "$code" ]; then ( echo "${code}  ${file}" | md5sum -c --quiet );return $?;fi
      if [ -z "$code" ]; then :;return 0;fi
    fi

    return 1
  }

  download_file_to_path() {
    if verify_file; then
      return 0
    #else
    #  echo -en "[ \033[31m `basename $url`, verify failed!! \033[0m ]"
    #  exit 1
    fi

    if [ $retry -ge 3 ]; then
      rm -f "$file"
      echo -en "[ \033[31m `basename $url`,failed!! \033[0m ]"

      exit 1
    fi

    [[ -n "$seg" ]] && {
      if [ "$tmpBUILD" != "1" ]; then
        ( (for i in `seq -w 000 $seg`;do wget -qO- --no-check-certificate $url"_"$i; done) > $file )
      else
        ( (for i in `seq -f '%03.0f' 000 $seg`;do wget -qO- --no-check-certificate $url"_"$i; done) > $file )
      fi
    }
    if [ -z "$seg" ]; then ( wget -qO- --no-check-certificate $url ) > $file;quiet='1';fi
    if [ "$?" != "0" ] && ! verify_file; then
      retry=$(expr $retry + 1)
      download_file_to_path
    else
      [[ "$quiet" != '1' ]] && echo -en "[ \033[32m `basename $url`,ok!! \033[0m ]"
    fi
  }

  download_file_to_path
}


function getbasics(){

  compositemode="$1"
  instcheck=$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n binary-arm64 || echo -n binary-amd64)/instcheck.dat
  installmodechoosevmlinuz=$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n binary-arm64 || echo -n binary-amd64)/tarball/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64)
  installmodechoosevmlinuz2=vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64)
  installmodechoosevmlinuzcode=`wget --no-check-certificate -qO- "$DEBMIRROR"/_build/onekeydevdesk/"$instcheck"|grep "$installmodechoosevmlinuz2":|awk -F ':' '{ print $2}'`
  installmodechoosetdlcore=$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n binary-arm64 || echo -n binary-amd64)/tarball/tdlcore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).xz
  installmodechoosetdlcore2=tdlcore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).xz
  installmodechoosetdlcorecode=`wget --no-check-certificate -qO- "$DEBMIRROR"/_build/onekeydevdesk/"$instcheck"|grep "$installmodechoosetdlcore2":|awk -F ':' '{ print $2}'`

  # when down was used,only targetmode 0 occurs
  [[ "$1" == 'down' && "$tmpTARGETMODE" != '4' ]] && {

    [[ ! -f $topdir/$downdir/onekeydevdesk/$installmodechoosevmlinuz2 || ! -s $topdir/$downdir/onekeydevdesk/$installmodechoosevmlinuz2 ]] && download_file $DEBMIRROR/_build/onekeydevdesk/$installmodechoosevmlinuz $topdir/$downdir/onekeydevdesk/$installmodechoosevmlinuz2 030 $installmodechoosevmlinuzcode
    [[ ! -f $topdir/$downdir/onekeydevdesk/$installmodechoosetdlcore2 || ! -s $topdir/$downdir/onekeydevdesk/$installmodechoosetdlcore2 ]] && download_file $DEBMIRROR/_build/onekeydevdesk/$installmodechoosetdlcore $topdir/$downdir/onekeydevdesk/$installmodechoosetdlcore2 060 $installmodechoosetdlcorecode

  }

  [[ "$1" == 'down' && "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debianct' ]] && { [[ ! -f $topdir/$downdir/x.xz || ! -s $topdir/$downdir/x.xz ]] && download_file $TARGETDDURL $topdir/$downdir/x.xz 099; }
  [[ "$1" == 'down' && "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debianctmu' ]] && { [[ ! -f $topdir/$downdir/x.xz || ! -s $topdir/$downdir/x.xz ]] && download_file $TARGETDDURL"/onekeydevdeskd-01core$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz" $topdir/$downdir/x.xz 999; }
  [[ "$1" == 'down' && "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debiandemu' ]] && {
    [[ ! -f $topdir/$downdir/x.xz || ! -s $topdir/$downdir/x.xz ]] && download_file $TARGETDDURL"/onekeydevdeskd-01core$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz" $topdir/$downdir/x.xz 999
    [[ ! -f $topdir/$downdir/vmlinuz || ! -s $topdir/$downdir/vmlinuz ]] && download_file $TARGETDDURL"/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64)" $topdir/$downdir/vmlinuz 029
    [[ ! -f $topdir/$downdir/initrfs.img || ! -s $topdir/$downdir/initrfs.img ]] && download_file $TARGETDDURL"/initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).img" $topdir/$downdir/initrfs.img 049
  }


  # when copy was used,sometimes targetmode 0 and 1 both occurs
  # [[ "$1" == 'copy' ]] && {

    # [[ ! -f $topdir/$downdir/onekeydevdesk/tdlcore.tar.gz || ! -s $topdir/$downdir/onekeydevdesk/tdlcore.tar.gz ]] && cat $topdir/$downdir/onekeydevdesk/tdlcore.tar.gz_* > $topdir/$downdir/onekeydevdesk/tdlcore.tar.gz && [[ $? -ne '0' ]] && echo "cat failed" && exit 1
    # tdlinitrd.gz only in builddir p/
    # [[ "$tmpTARGETMODE" == "1" ]] && [[ ! -f $topdir/$downdir/onekeydevdesk/tdlinitrd.tar.gz || ! -s $topdir/$downdir/onekeydevdesk/tdlinitrd.tar.gz ]] && (for i in `seq -w 000 038`;do wget -qO- --no-check-certificate $MIRROR/$downdir/onekeydevdesk/binary-amd64/tdlinitrd.tar.gz_$i; done) > $topdir/$downdir/onekeydevdesk/tdlinitrd.tar.gz & pid=`expr $! + 0`;wait $pid;echo -en "[ \033[32m tdlinitrd tarball,done \033[0m ]" && [[ $? -ne '0' ]] && echo "download failed" && exit 1
    # [[ ! -f $kernelimage ]] && cat $kernelimage*  > $kernelimage && [[ $? -ne '0' ]] && echo "cat failed" && exit 1

  # }

}


function processbasics(){


  if [[ "$tmpTARGETMODE" != '1' && "$tmpTARGETMODE" != '4' ]]; then

    #cd $topdir/$remasteringdir/initramfs/files;
    #CWD="$(pwd)"
    #echo -en "[ \033[32m cd to ${CWD##*/} \033[0m ]"

    #echo -en " - busy unpacking tdlcore.xz ..."
    [[ "$tmpBUILD" != "1" ]] && tar Jxf $topdir/$downdir/onekeydevdesk/tdlcore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).xz --warning=no-timestamp -C $topdir/$remasteringdir/initramfs/files || tar Jxf $topdir/$downdir/onekeydevdesk/tdlcore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).xz -C $topdir/$remasteringdir/initramfs/files
    [[ "$?" != "0" ]] && exit 1
  fi

  if [[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debianct' ]]; then
    #echo -en " - busy unpacking x.xz ..."
    (cd $topdir/$remasteringdir;tar Jxf $topdir/$downdir/x.xz --warning=no-timestamp;[[ "$?" != "0" ]] && exit 1);
  fi
  if [[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debianctmu' ]]; then
    (mkdir -p /x;cd /x;tar Jxf $topdir/$downdir/x.xz --warning=no-timestamp --strip-components=1 01-core --exclude=01-core/dev/*;[[ "$?" != "0" ]] && exit 1);
  fi


  #cp -aR $topdir/$downdir/onekeydevdesk/debian-live ./lib >>/dev/null 2>&1
  #chmod +x ./lib/debian-live/*
  #cp -aR $topdir/$downdir/onekeydevdesk/updates ./lib/modules/5.10.0-22-amd64 >>/dev/null 2>&1


}


processgrub(){

  [[ "$GRUBTYPE" != '3' && "$GRUBTYPE" != '10' ]] && {


    READGRUB=''$remasteringdir'/boot/grub.read'
    # -a is important to avoid grep error of binary file matching and initrdfail for ubuntu fix
    # under win need escape cf, dont need grep \ and initrdfail
    [[ "$GRUBTYPE" == '11' ]] && cat $GRUBDIR/$GRUBFILE |sed 's/\r//g' |sed -n '1h;1!H;$g;s/\n/%%%%%%%/g;$p' |grep -a -om 1 'menuentry [^{]*{[^}]*}%%%%%%%' |sed 's/%%%%%%%/\n/g' >$READGRUB || cat $GRUBDIR/$GRUBFILE |sed -e 's/"\${initrdfail}"/\$initrdfail/g' |sed -n '1h;1!H;$g;s/\n/%%%%%%%/g;$p' |grep -a -om 1 'menuentry\ [^{]*{[^}]*}%%%%%%%' |sed 's/%%%%%%%/\n/g' >$READGRUB
    LoadNum="$(cat $READGRUB |grep -c 'menuentry ')"
    if [[ "$LoadNum" -eq '1' ]]; then
      cat $READGRUB |sed '/^$/d' >$remasteringdir/boot/grub.new;
    elif [[ "$LoadNum" -gt '1' ]]; then
      CFG0="$(awk '/menuentry /{print NR}' $READGRUB|head -n 1)";
      CFG2="$(awk '/menuentry /{print NR}' $READGRUB|head -n 2 |tail -n 1)";
      CFG1="";
      for tmpCFG in `awk '/}/{print NR}' $READGRUB`
        do
          [ "$tmpCFG" -gt "$CFG0" -a "$tmpCFG" -lt "$CFG2" ] && CFG1="$tmpCFG";
        done
      [[ -z "$CFG1" ]] && {
        echo "Error! read $GRUBFILE. ";
        exit 1;
      }

      sed -n "$CFG0,$CFG1"p $READGRUB >$remasteringdir/boot/grub.new;
      [[ -f $remasteringdir/boot/grub.new ]] && [[ "$(grep -c '{' $remasteringdir/boot/grub.new)" -eq "$(grep -c '}' $remasteringdir/boot/grub.new)" ]] || {
        echo -ne "\033[31m Error! \033[0m Not configure $GRUBFILE. \n";
        exit 1;
      }
    fi
    [ ! -f $remasteringdir/boot/grub.new ] && echo "Error! process $GRUBFILE. " && exit 1;
    [[ "$GRUBTYPE" == '11' ]] && sed -i ':a;N;$!ba;s/menuentry.*{/menuentry\ '"'"'COLXC \[cooperlxclinux\ withrecoveryandhypervinside\]'"'"'\ --class bootinfo\ --class\ icon-bootinfo\ \{/g;s/{.*}/{\n\tlinux\ \/vmlinuz_1kddinst\n\tinitrd\ \/initrfs_1kddinst.img\n}/g' $remasteringdir/boot/grub.new || sed -i "/menuentry.*/c\menuentry\ \'COLXC \[cooperlxclinux\ withrecoveryandhypervinside\]\'\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ --unrestricted\ \{" $remasteringdir/boot/grub.new;
    sed -i "/echo.*Loading/d" $remasteringdir/boot/grub.new;

    CFG00="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)";
    CFG11=()
    for tmptmpCFG in `awk '/}/{print NR}' $GRUBDIR/$GRUBFILE`
    do
      [ "$tmptmpCFG" -gt "$CFG00" ] && CFG11+=("$tmptmpCFG");
    done
    # all routed to grub-reboot logic except win
    [[ "$GRUBTYPE" == '11' ]] && { [[ "$LoadNum" -eq '1' ]] && INSERTGRUB="$(expr ${CFG11[0]} + 1)" || INSERTGRUB="$(awk '/submenu |menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"; } || { [[ "$LoadNum" -eq '1' ]] && INSERTGRUB="$(expr ${CFG11[0]} + 1)" || INSERTGRUB="$(awk '/submenu |menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 2|tail -n 1)"; }
    echo -en "[ \033[32m grubline: $INSERTGRUB \033[0m ]"
  }
  [[ "$GRUBTYPE" == '3' && "$GRUBTYPE" != '10' ]] && {
    CFG0="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)";
    CFG1="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)";
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 == $CFG0 ] && sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE >$remasteringdir/boot/grub.new;
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 != $CFG0 ] && sed -n "$CFG0,$[$CFG1-1]"p $GRUBDIR/$GRUBFILE >$remasteringdir/boot/grub.new;
    [[ ! -f $remasteringdir/boot/grub.new ]] && echo "Error! configure append $GRUBFILE. " && exit 1;
    sed -i "/title.*/c\title\ \'DebianNetboot \[buster\ amd64\]\'" $remasteringdir/boot/grub.new;
    sed -i '/^#/d' $remasteringdir/boot/grub.new;
    INSERTGRUB="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
  }

  [[ "$GRUBTYPE" == '10' ]] && {

    >$remasteringdir/boot/grub.new
    tee -a $remasteringdir/boot/grub.new > /dev/null <<EOF
set timeout=10
set default=0
# if on GRUB shell, this might be useful
set root=(memdisk)

# without this,it pops the no video mode in booting
insmod efi_gop

menuentry "COLXC" {
    # "/" automatically references the (memdisk)-volume
    # for other volumes, the path would be "(hd0)/boot/..." for example
    linux /boot/vmlinuz
    initrd /boot/initrfs.img
}
menuentry "osx(avaliable till grub supports apfs)" {
    chainloader /System/Library/CoreServices
}
EOF

  }

  [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && {

    [[ -n "$(grep 'linux.*/\|kernel.*/' $remasteringdir/boot/grub.new |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot';

    LinuxKernel="$(grep 'linux.*/\|kernel.*/' $remasteringdir/boot/grub.new |awk '{print $1}' |head -n 1)";
    [[ -z "$LinuxKernel" ]] && echo "Error! read grub config! " && exit 1;
    LinuxIMG="$(grep 'initrd.*/' $remasteringdir/boot/grub.new |awk '{print $1}' |tail -n 1)";
    [ -z "$LinuxIMG" ] && sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" $remasteringdir/boot/grub.new && LinuxIMG='initrd';

    # we have force1stnicname and ln -s tricks instead
    # if [[ "$setInterfaceName" == "1" ]]; then
    #   Add_OPTION="net.ifnames=0 biosdevname=0";
    # else
    #   Add_OPTION="";
    # fi

    # if [[ "$setIPv6" == "1" ]]; then
    #   Add_OPTION="$Add_OPTION ipv6.disable=1";
    # fi

    # $([[ "$tmpINSTEMBEDVNC" == '1' ]] && echo DEBIAN_FRONTEND=gtk) is not needed,will be forced in debug mode
    BOOT_OPTION="console=ttyS0,115200n8 console=tty0 debian-installer/framebuffer=false $([[ "$tmpINSTSSHONLY" == '1' ]] && echo DEBIAN_FRONTEND=text) $([[ "$tmpTARGET" == 'dummy' && "$tmpINSTWITHMANUAL" == '1' ]] && echo rescue/enable=true) auto=true $Add_OPTION hostname=debian domain= -- quiet";

    [[ "$Type" == 'InBoot' ]] && {
      sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz_1kddinst $BOOT_OPTION" $remasteringdir/boot/grub.new;
      sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/boot\/initrfs_1kddinst.img" $remasteringdir/boot/grub.new;
    }

    [[ "$Type" == 'NoBoot' ]] && {
      sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/vmlinuz_1kddinst $BOOT_OPTION" $remasteringdir/boot/grub.new;
      sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/initrfs_1kddinst.img" $remasteringdir/boot/grub.new;
    }
  }

  [[ "$tmpBUILD" == "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && {

    LinuxKernel="linux";
    LinuxIMG="initrd";
    BOOT_OPTION="console=ttyS0,115200n8 console=tty0 debian-installer/framebuffer=false $([[ "$tmpINSTSSHONLY" == '1' ]] && echo DEBIAN_FRONTEND=text) $([[ "$tmpTARGET" == 'dummy' && "$tmpINSTWITHMANUAL" == '1' ]] && echo rescue/enable=true) auto=true hostname=debian domain= -- quiet";
    sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\\\$prefix\/vmlinuz_1kddinst $BOOT_OPTION" $remasteringdir/boot/grub.new;
    sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\\\$prefix\/initrfs_1kddinst.img" $remasteringdir/boot/grub.new;

  }

  [[ "$tmpBUILD" == "1" ]] && [[ "$tmpTARGETMODE" != "1" ]] && {

    LinuxKernel="linux";
    LinuxIMG="initrd";
    BOOT_OPTION="console=ttyS0,115200n8 console=tty0 debian-installer\/framebuffer=false $([[ "$tmpINSTSSHONLY" == '1' ]] && echo DEBIAN_FRONTEND=text) $([[ "$tmpTARGET" == 'dummy' && "$tmpINSTWITHMANUAL" == '1' ]] && echo rescue\/enable=true) auto=true hostname=debian domain= -- quiet";
    sed -i "" "s/$LinuxKernel.*/$LinuxKernel \/vmlinuz_1kddinst $BOOT_OPTION/g" $remasteringdir/boot/grub.new;
    sed -i "" "s/$LinuxIMG.*/$LinuxIMG \/initrfs_1kddinst.img/g" $remasteringdir/boot/grub.new;

  }

  [[ "$tmpBUILD" != "1" ]] && sed -i '$a\\n' $remasteringdir/boot/grub.new || sed -i "" $'$a\\\n\n' $remasteringdir/boot/grub.new;

}

patchgrub(){

  GRUBPATCH='0';

  if [[ "$tmpBUILD" != "1" && "$tmpTARGETMODE" != '1' || "$tmpBUILDINSTTEST" == '1' ]]; then
    #[ -f '/etc/network/interfaces' ] || {
    #  echo "Error, Not found interfaces config.";
    #  exit 1;
    #}

    sed -i ''${INSERTGRUB}'i\\n' $GRUBDIR/$GRUBFILE;
    sed -i ''${INSERTGRUB}'r '$remasteringdir'/boot/grub.new' $GRUBDIR/$GRUBFILE;

    sed -i 's/timeout_style=hidden/timeout_style=menu/g' $GRUBDIR/$GRUBFILE;
    sed -i 's/timeout=[0-9]*/timeout=10/g' $GRUBDIR/$GRUBFILE;

    [[ "$tmpBUILDINSTTEST" == '1' ]] && sed -e 's/vmlinuz_1kddinst/vmlinuz_1kddlocaltest live/g' -e 's/initrfs_1kddinst.img/initrfs_1kddlocaltest.img/g' -i $GRUBDIR/$GRUBFILE;

    [[ -f $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv;
  fi

}

restoreall(){

  [[ "$1" == 'dnsonly' ]] && {
    [[ -f /etc/resolv.conf.bak ]] && cp -f /etc/resolv.conf.bak /etc/resolv.conf
    [[ -f /etc/resolv.conf.old ]] && cp -f /etc/resolv.conf.old /etc/resolv.conf
  } || {
    [[ -f /etc/resolv.conf.bak ]] && cp -f /etc/resolv.conf.bak /etc/resolv.conf
    [[ -f /etc/resolv.conf.old ]] && cp -f /etc/resolv.conf.old /etc/resolv.conf
    [[ -f $GRUBDIR/$GRUBFILE.bak ]] && cp -f $GRUBDIR/$GRUBFILE.bak $GRUBDIR/$GRUBFILE
    [[ -f $GRUBDIR/$GRUBFILE.old ]] && cp -f $GRUBDIR/$GRUBFILE.old $GRUBDIR/$GRUBFILE

    [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && grub-reboot 0
    [[ "$tmpBUILD" == "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && { GRUBID=`bcdedit /enum ACTIVE|sed 's/\r//g'|tail -n4|head -n 1|awk -F ' ' '{ print $2}'`;bcdedit /enum all | grep --text $GRUBID && bcdedit /bootsequence $GRUBID /remove; }

  }

}


deepumount(){

  # for inplacedd
  umount -f -l "$remasteringdir/x" >/dev/null 2>&1
  # if in a gui natuils filemanager or sth, x is mounted twice, if this is not unmounted, then losetup -d wont take effect
  [[ -d /media/$(whoami) ]] && ls /media/$(whoami)|while read line;do umount -f -l $line >/dev/null 2>&1;done
  # abspath is needed
  losetup -j "$topdir/$remasteringdir/vm-1010102-disk-0.raw" >/dev/null 2>&1|while read line;do losetup -d `echo $line|awk '{print $1}'|sed 's/://'` >/dev/null 2>&1;done
  [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { if mountpoint -q "$remasteringdir/x";then echo "$remasteringdir/x" still mounted && exit 1;fi; }

}

inplacemutating(){


  [[ "$tmpTARGET" == 'debianct' || "$tmpTARGET" == 'debianctmu' ]] && [[ "$tmpCTVIRTTECH" != '' && "$tmpCTVIRTTECH" == '1' ]] && {


    ### migrate_configuration
    sed -i '/^root:/d' /x/etc/shadow
    grep '^root:' /etc/shadow >> /x/etc/shadow
    # [ -d /root/.ssh ] && cp -a /root/.ssh /x/root/
    [ -d /x/etc/network/ ] || mkdir -p /x/etc/network/
    if [ -f /etc/network/interfaces ] && grep static /etc/network/interfaces > /dev/null ; then
        cp -rf /etc/network/interfaces /x/etc/network/interfaces
    else
        cp -rf $remasteringdir/ctrnet /x/etc/network/interfaces
    fi
    rm /x/etc/resolv.conf
    cp -rf $remasteringdir/ctrdns /x/etc/resolv.conf


    ### replace_os
    mkdir /x/oldroot
    mount --bind / /x/oldroot
    chroot "/x/" /bin/bash -c 'cd /oldroot; '`
        `'rm -rf $(ls /oldroot | grep -vE "(^dev|^proc|^sys|^run|^x)") ; '`
        `'cd /; '`
        `'mv -f $(ls / | grep -vE "(^dev|^proc|^sys|^run|^oldroot)") /oldroot'
    umount /x/oldroot


    ### post_install
    export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
    apt-get install -y -qq openssh-server openssh-client net-tools
    # systemctl disable systemd-networkd.service
    echo PermitRootLogin yes >> /etc/ssh/sshd_config
    rm -rf /x
    sync
  }

  [[ "$tmpTARGET" == 'debianct' || "$tmpTARGET" == 'debianctmu' ]] && [[ "$tmpCTVIRTTECH" != '' && "$tmpCTVIRTTECH" == '2' ]] && {

    tmpDEV=$(mount | grep "$remasteringdir/x" | awk '{print $1}')
    [ -z "$tmpDEV" ] && {

      tmpDEV=`losetup -fP --show $remasteringdir/vm-1010102-disk-0.raw | awk '{print $1}'`
      sleep 2 && echo -en "[ \033[32m tmpdev: $tmpDEV \033[0m ]"
    
      [ -n "$tmpDEV" ] && {

       sleep 2 && echo -en "[ \033[32m tmpmnt: "$remasteringdir/x" \033[0m ]"
       mount "$tmpDEV"p1 "$remasteringdir/x"
      }

      #[ ! -d "$remasteringdir/x" ] && {
      #}
    }

    [[ -f "$remasteringdir/x"/etc/network/interfaces ]] && sed -i "s/iface eth0 inet dhcp/iface eth0 inet static\n  address $IP\n  netmask $MASK\n  gateway $GATE/g" "$remasteringdir/x"/etc/network/interfaces
    [[ -f "$remasteringdir/x"/init ]] && sed -i "s/vda/$DEFAULTHD/g" "$remasteringdir/x"/init
    deepumount

  }


  #[[ "$tmpCTVIRTTECH" != '' && "$tmpCTVIRTTECH" == '1' ]] && echo #rsync -a -v --delete-after --ignore-times --exclude="/dev" --exclude="/proc" --exclude="/sys" --exclude="/x" --exclude="/run" $topdir/$remasteringdir/x/* /
  # we cant echo anything out,or dd will fail,this is strange
  #[[ "$tmpCTVIRTTECH" != '' && "$tmpCTVIRTTECH" == '2' ]] && echo u > /proc/sysrq-trigger && dd if="$topdir/$remasteringdir/vm-1010102-disk-0.raw" of=/dev/"$DEFAULTHD" bs=10M #status=progress
}


ddtoafile(){

  tmpMNT="$topdir/mnt"
  tmpDEV=$(mount | grep "$tmpMNT" | awk '{print $1}')

  sleep 2s && echo -en "\n - clearing the scaffold image file: ..."

  umount -f -l "$tmpMNT"_p2 "$tmpMNT"_p3 >/dev/null 2>&1
  if mountpoint -q "$tmpMNT"_p2;then echo "$tmpMNT"_p2 still mounted && exit 1;fi
  if mountpoint -q "$tmpMNT"_p3;then echo "$tmpMNT"_p3 still mounted && exit 1;fi
  losetup -j "$topdir/imgscafford"|while read line;do sudo losetup -d `echo $line|awk '{print $1}'|sed 's/://'`;done
  losetup -j "$topdir/imgscafford (deleted)"|while read line;do sudo losetup -d `echo $line|awk '{print $1}'|sed 's/://'`;done
  rm -rf $topdir/imgscafford "$tmpMNT"_p2 "$tmpMNT"_p3

  sleep 2s && echo -en "\n - preparing the scaffold image file: ..."

  [ -z "$tmpDEV" ] && {

    dd if=/dev/zero of=$topdir/imgscafford bs=512 seek=`expr 2097152 \* $custIMGSIZE` count=0 >/dev/null 2>&1
    tmpDEV=`losetup -fP --show $topdir/imgscafford | awk '{print $1}'`
    sleep 2s && echo -en "[ \033[32m dev:$tmpDEV \033[0m ]"
    
    [ -n "$tmpDEV" ] && {

      # we must guarantee the 200m as fat32(not fat16) tagged and formatted both in mbr or gpt,or the linuxlive wont recongize it
      parted -s "$tmpDEV" mklabel gpt >/dev/null 2>&1 && \
      parted -s "$tmpDEV" mkpart non-fs 2048s 4095s mkpart rom 4096s 413695s mkpart rom2 413696s 823295s mkpart sys 823296s 11309055s mkpart data 11309056s 90% mkpart swap 90% 100% >/dev/null 2>&1 && \
      parted -s "$tmpDEV" set 1 bios_grub on set 1 hidden on set 3 boot on set 3 esp on >/dev/null 2>&1 && \
      mkfs.ext2 "$tmpDEV"p2 -L "ROM" >/dev/null 2>&1 && \
      mkfs.fat -F16 "$tmpDEV"p3 -n "ROM2" >/dev/null 2>&1 && \
      mkfs.ext4 "$tmpDEV"p4 -L "SYS" >/dev/null 2>&1 && \
      mkfs.ext4 "$tmpDEV"p5 -L "DATA" >/dev/null 2>&1 && \
      mkswap "$tmpDEV"p6 -L "SWAP" >/dev/null 2>&1
    }

    [ ! -d "$tmpMNT" ] && \
      mkdir -p "$tmpMNT"_p2 "$tmpMNT"_p3 "$tmpMNT"_p4 "$tmpMNT"_p5 && \
      mount "$tmpDEV"p2 "$tmpMNT"_p2 && mount "$tmpDEV"p3 "$tmpMNT"_p3 && mount "$tmpDEV"p4 "$tmpMNT"_p4 && mount "$tmpDEV"p5 "$tmpMNT"_p5
      sleep 2s && echo -en "[ \033[32m mnts: ""$tmpMNT"_p2" ""$tmpMNT"_p3" ""$tmpMNT"_p4" ""$tmpMNT"_p5" \033[0m ]"
  }

  sleep 2s && echo -en "\n - processing the scaffold image file: ..."

  cat $topdir/$downdir/vmlinuz >> "$tmpMNT"_p2/vmlinuz
  cat $topdir/$downdir/initrfs.img >> "$tmpMNT"_p2/initrfs.img
  cat $topdir/$downdir/x.xz|tar Jx -C "$tmpMNT"_p4

  mv "$tmpMNT"_p4/01-core/boot/grub "$tmpMNT"_p2
  mv "$tmpMNT"_p4/01-core/boot/EFI "$tmpMNT"_p3
  mkdir -p "$tmpMNT"_p4/onekeydevdesk
  mv "$tmpMNT"_p4/01-core "$tmpMNT"_p4/02-gui "$tmpMNT"_p4/onekeydevdesk

  [[ $tmpBUILDGENE == '0' ]] && grub-mkimage -C xz -O i386-pc -o "$tmpMNT"_p2/grub/i386-pc/core.img -p "(hd0,gpt2)/grub" -d "$tmpMNT"_p2/grub/i386-pc biosdisk part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec
  [[ $tmpBUILDGENE == '0' ]] && "$tmpMNT"_p2/grub/i386-pc/grub-bios-setup -d "$tmpMNT"_p2/grub/i386-pc -b boot.img -c core.img "$tmpDEV"
  [[ $tmpBUILDGENE == '0' ]] && grub-mkimage -C xz -O x86_64-efi -o "$tmpMNT"_p3/EFI/boot/bootx64.efi -p "(hd0,gpt2)/grub" -d "$tmpMNT"_p2/grub/x86_64-efi part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec || grub-mkimage -C xz -O arm64-efi -o "$tmpMNT"_p3/EFI/boot/bootaa64.efi -p "(hd0,gpt2)/grub" -d "$tmpMNT"_p2/grub/arm64-efi part_msdos part_gpt exfat ext2 fat iso9660 btrfs lvm dm_nv mdraid09_be mdraid09 mdraid1x raid5rec raid6rec

  bootfsuuid=`blkid -s UUID -o value "$tmpDEV"p2`
  rootfsuuid=`blkid -s UUID -o value "$tmpDEV"p5`
  # dont -e s/ROOTFSUUID/$rootfsuuid/g or the grubmenu wont show
  sed -e s/BOOTPARTNO/2/g -e s/BOOTFSUUID/$bootfsuuid/g -i "$tmpMNT"_p2/grub/grub.cfg
  #sed -e s/BOOTFSUUID/$bootfsuuid/g -e s/UEFIFSUUID/$uefifsuuid/g -e s/SWAPFSUUID/$swapfsuuid/g -e s/ROOTFSUUID/$rootfsuuid/g -i $remasteringdir/fstab
  mkdir -p "$tmpMNT"_p2/efi "$tmpMNT"_p5/sys "$tmpMNT"_p5/dockerd "$tmpMNT"_p5/onekeydevdeskd "$tmpMNT"_p5/onekeydevdeskd/changes1 "$tmpMNT"_p5/onekeydevdeskd/changes2 "$tmpMNT"_p5/onekeydevdeskd/updates

  > $topdir/start.txt
  tee -a $topdir/start.txt > /dev/null <<EOF
#for linux
qemu-system-x86_64 -accel kvm -accel tcg -machine q35 -smp 2 -m 1G \\
-vga std -usbdevice tablet -usbdevice keyboard -drive "file=./imgscafford,format=raw" -net nic,model=virtio-net-pci -net user \\
-boot order=c,menu=on

#for osx
qemu-system-x86_64 -accel hvf -accel tcg -machine q35 -smp 2 -m 1G \\
-vga std -usbdevice tablet -usbdevice keyboard -drive "file=./imgscafford,format=raw" -net nic,model=virtio-net-pci -net vmnet-shared \\
-boot order=c,menu=on

#for win
"C:\Program Files\qemu\qemu-system-x86_64" -accel whpx -accel tcg -machine q35 -smp 2 -m 1G ^
-vga std -usbdevice tablet -usbdevice keyboard -drive "file=./imgscafford,format=raw" -net nic,model=virtio-net-pci -net user ^
-boot order=c,menu=on
EOF

}


# . p/999.utils/build2.sh

# =================================================================
# Below are main routes
# =================================================================

export PATH=.:./tools:../tools:$PATH
CWD="$(pwd)"
topdir=$CWD
cd $topdir
clear
Outbanner wizardmode
[[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Changing current directory to $CWD"
[[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && [[ `command -v "tput"` && `command -v "resize"` ]] && [[ "$(tput cols)" -lt '100'  ]] && resize -s "$(tput lines)" 110 >/dev/null 2>&1

# dir settings
downdir='_tmpdown'
remasteringdir='_tmpremastering'
targetdir='_tmpbuild'
mkdir -p $downdir $remasteringdir $targetdir

# below,we put enviroment-forced args(full args logics) prior over manual ones(simplefrontend)

[[ $# -eq 0 ]] && {


  while [[ -z "$tmpTARGET" ]]; do
    # bash read don't show prompt while using with exec sudo bash -c "`cat -`" -a "$@",,so we should
    read -p "target needed, type a target to go, or any -option to continue: " NN </dev/tty
    case $NN in
      -m) read -p "Enter your own FORCEDEBMIRROR directlink (or type to use inbuilt: `echo -e "\033[33mgithub,gitee\033[0m"`): " FORCEDEBMIRROR </dev/tty;[[ "$FORCEDEBMIRROR" == 'github' ]] && FORCEDEBMIRROR=$autoDEBMIRROR0;[[ "$FORCEDEBMIRROR" == 'gitee' ]] && FORCEDEBMIRROR=$autoDEBMIRROR1 ;;
      -i) read -p "Enter your own FORCE1STNICNAME (format: `echo -e "\033[33mensp0\033[0m"`): " FORCE1STNICNAME </dev/tty ;;
      -n) read -p "Enter your own FORCENETCFGSTR (format: `echo -e "\033[33m10.211.55.2/24,10.211.55.1\033[0m"`): " FORCENETCFGSTR </dev/tty;[[ -n "$FORCENETCFGSTR" ]] && [[ `echo "$FORCENETCFGSTR" | grep -Eo ":"` != '' ]] && FORCENETCFGV6ONLY=1 ;;
      -6) FORCENETCFGV6ONLY=1;echo "FORCENETCFGV6ONLY set to `echo -e "\033[33m1\033[0m"` " ;;
      -p) read -p "Enter your own FORCE1STHDNAME (format: `echo -e "\033[33mnvme0p1\033[0m"`): " FORCE1STHDNAME </dev/tty ;;
      -w) read -p "Enter your own FORCEPASSWORD (format: `echo -e "\033[33mmypass\033[0m"`): " FORCEPASSWORD </dev/tty ;;
      -o) read -p "Enter your own FORCEINSTCTL (format: `echo -e "\033[33m1=noexpanddisk|2=noinjectnetcfg|3=noreboot|4=nopreclean\033[0m"`): " FORCEINSTCTL </dev/tty ;;
      -d) tmpDEBUG=1;echo "tmpDEBUG set to `echo -e "\033[33m1\033[0m"` ";[[ "$tmpDEBUG" == '1' ]] && [[ "$tmpTARGETMODE" != '1' ]] && tmpINSTWITHMANUAL='1' ;;
      -t|*) [[ ${NN} == '-t' ]] && { mapfile -t -s 0 myarr < <(wget --no-check-certificate -qO- https://minlearn.org/inst/instrepos/mini |grep -Eo '<tbody>.*</tbody>' |sed -e 's#</td></tr><tr><td#</td></tr>\n<tr><td#g' -e "s#<tbody>\|</tbody>\|<tr>\|</td>\|</tr>##g"  | sed -e 's#<a href=".*">##g' -e 's#</a>##g'|awk -v var1="$([[ $tmpHOSTARCH != '1' ]] && echo amd || echo arm)64" -v var2="$([[ $tmpBUILDGENE != '2' ]] && echo BIOS || echo UEFI)" -F "<td align=\"center\">" '{if ($5==var1 && $6~var2) print $8}');read -p "Enter a target name/idx or bringyourown directlink (inbuilt: `echo -e "\033[33mdebian|debianmu|debiandemu|debianctmu|dummy\033[0m"` 3rd: `[[ -n myarr ]] && { i=0;while [ $i -lt ${#myarr[@]} ];do echo -ne "\033[33m[\`expr $i \+ 1\`]${myarr[$i]##*/} \033[0m";((i++));done; }`): " tmpTARGET0 </dev/tty; } || tmpTARGET0=$NN;[[ ${tmpTARGET0:0:1} != '/' ]] && { tmpTARGET=$tmpTARGET0; } || { [[ "$autoDEBMIRROR0" =~ "/inst/raw/master" ]] || { IMGMIRROR0=${autoDEBMIRROR0}"/.." && tmpTARGET00=$tmpTARGET0 && tmpTARGET=`echo "$tmpTARGET00" |sed "s#^#$IMGMIRROR0#g"`; }; };[[ "$tmpTARGET0" == "debianct" || "$tmpTARGET0" == "debianctmu" ]] && tmpTARGETMODE='4';[[ "$FORCE1STHDNAME" != '' && "$tmpTARGET0" == "debiandemu" ]] && echo "cant set -p when target is debiandemu" && exit 1;[[ "$tmpTARGET0" == "debiandemu" ]] && tmpTARGETMODE='4';[[ "$tmpTARGET0" == "dummy" ]] && tmpTARGETMODE='0' && tmpTARGET='dummy' && tmpINSTWITHMANUAL='1';[[ $tmpTARGET0 =~ ^-?[0-9]+$ ]] && { tmpTARGET=${myarr[tmpTARGET0-1]#*]}; };echo "$tmpTARGET0" |grep -q '^http://\|^ftp://\|^https://';[[ $? -eq '0' ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && tmpTARGETMODE=0;echo "$tmpTARGET0" |grep -q '^10000:/dev/';[[ $? -eq '0' ]] && tmpTARGETMODE=2;echo "$tmpTARGET0" |grep -q '^http://.*:10000';[[ $? -eq '0' ]] && tmpTARGETMODE=0 ;;
    esac;
  done

}

[[ "$(uname)" == "Darwin" ]] && tmpBUILD='1' && echo "osx detected"
[[ -f /cygdrive/c/cygwin64/bin/uname && ( "$(/cygdrive/c/cygwin64/bin/uname -o)" == "Cygwin" || "$(/cygdrive/c/cygwin64/bin/uname -o)" == "Msys") ]] && tmpBUILD='11' && echo "windows detected"
[[ "$(arch)" == "aarch64" ]] && echo Arm64 detected,will force arch as 1 && tmpHOSTARCH='1'
[[ -d /sys/firmware/efi ]] && echo uefi detected,will force gen as 2 && tmpBUILDGENE='2'
[[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && { DEFAULTWORKINGNIC2="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')"; [[ -z "$DEFAULTWORKINGNIC2" ]] && { DEFAULTWORKINGNIC2="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; }; DEFAULTWORKINGIPSUBV42="$(ip addr |grep ''${DEFAULTWORKINGNIC2}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";DEFAULTWORKINGGATEV42="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";DEFAULTWORKINGIPSUBV62="$(ip -6 -brief address show scope global|grep ''${DEFAULTWORKINGNIC2}'' |awk -F ' ' '{ print $3}')";DEFAULTWORKINGGATEV62="$(ip -6 -brief route show default|grep ''${DEFAULTWORKINGNIC2}'' |awk -F ' ' '{ print $3}')"; [[ -n "$DEFAULTWORKINGIPSUBV42" && -n "$DEFAULTWORKINGGATEV42" ]] || { [[ -n "$DEFAULTWORKINGIPSUBV62" && -n "$DEFAULTWORKINGGATEV62" ]] && echo "IPV6 only detected,will force FORCENETCFGV6ONLY to 1" && FORCENETCFGV6ONLY=1; }; };
[[ "$tmpBUILD" == "11" ]] && { DEFAULTWORKINGNICIDX2="$(netsh int ipv4 show route | grep --text -F '0.0.0.0/0' | awk '$6 ~ /\./ {print $5}')";[[ -z "$DEFAULTWORKINGNICIDX2" ]] && { DEFAULTWORKINGNICIDX2="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')"; }; [[ -n "$DEFAULTWORKINGNICIDX2" ]] && DEFAULTWORKINGIPARR1=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX2'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`; DEFAULTWORKINGGATEARR1=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX2'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`; [[ -n "$DEFAULTWORKINGNICIDX2" ]] && DEFAULTWORKINGIPARR2=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX2'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f2)`; DEFAULTWORKINGGATEARR2=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX2'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f2)`; [[ `echo $DEFAULTWORKINGIPARR1|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR1|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR2|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR2|grep -Eo ":"` ]] && echo "IPV6 only detected,will force FORCENETCFGV6ONLY to 1" && FORCENETCFGV6ONLY=1; };
[[ "$tmpBUILD" == "1" ]] && { DEFAULTWORKINGNIC2="$(netstat -nr -f inet|grep default|awk '{print $4}')";[[ -z "$DEFAULTWORKINGNIC2" ]] && { DEFAULTWORKINGNIC2="$(netstat -nr -f inet6|grep default|awk '{print $4}' |head -n1)"; }; [[ -n "$DEFAULTWORKINGNIC2" ]] && DEFAULTWORKINGIPARR1=`ifconfig ''${DEFAULTWORKINGNIC2}'' |grep -Fv inet6|grep inet|awk '{print $2}'`; DEFAULTWORKINGGATEARR1=`netstat -nr -f inet|grep default|grep ''${DEFAULTWORKINGNIC2}'' |awk '{print $2}'`; [[ -n "$DEFAULTWORKINGNIC2" ]] && DEFAULTWORKINGIPARR2=`ifconfig ''${DEFAULTWORKINGNIC2}'' |grep inet6|head -n1|awk '{print $2}'|sed 's/%.*//g'`; DEFAULTWORKINGGATEARR2=`netstat -nr -f inet6|grep default|grep ''${DEFAULTWORKINGNIC2}'' |awk '{ print $2}'|sed 's/%.*//g'`; [[ `echo $DEFAULTWORKINGIPARR1|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR1|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR2|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR2|grep -Eo ":"` ]] && echo "IPV6 only detected,will force FORCENETCFGV6ONLY to 1" && FORCENETCFGV6ONLY=1; };

while [[ $# -ge 1 ]]; do
  case $1 in
    -n|--forcenetcfgstr)
      shift
      FORCENETCFGSTR="$1"
      [[ -n "$FORCENETCFGSTR" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && [[ `echo "$FORCENETCFGSTR" | grep -Eo ":"` != '' ]] && { FORCENETCFGV6ONLY=1 && echo "Netcfgstr forced to some v6 value,will force setnet mode"; } || { echo "Netcfgstr forced to some v4 value,will force setnet mode"; }
      shift
      ;;
    -6|--forcenetcfgv6only)
      shift
      FORCENETCFGV6ONLY="$1"
      [[ -n "$FORCENETCFGV6ONLY" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "FORCENETCFGV6ONLY forced to some value,will force IPV6ONLY stack probing mode"
      shift
      ;;
    -i|--force1stnicname)
      shift
      FORCE1STNICNAME="$1"
      [[ -n "$FORCE1STNICNAME" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "1stnicname forced to some value,will force 1stnic name"
      shift
      ;;
    -m|--forcemirror)
      shift
      FORCEDEBMIRROR="$1"
      [[ "$FORCEDEBMIRROR" == 'github' ]] && FORCEDEBMIRROR=$autoDEBMIRROR0;[[ "$FORCEDEBMIRROR" == 'gitee' ]] && FORCEDEBMIRROR=$autoDEBMIRROR1
      [[ -n "$FORCEDEBMIRROR" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Mirror forced to some value,will override autoselectdebmirror results"
      shift
      ;;
    -p|--force1sthdname)
      shift
      FORCE1STHDNAME="$1"
      [[ "$tmpTARGET" == 'debiandemu' ]] && echo "cant set -p when target is debiandemu" && exit 1;
      [[ -n "$FORCE1STHDNAME" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "1sthdname forced to some value,will force 1sthd name"
      shift
      ;;
    -w|--forcepassword)
      shift
      FORCEPASSWORD="$1"
      [[ -n "$FORCEPASSWORD" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "password forced to some value,will force oripass or curpass"
      shift
      ;;
    -o|--forceinstctl)
      shift
      FORCEINSTCTL="$1"
      [[ -n "$FORCEINSTCTL" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "instctl forced to some value,will force instctl (and post process)"
      shift
      ;;
    -b|--build)
      shift
      tmpBUILD="$1"
      #[[ "$tmpBUILD" == '2' ]] && echo "LXC given,will auto inform tmpBUILDADDONS as 1,this is not by customs" && tmpBUILDADDONS='1' && tmpTARGETMODE='1' && echo -en "\n" && [[ -z "$tmpBUILDADDONS" ]] && echo "buildci were empty" && exit 1
      #[[ "$tmpBUILD" != '2' ]] && tmpBUILDADDONS='0' && tmpTARGETMODE='1'
      shift
      ;;
    -h|--host)
      shift
      tmpHOST="$1"
      case $tmpHOST in
        ''|spt|orc) tmpHOSTMODEL='0' ;;
        az) tmpHOSTMODEL='1' ;;
        sr) tmpHOSTMODEL='2' ;;
        ks|mbp) tmpHOSTMODEL='3' ;; # && [[ -z "$tmpHOSTMODEL" ]] && echo "Hostmodel should be 3 but not set" && exit 1 ;;
        0*)

          for ht in `[[ "$tmpBUILD" -ne '0' ]] && echo "${1##0}" |sed 's/,/\n/g' || echo "${1##0}" |sed 's/,/\'$'\n''/g'`
          do
            HOSTMODLIST+=",""${ht}"
          done
          [[ "$tmpHOST" == '0' ]] && tmpHOSTMODEL='0'
          [[ "$tmpHOST" =~ '0,' ]] && tmpHOSTMODEL='99' && echo "With host modules to be inc in:""$HOSTMODLIST"",will force hostmodel as 99" ;;

        *) echo "Unknown host" && exit 1 ;;
      esac
      shift
      ;;
    -s|--serial)
      shift
      tmpINSTSERIAL="$1"
      [[ "$tmpINSTSERIAL" == '1' ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Serial forced,will process serial console after booting"
      shift
      ;;
    -g|--gene)
      shift
      tmpBUILDGENE="$1"
      [[ "$tmpBUILDGENE" == '0' && "$tmpBUILDGENE" != '' ]] && [[ $tmpTARGETMODE == 0 || $tmpTARGETMODE == 1 && $forcemaintainmode != 1 ]] && echo "biosmbr only given,will process biosmbr bootinglogic and disk supports for buildmode or force it in installmode"
      [[ "$tmpBUILDGENE" == '1' && "$tmpBUILDGENE" != '' ]] && [[ $tmpTARGETMODE == 0 || $tmpTARGETMODE == 1 && $forcemaintainmode != 1 ]] && echo "biosgpt only given,will process biosgpt bootinglogic and disk supports for buildmode or force it in installmode"
      [[ "$tmpBUILDGENE" == '2' && "$tmpBUILDGENE" != '' ]] && [[ $tmpTARGETMODE == 0 || $tmpTARGETMODE == 1 && $forcemaintainmode != 1 ]] && echo "uefigpt only given,will process uefigpt bootinglogic and disk supports for buildmode or force it in installmode"
      [[ "$tmpBUILDGENE" == '0,1,2' && "$tmpBUILDGENE" != '' ]] && tmpTARGETMODE='1' && echo "all gens given,will process all bootinglogic and disk supports for buildmode"
      shift
      ;;
    -a|--arch)
      shift
      tmpHOSTARCH="$1"
      [[ "$tmpHOSTARCH" == '0' && "$tmpHOSTARCH" != '' ]] && [[ $tmpTARGETMODE == 0 || $tmpTARGETMODE == 1 && $forcemaintainmode != 1 ]] && echo "Amd64 only given,will process amd64 addon supports for buildmode or force arm in installmode"
      [[ "$tmpHOSTARCH" == '1' && "$tmpHOSTARCH" != '' ]] && [[ $tmpTARGETMODE == 0 || $tmpTARGETMODE == 1 && $forcemaintainmode != 1 ]] && echo "Arm64 only given,will process arm64 addon supports for buildmode or force arm in installmode"
      [[ "$tmpHOSTARCH" == '0,1' && "$tmpHOSTARCH" != '' ]] && tmpTARGETMODE='1' && echo "all archs given,will process all addon supports for buildmode"
      shift
      ;;
    -v|--virt)
      shift
      tmpCTVIRTTECH="$1"
      [[ "$tmpCTVIRTTECH" == '1' && $tmpTARGETMODE == 4 && $forcemaintainmode != 1 ]] && echo "ct lxc tech given,will force lxc in inplacedd installmode"
      [[ "$tmpCTVIRTTECH" == '2' && $tmpTARGETMODE == 4 && $forcemaintainmode != 1 ]] && echo "ct kvm tech given,will force kvm in inplacedd installmode"
      shift
      ;;

      # the targetmodel are auto deduced finally here (with hostmodel and tmptarget determined it)
      # for hostmodel,if -h are < 99,it must be in instmode and given as invidude,in buildmode = 99,it is always mixed with 0,and goes after it
    -t|--target)
      shift
      tmpTARGET="$1"
      case $tmpTARGET in
        '') echo "Target not given,will exit" && exit 1 ;;
        dummy) echo "dummy given,will try debugmode" && tmpTARGETMODE='0' && tmpINSTWITHMANUAL='1' ;;
        debianbase|onekeydevdesk) tmpTARGETMODE='1' ;;
        deb) tmpTARGET='debian' && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "deb given,will force nativedi instmode and debian target(currently 11)" ;;
        debian) tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "debian given,will force nativedi instmode and debian target(currently 11)" ;;
        lxc*|qemu*) tmpTARGETMODE='1';GENCONTAINERS="$1";PACKCONTAINERS="$1";echo "Standalone container/qemuserver pack mode without building initfs and 01-core" ;;
        debian10r) tmpTARGETMODE='0' ;;
        debianctmu) tmpTARGETMODE='4' && echo "debianctmu given,will force inplace instmode and devdeskos ct images(based on virttech)" ;;
        debiandemu) [[ "$FORCE1STHDNAME" != '' ]] && echo "cant set -p when target is debiandemu" && exit 1;tmpTARGETMODE='4' && FORCE1STHDNAME='localfile' && echo "debiandemu given,will force inplace instmode and localfile -p" ;;
        devdeskos*|debianmu*) tmpTARGET=${1/debianmu/devdeskos}

          for tgt in `[[ "$tmpBUILD" -ne '0' ]] && echo "${tmpTARGET##devdeskos}" |sed 's/,/\n/g' || echo "${tmpTARGET##devdeskos}" |sed 's/,/\'$'\n''/g'`
          do
          [[ $tgt =~ "++" ]] && { GENCONTAINERS+=",""${tgt##++}";PACKCONTAINERS+=",""${tgt##++}"; } || GENCONTAINERS+=",""${tgt##+}"
          done
          [[ "$tmpHOSTMODEL" -lt '99' && "$tmpTARGET" == 'devdeskos' ]] && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Devdeskos Wgetdd instonly mode detected"
          [[ "$tmpHOSTMODEL" -lt '99' && "${tmpTARGET:0:9}" == "devdeskos" && "${#tmpTARGET}" -gt '9' ]] && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Devdeskos specialedition Wgetdd instonly mode detected"
          [[ "$tmpHOSTMODEL" == '99' && "$tmpTARGET" == 'devdeskos' ]] && tmpTARGETMODE='1' && echo "Fullgen mode detected"
          [[ "$tmpHOSTMODEL" == '99' && "$tmpTARGET" =~ 'devdeskos,' ]] && tmpTARGET='devdeskos' && tmpTARGETMODE='1' && echo "Fullgen mode detected,with container/qemuserver merge/pack addons:""$GENCONTAINERS" |sed 's/,/ /g' ;;
          #[[ "$tmpHOST" != '2' && "$tmpTARGET" == 'devdeskos' ]] && tmpTARGETMODE=1 || tmpTARGETMODE='0' ;;

        /*) [[ "$autoDEBMIRROR0" =~ "/inst/raw/master" ]] || { IMGMIRROR0=${autoDEBMIRROR0}"/.." && tmpTARGET0=$tmpTARGET && tmpTARGET=`echo "$tmpTARGET0" |sed "s#^#$IMGMIRROR0#g"`; }; tmpTARGETMODE='0' ;;
        *) echo "$tmpTARGET" |grep -q '^http://\|^ftp://\|^https://\|^10000:/dev/\|^/dev/';[[ $? -ne '0' ]] && echo -e "\033[31mTargetname not known or in blank!\033[0m" && exit 1 || { 
          echo "$tmpTARGET" |grep -q '^http://\|^ftp://\|^https://';[[ $? -eq '0' ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "(trans) Raw urls detected,will override autotargetddurl results and force wgetdd instmode" && tmpTARGETMODE=0;
          # if -t were given as port:blkdevname,then enter nc servermode(rever,target)
          # if -t were given as port:ip:blkdevname,then enter nc clientmode(sender,src)
          echo "$tmpTARGET" |grep -q '^10000:/dev/';[[ $? -eq '0' ]] && echo "Port:blkdevname detected,will force nchttpsrv resmode" && tmpTARGETMODE=2;
          echo "$tmpTARGET" |grep -q '^http://.*:10000';[[ $? -eq '0' ]] && echo "Http:Port detected,will force nctarget+instmode" && tmpTARGETMODE=0; } ;;
      esac
      shift
      ;;
    -d|--debug)
      shift
      tmpDEBUG="$1"
      [[ "$tmpTARGET" == '' ]]  && tmpTARGET='dummy' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "no target given, will force target as dummy"
      [[ ("$tmpDEBUG" == '1' || "$tmpDEBUG" == '') && "$tmpTARGETMODE" != '1' ]] && tmpINSTWITHMANUAL='1' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Manual modes enabled in instmode,will force target as its, and force hold before reboot to network-console"
      [[ ("$tmpDEBUG" == '1' || "$tmpDEBUG" == '') && "$tmpTARGETMODE" == '1' ]] && tmpBUILDINSTTEST='1' && tmpINSTWITHMANUAL='1' && echo "Debug supports enabled in buildmode,will keep target as its, and force hold before reboot and localinstant boot test"
      [[ ("$tmpBUILDADDONS" == '1' || "$tmpBUILDADDONS" == '') && "$tmpDEBUG" == '1' ]] && echo "debug and ci cant coexsits" && exit 1
      shift
      ;;
    -c|--ci)
      shift
      tmpBUILDADDONS="$1"
      [[ ("$tmpBUILDADDONS" == '1' || "$tmpBUILDADDONS" == '') && "$tmpTARGETMODE" == '1' ]] && echo "ci forced in buildmode,will force ci actions"
      [[ ("$tmpBUILDADDONS" == '1' || "$tmpBUILDADDONS" == '') && "$tmpDEBUG" == '1' ]] && echo "debug and ci cant coexsits" && exit 1
      shift
      ;;
    --help|*)
      if [[ "$1" != 'error' ]]; then echo -ne "\nInvaild option: '$1'\n\n"; fi
      echo -ne "Usage(args are self explained):\n\t-m/--forcemirror\n\t-n/--forcenetcfgstr\n\t-b/--build\n\t-h/--host\n\t-t/--target\n\t-s/--serial\n\t-g/--gene\n\t-a/--arch\n\t-d/--debug\n\n"
      exit 1;
      ;;
    esac
  done

[[ $tmpTARGETMODE != 1 && $forcemaintainmode == 1 ]] && { echo -e "\033[31m\n维护,脚本无限期闭源或开放，请联系作者\nThe script was invalid in maintaince mode with a undetermined closed/reopen date,please contact the author\n \033[0m"; exit 1; }

#echo -en "\n\033[36m # Checking Prerequisites: \033[0m"

printf "\n ✔ %-30s" "Checking deps ......"
if [[ "$tmpTARGET" == 'debianbase' && "$tmpTARGETMODE" == '1' ]]; then
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,xzcat,zcat,md5sum,sha1sum,sha256sum,grub-reboot;
elif [[ ( "$tmpTARGET" == 'debianct' || "$tmpTARGET" == 'debianctmu' ) && "$tmpTARGETMODE" == '4' && "$tmpBUILD" != '1' ]] ; then
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,xzcat,zcat,rsync,virt-what;
elif [[ "$tmpTARGET" == 'debiandemu' && "$tmpTARGETMODE" == '4' && "$tmpBUILD" != '1' ]] ; then
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,fdisk,xzcat,zcat;
else
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,fdisk,xzcat,zcat,df,openssl;
fi

[[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" != 'debiandemu' ]] && printf "\n ✔ %-30s" "Checking virttech ......"
[[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" != 'debiandemu' ]] && {
  [[ "$tmpCTVIRTTECH" == '1' ]] && echo -en "[ \033[32m force,lxc \033[0m ]";
  [[ "$tmpCTVIRTTECH" == '2' ]] && echo -en "[ \033[32m force,kvm \033[0m ]";
  [[ "$tmpCTVIRTTECH" != '1' && ( "$(virt-what|head -n1)" == "lxc" || "$(virt-what|head -n1)" == "openvz" ) ]] && tmpCTVIRTTECH='1' && echo -en "[ \033[32m auto,lxc \033[0m ]";
  [[ "$tmpCTVIRTTECH" != '2' && "$(virt-what|head -n1)" == "kvm" ]] && tmpCTVIRTTECH='2' && echo -en "[ \033[32m auto,kvm \033[0m ]";
  [[ "$tmpCTVIRTTECH" == '0' ]] && [[ "$tmpCTVIRTTECH" != '1' && "$tmpCTVIRTTECH" != '2' ]] && echo "fail,no virttech detected,will exit" && exit 1;
}

printf "\n ✔ %-30s" "Selecting Mirror/Targets ..." 

if [[ "$tmpTARGETMODE" == '0' || "$tmpTARGETMODE" == '4' ]]; then
  AUTODEBMIRROR=`echo -e $(SelectDEBMirror $autoDEBMIRROR0 $autoDEBMIRROR1)|sort -n -k 2 | head -n2 | grep http | sed  -e 's#[[:space:]].*##'`
  [[ -n "$AUTODEBMIRROR" && -z "$FORCEDEBMIRROR" ]] && DEBMIRROR=$AUTODEBMIRROR && echo -en "[ \033[32m auto,${DEBMIRROR} \033[0m ]"  # || exit 1
  [[ -n "$AUTODEBMIRROR" && -n "$FORCEDEBMIRROR" ]] && DEBMIRROR=$FORCEDEBMIRROR && echo -en "[ \033[32m force,${DEBMIRROR} \033[0m ]"  # || exit 1
  [[ -z "$AUTODEBMIRROR" && -n "$FORCEDEBMIRROR" ]] && DEBMIRROR=$FORCEDEBMIRROR && echo -en "[ \033[32m force,${DEBMIRROR} \033[0m ]"  # || exit 1
  [[ -z "$AUTODEBMIRROR" && -z "$FORCEDEBMIRROR" ]] && DEBMIRROR=$autoDEBMIRROR0 && echo -en "[ \033[32m failover,${DEBMIRROR} \033[0m ]"  # || exit 1
  # simply select auto target img mirror based on github or nongithub url postfix
  [[ "$DEBMIRROR" =~ "/inst/raw/master" ]] && IMGMIRROR=${DEBMIRROR/\/inst\/raw\/master/}"/xxxxxx/raw/master" || IMGMIRROR=${DEBMIRROR/\/inst/}"/xxxxxx"
else
  # force to main github
  DEBMIRROR=$autoDEBMIRROR0 && echo -en "[ \033[32m force,${DEBMIRROR} \033[0m ]";[[ "$DEBMIRROR" =~ "/inst/raw/master" ]] && IMGMIRROR=${DEBMIRROR/\/inst\/raw\/master/}"/xxxxxx/raw/master" || IMGMIRROR=${DEBMIRROR/\/inst/}"/xxxxxx";
fi

# check targeturl
case $tmpTARGET in
  # no need to check,targeturl is debmirror url
  dummy) TARGETDDURL='' ;;
  deb|debian) TARGETDDURL=${IMGMIRROR/xxxxxx/1keyddhubfree-debianbase} ;;
  devdeskos*|devdeskosfull|debianmu*|debianmufull) tmpTARGET=${tmpTARGET/debianmu/devdeskos}; [[ "${#tmpTARGET}" -gt '9' && "${tmpTARGET}" != "devdeskosfull" ]] && TARGETDDURL=${IMGMIRROR/xxxxxx/$tmpTARGET}"/"$tmpTARGET"/binary$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -arm64 || echo -amd64)/tarball" || TARGETDDURL=${IMGMIRROR/xxxxxx/1kdd}"/devdeskos/binary$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n -arm64 || echo -n -amd64)/tarball"
  CheckTargeturl $TARGETDDURL"/onekeydevdeskd-01core$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz_000" ;;
  #devdeskos) TARGETDDURL=$MIRROR/_build/devdeskos/onekeydevdeskd$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64)
    #[[ "$tmpTARGETMODE" == '0' ]] && CheckTargeturl $TARGETDDURL ;;
  debian10r) TARGETDDURL=${IMGMIRROR/xxxxxx/1keyddhubfree-$tmpTARGET}"/"$tmpTARGET"estore/binary$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -arm64 || echo -amd64)/"$tmpTARGET"estore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz"
    [[ "$tmpTARGETMODE" == '0' ]] && CheckTargeturl $TARGETDDURL"_000" ;;
  debianct) TARGETDDURL=${IMGMIRROR/xxxxxx/1keyddhubfree-debtpl}/"$([ "$tmpCTVIRTTECH" == '1' -a "$tmpCTVIRTTECH" != '' ]  && echo lxcdebtpl || echo qemudebtpl)"/binary"$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -arm64 || echo -amd64)"/tarball/"$([ "$tmpCTVIRTTECH" == '1' -a "$tmpCTVIRTTECH" != '' ]  && echo lxcdebtpl || echo qemudebtpl)""$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).tar.xz"
    [[ "$tmpTARGETMODE" == '4' ]] && CheckTargeturl $TARGETDDURL"_000" ;;
  debiandemu|debianctmu) TARGETDDURL=${IMGMIRROR/xxxxxx/1kdd}"/devdeskos/binary$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n -arm64 || echo -n -amd64)/tarball"
    [[ "$tmpTARGETMODE" == '4' ]] && CheckTargeturl $TARGETDDURL"/clientcore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz_000" ;;
  /*|*) TARGETDDURL=$tmpTARGET
    # wedont check "$tmpTARGETMODE" == '1'
    [[ "$tmpTARGETMODE" != '1' ]] && CheckTargeturl $TARGETDDURL ;;
esac


sleep 2


#echo -en "\n\033[36m # Parse and gather infos before remastering: \033[0m"

# lsattr and cont delete,then you shoud restart
umount --force $remasteringdir/initramfs/{dev/pts,dev,proc,sys} $remasteringdir/initramfs_arm64/{dev/pts,dev,proc,sys} >/dev/null 2>&1
umount --force $remasteringdir/onekeydevdeskd/01-core/{dev/pts,dev,proc,sys} $remasteringdir/onekeydevdeskd_arm64/01-core/{dev/pts,dev,proc,sys} >/dev/null 2>&1

# for inplacedd
deepumount

# we should also umount the top mounted dir here after umount chrootsubdir?
# xxx

[[ -d $remasteringdir ]] && rm -rf $remasteringdir;

mkdir -p $remasteringdir/initramfs/files/usr/bin $remasteringdir/initramfs/files/hehe0 $remasteringdir/initramfs_arm64/files/usr/bin $remasteringdir/initramfs_arm64/files/hehe0 $remasteringdir/onekeydevdeskd/01-core $remasteringdir/onekeydevdeskd_arm64/01-core $remasteringdir/x

sleep 2 && printf "\n ✔ %-30s" "Parsing netcfg ......"
[[ "$tmpTARGET" != 'debianbase' ]] && parsenetcfg
sleep 2 && printf "\n ✔ %-30s" "Parsing diskcfg .."
[[ "$tmpTARGET" != 'debianbase' ]] && parsediskcfg
trap 'echo; echo "- aborting by user, restore dns"; restoreall dnsonly;exit 1' SIGINT

sleep 2 && printf "\n ✔ %-30s" "Provisioning instcfg ......."
preparepreseed
[[ "$tmpTARGETMODE" != '4' ]] && patchpreseed

#echo -en "\n\033[36m # Remastering all up... \033[0m"

# under GENMODE we reuse the downdir,but not for INSTMODE
[[ "$tmpTARGETMODE" != '1' ]] && [[ -d $downdir ]] && rm -rf $downdir;
mkdir -p $downdir/onekeydevdesk $downdir/debianbase/dists/bullseye/main/binary-amd64/deb $downdir/debianbase/dists/bullseye/main/binary-arm64/deb $downdir/debianbase/dists/bullseye/main-debian-installer/binary-amd64/udeb $downdir/debianbase/dists/bullseye/main-debian-installer/binary-arm64/udeb $downdir/debianbase/main-addons/{docker,extradeps,extradeps_arm64,lxc,qemu,qemuarm-fix,zfs-utils} $downdir/debianbase/main-core

sleep 2 && printf "\n ✔ %-30s" "Busy Retrieving Res ......"
[[ "$tmpTARGETMODE" != '1' || "$tmpTARGETMODE" == '4' ]] && getbasics down
[[ "$tmpTARGETMODE" == '1' ]] && getbasics copy
#printf "\n ✔ %-30s" "Get optional/necessary deb pkg files to build a debianbase ...... "
#[[ "$tmpBUILD" != '1' && "$tmpTARGET" == 'debianbase' ]] && getoptpkgs libc,common,wgetssl,extendhd,ddprogress || echo -en "[ \033[32m not debianbase,skipping!! \033[0m ]"
#printf "\n ✔ %-30s" "Get full debs pkg files to build a debianbase: ..... "
#[[ "$tmpBUILD" != '1' && "$tmpTARGET" == 'debianbase' ]] && getfullpkgs || echo -en "[ \033[32m not debianbase,skipping!! \033[0m ]"
processbasics

# we also offer a efi here
mkdir -p $remasteringdir/boot # $remasteringdir/boot/grub/i386-pc $remasteringdir/boot/EFI/boot/x86_64-efi

[[ "$tmpDRYRUNREMASTER" == '0' ]] && [[ "$tmpTARGETMODE" == '0' || "$tmpTARGETMODE" == '1' || "$tmpTARGETMODE" == '2' || "$tmpTARGETMODE" == '4' ]] && {



  sleep 2 && printf "\n ✔ %-30s" "Busy Remastering/mutating .."

  [[ "$tmpTARGETMODE" != '4' && "$tmpTARGETMODE" != '1' ]] && cp -f $remasteringdir/initramfs/preseed.cfg $remasteringdir/initramfs/files/preseed.cfg
  [[ "$tmpTARGETMODE" != '4' && "$tmpTARGETMODE" != '1' ]] && cp -f $remasteringdir/initramfs_arm64/preseed.cfg $remasteringdir/initramfs_arm64/files/preseed.cfg

  if [[ "$tmpTARGETMODE" == '0' || "$tmpTARGETMODE" == '2' ]]; then

    #sleep 2 && printf "\n ✔ %-30s" "Instmode,perform below instmodeonly remastering tasks ......"
    #sleep 2 && [[ "$tmpTARGETMODE" != '4' ]] && printf "\n ✔ %-30s" "Parsing grub ......"

    # we have forcenicname and ln -s tricks instead
    # setInterfaceName='0'
    # setIPv6='0'

    #[[ "$tmpBUILD" != '1' && "$tmpTARGETMODE" != '1' && "$tmpTARGET" != 'debianbase' || "$tmpBUILDINSTTEST" == '1' ]] && [[ "$tmpTARGETMODE" != '4' ]] && processgrub
    #[[ "$tmpTARGETMODE" == '1' ]] && [[ "$tmpTARGET" == "devdeskos" ]] && [[ "$tmpTARGETMODE" != '4' ]] && processgrub
    processgrub
    #[[ "$tmpTARGETMODE" != '4' ]] && patchgrub
    patchgrub

  fi


  [[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" != 'debiandemu' ]] && inplacemutating
  [[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debiandemu' ]] && ddtoafile

  # finally showing a hint
  echo -en "[ \033[32m done. \033[0m ]"

}

#echo -en "\n\033[36m # Finishing... \033[0m"

# rewind the $(pwd)
cd $topdir/$targetdir # && CWD="$(pwd)" && echo -en "[ \033[32m cd to ${CWD##*/} \033[0m ]"

[[ "$tmpTARGETMODE" != "1" ]] && [[ "$tmpTARGETMODE" != '4' ]] && {
  printf "\n ✔ %-30s" "Copying vmlinuz ......" && [[ "$tmpBUILD" != "1" ]] && { [[ -d $instto ]] && cp -f $topdir/$downdir/onekeydevdesk/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64) $instto/vmlinuz_1kddinst && echo -en "[ \033[32m done. \033[0m ]"; } || { cp -f $topdir/$downdir/onekeydevdesk/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64) $topdir/$remasteringdir/boot/vmlinuz_1kddinst && echo -en "[ \033[32m done. \033[0m ]"; }
  sleep 2 && printf "\n ✔ %-30s" "Packaging initrfs ....." && [[ "$tmpBUILD" != '1' ]] && { ( cd $topdir/$remasteringdir/initramfs/files; find . | cpio -H newc --create --quiet | gzip -9 > $instto/initrfs_1kddinst.img ) && echo -en "[ \033[32m done. \033[0m ]"; } || { ( cd $topdir/$remasteringdir/initramfs/files; find . | cpio -o --format newc -z > $topdir/$remasteringdir/boot/initrfs_1kddinst.img )  >/dev/null 2>&1 && echo -en "[ \033[32m done. \033[0m ]"; }
}

# if insttest then directly reboot here



#rm -rf $remasteringdir/initramfs;
curl --max-time 5 --silent --output /dev/null https://counter.minlearn.org/{dsrkafuu:demo}&add={1}

[[ "$tmpTARGETMODE" != '1' || "$tmpBUILDINSTTEST" == '1' ]] && [[ "$tmpBUILD" != '1' && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != '4' ]] && {

  chown root:root $GRUBDIR/$GRUBFILE
  chmod 444 $GRUBDIR/$GRUBFILE
  printf "\n ✔ %-30s" "Prepare grub-reboot for 1 ... " && { [[ -f /usr/sbin/grub-reboot ]] && grub-reboot 1 >/dev/null 2>&1;[[ -f /usr/sbin/grub2-reboot ]] && grub2-reboot 1 >/dev/null 2>&1;[[ ! -f /usr/sbin/grub-reboot && ! -f /usr/sbin/grub2-reboot ]] && echo grub-reboot not found && exit 1; }
  # Automatically remove DISK on sigint，note,we should put it in the right place to let it would occur
  trap 'echo; echo "- aborting by user, restoreall"; restoreall;exit 1' SIGINT

  printf "\n ✔ %-30s" "All done! `echo -n \" wait till auto reboot after 20s,or ctlc to interrupt \"`......"
  echo;echo -en "[ \033[32m after reboot, it will enter online $( [[ "$tmpTARGETMODE" == '0' ]] && echo install;[[ "$tmpTARGETMODE" == '2' ]] && echo restore) mode: " && \
  printf "\n %-20s" "`echo -en \" \033[32m if netcfg valid,open and refresh http://$( [[ "$FORCENETCFGV6ONLY" != '1' ]] && echo publicIPv4ofthisserver:80 || echo [publicIPv6ofthisserver:80]) for novncview\033[0m \"`" && [[ "$tmpINSTWITHMANUAL" == '1' ]] && \
  printf "\n %-20s" "`echo -en \" \033[32m if netcfg valid,connected to sshd@publicIPofthisserver:22 without passwords\033[0m \"`"
  printf "\n %-20s" "`echo -en \" \033[32m if netcfg unvalid,the system will roll to normal current running os after 5 mins\033[0m \033[0m ] \"`"

  echo;for time in `seq -w 20 -1 0`;do echo -n -e "\b\b$time";sleep 1;done;reboot -f >/dev/null 2>&1;
}

[[ "$tmpBUILD" == "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && {
  printf "\n ✔ %-30s" "Prepare reboot ... " && { GRUBID=`bcdedit /enum ACTIVE|sed 's/\r//g'|tail -n4|head -n 1|awk -F ' ' '{ print $2}'`;bcdedit /bootsequence $GRUBID /addfirst; }
  trap 'echo; echo "- aborting by user, restoreall"; restoreall;exit 1' SIGINT
  printf "\n ✔ %-30s" "All done! `echo -n \" wait till auto reboot after 20s,or ctlc to interrupt \"`......"
  echo;for time in `seq -w 20 -1 0`;do echo -n -e "\b\b$time";sleep 1;done;shutdown -t 0 -r -f >/dev/null 2>&1;
}

[[ "$tmpBUILD" == "1" ]] && [[ "$tmpTARGETMODE" != "1" ]] && {
  [[ ! -d /Volumes/EFI ]] && sudo diskutil mount /dev/disk0s1
  [[ ! -d /Volumes/EFI ]] && echo efipartiation cloudnt be mount !! && exit 1
  printf "\n ✔ %-30s" "Prepare reboot ... " && { sudo grub-mkstandalone -o /Volumes/EFI/out.efi -O x86_64-efi /vmlinuz_1kddinst=$topdir/$remasteringdir/boot/vmlinuz_1kddinst /initrfs_1kddinst.img=$topdir/$remasteringdir/boot/initrfs_1kddinst.img /boot/grub/grub.cfg=$topdir/$remasteringdir/boot/grub.new;sudo bless --mount /Volumes/EFI --setBoot --file /Volumes/EFI/out.efi --shortform; }
  trap 'echo; echo "- aborting by user, restoreall"; restoreall;exit 1' SIGINT
  printf "\n ✔ %-30s" "All done! `echo -n \" wait till auto reboot after 20s,or ctlc to interrupt \"`......"
  echo;for time in `seq -w 20 -1 0`;do echo -n -e "\b\b$time";sleep 1;done;sudo reboot -f >/dev/null 2>&1;
}

[[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" != 'debiandemu' ]] && {


  printf "\n ✔ %-30s" "All done! `echo -n \" press anykey to reboot, your sys are replaced \"`......"
  read -n1 </dev/tty
  sudo reboot -f >/dev/null 2>&1;

}

[[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debiandemu' ]] && {

   
  # Automatically remove DISK on exit
  trap 'echo; echo "- Ejecting tmpdev disk(linux)"; \
  umount "$tmpMNT"_p2 "$tmpMNT"_p3 "$tmpMNT"_p4 "$tmpMNT"_p5 && losetup -d "$tmpDEV" && rm -rf "$tmpMNT"_p2 "$tmpMNT"_p3 "$tmpMNT"_p4 "$tmpMNT"_p5' EXIT


  # Automatically remove DISK on sigint，note,we should put it in the right place to let it would occur
  trap 'echo; echo "- aborting by user"; exit 1' SIGINT

  printf "\n ✔ %-30s" "All done! `echo -n \" press anykey to esc,your sys are produced \"`"
  read -n1 </dev/tty
  exit

}


  exit
}
#----------------------------genmode only end-------------------------------



