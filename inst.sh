#!/usr/bin/env bash

## free, bootstrap script for inst.sh by minlearn (https://github.com/minlearn/inst/)
## meant to work/tested under linux family with bash > 4
## usage: wget -qO- inst.sh | bash [ -s - -o [...] -t debian|your.gzhttp/httpslocation|port:blknameforncrestore [-d]]
## for win,download and install cygwin installler and grub2win installer and setup them

# those guards must be put headmost, because we use bash -c to take control of direct bash evaluation
[[ "$(uname)" == "Darwin" ]] && earlytmpBUILD='1'
[[ -f /cygdrive/c/cygwin64/bin/uname && ( "$(/cygdrive/c/cygwin64/bin/uname -o)" == "Cygwin" || "$(/cygdrive/c/cygwin64/bin/uname -o)" == "Msys") ]] && earlytmpBUILD='11'
[[ "$(command -v systemd-detect-virt)" && "$(systemd-detect-virt)" == "openvz" ]] && earlytmpCTVIRTTECH='1'

[[ "$earlytmpBUILD" != "1" && "$earlytmpBUILD" != "11" ]] && [[ ! "$(bash --version | head -n 1 | grep -o '[1-9]'| head -n 1)" -ge '4' ]] && echo "Error:bash must be at least 4!" && exit 1
# for wget -qO- xxx| bash -s - subsitute manner
[[ "$earlytmpBUILD" != "1" && "$earlytmpBUILD" != "11" ]] && [ "$(id -u)" != 0 ] && exec sudo bash -c "`cat -`" -a "$@"
# for bash <(wget -qO- xxx) -t subsitute manner we should:
# [ "$(id -u)" != 0 ] && exec sudo bash -c "`cat "$0"`" -a "$@"
[[ "$earlytmpBUILD" != "1" && "$earlytmpBUILD" != "11" ]] && [[ "$EUID" -ne '0' ]] && echo "Error:This script must be run as root!" && exit 1

# =================================================================
# globals
# =================================================================

forcemaintainmode='0'                             # 0:all put in maintain,1,just devdeskos in maintain

export autoDEBMIRROR0=https://github.com/minlearn/inst/raw/master
export autoDEBMIRROR1=https://gitee.com/minlearn/inst/raw/master
export FORCEDEBMIRROR=''                          # force apply a fixed mirror/targetddurl selection to force override autoselectdebmirror results based on -t -m args given
export tmpTARGETMODE='0'                          # 0:WGETDD INSTMODE ONLY 1:CLOUDDDINSTALL+BUILD MIXTURE,2,3,nc install mode,defaultly it sholudbe 0, 4 inplace dd mode for devdeskct(lxcct,or kvmct) or devdeskde, 9,ociinst mode,10,appinst mode
export tmpTARGET=''                               # dummy(for -d only),debianbase,onekeydevdesk,devdeskos,lxcdebtpl,lxcdebiantpl,qemudebtpl,qemudebiantpl,devdeskosfull,debian,debian10restore,debianct,devdeskde,devdeskct

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
FORCEINSTCTL_ARR=('0')                            # instcontrol,0:auto(with autohdexp,autonetcfginject,autoreboot),1:pure dd,without auto hd exp,2:pure dd,without networkcfg injection,3:hold without reboot,4: without pre clean just umount
export FORCEINSTCMD=''                            # postcmdstr, only for win
export tmpINSTSERIAL='0'                          # 0 with serial console output support
export tmpINSTSSHONLY='0'
export tmpCTVIRTTECH='0'                          # 0,no virt tech,1,lxc,2,kvm
export tmpPVEREADY='0'                            # 0,pve not ready for install app,1,pve installed and version meets requires to install app

# part II: customables related with buildmode,initrfs,01-core,clients,lxcapps
export tmpBUILD='0'                               # 0:linux,1:unix,osx,2,lxc
export tmpBUILDGENE='0'                           # 0:biosmbr,1:biosgpt,2:uefigpt,used both in buildtime(0or1or2,0and1and2) and insttime(0or1or2)
export tmpBUILDPUTPVEINIFS='0'                    # put pve building prodcure inside initramfs? defaultly no
export tmpHOST=''                                 # (blank)0,az,servarica(sr),(kimsurf/ovh/sys)ks,orc,bwg10g512m,mbp,pd
export HOSTMODLIST='0'
export tmpHOSTARCH='0'                            # 0,x86-64,1,arm64,used both in buildtime（0or1singlearchonlymode，0and1fullarchmode） and insttime（0or1singlearchonlymode）
export custIMGSIZE='10'
export custUSRANDPASS='tdl'
export tmpTGTNICNAME='eth0'
export tmpTGTNICIP='111.111.111.111'              # pve only,input target nic public ip(127.0.0.1 and 127.0.1.1 forbidden,enter to use defaults 111.111.111.111)
export tmpWIFICONNECT='CMCC-xxx,11111111,wlan0'   # input target wifi connecting settings(in valid hotspotname,hotspotpasswd,wifinicname form,passwd 8-63 long,enter to leave blank)
export GENCLIENTS='y'                             # linux,win,osx
export GENCLIENTSWINOSX='n'
export PACKCLIENTS='n'
export tmpEBDCLIENTURL='xxx.com'                  # input target ip or domain that will be embeded into client
export PACKCONTAINERS=''                          # list for defaultly packmode into 01-core
export GENCONTAINERS=''                           # list for mergemode into 01-core

# part III: debug and ci/cd extra addons, debug and ci cant coexists in a single subtitute
export tmpDEBUG='0'                               # 1,debug=manualmode in instmode, or special initramfsgen and localinst boot test in buildmode,2,is3rdrescue(normal with base, but no boot,no hd mount)
export tmpDRYRUNREMASTER='0'                      # 0,use dryrunmode,wont mod grub? exists but dreprecated, we use ctlc sigint to do it
export tmpINSTWITHMANUAL='0'                      # 0,enter manual mode, for debugging purpose,will force reboot to a network-console
export tmpINSTWITHBORE=''                         # a selfhosting bore instance ip 
export tmpINSTVNCPORT=''                          # defaultly it is blank(80 by default)
export tmpBUILDINSTTEST='0'                       # inst test after initramfs gened
export tmpBUILDADDONS='0'                         # full build mode,with split post addon actions,0，no addons,1,normal buildaddons for 1keyddbuild 2,buildaddons for lxc*build standalone

# =================================================================
# Below are function libs
# =================================================================

function prehint0(){

  [ -d /sys/firmware/efi ] && echo -n u, || echo -n b,;
  [[ "$earlytmpBUILD" != "11" && "$earlytmpBUILD" != "1" ]] && { [[ "$(find /sys/class/net/ -type l ! -lname '*/devices/virtual/net/*' |  wc -l)" -lt 2 ]] && echo -n "i:1," || echo -n "i:>1,"; } || echo -n "i:d,"
  [[ "$earlytmpBUILD" != "11" && "$earlytmpBUILD" != "1" ]] && { [[ "$(lsblk -e 7 -e 11 -d | tail -n+2 | wc -l)" -lt 2 ]] && echo -n "p:1" || echo -n "p:>1"; } || echo -n "p:d"

}

function prehint4(){

  [[ "$earlytmpBUILD" != "1" && "$earlytmpBUILD" != "11" && "$earlytmpCTVIRTTECH" != "1" ]] && {
    DEFAULTWORKINGNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    [[ -z "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGNIC="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; };
    [[ -n "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGIPSUBV4="$(ip addr |grep ''${DEFAULTWORKINGNIC}'' |grep 'global' |grep 'brd\|' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";[[ -z "$DEFAULTWORKINGIPSUBV4" ]] && DEFAULTWORKINGIPSUBV4="$(ip addr |grep ''${DEFAULTWORKINGNIC}'' |grep 'global' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')"; };
    DEFAULTWORKINGGATEV4="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";
    [[ -n "$DEFAULTWORKINGIPSUBV4" ]] && [[ -n "$DEFAULTWORKINGGATEV4" ]] && echo -n $DEFAULTWORKINGIPSUBV4,$DEFAULTWORKINGGATEV4 || echo -n 'no default working ipv4';
  };

  [[ "$earlytmpBUILD" != "1" && "$earlytmpCTVIRTTECH" != "11" && "$earlytmpCTVIRTTECH" == "1" ]] && {
    DEFAULTWORKINGNIC="$(awk '$2 == 00000000 { print $1 }' /proc/net/route)";
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGIPSUBV4="$(ip addr show dev ''${DEFAULTWORKINGNIC}'' | sed -nE '/global/s/.*inet (.+) brd.*$/\1/p' | head -n 1)";
    DEFAULTWORKINGGATEV4="locallink";
    [[ -n "$DEFAULTWORKINGIPSUBV4" ]] && [[ -n "$DEFAULTWORKINGGATEV4" ]] && echo -n $DEFAULTWORKINGIPSUBV4,$DEFAULTWORKINGGATEV4 || echo -n 'no default working ipv4';
  };

  [[ "$earlytmpBUILD" == "11" ]] && {
    DEFAULTWORKINGNICIDX="$(netsh int ipv4 show route | grep --text -F '0.0.0.0/0' | awk '$6 ~ /\./ {print $5}')";
    [[ -z "$DEFAULTWORKINGNICIDX" ]] && { DEFAULTWORKINGNICIDX="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')"; };
    [[ -n "$DEFAULTWORKINGNICIDX" ]] && { for i in `echo "$DEFAULTWORKINGNICIDX"|sed 's/\ /\n/g'`; do if grep -q '=$' <<< `wmic nicconfig where "InterfaceIndex='$i'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1`; then :; else DEFAULTWORKINGNICIDX=$i;fi;done;  };
    DEFAULTWORKINGIPV4=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`;
    DEFAULTWORKINGGATEV4=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`;
    DEFAULTWORKINGMASKV4=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'" get IPSubnet /format:list|sed 's/\r//g'|sed 's/IPSubnet={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`;
    [[ -n "$DEFAULTWORKINGIPV4" ]] && [[ -n "$DEFAULTWORKINGGATEV4" ]] && echo -n $DEFAULTWORKINGIPV4,$DEFAULTWORKINGGATEV4 || echo -n 'no default working ipv4';
  };

  [[ "$earlytmpBUILD" == "1" ]] && {
    DEFAULTWORKINGNIC="$(netstat -nr -f inet|grep default|awk '{print $4}')";
    [[ -z "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGNIC="$(netstat -nr -f inet6|grep default|awk '{print $4}' |head -n1)"; };
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGIPSUBV4="$(ifconfig ''${DEFAULTWORKINGNIC}'' |grep -Fv inet6|grep inet|awk '{print $2}')";
    DEFAULTWORKINGGATEV4="$(netstat -nr -f inet|grep default|grep ''${DEFAULTWORKINGNIC}'' |awk '{print $2}')";
    [[ -n "$DEFAULTWORKINGIPSUBV4" ]] && [[ -n "$DEFAULTWORKINGGATEV4" ]] && echo -n $DEFAULTWORKINGIPSUBV4,$DEFAULTWORKINGGATEV4 || echo -n 'no default working ipv4';
  };

}

function prehint61(){

  [[ "$earlytmpBUILD" != "1" && "$earlytmpBUILD" != "11" ]] && {
    DEFAULTWORKINGNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    [[ -z "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGNIC="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; };
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGIPSUBV6="$(ip -6 -brief address show scope global|grep ''${DEFAULTWORKINGNIC}'' |awk -F ' ' '{ print $3}')";
    [[ -n "$DEFAULTWORKINGIPSUBV6" ]] && echo -n $DEFAULTWORKINGIPSUBV6 || echo -n 'no default working v6ip';
  };

  [[ "$earlytmpBUILD" == "11" ]] && {
    DEFAULTWORKINGNICIDX="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')";
    [[ -n "$DEFAULTWORKINGNICIDX" ]] && { for i in `echo "$DEFAULTWORKINGNICIDX"|sed 's/\ /\n/g'`; do if grep -q '=$' <<< `wmic nicconfig where "InterfaceIndex='$i'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1`; then :; else DEFAULTWORKINGNICIDX=$i;fi;done;  };
    [[ -n "$DEFAULTWORKINGNICIDX" ]] && DEFAULTWORKINGIPV6=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f2)`;
    [[ -n "$DEFAULTWORKINGIPV6" ]] && echo -n $DEFAULTWORKINGIPV6 || echo -n 'no default working v6ip';
  };

  [[ "$earlytmpBUILD" == "1" ]] && {
    DEFAULTWORKINGNIC="$(netstat -nr -f inet6|grep default|awk '{print $4}' |head -n1)";
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGIPSUBV6="$(ifconfig ''${DEFAULTWORKINGNIC}'' |grep inet6|head -n1|awk '{print $2}'|sed 's/%.*//g')";
    [[ -n "$DEFAULTWORKINGIPSUBV6" ]] && echo -n $DEFAULTWORKINGIPSUBV6 || echo -n 'no default working v6ip';
  };

}

function prehint62(){

  [[ "$earlytmpBUILD" != "1" && "$earlytmpBUILD" != "11" ]] && {
    DEFAULTWORKINGNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    [[ -z "$DEFAULTWORKINGNIC" ]] && { DEFAULTWORKINGNIC="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; };
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGGATEV6="$(ip -6 -brief route show default|grep ''${DEFAULTWORKINGNIC}'' |awk -F ' ' '{ print $3}')";
    [[ -n "$DEFAULTWORKINGGATEV6" ]] && echo -n $DEFAULTWORKINGGATEV6 || echo -n 'no default working v6gate';
  };

  [[ "$earlytmpBUILD" == "11" ]] && {
    DEFAULTWORKINGNICIDX="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')";
    [[ -n "$DEFAULTWORKINGNICIDX" ]] && { for i in `echo "$DEFAULTWORKINGNICIDX"|sed 's/\ /\n/g'`; do if grep -q '=$' <<< `wmic nicconfig where "InterfaceIndex='$i'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1`; then :; else DEFAULTWORKINGNICIDX=$i;fi;done;  };
    [[ -n "$DEFAULTWORKINGNICIDX" ]] && DEFAULTWORKINGGATEV6=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f2)`;
    [[ -n "$DEFAULTWORKINGGATEV6" ]] && echo -n $DEFAULTWORKINGGATEV6 || echo -n 'no default working v6gate';
  };

  [[ "$earlytmpBUILD" == "1" ]] && {
    DEFAULTWORKINGNIC="$(netstat -nr -f inet6|grep default|awk '{print $4}' |head -n1)";
    [[ -n "$DEFAULTWORKINGNIC" ]] && DEFAULTWORKINGGATEV6="$(netstat -nr -f inet6|grep default|grep ''${DEFAULTWORKINGNIC}'' |awk '{ print $2}'|sed 's/%.*//g')";
    [[ -n "$DEFAULTWORKINGGATEV6" ]] && echo -n $DEFAULTWORKINGGATEV6 || echo -n 'no default working v6gate';
  };

}

function Outbanner(){
  RD=$(echo "\033[01;31m")
  CL=$(echo "\033[m")

  [[ "$1" == 'wizardmode' ]] && echo -e "
 ██${RD}╗${CL}███${RD}╗${CL}   ██${RD}╗${CL}███████${RD}╗${CL}████████${RD}╗${CL}  \033[1;31m!!THE SCIRPT MAY WIPE ALL DATA!!\033[0m \033[32m`[[ "$tmpTARGETMODE" != '1' && "$tmpBUILD" != '1' ]] && echo -n $(wget --no-check-certificate --no-verbose --content-on-error=on --timeout=1 --tries=2 -qO- 'https://counter.minlearn.org/api/dsrkafuu:demo'|grep -Eo [0-9]*[0-9])`\033[0m
 ██${RD}║${CL}████${RD}╗${CL}  ██${RD}║${CL}██${RD}╔════╝╚══${CL}██${RD}╔══╝${CL}  一键装机及商店:https://inst.sh
 ██${RD}║${CL}██${RD}╔${CL}██${RD}╗${CL} ██${RD}║${CL}███████${RD}╗${CL}   ██${RD}║${CL}     
 ██${RD}║${CL}██${RD}║╚${CL}██${RD}╗${CL}██${RD}║╚════${CL}██${RD}║${CL}   ██${RD}║${CL}     [`prehint0`][`prehint4`]
 ██${RD}║${CL}██${RD}║ ╚${CL}████${RD}║${CL}███████${RD}║${CL}   ██${RD}║${CL}     [`prehint61`]
 ${RD}╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝${CL}     [`prehint62`]              

`printf "=%0.s" {1..74}`
"

}

function CheckDependence(){

  [[ "$tmpDEBUG" == "2" ]] && echo -en "[ \033[32m 3rd rescue,assume preinstalled \033[0m ]" && return;
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
  [[ $lostdeplist =~ "rsync" ]] && lostpkglist+=" rsync"; \
  [[ $lostdeplist =~ "qemu-img" ]] && lostpkglist+=" qemu-utils"; \
  [[ $lostdeplist =~ "skopeo" ]] && lostpkglist+=" skopeo"; \
  [[ $lostdeplist =~ "umoci" ]] && lostpkglist+=" umoci"; \
  [[ $lostdeplist =~ "jq" ]] && lostpkglist+=" jq";

  [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ ! -f /usr/sbin/grub-reboot && ! -f /usr/sbin/grub2-reboot ]] && FullDependence='1' && lostdeplist+="grub2-common"  && lostpkglist+=" grub2-common"
  [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ "$FORCENETCFGV6ONLY" == '1' ]] && [[ ! -f /usr/bin/subnetcalc ]] && FullDependence='1' && lostdeplist+="subnetcalc"  && lostpkglist+=" subnetcalc"
  # [[ "$tmpBUILDGENE" == '1' && "$tmpTARGET" == 'devdeskos' && "$tmpTARGETMODE" == '1' ]] && [[ ! -f /usr/lib/grub/x86_64-efi/acpi.mod ]] && FullDependence='1' && lostdeplist+="grub-efi" && lostpkglist+=" grub-efi"

  if [ "$FullDependence" == '1' ]; then
    echo -en "[ \033[32m deps missing! perform autoinstall \033[0m ] ";
    if [[ $(command -v yum) && ! $(command -v apt-get) ]]; then
    yum update >/dev/null 2>&1
    yum reinstall `echo -n "$lostpkglist"` -y >/dev/null 2>&1
    [[ $? == '0' ]] && echo -en "[ \033[32m done. \033[0m ]" || { echo;echo -en "\033[31m $lostdeplist missing !error happen while autoinstall! please fix to run 'yum update && yum install $lostpkglist ' to install them\033[0m";exit 1; }
    fi
    if [[ ! $(command -v yum) && $(command -v apt-get) ]]; then
    apt-get update --allow-releaseinfo-change --allow-unauthenticated --allow-insecure-repositories -y -qq  >/dev/null 2>&1
    # use reinstall but not install, cause some pkgs maybe already there, but indeedly broken in bin/deps level(the bin were wrong delt)
    # dont use apt-get update && apt-get reinstall here,cause apt-get update may fail but actually run
    apt-get reinstall --no-install-recommends -y -qq `echo -n "$lostpkglist"` >/dev/null 2>&1
    [[ $? == '0' ]] && echo -en "[ \033[32m done. \033[0m ]" || { echo;echo -en "\033[31m $lostdeplist missing !error happen while autoinstall! please fix to run 'apt-get update && apt-get install $lostpkglist ' to install them\033[0m";exit 1; }
    fi
  else
    # simple log under instmode
    [[ "$tmpTARGETMODE" != '1' ]] && echo -en "[ \033[32m all,ok \033[0m ]";
  fi
}

function test_mirror() {

  SAMPLES=1
  BYTES=511999 #0.5mb
  TIMEOUT=10
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

  [[ "$FORCEDEBMIRROR" != "" ]] && return;

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
        LC_ALL=C printf '%-60s %.5f\\n' $CurMirror $mean
      # else
        # LC_ALL=C printf '%-60s failed, ignoring\\n' $CurMirror 1>&2
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
        LC_ALL=C printf '%-60s %.5f\\n' $CurMirror $mean
      # else
        # LC_ALL=C printf '%-60s failed, ignoring\\n' $CurMirror 1>&2
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
    [[ "$tmpTARGETMODE" == '4' && "$tmpBUILD" != '1' ]] && [[ "$tmpTARGET" == "debianct" || "$tmpTARGET" == "devdeskct" ]] && [[ "$IMGTYPECHECK" == '200' || "$IMGTYPECHECK" == '302' ]] && UNZIP='2' && { sleep 3 && echo -en "[ \033[32m inbuilt \033[0m ]"; }
    [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ "$tmpTARGET" == "devdeskos" || "$tmpTARGET" == "debian10r" ]] && [[ "$IMGTYPECHECK" == '200' || "$IMGTYPECHECK" == '302' ]] && sleep 3 && UNZIP='2' && echo -en "[ \033[32m inbuilt \033[0m ]"
    [[ "$tmpTARGETMODE" == '0' && "$IMGTYPECHECK" == 'nc' ]] && sleep 3 && UNZIP='1' && echo -en "[ \033[32m nc \033[0m ]"
    [[ "$tmpTARGETMODE" == '0' && "$tmpBUILD" != '1' ]] && [[ "$tmpTARGET" != "devdeskos" && "$tmpTARGET" != "debian10r" ]] && [[ "$IMGTYPECHECK" == '200' || "$IMGTYPECHECK" == '302' ]] && {
      # begin pass1:check imagetype
      # sometimes one file could contain both gzip and application/x-xz strings, only the application/x-xz effects the real mimetype, so we cant just rely on gzip str
      IMGTYPECHECKPASS_DRTREF="$(echo "$IMGHEADERCHECK"|grep -E -o 'github|raw|qcow2|application/gzip|application/x-gzip|application/x-xz|zstd|application/x-iso9660-image'|head -n 1)";
      # github tricks,cause it has raw word in its typecheck info
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'github' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m github \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'raw' ]] && UNZIP='0' && sleep 3 && echo -en "[ \033[32m raw \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'application/x-iso9660-image' ]] && UNZIP='0' && sleep 3 && echo -en "[ \033[32m iso \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'application/gzip' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m gzip \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'application/x-gzip' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m x-gzip \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'application/gunzip' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m gunzip \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'application/x-xz' ]] && UNZIP='2' && sleep 3 && echo -en "[ \033[32m xz \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'zstd' ]] && UNZIP='3' && sleep 3 && echo -en "[ \033[32m zstd \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == 'qcow2' ]] && UNZIP='4' && sleep 3 && echo -en "[ \033[32m qcow2 \033[0m ]";
      [[ "$IMGTYPECHECKPASS_DRTREF" == '' || "$UNZIP" == '' ]] && {
        # begin pass2:simply check ext
        EXTCHECKPASS="$([[ $1 =~ '.' ]] && echo ${1##*.})"
        [[ "$EXTCHECKPASS" == '' ]] && { UNZIP='0' && sleep 3 && echo -en "[ \033[32m noext \033[0m ]"; } || { [[ "$EXTCHECKPASS" == 'raw' ]] && UNZIP='0' && sleep 3 && echo -en "[ \033[32m raw \033[0m ]";[[ "$EXTCHECKPASS" == 'iso' ]] && UNZIP='0' && sleep 3 && echo -en "[ \033[32m iso \033[0m ]";[[ "$EXTCHECKPASS" == 'gz' || "$EXTCHECKPASS" == 'gzip' ]] && UNZIP='1' && sleep 3 && echo -en "[ \033[32m gzip \033[0m ]";[[ "$EXTCHECKPASS" == 'xz' ]] && UNZIP='2' && sleep 3 && echo -en "[ \033[32m xz \033[0m ]";[[ "$EXTCHECKPASS" == 'zstd' ]] && UNZIP='3' && sleep 3 && echo -en "[ \033[32m zstd \033[0m ]";[[ "$EXTCHECKPASS" == 'qcow2' || "$EXTCHECKPASS" == 'img' ]] && UNZIP='4' && sleep 3 && echo -en "[ \033[32m qcow2 \033[0m ]"; }
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

tweakall(){
  [[ -f /etc/resolv.conf ]] && {
    [[ ! -f /etc/resolv.conf.old ]] && {
      cp -f /etc/resolv.conf /etc/resolv.conf.old && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf;
    } || {
      cp -f /etc/resolv.conf /etc/resolv.conf.bak && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf;
    };
  } || {
    [[ -f /etc/resolv.conf.old ]] && cp -f /etc/resolv.conf.old /etc/resolv.conf;
  }
  [[ -f /etc/gai.conf ]] && {
    grep -q "^precedence ::ffff:0:0/96  100" /etc/gai.conf
    [[ $? -eq '0' ]] || {
      grep -q "#precedence ::ffff:0:0/96  100" /etc/gai.conf
      [[ $? -eq '0' ]] && {
        sed -i "s|#precedence ::ffff:0:0/96  100|precedence ::ffff:0:0/96  100|" /etc/gai.conf
      } || {
        echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
      }
    }
  } || {
    echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
  }
}
tweakall2(){
  [[ -f /etc/resolv.conf && ! -f /etc/resolv.conf.old ]] && {
    cp -f /etc/resolv.conf /etc/resolv.conf.old && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf;
  } || {
    cp -f /etc/resolv.conf /etc/resolv.conf.bak && > /etc/resolv.conf && echo -e 'nameserver 2001:67c:2b0::4\nnameserver 2001:67c:2b0::6' >/dev/null 2>&1 >> /etc/resolv.conf;
  }
  [[ -f /etc/gai.conf ]] && {
    grep -q "^precedence ::ffff:0:0/96  100" /etc/gai.conf
    [[ $? -eq '0' ]] || {
      grep -q "#precedence ::ffff:0:0/96  100" /etc/gai.conf
      [[ $? -eq '0' ]] && {
        sed -i "s|#precedence ::ffff:0:0/96  100|precedence ::ffff:0:0/96  100|" /etc/gai.conf
      } || {
        echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
      }
    }
  } || {
    echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf
  }
}
tweakall3(){
  [[ -f /etc/resolv.conf.old ]] && cp -f /etc/resolv.conf.old /etc/resolv.conf
}

parsenetcfg(){

  sleep 2 && printf "\n ✔ %-30s" "Parsing netcfg ......"

  # never use
  interface=''

  # 1): setnet=1
  # 2): setnet!=1 and netcfgfile containes static (autonet=1=still static)
  # 3): setnet!=1 and netcfgfile dont containes static (autonet=2=dhcp)

  [[ -n "$FORCENETCFGSTR" || "$FORCENETCFGV6ONLY" == '1' || ( "$tmpBUILD" == '11' || "$tmpBUILD" == '1' ) || "$tmpCTVIRTTECH" == '1' ]] && setNet='1';

  # defaultly set as static in case of autonet undertermined values, because below updates for nm and netplan doesnt cover 100% cases
  [[ "$setNet" != '1' ]] && AutoNet='1'

  # networkmanager
  [[ "$setNet" != '1' ]] && [[ -f '/etc/network/interfaces' ]] && [[ ! -f '/etc/NetworkManager/NetworkManager.conf' ]] && {
    [[ -n "$(sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='1' || AutoNet='2'
    [[ -n "$(sed -n '/iface.*inet manual/p' /etc/network/interfaces)" ]] && [[ -n "$(sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='1'
    
    [[ -d /etc/network/interfaces.d ]] && {
      ICFGN="$(find /etc/network/interfaces.d -type f -name '*' |wc -l)" || ICFGN='0';
      [[ "$ICFGN" -ne '0' ]] && {
        for NetCFG in `ls -1 /etc/network/interfaces.d/*`
          do 
            [[ -n "$(cat $NetCFG | sed -n '/iface.*inet static/p')" ]] && AutoNet='1' || AutoNet='2'
            [[ -n "$(cat $NetCFG | sed -n '/iface.*inet manual/p' /etc/network/interfaces)" ]] && [[ -n "$(cat $NetCFG | sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='1'
            [[ "$AutoNet" -eq '0' ]] && break;
          done
      }
    }
  } || {
    [[ -f '/etc/NetworkManager/NetworkManager.conf' ]] && [[ -n "$(sed -n '/managed=false/p' /etc/NetworkManager/NetworkManager.conf)" ]] && {
      for NetCFG in /etc/NetworkManager/system-connections/*; do
        [ -e "$NetCFG" ] || continue
        if awk '
          /\[ipv4\]/ {in_ipv4=1} 
          /\[ipv6\]/ {in_ipv4=0} 
          in_ipv4 && /method=(manual|static)/ {found=1; exit}
          END {exit !found}' "$NetCFG"; then
          AutoNet='1'
          break
        else
          AutoNet='2'
        fi
      done
    }
  }

  # netplan
  WORKYML=`[[ -e "/etc/netplan" ]] && find /etc/netplan* -maxdepth 1 -mindepth 1 -name *.yaml | head -n1`
  [[ "$setNet" != '1' ]] && [[ -f "$WORKYML" ]] && {
    [[ -z "$(sed -n '/dhcp4: false\|- \([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}.../p' $WORKYML)" ]] && AutoNet='2' || AutoNet='1'
  }

  # we have force1stnicname
  [[ "$tmpBUILD" != '11' && "$tmpBUILD" != '1' ]] && { if [[ -n "$FORCE1STNICNAME"  ]]; then
    IFETH=`[[ \`echo $FORCE1STNICNAME|grep -Eo ":"\` ]] && echo $FORCE1STNICNAME || echo \`ip addr show $FORCE1STNICNAME|grep link/ether | awk '{print $2}'\``
    IFETHMAC=`echo $IFETH`
  else
    #IFETH="auto"

    # no more auto, alwaysly force1stnicname and force mac
    DEFAULTNIC="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    FORCE1STNICNAME=`echo \`ip addr show $DEFAULTNIC|grep link/ether | awk '{print $2}'\``
    IFETH=`echo $FORCE1STNICNAME`
    IFETHMAC=`echo $IFETH`
  fi; }

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
    FORCE1STNICIDX="$(netsh int ipv4 show route | grep --text -F '0.0.0.0/0' | awk '$6 ~ /\./ {print $5}')";[[ -n "$FORCE1STNICIDX" ]] && { for i in `echo "$FORCE1STNICIDX"|sed 's/\ /\n/g'`; do if grep -q '=$' <<< `wmic nicconfig where "InterfaceIndex='$i'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1`; then :; else FORCE1STNICIDX=$i;fi;done;  };[[ -z "$FORCE1STNICIDX" ]] && { FORCE1STNICIDX="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')";FORCE1STNICNAME=`echo $(wmic nicconfig where "InterfaceIndex='$FORCE1STNICIDX'" get MACAddress /format:list|sed 's/\r//g'|sed 's/MACAddress=//g')`; } || { FORCE1STNICNAME=`echo $(wmic nicconfig where "InterfaceIndex='$FORCE1STNICIDX'" get MACAddress /format:list|sed 's/\r//g'|sed 's/MACAddress=//g')`; }
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
      [[ `echo $FIP|grep -Eo ":"` ]] && tweakall;
    }
    [[ `echo "$FORCENETCFGSTR" | grep -Eo ,|wc -l` == 2 ]] && { 
      #NAME=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $1}' | awk -F ':' '{ print $2}'`
      FIP=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $1}'`
      #CIDR=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $3}' | awk -F ':' '{ print $2}'`
      #MAC=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $4}' | awk -F ':' '{ print $2}'`
      FMASK=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $2}'`
      FGATE=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $3}'`
      [[ `echo $FIP|grep -Eo ":"` ]] && tweakall;
      #STATICROUTE=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $7}' | awk -F ':' '{ print $2}'`
      #DNS1=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $8}' | awk -F ':' '{ print $2}'`
      #DNS2=`echo "$FORCENETCFGSTR" | awk -F ',' '{ print $9}' | awk -F ':' '{ print $2}'`
    }

    # force ipv6 also force ipv6 staticnetcfg
    [[ "$FORCENETCFGV6ONLY" == '1' && -z "$FORCENETCFGSTR" ]] && { [[ -n "$DEFAULTNIC" ]] && TMPIPSUBV6="$(ip -6 -brief address show scope global|grep ''${DEFAULTNIC}'' |awk -F ' ' '{ print $3}')";
    FIP="$(echo -n "$TMPIPSUBV6" |cut -d'/' -f1)";
    TMPCIDRV6="$(echo -n "$TMPIPSUBV6" |cut -d'/' -f2)";
    FGATE="$(ip -6 -brief route show default|grep ''${DEFAULTNIC}'' |awk -F ' ' '{ print $3}')";
    [[ -n "$TMPCIDRV6" ]] && FMASK="$(prefixlen2subnetmask)"; } && FORCENETCFGSTR="$FIP,$FMASK,$FGATE" && { tweakall2; }

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

  [[ "$setNet" != '1' ]] && {  # "setNet" != '1' && "AutoNet" != '2' ??

    [[ -n "$DEFAULTNIC" ]] && { IPSUBV4="$(ip addr |grep ''${DEFAULTNIC}'' |grep 'global' |grep 'brd\|' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";[[ -z "$IPSUBV4" ]] && IPSUBV4="$(ip addr |grep ''${DEFAULTWORKINGNIC}'' |grep 'global' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')"; };
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
      [[ -n "$GATEV4" && -n "$MASKV4" && -n "$IPV4" ]] && { IP=$IPV4;MASK=$MASKV4;GATE=$GATEV4;tweakall3; } || {
        # if reach || here,there maybe no ipv4 stacks
        [[ -n "$GATEV6" && -n "$MASKV6" && -n "$IPV6" ]] && { IP=$IPV6;MASK=$MASKV6;GATE=$GATEV6;tweakall2; } # || exit 1;
        # if reach && here,there may still be useful ipv6 stacks
      }
      # final give up both stack(there maybe no any ipstacks)
      [[ -n "$GATE" && -n "$MASK" && -n "$IP" ]] || {
        echo "Error! get netcfg auto ipv4/ipv6 stack settings failed. please speficty static netcfg settings";
        exit 1;
      }
    }

    # [[ "setNet" != '1' && "AutoNet" == '2' ]] && {:; # will use dhcp } ??


  }

  # buildmode, set auto net hints
  [[ "$FORCE1STNICNAME" == "" && "$setNet" == '1' && "$AutoNet" != '1' && "$AutoNet" != '2' ]] && echo -en "[ \033[32m force,static \033[0m ]" && echo -en "[ \033[32m $DEFAULTNIC:$FIP,$FMASK,$FGATE \033[0m ]"
  [[ "$FORCE1STNICNAME" != "" && "$setNet" == '1' && "$AutoNet" != '1' && "$AutoNet" != '2' ]] && echo -en "[ \033[32m force,static \033[0m ]" && echo -en "[ \033[32m `[[ "$tmpBUILD" == '11' || "$tmpBUILD" == '1' ]] && echo $DEFAULTNIC:$FIP,$FMASK,$FGATE || echo $FORCE1STNICNAME:$FIP,$FMASK,$FGATE` \033[0m ]"
  [[ "$setNet" != '1' && "$AutoNet" != '1' && "$AutoNet" == '2' ]] && echo -en "[ \033[32m auto,dhcp \033[0m ]" && echo -en "[ \033[32m $DEFAULTNIC:$IP,$MASK,$GATE \033[0m ]"
  [[ "$setNet" != '1' && "$AutoNet" == '1' && "$AutoNet" != '2' ]] && echo -en "[ \033[32m auto,static \033[0m ]" && echo -en "[ \033[32m $DEFAULTNIC:$IP,$MASK,$GATE \033[0m ]"

}

parsediskcfg(){

  sleep 2 && printf "\n ✔ %-30s" "Parsing diskcfg .."


  #maybe we can force grub *_hints here, just in the plan

  [[ "$tmpDEBUG" == "2" ]] && {
    [[ "$FORCE1STHDNAME" != '' ]] && {
      defaulthd="$FORCE1STHDNAME";
      defaulthdid="$defaulthd";
      [[ "$tmpTARGETMODE" != "1" && "$tmpTARGETMODE" != "4" ]] && { [ ! -e  "$defaulthdid" ] && echo -ne "Error! \nselected defaulthd is invalid.\n" && exit 1; }

      echo -en "[ \033[32m force \033[0m ] [ \033[32m $defaulthd \033[0m ]";
    } || {
      mapper=$(lsblk -d -n -o NAME | grep -E '^(sd|vd|nvme|xvd)' | head -n 1 | sed 's|^|/dev/|')
      # in case this is a raid,we should add head -n1
      defaulthd=$(lsblk -rn --inverse $mapper | grep -w disk | awk '{print $1}' | sort -u| head -n1)
      defaulthdid=$defaulthd
      [[ "$tmpTARGETMODE" != "1" && "$tmpTARGETMODE" != "4" ]] && { [ -z "$defaulthd" -o -z "$defaulthdid" ] && echo -ne "Error! \nCant select defaulthd.\n" && exit 1; }

      echo -en "[ \033[32m auto \033[0m ] [ \033[32m $defaulthd \033[0m ]";
    }

    return 
  } 

  [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && [[ ! -d /boot ]] && echo -ne "Error! \nNo boot directory mounted.\n" && exit 1;
  [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && [[ -z `find /boot -name grub.cfg -o -name grub.conf` ]] && echo -ne "Error! \nNo grubcfg files in the boot directory.\n" && exit 1;

  # try lookingfor the full working grub(file+dir+ver); simple case : only one grub gen(bios) and grub cfg
  if [[ "$tmpBUILDGENE" != "2" ]] && [[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != "1" ]]; then
     # sometimes it is very strangly that both grub.cfg and grub.conf mistakely configured there,just force head -n1
     WORKINGGRUB=`find /boot/grub* -maxdepth 1 -mindepth 1 -name grub.cfg -o -name grub.conf|head -n1`
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
      echo "$FORCE1STHDNAME" |grep -q ',noid';
      [[ $? -eq '0' ]] && {
        defaulthd=${FORCE1STHDNAME/,noid};
      } || {
        defaulthd="$FORCE1STHDNAME";
        defaulthdid=$(LC_ALL=C fdisk -l /dev/$defaulthd 2>/dev/null| grep 'Disk identifier' | awk '{print $NF}' | sed 's/0x//');
        [[ "$tmpTARGETMODE" != "1" && "$tmpTARGETMODE" != "4" ]] && { [ -z  "$defaulthdid" ] && echo -ne "Error! \nselected defaulthd has a invalid id.\n" && exit 1; }
      }

      echo -en "[ \033[32m force \033[0m ] [ \033[32m $defaulthd,$instto \033[0m ]";
    } || {
      mapper=$(df -P $instto |  grep -Eo  '/dev/[^ ]*')
      # in case this is a raid ($instto accross much disk),we should add head -n1
      defaulthd=$(lsblk -rn --inverse $mapper | grep -w disk | awk '{print $1}' | sort -u| head -n1)
      defaulthdid=$(LC_ALL=C fdisk -l /dev/$defaulthd 2>/dev/null| grep 'Disk identifier' | awk '{print $NF}' | sed 's/0x//')
      [[ "$tmpTARGETMODE" != "1" && "$tmpTARGETMODE" != "4" ]] && { [ -z "$instto" -o -z "$defaulthd" -o -z "$defaulthdid" ] && echo -ne "Error! \nCant select defaulthd.\n" && exit 1; }

      echo -en "[ \033[32m auto \033[0m ] [ \033[32m $defaulthd,$instto \033[0m ]";
    } 
  } || echo -en "[ \033[32m non linux \033[0m ]"

}

preparepreseed(){

  sleep 2 && printf "\n ✔ %-30s" "Provisioning instcfg ......."

  #never use
  [[ -n "$custWORD" ]] && myPASSWORD="$(openssl passwd -1 "$custWORD")";
  [[ -z "$myPASSWORD" ]] && myPASSWORD='$1$4BJZaD0A$y1QykUnJ6mXprENfwpseH0';

  > $topdir/$remasteringdir/initramfs/preseed.cfg # $topdir/$remasteringdir/initramfs_arm64/preseed.cfg
  tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
# commonones:
# ----------

# Don't do the usual installation of everything we can find.
# $([[ "$tmpTARGET" != debian* ]] && echo d-i anna/standard_modules boolean false || echo \#d-i anna/standard_modules boolean false)
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
# d-i netcfg/choose_interface select $IFETH
d-i netcfg/disable_autoconfig boolean true
d-i netcfg/dhcp_failed note
d-i netcfg/dhcp_options select Configure network manually
# d-i netcfg/get_ipaddress string $custIPADDR
# d-i netcfg/get_ipaddress string $([[ "$setNet" == '1' && "$FORCENETCFGSTR" != '' ]] && echo "$FIP" || echo "$IP")
# d-i netcfg/get_netmask string $([[ "$setNet" == '1' && "$FORCENETCFGSTR" != '' ]] && echo "$FMASK" || echo "$MASK")
# d-i netcfg/get_gateway string $([[ "$setNet" == '1' && "$FORCENETCFGSTR" != '' ]] && echo "$FGATE" || echo "$GATE")
d-i netcfg/get_nameservers string 1.1.1.1 8.8.8.8 2001:67c:2b0::4 2001:67c:2b0::6
d-i netcfg/no_default_route boolean true
d-i netcfg/confirm_static boolean true
d-i mirror/country string manual
#d-i mirror/http/hostname string $IP
# d-i mirror/http/hostname string $RLSMIRROR
# d-i mirror/http/directory string /
d-i mirror/http/proxy string
d-i debian-installer/allow_unauthenticated boolean true
d-i debian-installer/allow_unauthenticated_ssl boolean true

# debianones:
# ----------


d-i apt-setup/services-select multiselect
d-i passwd/root-login boolean ture
d-i passwd/make-user boolean false
d-i passwd/root-password-crypted password $([[ "$FORCEPASSWORD" != '' && "$FORCEPASSWORD" != '0' ]] && echo $(openssl passwd -1 "$FORCEPASSWORD") || echo $(openssl passwd -1 "inst.sh"))
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false
d-i clock-setup/utc boolean true
d-i time/zone string US/Eastern
d-i clock-setup/ntp boolean true

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
# because partman-auto/disk not explictly defined in preseed.cfg so disable below
# d-i grub-installer/bootdev string default
d-i grub-installer/force-efi-extra-removable boolean true

d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/reboot boolean true
EOF



  
  [[ "$tmpTARGETMODE" == '4' ]] && {
    #dont use onthefly
    #ONTHEFLYPIPECMDSTR='wget -qO- --no-check-certificate '$TARGETDDURL' | dd of=$(list-devices disk |head -n1) bs=10M status=progress';
    # we must pre calc below before inplace dd
    DEFAULTHD=`lsblk -e 7 -e 11 -d | tail -n+2 | cut -d" " -f1 |head -n 1`
  }

  [[ "$tmpTARGETMODE" == '5' ]] && {
    DEFAULTPTSRC=`df $tmpTARGET | grep -v Filesystem | awk '{print $1}'|sed 's/.*\([0-9]\)$/\1/'`
    DEFAULTHDSRC=`LC_ALL=C fdisk -l \`df $tmpTARGET | grep -v Filesystem | awk '{print $1}'|sed s/.$//\` 2>/dev/null| grep 'Disk identifier' | awk '{print $NF}' | sed 's/0x//'`
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
  local quiet="$3"
  # 4,5 optional
  local seg="$4"
  local code="$5"


  local retry=0

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
        ( (for i in `seq -w 000 $seg`;do [ -t 2 ] && { if [ "$i" != "000" ]; then printf "%13s" | tr ' ' '\b' >&2;printf "%13s" >&2;printf "%13s" | tr ' ' '\b' >&2; fi; echo -ne "[ \033[32m $i/$seg \033[0m ]" >&2; }; wget -qO- --no-check-certificate $url"_"$i".chunk"; done) > $file )
      else
        ( (for i in `seq -f '%03.0f' 000 $seg`;do wget -qO- --no-check-certificate $url"_"$i".chunk"; done) > $file )
      fi
    }
    if [ -z "$seg" ]; then ( wget -qO- --no-check-certificate $url ) > $file;fi
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

  sleep 2 && printf "\n ✔ %-30s" "Busy Retrieving Res ......"

  [[ "$tmpDEBUG" == "2" ]] && echo -en "[ \033[32m 3rd rescue,skipped \033[0m ]" && return;
  compositemode="$1"
  instcheck=instcheck.dat
  installmodechoosevmlinuz=vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64)
  installmodechoosevmlinuzcode=`wget --no-check-certificate -qO- "$RLSMIRROR"/"$instcheck"|grep "$installmodechoosevmlinuz":|awk -F ':' '{ print $2}'`
  installmodechoosetdlcore=initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).img
  installmodechoosetdlcorecode=`wget --no-check-certificate -qO- "$RLSMIRROR"/"$instcheck"|grep "$installmodechoosetdlcore":|awk -F ':' '{ print $2}'`

  # when down was used,only targetmode 0 occurs
  [[ "$1" == 'down' && ( "$tmpTARGETMODE" != '4' && "$tmpTARGETMODE" != '1' && "$tmpTARGETMODE" != '5' && "$tmpTARGETMODE" != '9' && "$tmpTARGETMODE" != '10' ) ]] && {

    [[ ! -f $topdir/$downdir/debianbase/$installmodechoosevmlinuz || ! -s $topdir/$downdir/debianbase/$installmodechoosevmlinuz ]] && download_file $RLSMIRROR/$installmodechoosevmlinuz $topdir/$downdir/debianbase/$installmodechoosevmlinuz 0
    [[ ! -f $topdir/$downdir/debianbase/$installmodechoosetdlcore || ! -s $topdir/$downdir/debianbase/$installmodechoosetdlcore ]] && download_file $RLSMIRROR/$installmodechoosetdlcore $topdir/$downdir/debianbase/$installmodechoosetdlcore 0

  }

  [[ "$1" == 'down' && "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debianct' ]] && { [[ ! -f $topdir/$downdir/x.xz || ! -s $topdir/$downdir/x.xz ]] && download_file $TARGETDDURL $topdir/$downdir/x.xz 099; }
  [[ "$1" == 'down' && "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'devdeskct' ]] && { [[ ! -f $topdir/$downdir/x.xz || ! -s $topdir/$downdir/x.xz ]] && download_file $TARGETDDURL"/onekeydevdeskd-01core$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz" $topdir/$downdir/x.xz 999; }
  [[ "$1" == 'down' && "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'devdeskde' ]] && {
    [[ ! -f $topdir/$downdir/x.xz || ! -s $topdir/$downdir/x.xz ]] && download_file $TARGETDDURL"/onekeydevdeskd-01core$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz" $topdir/$downdir/x.xz 999
    [[ ! -f $topdir/$downdir/vmlinuz || ! -s $topdir/$downdir/vmlinuz ]] && download_file $RLSMIRROR/$installmodechoosevmlinuz $topdir/$downdir/vmlinuz 030
    [[ ! -f $topdir/$downdir/initrfs.img || ! -s $topdir/$downdir/initrfs.img ]] && download_file $RLSMIRROR/$installmodechoosetdlcore $topdir/$downdir/initrfs.img 060
  }


  [[ "$tmpHOSTARCH" == '0' ]] && [[ "$1" == 'down' && ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) && "$tmpTARGET" != '' && "$tmpPVEREADY" != '1' ]] && {
    download_file $RLSMIRROR/epvecore.xz $downdir/debianbase/epvecore.xz 0
    download_file $RLSMIRROR/lxcdebtpl.tar.xz $downdir/debianbase/lxcdebtpl.tar.xz 0

    for i in criu_3.15-1-pve-1_amd64.deb lxcfs_5.0.3-pve1_amd64.deb vncterm_1.7-1_amd64.deb pve-lxc-syscalld_1.2.2-1_amd64.deb lxc-pve_5.0.2-2_amd64.deb;do download_file $RLSMIRROR/$i $downdir/debianbase/$i 1;done

  }

  [[ "$tmpHOSTARCH" == '1' ]] && [[ "$1" == 'down' && ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) && "$tmpTARGET" != '' && "$tmpPVEREADY" != '1' ]] && {
    download_file $RLSMIRROR/epvecore_arm64.xz $downdir/debianbase/epvecore_arm64.xz 0
    download_file $RLSMIRROR/lxcdebtpl_arm64.tar.xz $downdir/debianbase/lxcdebtpl_arm64.tar.xz 0

    for i in criu_3.15-1_arm64.deb vncterm_1.7-1_arm64.deb pve-lxc-syscalld_1.0.0-1_arm64.deb lxc-pve_5.0.0-3_arm64.deb;do download_file $RLSMIRROR/$i $downdir/debianbase/$i 1;done

  }


}


function processbasics(){


  [[ "$tmpDEBUG" == "2" ]] && return;
  if [[ "$tmpTARGETMODE" != '0' && "$tmpTARGETMODE" != '1' && "$tmpTARGETMODE" != '2' && "$tmpTARGETMODE" != '4' && "$tmpTARGETMODE" != '5' && "$tmpTARGETMODE" != '9' && "$tmpTARGETMODE" != '10' ]]; then

    #cd $topdir/$remasteringdir/initramfs/files;
    #CWD="$(pwd)"
    #echo -en "[ \033[32m cd to ${CWD##*/} \033[0m ]"

    #echo -en " - busy unpacking initrfs.img ..."
    [[ "$tmpBUILD" != "1" ]] && tar Jxf $topdir/$downdir/debianbase/initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).img --warning=no-timestamp -C $topdir/$remasteringdir/initramfs/files || tar Jxf $topdir/$downdir/debianbase/initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).img -C $topdir/$remasteringdir/initramfs/files
    [[ "$?" != "0" ]] && exit 1
  fi

  if [[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'debianct' ]]; then
    #echo -en " - busy unpacking x.xz ..."
    (cd $topdir/$remasteringdir;tar Jxf $topdir/$downdir/x.xz --warning=no-timestamp;[[ "$?" != "0" ]] && exit 1);
  fi
  if [[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'devdeskct' ]]; then
    (mkdir -p /x;cd /x;tar Jxf $topdir/$downdir/x.xz --warning=no-timestamp --strip-components=1 01-core --exclude=01-core/dev/*;[[ "$?" != "0" ]] && exit 1);
  fi

  if [[ ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) && "$tmpTARGET" != '' ]]; then
    #just a placment or echo processbasics here
    :;
  fi


  #cp -aR $topdir/$downdir/onekeydevdesk/debian-live ./lib >>/dev/null 2>&1
  #chmod +x ./lib/debian-live/*
  #cp -aR $topdir/$downdir/onekeydevdesk/updates ./lib/modules/5.10.0-22-amd64 >>/dev/null 2>&1


}


processgrub(){

  patchsdir="$DEBMIRROR"/_build/apps/xxx$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64)
  kerneldir="$DEBMIRROR"/_build/debianbase/dists/bullseye/main-debian-installer/$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n binary-arm64 || echo -n binary-amd64)/tarball

  [[ "$tmpDEBUG" == "2" ]] && [[ "$tmpTARGETMODE" == '0' ]] && [[ "$tmpTARGET" != debian* && "$tmpTARGET" != devdeskos* && "$tmpTARGET" != dummy && "$tmpTARGET" != *.iso ]] && {
    rescuecommandstring="[[ ! -f /longrunpipefgcmd.sh ]] && wget --no-check-certificate -q "${patchsdir/xxx/ddinstall-patchs}"/longrunpipebgcmd_redirectermoniter.sh -O /longrunpipefgcmd.sh;chmod +x /longrunpipefgcmd.sh;/longrunpipefgcmd.sh "$TARGETDDURL,$UNZIP" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { [[ "$defaulthdid" != "" ]] && echo "$defaulthdid" || echo "$defaulthd"; } || echo "nonlinux" ) $([[ "$FORCE1STNICNAME" != '' ]] && echo "$IFETHMAC" || echo "\"\$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print \$NF}')\"") $([[ "$FORCEINSTCTL" != '' ]] && echo "$FORCEINSTCTL") $([[ "$FORCEPASSWORD" != '' ]] && echo "$FORCEPASSWORD") $([ "$setNet" == '1' -a "$FORCENETCFGSTR" != '' ] && echo "$FIP,$FMASK,$FGATE";[ "$AutoNet" == '1' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE";[ "$AutoNet" == '2' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE","dhcp") $([ "$FORCEINSTCMD" != '' ] && printf "%s" "$FORCEINSTCMD"| while IFS= read -r -n1 char; do [[ ! "$char" =~ [a-zA-Z0-9] ]] && printf "\\\\\%04o" "'$char" || printf "%s" "$char"; done)"

    return
  }

  [[ "$tmpTARGETMODE" == '4' ]] && [[ "$tmpTARGET" == 'devdeskct' ]] && {
    inplacecommandstring="[[ ! -f /inplacemutating.sh ]] && wget --no-check-certificate -q "${patchsdir/xxx/inplace-patchs}"/inplacemutating.sh -O /inplacemutating.sh;chmod +x /inplacemutating.sh;/inplacemutating.sh"

    return
  }

  [[ "$tmpTARGETMODE" == '4' ]] && [[ "$tmpTARGET" == 'devdeskde' ]] && {
    inplacecommandstring="[[ ! -f /ddtoafile.sh ]] && wget --no-check-certificate -q "${patchsdir/xxx/inplace-patchs}"/ddtoafile.sh.sh -O /ddtoafile.sh.sh;chmod +x /ddtoafile.sh;/ddtoafile.sh"

    return
  }

  [[ "$tmpTARGETMODE" == '0' && "$tmpTARGET" == debian* ]] && { # tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
    # will never go here cause we assume debver 11 when blank or not correct
    if [[ -z "$DEBVER" ]]; then
# we mixed the efi and bios togeth in 30atomic
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
dipreseedearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 300;" )screen -dmS vnc /bin/linuxvnc -t 1 -p $([[ "$tmpINSTVNCPORT" != '' ]] && echo "$tmpINSTVNCPORT" || echo "80" )"
dipartmanearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/forcelost.sh;chmod +x /forcelost.sh;/forcelost.sh;wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startssh.sh;chmod +x /startssh.sh;/startssh.sh;" ) $([[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" != '' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startrathole.sh;chmod +x /startrathole.sh;/startrathole.sh "$tmpINSTWITHBORE";" )anna net-retriever default;wget --no-check-certificate -q "${patchsdir/xxx/debianinstall-patchs}"/preinstall.sh;chmod +x /preinstall.sh;/preinstall.sh "$TARGETDDURL" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { [[ "$defaulthdid" != "" ]] && echo "$defaulthdid" || echo "$defaulthd"; } || echo "nonlinux" )"
# sometimes https were auto-transed to http, we should adjust it backed
dipreseedlatecommandstring="wget --no-check-certificate -q "${patchsdir/xxx/debianinstall-patchs}"/postinstall.sh -O postinstall.sh;chmod +x /postinstall.sh;/postinstall.sh $DEBMIRROR $([[ "$FORCEINSTCTL" != '' ]] && echo "$FORCEINSTCTL") $([ "$FORCEINSTCMD" != '' ] && printf "%s" "$FORCEINSTCMD"| while IFS= read -r -n1 char; do [[ ! "$char" =~ [a-zA-Z0-9] ]] && printf "\\\\\%04o" "'$char" || printf "%s" "$char"; done)"
    else
dipreseedearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 300;" )screen -dmS vnc /bin/linuxvnc -t 1 -p $([[ "$tmpINSTVNCPORT" != '' ]] && echo "$tmpINSTVNCPORT" || echo "80" )"
dipartmanearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/forcelost.sh;chmod +x /forcelost.sh;/forcelost.sh;wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startssh.sh;chmod +x /startssh.sh;/startssh.sh;" ) $([[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" != '' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startrathole.sh;chmod +x /startrathole.sh;/startrathole.sh "$tmpINSTWITHBORE";" )wget --no-check-certificate -q "${patchsdir/xxx/debootstrapinstall-patchs}"/longrunpipebgcmd_redirectermoniter.templates;wget --no-check-certificate -q "${patchsdir/xxx/debootstrapinstall-patchs}"/longrunpipebgcmd_redirectermoniter.sh;chmod +x /longrunpipebgcmd_redirectermoniter.sh;/longrunpipebgcmd_redirectermoniter.sh "$RLSMIRROR,$TARGETDDURL,$DEBVER,$UNZIP" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { [[ "$defaulthdid" != "" ]] && echo "$defaulthdid" || echo "$defaulthd"; } || echo "nonlinux" ) $([[ "$FORCE1STNICNAME" != '' ]] && echo "$IFETHMAC" || echo "\"\$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print \$NF}')\"") $([[ "$FORCEINSTCTL" != '' ]] && echo "$FORCEINSTCTL") $([[ "$FORCEPASSWORD" != '' ]] && echo "$FORCEPASSWORD") $([ "$setNet" == '1' -a "$FORCENETCFGSTR" != '' ] && echo "$FIP,$FMASK,$FGATE";[ "$AutoNet" == '1' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE";[ "$AutoNet" == '2' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE","dhcp")"
    fi
} #EOF

  # both inst and buildmode share PIPECMSTR defines but without forcenetcfgstr and force github mirror for buildmode
  # we use both ext2/fat16 duplicated parts cause some machine only regnoice ext2(the ones boot with its own grub instead of on disk grubs)but not fat16
  [[ "$tmpTARGET" == devdeskos* ]] && {
    choosevmlinuz=$kerneldir/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64)
    chooseinitrfs=$kerneldir/initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).img
    chooseonekeydevdeskd1=$TARGETDDURL/onekeydevdeskd-01core$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).xz
    chooseonekeydevdeskd2=$TARGETDDURL/onekeydevdeskd-02gui$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).xz
  }

  # we meant to use live-installer but it is too complicated so we turn to parted
  # there is only grub-efi on arm64,shall we separate preseed?
  # we must put force1sthdname before forcenetcfgstr,because argpositiion 1,2,3,4 is always there(fixedly appear) but 5 not(if not forced,it dont occpy a pos),we pust fixed ones piorr in front
  [[ "$tmpTARGETMODE" == '0' && "$tmpTARGET" == *.iso ]] && { # tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
# in debian installer, some machine dhcp mode are not clever enough, so just force autonet 1 and 2 both static
dipreseedearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 300;" )screen -dmS vnc /bin/linuxvnc -t 1 -p $([[ "$tmpINSTVNCPORT" != '' ]] && echo "$tmpINSTVNCPORT" || echo "80" )"
dipartmanearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/forcelost.sh;chmod +x /forcelost.sh;/forcelost.sh;wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startssh.sh;chmod +x /startssh.sh;/startssh.sh;" ) $([[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" != '' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startrathole.sh;chmod +x /startrathole.sh;/startrathole.sh "$tmpINSTWITHBORE";" )wget --no-check-certificate -q "${patchsdir/xxx/transinstall-patchs}"/longrunpipebgcmd_redirectermoniter.templates;wget --no-check-certificate -q "${patchsdir/xxx/transinstall-patchs}"/longrunpipebgcmd_redirectermoniter.sh;chmod +x /longrunpipebgcmd_redirectermoniter.sh;/longrunpipebgcmd_redirectermoniter.sh "$RLSMIRROR,$TARGETDDURL,$UNZIP" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { [[ "$defaulthdid" != "" ]] && echo "$defaulthdid" || echo "$defaulthd"; } || echo "nonlinux" ) $([[ "$FORCE1STNICNAME" != '' ]] && echo "$IFETHMAC" || echo "\"\$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print \$NF}')\"") $([[ "$FORCEINSTCTL" != '' ]] && echo "$FORCEINSTCTL") $([[ "$FORCEPASSWORD" != '' ]] && echo "$FORCEPASSWORD") $([ "$setNet" == '1' -a "$FORCENETCFGSTR" != '' ] && echo "$FIP,$FMASK,$FGATE";[ "$AutoNet" == '1' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE";[ "$AutoNet" == '2' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE","dhcp")"
} #EOF




  # azure hd need bs=10M or it will fail
  [[ "$tmpTARGET" != 'debian10r' ]] && [[ "$UNZIP" == '0' ]] && PIPECMDSTR='wget -qO- --no-check-certificate '$TARGETDDURL' |stdbuf -oL dd of=$(list-devices disk |head -n1) bs=10M 2> /var/log/progress & pid=`expr $! + 0`;echo $pid';

  [[ "$tmpTARGET" == 'debian10r' ]] && [[ "$UNZIP" == '2' ]] && [[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && PIPECMDSTR='(for i in `seq -w 000 699`;do wget -qO- --no-check-certificate '$TARGETDDURL'_$i; done) |tar JOx |stdbuf -oL dd of='$defaulthdid' bs=10M 2> /var/log/progress & pid=`expr $! + 0`;echo $pid' || PIPECMDSTR='(for i in `seq -w 000 699`;do wget -qO- --no-check-certificate '$TARGETDDURL'_$i; done) |tar JOx |stdbuf -oL dd of=nonlinux bs=10M 2> /var/log/progress & pid=`expr $! + 0`;echo $pid';


  # we must put force1sthdname before forcenetcfgstr,because argpositiion 1,2,3,4,5 is always there(fixedly appear) but 6 not(if not forced,it dont occpy a pos),we pust fixed ones piorr in front
  [[ "$tmpTARGETMODE" == '0' ]] && [[ "$tmpTARGET" != debian* && "$tmpTARGET" != devdeskos* && "$tmpTARGET" != dummy && "$tmpTARGET" != *.iso ]] && { # tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
# anna-install wget-udeb here?
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
# in debian installer, some machine dhcp mode are not clever enough, so just force autonet 1 and 2 both static
dipreseedearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 300;" )screen -dmS vnc /bin/linuxvnc -t 1 -p $([[ "$tmpINSTVNCPORT" != '' ]] && echo "$tmpINSTVNCPORT" || echo "80" )"
dipartmanearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/forcelost.sh;chmod +x /forcelost.sh;/forcelost.sh;wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startssh.sh;chmod +x /startssh.sh;/startssh.sh;" ) $([[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" != '' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startrathole.sh;chmod +x /startrathole.sh;/startrathole.sh "$tmpINSTWITHBORE";" )wget --no-check-certificate -q "${patchsdir/xxx/ddinstall-patchs}"/longrunpipebgcmd_redirectermoniter.templates;wget --no-check-certificate -q "${patchsdir/xxx/ddinstall-patchs}"/longrunpipebgcmd_redirectermoniter.sh;chmod +x /longrunpipebgcmd_redirectermoniter.sh;/longrunpipebgcmd_redirectermoniter.sh "$TARGETDDURL,$UNZIP" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { [[ "$defaulthdid" != "" ]] && echo "$defaulthdid" || echo "$defaulthd"; } || echo "nonlinux" ) $([[ "$FORCE1STNICNAME" != '' ]] && echo "$IFETHMAC" || echo "\"\$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print \$NF}')\"") $([[ "$FORCEINSTCTL" != '' ]] && echo "$FORCEINSTCTL") $([[ "$FORCEPASSWORD" != '' ]] && echo "$FORCEPASSWORD") $([ "$setNet" == '1' -a "$FORCENETCFGSTR" != '' ] && echo "$FIP,$FMASK,$FGATE";[ "$AutoNet" == '1' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE";[ "$AutoNet" == '2' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "$IP","$MASK","$GATE","dhcp") $([ "$FORCEINSTCMD" != '' ] && printf "%s" "$FORCEINSTCMD"| while IFS= read -r -n1 char; do [[ ! "$char" =~ [a-zA-Z0-9] ]] && printf "\\\\\%04o" "'$char" || printf "%s" "$char"; done)"
} #EOF

  [[ "$tmpTARGETMODE" == '2' ]] && [[ "${tmpTARGET:0:11}" == '10000:/dev/' ]] && { # tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
dipreseedearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 300;" )screen -dmS vnc /bin/linuxvnc -t 1 -p $([[ "$tmpINSTVNCPORT" != '' ]] && echo "$tmpINSTVNCPORT" || echo "80" )"
dipartmanearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/forcelost.sh;chmod +x /forcelost.sh;/forcelost.sh;wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startssh.sh;chmod +x /startssh.sh;/startssh.sh;" ) $([[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" != '' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startrathole.sh;chmod +x /startrathole.sh;/startrathole.sh "$tmpINSTWITHBORE";" )wget --no-check-certificate -q "${patchsdir/xxx/ncrestore-patchs}"/longrunpipebgcmd_redirectermoniter.templates;wget --no-check-certificate -q "${patchsdir/xxx/ncrestore-patchs}"/longrunpipebgcmd_redirectermoniter.sh;chmod +x /longrunpipebgcmd_redirectermoniter.sh;/longrunpipebgcmd_redirectermoniter.sh "$tmpTARGET""
} #EOF

  # important for submenu in typing dummy
  [[ "$tmpTARGETMODE" == '0' && "$tmpTARGET" == 'dummy' ]] && { # tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
#debian d-i has a bug cuasing bgcmd not running,so we use screen
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
dipreseedearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 300;" )screen -dmS vnc /bin/linuxvnc -t 1 -p $([[ "$tmpINSTVNCPORT" != '' ]] && echo "$tmpINSTVNCPORT" || echo "80" )"
dipartmanearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/forcelost.sh;chmod +x /forcelost.sh;/forcelost.sh;" )wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startssh.sh;chmod +x /startssh.sh;/startssh.sh; $([[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" != '' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startrathole.sh;chmod +x /startrathole.sh;/startrathole.sh "$tmpINSTWITHBORE";" )UDPKG_QUIET=1 exec udpkg --configure --force-configure di-utils-shell"
} #EOF


  [[ "$tmpTARGETMODE" == '5' && "$tmpTARGET" =~ './' ]] && { # tee -a $topdir/$remasteringdir/initramfs/preseed.cfg $topdir/$remasteringdir/initramfs_arm64/preseed.cfg > /dev/null <<EOF
#debian d-i has a bug cuasing bgcmd not running,so we use screen
# must not place anna-install network-console here in preseed/early_command but instead in partman/early_command
dipreseedearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "screen -dmS reboot /sbin/reboot -d 300;" )screen -dmS vnc /bin/linuxvnc -t 1 -p $([[ "$tmpINSTVNCPORT" != '' ]] && echo "$tmpINSTVNCPORT" || echo "80" )"
dipartmanearlycommandstring="$([[ "$tmpINSTWITHMANUAL" == '1' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/forcelost.sh;chmod +x /forcelost.sh;/forcelost.sh;" )wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startssh.sh;chmod +x /startssh.sh;/startssh.sh; $([[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" != '' ]] && echo "wget --no-check-certificate -q "${patchsdir/xxx/rescue-patchs}"/startrathole.sh;chmod +x /startrathole.sh;/startrathole.sh "$tmpINSTWITHBORE";" )wget --no-check-certificate -q "${patchsdir/xxx/localinstall-patchs}"/longrunpipebgcmd_redirectermoniter.templates;wget --no-check-certificate -q "${patchsdir/xxx/localinstall-patchs}"/longrunpipebgcmd_redirectermoniter.sh;chmod +x /longrunpipebgcmd_redirectermoniter.sh;/longrunpipebgcmd_redirectermoniter.sh "$DEFAULTHDSRC,$DEFAULTPTSRC,$TARGETDDURL,${tmpTARGET##./},$UNZIP" $([[ "$tmpBUILD" != "11" && "$tmpBUILD" != "1" ]] && { [[ "$defaulthdid" != "" ]] && echo "$defaulthdid" || echo "$defaulthd"; } || echo "nonlinux" )"
} #EOF

  [[ "$GRUBTYPE" != '3' && "$GRUBTYPE" != '10' && "$GRUBTYPE" != '11' ]] && {


    READGRUB=''$remasteringdir'/boot/grub.read'
    # -a is important to avoid grep error of binary file matching and initrdfail for ubuntu fix
    # under win need escape cf, dont need grep \ and initrdfail
    cat $GRUBDIR/$GRUBFILE |sed -e 's/"\${initrdfail}"/\$initrdfail/g' |sed -n '1h;1!H;$g;s/\n/%%%%%%%/g;$p' |grep -a -om 1 'menuentry\ [^{]*{[^}]*}%%%%%%%' |sed 's/%%%%%%%/\n/g' >$READGRUB
    LoadNum="$(cat $READGRUB |grep -c 'menuentry ')"
    # some centos versions need guessout the whole menuentry cause there is none in readgrub file
    needguess="$(grep 'linux.*/\|kernel.*/\|initrd.*/' $READGRUB |awk '{print $1}')"
    if [[ "$LoadNum" -eq '1' ]] && [[ -n "$needguess" ]]; then
      cat $READGRUB |sed '/^$/d' >$remasteringdir/boot/grub.new;
    elif [[ "$LoadNum" -gt '1' ]] && [[ -n "$needguess" ]]; then
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
      sed -i -e 's/^/  /' $remasteringdir/boot/grub.new;
      [[ -f $remasteringdir/boot/grub.new ]] && [[ "$(grep -c '{' $remasteringdir/boot/grub.new)" -eq "$(grep -c '}' $remasteringdir/boot/grub.new)" ]] || {
        echo -ne "\033[31m Error! \033[0m Not configure $GRUBFILE. \n";
        exit 1;
      }
    # now begin to guess out the menuentry
    elif [[ -z "$needguess" ]]; then
      CFG0="$(awk '/insmod part_/{print NR}' $GRUBDIR/$GRUBFILE | head -n 1)"
      CFG2=$(expr $(awk '/--fs-uuid --set=root/{print NR}' $GRUBDIR/$GRUBFILE | head -n 2 | tail -n 1) + 1)
      CFG1=""
      for tmpCFG in $(awk '/fi/{print NR}' $GRUBDIR/$GRUBFILE); do
        [ "$tmpCFG" -ge "$CFG0" -a "$tmpCFG" -le "$CFG2" ] && CFG1="$tmpCFG"
      done
      [[ -z "$CFG1" ]] && {
        echo "Error! read $GRUBFILE. ";
        exit 1;
      }

      # caution from GRUBDIR/GRUBFILE not READGRUB
      cat >>$remasteringdir/boot/grub.new <<EOF
      menuentry 'COLOXC' --class gnu-linux --class gnu --class os {
  load_video
  insmod gzio
  $(sed -n "$CFG0,$CFG1"p $GRUBDIR/$GRUBFILE)
  linux /boot/vmlinuz
  initrd /boot/initrfs.img
}
EOF
      sed -i -e 's/^/  /' $remasteringdir/boot/grub.new;
      [[ -f $remasteringdir/boot/grub.new ]] && [[ "$(grep -c '{' $remasteringdir/boot/grub.new)" -eq "$(grep -c '}' $remasteringdir/boot/grub.new)" ]] || {
        echo -ne "\033[31m Error! \033[0m Not configure $GRUBFILE. \n";
        exit 1;
      }
    fi
    [ ! -f $remasteringdir/boot/grub.new ] && echo "Error! process $GRUBFILE. " && exit 1;
    sed -i "/menuentry.*/c\menuentry\ \'COLXC \[cooperlxclinux\ withrecoveryandhypervinside\]\'\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ --unrestricted\ \{" $remasteringdir/boot/grub.new;
    sed -i "/echo.*Loading/d" $remasteringdir/boot/grub.new;

    [[ -n "$needguess" ]] && CFG00="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)" || CFG00="$(awk '/insmod part_/{print NR}' $GRUBDIR/$GRUBFILE | head -n 1)";
    CFG11=()
    for tmptmpCFG in `awk '/}/{print NR}' $GRUBDIR/$GRUBFILE`
    do
      [ "$tmptmpCFG" -gt "$CFG00" ] && CFG11+=("$tmptmpCFG");
    done
    # all routed to grub-reboot logic except win
    [[ -n "$needguess" ]] && {
      [[ "$LoadNum" -eq '1' ]] && INSERTGRUB="$(expr ${CFG11[0]} + 1)" || INSERTGRUB="$(awk '/submenu |menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 2|tail -n 1)";
      REBOOTNO=1;
    }
    [[ -z "$needguess" ]] && {
      INSERTGRUB="$(expr ${CFG00} - 1)";
      REBOOTNO=1;
      # has blscfg,need update insertgrub
      if grep -q '^insmod blscfg$' $GRUBDIR/$GRUBFILE && grep -q '^blscfg$' $GRUBDIR/$GRUBFILE; then
        beforenum="$(awk '/^blscfg$/ {exit} /^menuentry / {count++} END{print count+0}' "$GRUBDIR/$GRUBFILE")"
        blscfgnum="$(find /boot/loader/entries -maxdepth 1 -type f | wc -l)"
        blsline="$(grep -n '^blscfg$' "$GRUBDIR/$GRUBFILE" | cut -d: -f1)"
        if [ "$INSERTGRUB" -lt "$blsline" ]; then INSERTGRUB=$((blsline + 1));REBOOTNO=$((beforenum + blscfgnum)); fi
      fi
    }

    echo -en "[ \033[32m grubline: $INSERTGRUB, rebootno: $REBOOTNO \033[0m ]"
  }
  [[ "$GRUBTYPE" == '3' ]] && {
    CFG0="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)";
    CFG1="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)";
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 == $CFG0 ] && sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE >$remasteringdir/boot/grub.new;
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 != $CFG0 ] && sed -n "$CFG0,$[$CFG1-1]"p $GRUBDIR/$GRUBFILE >$remasteringdir/boot/grub.new;
    [[ ! -f $remasteringdir/boot/grub.new ]] && echo "Error! configure append $GRUBFILE. " && exit 1;
    sed -i "/title.*/c\title\ \'DebianNetboot \[buster\ amd64\]\'" $remasteringdir/boot/grub.new;
    sed -i '/^#/d' $remasteringdir/boot/grub.new;
    INSERTGRUB="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
  }


[[ "$GRUBTYPE" == '11' ]] && {


    READGRUB=''$remasteringdir'/boot/grub.read'
    # -a is important to avoid grep error of binary file matching and initrdfail for ubuntu fix
    # under win need escape cf, dont need grep \ and initrdfail
    cat $GRUBDIR/$GRUBFILE |sed 's/\r//g' |sed -n '1h;1!H;$g;s/\n/%%%%%%%/g;$p' |grep -a -om 1 'menuentry [^{]*{[^}]*}%%%%%%%' |sed 's/%%%%%%%/\n/g' >$READGRUB
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
    sed -i ':a;N;$!ba;s/menuentry.*{/menuentry\ '"'"'COLXC \[cooperlxclinux\ withrecoveryandhypervinside\]'"'"'\ --class bootinfo\ --class\ icon-bootinfo\ \{/g;s/{.*}/{\n\tlinux\ \/vmlinuz_1kddinst\n\tinitrd\ \/initrfs_1kddinst.img\n}/g' $remasteringdir/boot/grub.new
    sed -i "/echo.*Loading/d" $remasteringdir/boot/grub.new;

    CFG00="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)";
    CFG11=()
    for tmptmpCFG in `awk '/}/{print NR}' $GRUBDIR/$GRUBFILE`
    do
      [ "$tmptmpCFG" -gt "$CFG00" ] && CFG11+=("$tmptmpCFG");
    done
    # all routed to grub-reboot logic except win
    [[ "$LoadNum" -eq '1' ]] && INSERTGRUB="$(expr ${CFG11[0]} + 1)" || INSERTGRUB="$(awk '/submenu |menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
    echo -en "[ \033[32m grubline: $INSERTGRUB \033[0m ]"
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

    Add_OPTION=""
    Add_OPTION="$Add_OPTION debian-installer/framebuffer=false"
    [[ "$tmpINSTSSHONLY" == '1' ]] && Add_OPTION="$Add_OPTION DEBIAN_FRONTEND=text"
    [[ "$tmpTARGET" == 'dummy' && "$tmpINSTWITHMANUAL" == '1' ]] && Add_OPTION="$Add_OPTION rescue/enable=true"
    # priority=critical is important to ingore force uefi hints, however need to match with a preseedearlycommand patch in lib/partman/init.d/50efi
    [[ $tmpTARGET != debian* ]] && Add_OPTION="$Add_OPTION standardmodules=false" || Add_OPTION="$Add_OPTION priority=critical"
    Add_OPTION="$Add_OPTION interface=$IFETH $([ "$setNet" == '1' -a "$FORCENETCFGSTR" != '' ] && echo "ipaddress=$FIP netmask=$FMASK gateway=$FGATE";[ "$setNet" != '1' ] && [ "$IP" != '' -a "$MASK" != '' -a "$GATE" != '' ] && echo "ipaddress=$IP netmask=$MASK gateway=$GATE")"
    Add_OPTION="$Add_OPTION mirrorhostname=$RLSMIRROR mirrordirectory=/"

    # $([[ "$tmpINSTEMBEDVNC" == '1' ]] && echo DEBIAN_FRONTEND=gtk) is not needed,will be forced in debug mode
    BOOT_OPTION="console=ttyS0,115200n8 console=tty0 auto=true $Add_OPTION $([[ $dipreseedearlycommandstring != '' ]] && echo preseedearlycommand=\"$dipreseedearlycommandstring\") partmanearlycommand=\"$dipartmanearlycommandstring\" $([[ $dipreseedlatecommandstring != '' ]] && echo preseedlatecommand=\"$dipreseedlatecommandstring\") hostname=debian domain= -- quiet";

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

    Add_OPTION=""
    Add_OPTION="$Add_OPTION debian-installer/framebuffer=false"
    [[ "$tmpINSTSSHONLY" == '1' ]] && Add_OPTION="$Add_OPTION DEBIAN_FRONTEND=text"
    [[ "$tmpTARGET" == 'dummy' && "$tmpINSTWITHMANUAL" == '1' ]] && Add_OPTION="$Add_OPTION rescue/enable=true"
    [[ $tmpTARGET != debian* ]] && Add_OPTION="$Add_OPTION standardmodules=false"
    Add_OPTION="$Add_OPTION interface=$IFETH ipaddress=$([[ $setNet == '1' && $FORCENETCFGSTR != '' ]] && echo $FIP || echo $IP) netmask=$([[ $setNet == '1' && $FORCENETCFGSTR != '' ]] && echo $FMASK || echo $MASK) gateway=$([[ $setNet == '1' && $FORCENETCFGSTR != '' ]] && echo $FGATE || echo $GATE)"
    Add_OPTION="$Add_OPTION mirrorhostname=$RLSMIRROR mirrordirectory=/"

    # $([[ "$tmpINSTEMBEDVNC" == '1' ]] && echo DEBIAN_FRONTEND=gtk) is not needed,will be forced in debug mode
    BOOT_OPTION="console=ttyS0,115200n8 console=tty0 auto=true $Add_OPTION $([[ $dipreseedearlycommandstring != '' ]] && echo preseedearlycommand=\"$dipreseedearlycommandstring\") partmanearlycommand=\"$dipartmanearlycommandstring\" $([[ $dipreseedlatecommandstring != '' ]] && echo preseedlatecommand=\"$dipreseedlatecommandstring\") hostname=debian domain= -- quiet";

    sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\\\$prefix\/vmlinuz_1kddinst $BOOT_OPTION" $remasteringdir/boot/grub.new;
    sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\\\$prefix\/initrfs_1kddinst.img" $remasteringdir/boot/grub.new;

  }

  [[ "$tmpBUILD" == "1" ]] && [[ "$tmpTARGETMODE" != "1" ]] && {

    LinuxKernel="linux";
    LinuxIMG="initrd";

    Add_OPTION=""
    Add_OPTION="$Add_OPTION debian-installer/framebuffer=false"
    [[ "$tmpINSTSSHONLY" == '1' ]] && Add_OPTION="$Add_OPTION DEBIAN_FRONTEND=text"
    [[ "$tmpTARGET" == 'dummy' && "$tmpINSTWITHMANUAL" == '1' ]] && Add_OPTION="$Add_OPTION rescue/enable=true"
    [[ $tmpTARGET != debian* ]] && Add_OPTION="$Add_OPTION standardmodules=false"
    Add_OPTION="$Add_OPTION interface=$IFETH ipaddress=$([[ $setNet == '1' && $FORCENETCFGSTR != '' ]] && echo $FIP || echo $IP) netmask=$([[ $setNet == '1' && $FORCENETCFGSTR != '' ]] && echo $FMASK || echo $MASK) gateway=$([[ $setNet == '1' && $FORCENETCFGSTR != '' ]] && echo $FGATE || echo $GATE)"
    Add_OPTION="$Add_OPTION mirrorhostname=$RLSMIRROR mirrordirectory=/"

    # $([[ "$tmpINSTEMBEDVNC" == '1' ]] && echo DEBIAN_FRONTEND=gtk) is not needed,will be forced in debug mode
    BOOT_OPTION="console=ttyS0,115200n8 console=tty0 auto=true $Add_OPTION $([[ $dipreseedearlycommandstring != '' ]] && echo preseedearlycommand=\"$dipreseedearlycommandstring\") partmanearlycommand=\"$dipartmanearlycommandstring\" $([[ $dipreseedlatecommandstring != '' ]] && echo preseedlatecommand=\"$dipreseedlatecommandstring\") hostname=debian domain= -- quiet";

    sed -i "" "s/$LinuxKernel.*/$LinuxKernel \/vmlinuz_1kddinst $BOOT_OPTION/g" $remasteringdir/boot/grub.new;
    sed -i "" "s/$LinuxIMG.*/$LinuxIMG \/initrfs_1kddinst.img/g" $remasteringdir/boot/grub.new;

  }

  [[ "$tmpBUILD" != "1" ]] && sed -i '$a\\n' $remasteringdir/boot/grub.new || sed -i "" $'$a\\\n\n' $remasteringdir/boot/grub.new;

}

patchgrub(){

  [[ "$tmpDEBUG" == "2" ]] && return;
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

installdeps(){
  apt-get update -y -qq --allow-releaseinfo-change --allow-unauthenticated --allow-insecure-repositories > /dev/null || exit 1

  (
  set -e
  # bridge-utils,isc-dhcp-server need to install as early as possiable and standalone, or siblings may broken it causing apt-get --fix-broken conflicts, thus make connection lost
  apt-get install -y -qq --no-install-recommends bridge-utils isc-dhcp-server > /dev/null || exit 1
  # libgnutlsxx28,libprotobuf23 need to install as early as possiable and standalone, or siblings may broken it causing apt-get --fix-broken conflicts
  apt-get install -y -qq --no-install-recommends libgnutlsxx28 libprotobuf23 > /dev/null || exit 1
  apt-get install -y -qq --no-install-recommends iptables \
  python3 \
  libnl-3-200 \
  apparmor libbsd0 libfuse2 libmd0 libnet1 libprotobuf-c1 python3-pkg-resources python3-protobuf python3-six uidmap \
  libapparmor1 > /dev/null || exit 1

  [[ "$tmpHOSTARCH" == '0' ]] && { dpkg -i $downdir/debianbase/{criu_3.15-1-pve-1_amd64.deb,lxcfs_5.0.3-pve1_amd64.deb,lxc-pve_5.0.2-2_amd64.deb} > /dev/null || exit 1; }
  [[ "$tmpHOSTARCH" == '1' ]] && {
    apt-get install -y -qq --no-install-recommends lxcfs > /dev/null || exit 1
    dpkg -i $downdir/debianbase/{criu_3.15-1_arm64.deb,lxc-pve_5.0.0-3_arm64.deb} > /dev/null || exit 1
  }

  update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null 2>&1
  # withoutv6 docker wont start
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >/dev/null 2>&1
  [ ! -f /usr/share/apparmor-features/.fixed ] && {
    mv /usr/share/apparmor-features/features /usr/share/apparmor-features/features2
    mv /usr/share/apparmor-features/features.stock /usr/share/apparmor-features/features
    mv /usr/share/apparmor-features/features2 /usr/share/apparmor-features/features.stock
    touch /usr/share/apparmor-features/.fixed
  }

  apt-get install -y -qq --no-install-recommends perl libclone-perl libjson-perl liblinux-inotify2-perl libhttp-daemon-perl libdevel-cycle-perl libfilesys-df-perl libstring-shellquote-perl libnet-ip-perl libnet-ssleay-perl libqb100 libcrypt-openssl-random-perl libcrypt-openssl-rsa-perl libmime-base32-perl libwww-perl libnet-ldap-perl libauthen-pam-perl libyaml-libyaml-perl libdigest-hmac-perl libuuid-perl \
  libnetaddr-ip-perl libposix-strptime-perl \
  libcpg4 libcmap4 libquorum5 libglib2.0-0 libfuse2 libsqlite3-0 librrd8 \
  librados2 libapt-pkg-perl libnet-dns-perl libnet-dbus-perl libanyevent-http-perl libanyevent-perl libio-stringy-perl libio-multiplex-perl libfile-chdir-perl libfile-readbackwards-perl librrds-perl libtemplate-perl \
  faketime \
  libcurl3-gnutls libjpeg62-turbo > /dev/null || exit 1

  [[ "$tmpHOSTARCH" == '0' ]] && { dpkg -i $downdir/debianbase/{vncterm_1.7-1_amd64.deb,pve-lxc-syscalld_1.2.2-1_amd64.deb} > /dev/null || exit 1; }
  [[ "$tmpHOSTARCH" == '1' ]] && { dpkg -i $downdir/debianbase/{vncterm_1.7-1_arm64.deb,pve-lxc-syscalld_1.0.0-1_arm64.deb} > /dev/null || exit 1; }

  apt-get install -y -qq --no-install-recommends dtach > /dev/null || exit 1

  mkdir -p /var/lib/rrdcached/db
  ) 2> >(grep -Ev '^(Created symlink |Extracting templates from packages: |apparmor_parser:)' >&2) || exit 1

  echo -en "[ \033[32m deps \033[0m ]"

}

buildsetupfuns(){
# pvesetnat, meant to be as a file and used as a instant cmd for this inst.sh, so we write it in cmdstr form
IFS='' read -r -d '' pvesetnat <<"EOFF"
iptablesconf='/root/.pvesetnatrc'
conf_list(){
    cat $iptablesconf
}
conf_add(){
    if [ ! -f $iptablesconf ];then
        echo "找不到配置文件!"
        exit 1
    fi
    echo "请输入虚拟机的内网IP(例:10.10.10.x)"
    [ -z "$confvmip" ] && read -p "(Default: Exit):" confvmip </dev/tty
    [ -z "$confvmip" ] && exit 1
    echo
    echo "虚拟机内网IP = $confvmip"
    echo
    while true
    do
    echo "请输入虚拟机的端口:"
    [ -z "$confvmport" ] && read -p "(默认端口: 80):" confvmport </dev/tty
    [ -z "$confvmport" ] && confvmport="80"
    expr $confvmport + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ $confvmport -ge 1 ] && [ $confvmport -le 65535 ]; then
            echo
            echo "虚拟机端口 = $confvmport"
            echo
            break
        else
            echo "输入错误，端口范围应为1-65535!"
        fi
    else
        echo "输入错误，端口范围应为1-65535!"
    fi
    done
    echo
    while true
    do
    echo "请输入宿主机的端口"
    [ -z "$natconfport" ] && read -p "(Default: Exit):" natconfport </dev/tty
    [ -z "$natconfport" ] && exit 1
    expr $natconfport + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ $natconfport -ge 1 ] && [ $natconfport -le 65535 ]; then
            echo
            echo "宿主机端口 = $natconfport"
            echo
            break
        else
            echo "输入错误，端口范围应为1-65535!"
        fi
    else
        echo "输入错误，端口范围应为1-65535!"
    fi
    done
    echo "请输入转发协议(tcp 或者 udp):"
    [ -z "$conftype" ] && read -p "(默认: tcp):" conftype </dev/tty
    [ -z "$conftype" ] && conftype="tcp"
    echo
    echo "协议类型 = $conftype"
    echo
    iptablesshell="iptables -t nat -A CUSTOM_RULES -i vmbr0 -p $conftype --dport $natconfport -j DNAT --to-destination $confvmip:$confvmport"
    if [ `grep -c "$iptablesshell" $iptablesconf` != '0' ]; then
        echo "配置已经存在"
        exit 1
    fi
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo
    echo "回车继续，Ctrl+C退出脚本"
    [[ $# -eq 1 ]] && char=`get_char`
    echo $iptablesshell >> $iptablesconf
    runreturn=`$iptablesshell`
    echo $runreturn
    echo '配置添加成功'
}
add_confs(){
    conf_add
}
del_conf(){
    echo
    while true
    do
    echo "请输入宿主机的端口"
    read -p "(默认操作: 退出):" confserverport </dev/tty
    [ -z "$confserverport" ] && exit 1
    expr $confserverport + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ $confserverport -ge 1 ] && [ $confserverport -le 65535 ]; then
           echo
           echo "宿主机端口 = $confserverport"
           echo
           break
        else
           echo "输入错误，端口范围应为1-65535!"
        fi
    else
        echo "输入错误，端口范围应为1-65535!"
    fi
    done
    echo
    iptablesshelldel=`cat $iptablesconf | grep "dport $confserverport"`
    if [ ! -n "$iptablesshelldel" ]; then
         echo "配置文件中没有该宿主机的端口"
         exit 1
    fi
    iptablesshelldelshell=`echo ${iptablesshelldel//-A/-D}`
    runreturn=`$iptablesshelldelshell`
    echo $runreturn
    sed -i "/$iptablesshelldel/d" $iptablesconf
    echo '配置删除成功'
}
del_confs(){
    printf "你确定要删除配置吗？操作是不可逆的(y/n) "
    printf "\n"
    read -p "(默认: n):" answer </dev/tty
    if [ -z $answer ]; then
       answer="n"
    fi
    if [ "$answer" = "y" ]; then
       del_conf
   else
       echo "配置删除操作取消"
   fi
}
refresh_confs(){
    iptables -t nat -D PREROUTING -j CUSTOM_RULES >/dev/null 2>&1;iptables -t nat -F CUSTOM_RULES >/dev/null 2>&1;iptables -t nat -X CUSTOM_RULES >/dev/null 2>&1
    iptables -t nat -N CUSTOM_RULES >/dev/null 2>&1;[[ $? == '0' ]] && { iptables -t nat -A PREROUTING -j CUSTOM_RULES;bash /root/.pvesetnatrc; }
}
    action=$1
    confvmip=$2
    confvmport=$3
    natconfport=$4
    conftype=$5
    case "$action" in
    add)
      add_confs
      ;;
    list)
      conf_list
      ;;
    del)
      del_confs
      ;;
    refresh)
      refresh_confs
      ;;
    *)
    echo "参数错误! [${action} ]"
    echo "用法: $0 {add|list|del|refresh}"
    ;;
    esac
EOFF
}
setupnetwork(){

  (
  set -e
  [ -f /etc/network/interfaces ] && [ ! -f /etc/network/interfaces.bak ] && cp /etc/network/interfaces /etc/network/interfaces.bak 
  [ -f /etc/network/interfaces ] && ! grep -q "auto vmbr0" /etc/network/interfaces && {
    ! grep -q "iface $DEFAULTNIC" /etc/network/interfaces && sed -i '$a\auto '"$DEFAULTNIC"'\niface '"$DEFAULTNIC"' inet manual' /etc/network/interfaces || {
      grep -q "iface $DEFAULTNIC inet dhcp" /etc/network/interfaces && sed -i '/^iface '"$DEFAULTNIC"'/c\iface '"$DEFAULTNIC"' inet manual' /etc/network/interfaces
      # sed -i use intermedia files too, so below awk inplace edit workarounds is not ugly at all
      grep -q "iface $DEFAULTNIC inet static" /etc/network/interfaces && awk -v pat="iface $DEFAULTNIC inet static" -v rep="iface $DEFAULTNIC inet manual" -v kw="gateway|netmask|address" -v n="3" '{if (found && count < n) {if ($0 ~ kw) {count++; next} else {found=0}} if ($0 == pat) {print rep; found=1; count=0; next} print}' /etc/network/interfaces > /etc/network/interfaces.tmp && mv /etc/network/interfaces.tmp /etc/network/interfaces
    }
  }
  [ -f /etc/network/interfaces ] && ! grep -q "auto vmbr0" /etc/network/interfaces && sed -i '$a\
\
# for additonal pubip to vms and the nat support\
auto vmbr0\
iface vmbr0 inet '"$([[ "$AutoNet" == '2' ]] && echo "dhcp";[[ "$AutoNet" == '1' ]] && echo -e "static\\
    address $IP\\
    netmask $MASK\\
    gateway $GATE")"'\
    bridge-ports '"$DEFAULTNIC"'\
    bridge-stp off\
    bridge-fd 0\
    #important for pbs to keep it stable not vary\
    post-up ip link set dev vmbr0 mtu 1500\
    #important for some ips restricts\
    post-up ip link set dev vmbr0 address \$(cat /sys/class/net/'"$DEFAULTNIC"'/address)\
    '"$([[ "$AutoNet" == '2' ]] && echo -e "# incase someos dont do lease even if with dhcp set\\
    post-up dhclient vmbr0")"'\
\
# for natip support to vms\
auto vmbr1\
iface vmbr1 inet static\
    address 10.10.10.254\
    netmask 255.255.255.0\
    bridge-ports none\
    bridge-stp off\
    bridge-fd 0\
    post-up   echo 1 > /proc/sys/net/ipv4/ip_forward\
    post-up   iptables -t nat -A POSTROUTING -s '\''10.10.10.0/24'\'' -o vmbr0 -j MASQUERADE\
    post-down iptables -t nat -D POSTROUTING -s '\''10.10.10.0/24'\'' -o vmbr0 -j MASQUERADE\
    #post-up   iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1\
    #post-down iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1\
    # use pvesetnat to add/list/del nat rules\
    post-up   bash /usr/bin/pvesetnat refresh' /etc/network/interfaces
  [ ! -f /root/.pvesetnatrc ] && tee -a /root/.pvesetnatrc > /dev/null <<EOF
#here goes nat logics for vms,we will make it pure text based someday
#the wrong settings here will make dns not functs,but network in good
EOF
  chmod +x /root/.pvesetnatrc
  [[ ! -f /usr/bin/pvesetnat ]] && tee -a /usr/bin/pvesetnat > /dev/null <<EOF
$pvesetnat
EOF
  chmod +x /usr/bin/pvesetnat
  /etc/init.d/networking restart >/dev/null 2>&1 || exit 1

  [ -f /etc/default/isc-dhcp-server ] && ! grep -q "INTERFACESv4=\"vmbr1\"" /etc/default/isc-dhcp-server && sed -i 's/INTERFACESv4=""/INTERFACESv4="vmbr1"/g' /etc/default/isc-dhcp-server
  [ -f /etc/dhcp/dhcpd.conf ] && ! grep -q "subnet 10.10.10.0" /etc/dhcp/dhcpd.conf && echo -e "subnet 10.10.10.0 netmask 255.255.255.0 {\noption routers 10.10.10.254;\noption subnet-mask 255.255.255.0;\noption domain-name-servers 8.8.8.8;\nrange 10.10.10.1 10.10.10.253;\n}" >> /etc/dhcp/dhcpd.conf
  update-rc.d -f isc-dhcp-server remove >/dev/null 2>&1;update-rc.d isc-dhcp-server defaults >/dev/null 2>&1
  /etc/init.d/isc-dhcp-server restart >/dev/null 2>&1 || exit 1
  ) 2> >(grep -Ev '^(Created symlink |Extracting templates from packages: |apparmor_parser:)' >&2) || exit 1

    echo -en "[ \033[32m network \033[0m ]"

}

# Check if the url is curlable
url_check() {
  http_status=$(curl -o /dev/null -sL -w "%{http_code}\n" "$1")
  if [ "$http_status" != 200 -a "$http_status" != 301 -a "$http_status" != 302 -a "$http_status" != 307 -a "$http_status" != 308 ]; then
    echo "url is not curlable,app missing?"
    exit
  fi
}

cfg_check() {
  resp_all=$(curl -sL -w "\n%{http_code}" "$1")
  http_code=$(tail -n1 <<< "$resp_all")
  if [ "$http_code" == 200 -o "$http_code" == 301 -o "$http_code" == 302 -o "$http_code" == 307 -o "$http_code" == 308 ]; then
    sed '$ d' <<< "$resp_all"
  fi
}

# This function collects user settings and integrates all the collected information.
build_container() {
#  if [ "$VERB" == "yes" ]; then set -x; fi

  if [ "$CT_TYPE" == "1" ]; then
    FEATURES="keyctl=1,nesting=1"
  else
    FEATURES="nesting=1"
  fi


  TEMP_DIR=$(mktemp -d)
  pushd $TEMP_DIR >/dev/null
  if [ "$var_os" == "alpine" ]; then
    export FUNCTIONS_FILE_PATH=""
    #export FUNCTIONS_FILE_PATH="$(curl -s https://raw.githubusercontent.com/minlearnminlearn/ProxmoxVE_fixed/main/misc/alpine-install.func.sh)"
  else
    export FUNCTIONS_FILE_PATH=""
    #export FUNCTIONS_FILE_PATH="$(curl -s https://raw.githubusercontent.com/minlearnminlearn/ProxmoxVE_fixed/main/misc/install.func.sh)"
  fi
  export CACHER="$APT_CACHER"
  export CACHER_IP="$APT_CACHER_IP"
  export tz="$timezone"
  export DISABLEIPV6="$DISABLEIP6"
  export APPLICATION="$APP"
  export app="$NSAPP"
  export PASSWORD="$PW"
  export VERBOSE="$VERB"
  export SSH_ROOT="${SSH}"
  export CTID="$CT_ID"
  export CTTYPE="$CT_TYPE"
  export PCT_OSTYPE="$var_os"
  export PCT_OSVERSION="$var_version"
  export PCT_DISK_SIZE="$DISK_SIZE"
  export PCT_OPTIONS="
    -features $FEATURES
    -hostname $HN
    $SD
    $NS
    -net0 name=eth0,bridge=$BRG$MAC,ip=$NET$GATE$VLAN$MTU
    -onboot 1
    -cores $CORE_COUNT
    -memory $RAM_SIZE
    -unprivileged $CT_TYPE
    $PW
  "
  # This executes create_lxc.sh and creates the container and .conf file
  # bash -c "$(wget -qLO - https://raw.githubusercontent.com/minlearnminlearn/ProxmoxVE_fixed/main/misc/create_lxc.sh)" || exit


  ########################################################

# create_lxc.sh
# This checks for the presence of valid Container Storage and Template Storage locations
#echo "Validating Storage"
VALIDCT=$(pvesm status -content rootdir | awk 'NR>1')
if [ -z "$VALIDCT" ]; then
  echo "Unable to detect a valid Container Storage location."
  exit 1
fi
VALIDTMP=$(pvesm status -content vztmpl | awk 'NR>1')
if [ -z "$VALIDTMP" ]; then
  echo "Unable to detect a valid Template Storage location."
  exit 1
fi

# This function is used to select the storage class and determine the corresponding storage content type and label.
function select_storage() {
  local CLASS=$1
  local CONTENT
  local CONTENT_LABEL
  case $CLASS in
  container)
    CONTENT='rootdir'
    CONTENT_LABEL='Container'
    ;;
  template)
    CONTENT='vztmpl'
    CONTENT_LABEL='Container template'
    ;;
  *) false || exit "Invalid storage class." ;;
  esac
  
  # This Queries all storage locations
  local -a MENU
  while read -r line; do
    local TAG=$(echo $line | awk '{print $1}')
    local TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    local FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
    local ITEM="  Type: $TYPE Free: $FREE "
    local OFFSET=2
    if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
      local MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
    fi
    MENU+=("$TAG" "$ITEM" "OFF")
  done < <(pvesm status -content $CONTENT | awk 'NR>1')
  
  # Select storage location
  if [ $((${#MENU[@]}/3)) -eq 1 ]; then
    printf ${MENU[0]}
  else
    local STORAGE
    while [ -z "${STORAGE:+x}" ]; do
      STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool you would like to use for the ${CONTENT_LABEL,,}?\nTo make a selection, use the Spacebar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${MENU[@]}" 3>&1 1>&2 2>&3) || exit "Menu aborted."
    done
    printf $STORAGE
  fi
}

# Test if required variables are set
[[ "${CTID:-}" ]] || exit "You need to set 'CTID' variable."
[[ "${PCT_OSTYPE:-}" ]] || exit "You need to set 'PCT_OSTYPE' variable."

# Test if ID is valid
#[ "$CTID" -ge "100" ] || exit "ID cannot be less than 100."

# Test if ID is in use
if pct status $CTID &>/dev/null; then
  echo -e "ID '$CTID' is already in use."
  unset CTID
  exit "Cannot use ID that is already in use."
fi

# Get template storage
TEMPLATE_STORAGE=$(select_storage template) || exit
#echo "Using ${BL}$TEMPLATE_STORAGE${CL} ${GN}for Template Storage."

# Get container storage
CONTAINER_STORAGE=$(select_storage container) || exit
#echo "Using ${BL}$CONTAINER_STORAGE${CL} ${GN}for Container Storage."

<<'BLOCK'

# Update LXC template list
echo "Updating LXC Template List"
pveam update >/dev/null
echo "Updated LXC Template List"

# Get LXC template string
TEMPLATE_SEARCH=${PCT_OSTYPE}-${PCT_OSVERSION:-}
mapfile -t TEMPLATES < <(pveam available -section system | sed -n "s/.*\($TEMPLATE_SEARCH.*\)/\1/p" | sort -t - -k 2 -V)
[ ${#TEMPLATES[@]} -gt 0 ] || exit "Unable to find a template when searching for '$TEMPLATE_SEARCH'."
TEMPLATE="${TEMPLATES[-1]}"

# Download LXC template if needed
if ! pveam list $TEMPLATE_STORAGE | grep -q $TEMPLATE; then
  echo "Downloading LXC Template"
  pveam download $TEMPLATE_STORAGE $TEMPLATE >/dev/null ||
    exit "A problem occured while downloading the LXC template."
  echo "Downloaded LXC Template"
fi

BLOCK

[[ "$tmpTARGETMODE" == '9' && "$tmpTARGET" != '' ]] && {
  docker_name="$(echo $tmpTARGET | sed 's/\//-/g' | sed 's/:/-/g')"
  config_file="/var/lib/lxc/$docker_name/config"
  output_file="/var/lib/lxc/$docker_name/rootfs/oci-config"
  TEMPLATE="${docker_name}$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).tar.xz";
  [[ ! -f /var/lib/vz/template/cache/${TEMPLATE} ]] && {
    echo "Making LXC Template: $TEMPLATE"
    if [ ! -d "/var/lib/lxc/$docker_name" ]; then
      # global fix
      if [ -f "/usr/share/lxc/templates/lxc-oci" ]; then sed -i 's/set -eu/set -u/g' /usr/share/lxc/templates/lxc-oci; fi
      # create dummy
      lxc-create -q -n $docker_name -t oci -- -u docker://docker.io/$tmpTARGET || { exit 1 && echo "lxc-create $docker_name failed"; }
      # process config
      if [ ! -d "/var/lib/lxc/$docker_name/rootfs" ]; then mkdir -p "/var/lib/lxc/$docker_name/rootfs"; fi
      execute_cmd=$(grep "^lxc.execute.cmd" "$config_file" | awk -F"'" '{print $2}' | tr -d '"')
      if [ -n "$execute_cmd" ]; then echo "lxc.init.cmd = $execute_cmd" | grep -v "=$" | grep -v "= $" >> "$output_file"; fi
      grep "^lxc.mount.auto" "$config_file" | grep -v "=$" | grep -v "= $" >> "$output_file"
      grep "^lxc.environment" "$config_file" | grep -v "=$" | grep -v "= $" >> "$output_file"
      grep "^lxc.uts.name" "$config_file" | grep -v "=$" | grep -v "= $" >> "$output_file"
      if [[ $tmpTARGET == *"redroid"* ]]; then
        echo "lxc.mount.entry = /dev/fuse dev/fuse none bind,create=file" >> "$output_file"
        echo "lxc.apparmor.profile = unconfined" >> "$output_file"
        echo "lxc.autodev = 1" >> "$output_file"
        echo "lxc.autodev.tmpfs.size = 25000000" >> "$output_file"

        modprobe binder_linux devices=$(seq -s, -f 'binder%g' 1 32)
        chmod 666 /dev/binder*

      fi
      #package
      # --exclude=vendor/bin/ipconfigstore??
      XZ_OPT=-e tar -C /var/lib/lxc/$docker_name/rootfs/ -cpJf "/var/lib/vz/template/cache/$TEMPLATE" --exclude=dev --exclude=sys --exclude=proc ./ || { exit 1 && echo "package $TEMPLATE failed"; }
      #clean
      lxc-destroy -q -n "$docker_name" || { echo "destroy $docker_name failed, manually del it"; }
    fi
    #echo "Template made"
  }
}

[[ "$tmpTARGETMODE" == '10' && "$tmpTARGET" != '' ]] && TEMPLATE="lxcdebtpl$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).tar.xz"

echo -e "${DGN}Using LXC Template: ${BGN}$TEMPLATE${CL}"

# Combine all options
DEFAULT_PCT_OPTIONS=(
  -arch $(dpkg --print-architecture))

PCT_OPTIONS=(${PCT_OPTIONS[@]:-${DEFAULT_PCT_OPTIONS[@]}})
[[ " ${PCT_OPTIONS[@]} " =~ " -rootfs " ]] || PCT_OPTIONS+=(-rootfs $CONTAINER_STORAGE:${PCT_DISK_SIZE:-8})

# Create container
echo "Creating LXC Container"
pct create $CTID ${TEMPLATE_STORAGE}:vztmpl/${TEMPLATE} ${PCT_OPTIONS[@]} >/dev/null ||
  exit "A problem occured while trying to create container."
#echo "LXC Container ${BL}$CTID${CL} ${GN}was successfully created."

########################################################


  LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
  
  if [ "$CT_TYPE" == "0" ]; then
    cat <<EOF >>$LXC_CONFIG
# USB passthrough
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/serial/by-id  dev/serial/by-id  none bind,optional,create=dir
lxc.mount.entry: /dev/ttyUSB0       dev/ttyUSB0       none bind,optional,create=file
lxc.mount.entry: /dev/ttyUSB1       dev/ttyUSB1       none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM0       dev/ttyACM0       none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM1       dev/ttyACM1       none bind,optional,create=file
# tun
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net dev/net none bind,create=dir
# VAAPI hardware transcoding
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.cgroup2.devices.allow: c 29:0 rwm
lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
# kvm
lxc.cgroup2.devices.allow: c 10:232 rwm
# loop
lxc.cgroup2.devices.allow: b 7:* rwm
lxc.cgroup2.devices.allow: c 10:237 rwm
lxc.mount.entry: /dev/loop0 dev/loop0 none bind,create=file 0 0
lxc.mount.entry: /dev/loop1 dev/loop1 none bind,create=file 0 0
lxc.mount.entry: /dev/loop2 dev/loop2 none bind,create=file 0 0
lxc.mount.entry: /dev/loop3 dev/loop3 none bind,create=file 0 0
lxc.mount.entry: /dev/loop4 dev/loop4 none bind,create=file 0 0
lxc.mount.entry: /dev/loop5 dev/loop5 none bind,create=file 0 0
lxc.mount.entry: /dev/loop6 dev/loop6 none bind,create=file 0 0
lxc.mount.entry: /dev/loop-control dev/loop-control none bind,create=file 0 0
EOF
#   else
#     if [[ -e "/dev/dri/renderD128" ]]; then
#       if [[ -e "/dev/dri/card0" ]]; then
#         cat <<EOF >>$LXC_CONFIG
# # VAAPI hardware transcoding
# dev0: /dev/dri/card0,gid=44
# dev1: /dev/dri/renderD128,gid=104
# EOF
#       else
#         cat <<EOF >>$LXC_CONFIG
# # VAAPI hardware transcoding
# dev0: /dev/dri/card1,gid=44
# dev1: /dev/dri/renderD128,gid=104
# EOF
#       fi
#     fi
  fi
  if [[ "$tmpTARGETMODE" == '9' && $tmpTARGET == *"redroid"* ]]; then
    echo '# binder' >>$LXC_CONFIG
    # 获取所有已分配 binder 编号
    assigned=$(
    for CTID in $(pct list | awk '$3 ~ /redroid/ {print $1}'); do
      pct config $CTID | grep 'lxc.mount.entry:.*binder' | sed -n 's/.*\/dev\/binder\([0-9]\+\).*/\1/p'
    done
    )

    # 找未分配的号
    unused=()
    for n in {1..32}; do
      if ! echo "$assigned" | grep -wq "$n"; then
        unused+=("$n")
      fi
      if [ "${#unused[@]}" -eq 3 ]; then
        break
      fi
    done

    # 如果至少有三个号可分配，写入
    if [ "${#unused[@]}" -eq 3 ]; then
      cat <<EOF >>$LXC_CONFIG
lxc.mount.entry: /dev/binder${unused[0]} dev/binder none bind,create=file 0 0
lxc.mount.entry: /dev/binder${unused[1]} dev/hwbinder none bind,create=file 0 0
lxc.mount.entry: /dev/binder${unused[2]} dev/vndbinder none bind,create=file 0 0
EOF
    else
      echo -e " 🖧  not enough binder devies"
      exit 1
    fi
  fi

  # also url_check it? no, it is not neccsary, sould check if cfg conents were empty if url_check return true
  cfg_check "${REPO}/${APP}/${APP}.conf" | sed '/unprivileged:.*/d;/defport:.*/d;/defsize:.*/d;/defram:.*/d;/defcore:.*/d' >>$LXC_CONFIG

}

buildinstfuncs(){
  # This function sets up the Container OS by generating the locale, setting the timezone, and checking the network connection
  IFS='' read -r -d '' setting_up_container <<"EOFF"
  echo "Setting up Container OS"
  if [[ -f "/etc/locale.gen" && -n "$LANG" ]]; then
  sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
  locale_line=$(grep -v '^#' /etc/locale.gen | grep -E '^[a-zA-Z]' | awk '{print $1}' | head -n 1)
  echo "LANG=${locale_line}" >/etc/default/locale
  locale-gen >/dev/null
  fi
  export LANG=${locale_line}
  echo $tz >/etc/timezone
  ln -sf /usr/share/zoneinfo/$tz /etc/localtime
  for ((i = 5; i > 0; i--)); do
    if [ "$(hostname -I)" != "" ]; then
      break
    fi
    #echo 1>&2 -en "${CROSS}${RD} No Network! "
    sleep 3
    if ((i == 1)); then
      echo 1>&2 -e "\n${CROSS}${RD} No Network After 5 Tries${CL}"
      echo -e " 🖧  Check Network Settings"
      exit 1
    fi
  done
  rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED
  #systemctl disable -q --now systemd-networkd-wait-online.service
  #echo "Set up Container OS"
  echo "Network Connected: ${BL}$(hostname -I)"
EOFF

  # This function checks the network connection by pinging a known IP address and prompts the user to continue if the internet is not connected
  IFS='' read -r -d '' network_check <<"EOFF"
  set +e
  trap - ERR
  ipv4_connected=false
  ipv6_connected=false
  sleep 1
  # Check IPv4 connectivity
  if ping -c 1 -W 1 1.1.1.1 &>/dev/null; then 
    #echo "IPv4 Internet Connected";
    ipv4_connected=true
  else
    echo "IPv4 Internet Not Connected";
  fi

  # Check IPv6 connectivity
  if ping6 -c 1 -W 1 2606:4700:4700::1111 &>/dev/null; then
    #echo "IPv6 Internet Connected";
    ipv6_connected=true
  else
    echo "IPv6 Internet Not Connected";
  fi

  # If both IPv4 and IPv6 checks fail, prompt the user
  if [[ $ipv4_connected == false && $ipv6_connected == false ]]; then
    read -r -p "No Internet detected,would you like to continue anyway? <y/N> " prompt2 </dev/tty
    if [[ "${prompt2,,}" =~ ^(y|yes)$ ]]; then
      echo -e " ⚠️  ${RD}Expect Issues Without Internet${CL}"
    else
      echo -e " 🖧  Check Network Settings"
      exit 1
    fi
  fi

  RESOLVEDIP=$(getent hosts github.com | awk '{ print $1 }')
  if [[ -z "$RESOLVEDIP" ]]; then echo "DNS Lookup Failure"; else echo "DNS Resolved github.com to ${BL}$RESOLVEDIP${CL}"; fi
  set -e
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
EOFF

  # This function updates the Container OS by running apt-get update and upgrade
  IFS='' read -r -d '' update_os <<"EOFF"
  silent() { "$@" >/dev/null 2>&1; }
  echo "Updating Container OS"
  if [[ "$CACHER" == "yes" ]]; then
    echo "Acquire::http::Proxy-Auto-Detect \"/usr/local/bin/apt-proxy-detect.sh\";" >/etc/apt/apt.conf.d/00aptproxy
    cat <<EOF >/usr/local/bin/apt-proxy-detect.sh
#!/bin/bash
if nc -w1 -z "${CACHER_IP}" 3142; then
  echo -n "http://${CACHER_IP}:3142"
else
  echo -n "DIRECT"
fi
EOF
  chmod +x /usr/local/bin/apt-proxy-detect.sh
  fi
   silent apt-get update
   silent apt-get -o Dpkg::Options::="--force-confold" -y dist-upgrade
  rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED
  #echo "Updated Container OS"
EOFF

  # This function modifies the message of the day (motd) and SSH settings
  IFS='' read -r -d '' motd_ssh <<"EOFF"
  echo "export TERM='xterm-256color'" >>/root/.bashrc
  echo -e "$APPLICATION LXC provided by https://appp.st/\n" >/etc/motd
  chmod -x /etc/update-motd.d/*
  if [[ "${SSH_ROOT}" == "yes" ]]; then
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
    systemctl restart sshd
  fi
EOFF

  # This function customizes the container by modifying the getty service and enabling auto-login for the root user
  IFS='' read -r -d '' customize <<"EOFF"
  if [[ "$PASSWORD" == "" ]]; then
    echo "Customizing Container"
    GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
    mkdir -p $(dirname $GETTY_OVERRIDE)
    cat <<EOF >$GETTY_OVERRIDE
  [Service]
  ExecStart=
  ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF
    systemctl daemon-reload
    systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')
    #echo "Customized Container"
  fi
  echo "bash -c \"\$(wget -qLO - https://github.com/minlearnminlearn/ProxmoxVE_fixed/raw/main/${app}.sh)\"" >/usr/bin/update
  chmod +x /usr/bin/update
  # in case fail and wont goon
  exit 0
EOFF
}



# . p/999.utils/build2.sh

# =================================================================
# Below are main routes
# =================================================================

[[ $tmpTARGETMODE != 1 && $forcemaintainmode == 1 ]] && { echo -e "\033[31m\n维护,脚本无限期闭源或开放，请联系作者\nThe script was invalid in maintaince mode with a undetermined closed/reopen date,please contact the author\n \033[0m"; exit 1; }

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
    echo -n "target needed, type a target to go, or any -option to continue: ";trap 'printf \\e[33m' DEBUG;trap 'printf \\e[0m' EXIT;read -p "" NN </dev/tty;trap 'printf \\e[0m' DEBUG
    case $NN in
      -m) read -p "Enter your own FORCEDEBMIRROR directlink (or type to use inbuilt: `echo -e "\033[33mgithub,gitea\033[0m"`): " FORCEDEBMIRROR </dev/tty;[[ "$FORCEDEBMIRROR" == 'github' ]] && FORCEDEBMIRROR=$autoDEBMIRROR0;[[ "$FORCEDEBMIRROR" == 'gitea' ]] && FORCEDEBMIRROR=$autoDEBMIRROR1 ;;
      -i) read -p "Enter your own FORCE1STNICNAME (format: `echo -e "\033[33mensp0\033[0m"`): " FORCE1STNICNAME </dev/tty ;;
      -n) read -p "Enter your own FORCENETCFGSTR (format: `echo -e "\033[33m10.211.55.2/24,10.211.55.1\033[0m"`): " FORCENETCFGSTR </dev/tty;[[ -n "$FORCENETCFGSTR" ]] && [[ `echo "$FORCENETCFGSTR" | grep -Eo ":"` != '' ]] && FORCENETCFGV6ONLY=1 ;;
      -6) FORCENETCFGV6ONLY=1;echo "FORCENETCFGV6ONLY set to `echo -e "\033[33m1\033[0m"` " ;;
      -p) read -p "Enter your own FORCE1STHDNAME (format: `echo -e "\033[33mnvme0p1\033[0m"`): " FORCE1STHDNAME </dev/tty ;;
      -w) read -p "Enter your own FORCEPASSWORD (format: `echo -e "\033[33mmypass\033[0m"`): " FORCEPASSWORD </dev/tty ;;
      -o) read -p "Enter your own FORCEINSTCTL (format: `echo -e "\033[33m1=doexpanddisk|2=noinjectnetcfg|3=noreboot|4=nopreclean\033[0m"`): " FORCEINSTCTL </dev/tty ;;
      -d) tmpDEBUG=1;echo "tmpDEBUG set to `echo -e "\033[33m1\033[0m"` ";[[ "$tmpDEBUG" == '1' ]] && [[ "$tmpTARGETMODE" != '1' ]] && tmpINSTWITHMANUAL='1' && FORCEINSTCTL_ARR+=('3' '4') ;;
      -t|*) [[ ${NN} == '-t' ]] && { mapfile -t -s 0 myarr < <(wget --no-check-certificate -qO- https://minlearn.org/inst |grep -Eo '<tbody>.*</tbody>' |sed -e 's#</td></tr><tr><td#</td></tr>\n<tr><td#g' -e "s#<tbody>\|</tbody>\|<tr>\|</td>\|</tr>##g"  |awk -v var1="$([[ $tmpHOSTARCH != '1' ]] && echo amd || echo arm)64" -v var2="$([[ $tmpBUILDGENE != '2' ]] && echo BIOS || echo UEFI)" -F "<td align=\"center\">" '{if ($5==var1 && $6~var2) print $8}'|grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*");read -p "Enter a target name/idx or bringyourown directlink (inbuilt: `echo -e "\033[33mdebian|devdesk|dummy\033[0m"` 3rd: `[[ -n myarr ]] && { i=0;while [ $i -lt ${#myarr[@]} ];do echo -ne "\033[33m[\`expr $i \+ 1\`]${myarr[$i]##*/} \033[0m";((i++));done; }`): " tmpTARGET0 </dev/tty; } || tmpTARGET0=$NN;[[ ${tmpTARGET0:0:1} != '/' ]] && { tmpTARGET=$tmpTARGET0; } || { [[ "$autoDEBMIRROR0" =~ "/inst/raw/master" ]] || { IMGMIRROR0=${autoDEBMIRROR0}"/.." && tmpTARGET00=$tmpTARGET0 && tmpTARGET=`echo "$tmpTARGET00" |sed "s#^#$IMGMIRROR0#g"`; }; };[[ "$tmpTARGET0" == "debianct" || "$tmpTARGET0" == "devdeskct" ]] && tmpTARGETMODE='4';[[ "$FORCE1STHDNAME" != '' && "$tmpTARGET0" == "devdeskde" ]] && echo "cant set -p when target is devdeskde" && exit 1;[[ "$tmpTARGET0" == "devdeskde" ]] && tmpTARGETMODE='4';[[ "$tmpTARGET0" == "devdesk" ]] && tmpTARGET="devdeskos";[[ "$tmpTARGET0" == "dummy" ]] && tmpTARGETMODE='0' && tmpTARGET='dummy' && tmpINSTWITHMANUAL='1';[[ $tmpTARGET0 =~ ^-?[0-9]+$ ]] && { tmpTARGET=${myarr[tmpTARGET0-1]#*]}; };echo "$tmpTARGET0" |grep -q '^http://\|^ftp://\|^https://';[[ $? -eq '0' ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && tmpTARGETMODE=0;echo "$tmpTARGET0" |grep -q '^10000:/dev/';[[ $? -eq '0' ]] && tmpTARGETMODE=2;echo "$tmpTARGET0" |grep -q '^http://.*:10000';[[ $? -eq '0' ]] && tmpTARGETMODE=0 ;;
    esac;
  done

}

[[ "$(uname)" == "Darwin" ]] && tmpBUILD='1' && echo "osx detected"
[[ -f /cygdrive/c/cygwin64/bin/uname && ( "$(/cygdrive/c/cygwin64/bin/uname -o)" == "Cygwin" || "$(/cygdrive/c/cygwin64/bin/uname -o)" == "Msys") ]] && tmpBUILD='11' && echo "windows detected"
[[ ! $(mount) =~ ^/dev/(sd|vd|nvme|xvd) ]] && [[ ! $(ls /boot 2>/dev/null) =~ grub ]] && [[ "$tmpBUILD" != '1' && "$tmpBUILD" != '11' ]] && { tmpDEBUG=2 && echo "3rd rescue env detected"; }
[[ "$(arch)" == "aarch64" ]] && echo Arm64 detected,will force arch as 1 && tmpHOSTARCH='1'
[[ -d /sys/firmware/efi ]] && echo uefi detected,will force gen as 2 && tmpBUILDGENE='2'
[[ "$tmpBUILD" != "1" && "$tmpBUILD" != "11" ]] && { DEFAULTWORKINGNIC2="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')"; [[ -z "$DEFAULTWORKINGNIC2" ]] && { DEFAULTWORKINGNIC2="$(ip -6 -brief route show default |head -n1 |grep -o 'dev .*'|sed 's/proto.*\|onlink.*\|metric.*//g' |awk '{print $NF}')"; }; DEFAULTWORKINGIPSUBV42="$(ip addr |grep ''${DEFAULTWORKINGNIC2}'' |grep 'global' |grep 'brd\|' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";DEFAULTWORKINGGATEV42="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";DEFAULTWORKINGIPSUBV62="$(ip -6 -brief address show scope global|grep ''${DEFAULTWORKINGNIC2}'' |awk -F ' ' '{ print $3}')";DEFAULTWORKINGGATEV62="$(ip -6 -brief route show default|grep ''${DEFAULTWORKINGNIC2}'' |awk -F ' ' '{ print $3}')"; [[ -n "$DEFAULTWORKINGIPSUBV42" && -n "$DEFAULTWORKINGGATEV42" ]] || { [[ -n "$DEFAULTWORKINGIPSUBV62" && -n "$DEFAULTWORKINGGATEV62" ]] && echo "IPV6 only detected,will force FORCENETCFGV6ONLY to 1" && FORCENETCFGV6ONLY=1; }; };
[[ "$tmpBUILD" == "11" ]] && { DEFAULTWORKINGNICIDX2="$(netsh int ipv4 show route | grep --text -F '0.0.0.0/0' | awk '$6 ~ /\./ {print $5}')";[[ -z "$DEFAULTWORKINGNICIDX2" ]] && { DEFAULTWORKINGNICIDX2="$(netsh int ipv6 show route | grep --text -F '::/0' | awk '$6 ~ /:/ {print $5}')"; };[[ -n "$DEFAULTWORKINGNICIDX2" ]] && { for i in `echo "$DEFAULTWORKINGNICIDX2"|sed 's/\ /\n/g'`; do if grep -q '=$' <<< `wmic nicconfig where "InterfaceIndex='$i'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1`; then :; else DEFAULTWORKINGNICIDX2=$i;fi;done;  }; [[ -n "$DEFAULTWORKINGNICIDX2" ]] && DEFAULTWORKINGIPARR1=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX2'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`; DEFAULTWORKINGGATEARR1=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX2'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f1)`; [[ -n "$DEFAULTWORKINGNICIDX2" ]] && DEFAULTWORKINGIPARR2=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX2'" get IPAddress /format:list|sed 's/\r//g'|sed 's/IPAddress={//g'|sed 's/\("\|}\)//g'|cut -d',' -f2)`; DEFAULTWORKINGGATEARR2=`echo $(wmic nicconfig where "InterfaceIndex='$DEFAULTWORKINGNICIDX2'"  get DefaultIPGateway /format:list|sed 's/\r//g'|sed 's/DefaultIPGateway={//g'|sed 's/\("\|}\)//g'|cut -d',' -f2)`; [[ `echo $DEFAULTWORKINGIPARR1|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR1|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR2|grep -Eo ":"` && `echo $DEFAULTWORKINGIPARR2|grep -Eo ":"` ]] && echo "IPV6 only detected,will force FORCENETCFGV6ONLY to 1" && FORCENETCFGV6ONLY=1; };
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
      [[ "$FORCEDEBMIRROR" == 'github' ]] && FORCEDEBMIRROR=$autoDEBMIRROR0;[[ "$FORCEDEBMIRROR" == 'gitea' ]] && FORCEDEBMIRROR=$autoDEBMIRROR1
      [[ -n "$FORCEDEBMIRROR" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Mirror forced to some value,will override autoselectdebmirror results"
      shift
      ;;
    -p|--force1sthdname)
      shift
      FORCE1STHDNAME="$1"
      [[ "$tmpTARGET" == 'devdeskde' ]] && echo "cant set -p when target is devdeskde" && exit 1;
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
      IFS=',' read -ra arr <<< "$1"
      for v in "${arr[@]}"; do
        FORCEINSTCTL_ARR+=("$v")
      done
      shift
      ;;
    --cmd)
      shift
      FORCEINSTCMD="$1"
      [[ -n "$FORCEINSTCMD" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "instcmd forced to some value,will force instctl (assum cmdstr were single quoted)"
      shift
      ;;
    -b|--build)
      shift
      tmpBUILD="$1"
      #[[ "$tmpBUILD" == '2' ]] && echo "LXC given,will auto inform tmpBUILDADDONS as 1,this is not by customs" && tmpBUILDADDONS='1' && tmpTARGETMODE='1' && echo -en "\n" && [[ -z "$tmpBUILDADDONS" ]] && echo "buildci were empty" && exit 1
      #[[ "$tmpBUILD" != '2' ]] && tmpBUILDADDONS='0' && tmpTARGETMODE='1'
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
    -t|--target)
      shift
      tmpTARGET="$1"
      case $tmpTARGET in
        '') echo "Target not given,will exit" && exit 1 ;;
        dummy) echo "dummy given,will try debugmode" && tmpTARGETMODE='0' && tmpINSTWITHMANUAL='1' ;;
        debianbase) tmpTARGETMODE='1' ;;
        onekeydevdesk*) tmpTARGETMODE='1' && tmpTARGET='onekeydevdesk'
        [[ "$1" =~ 'onekeydevdesk,' ]] && {
          for tgt in `[[ "$tmpBUILD" -ne '0' ]] && echo "${1##onekeydevdesk}" |sed 's/,/\n/g' || echo "${1##onekeydevdesk}" |sed 's/,/\'$'\n''/g'`
          do
          [[ $tgt =~ "++" ]] && { PACKCONTAINERS+=",""${tgt##++}";GENCONTAINERS+=",""${tgt##++}"; } || { [[ $tgt =~ "+" ]] && { GENCONTAINERS+=",""${tgt##+}"; } || { PACKCONTAINERS+=",""${tgt}"; }; }
          done
          echo -n "onekeydevdesk Fullgen mode detected,with pack addons:""$PACKCONTAINERS" |sed 's/,/ /g' && echo " and migrate addons:""$GENCONTAINERS" |sed 's/,/ /g'
        } ;;
        deb|debian*) 
          [[ "$1" == 'deb' ]] && tmpTARGET='debian' && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "deb given,will force debootstrap instmode and debian target(defaultly 11)"
          [[ "$1" == 'debian' ]] && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "debian given,will force debootstrap instmode and debian target(defaultly 11)"
          [[ "$1" =~ ^debian(10|11|12)$ ]] && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "debian ver given,will force debootstrap instmode and specified debian target"
          [[ "$1" =~ ^debian(10|11|12)?:[^:]+$ ]] && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "debian w/wo ver + debmirror given,will force debootstrap instmode using the specified debmirror and specified debian target"
          [[ "$1" =~ ^debian[^:0-9]+$ ]] && tmpTARGETMODE='10' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "app name given, will force appinst mode" ;;
        debian10r) tmpTARGETMODE='0' ;;
        devdesk*) 
        [[ "$tmpTARGET" == 'devdesk' ]] && { tmpTARGETMODE='10' && echo "devdesk given,will force install pve only (without app)"; } || {
        echo -e "\033[31mother devdesk variable target was temply deprecated, for now, you can use -t appname or -t devdesk instead to install a embeded devdesk!\033[0m" && exit 1
        [[ "$tmpTARGET" == 'devdeskct' ]] && { tmpTARGETMODE='4' && echo "devdeskct given,will force inplace instmode and devdeskos ct images(based on virttech)"; }
        [[ "$tmpTARGET" == 'devdeskde' ]] && { [[ "$FORCE1STHDNAME" != '' ]] && echo "cant set -p when target is devdeskde" && exit 1;tmpTARGETMODE='4' && FORCE1STHDNAME='localfile' && echo "devdeskde given,will force inplace instmode and localfile -p"; }
        [[ "$tmpTARGET" != 'devdeskct' && "$tmpTARGET" != 'devdeskde' ]] && { [[ ! ("$tmpTARGET" =~ 'devdeskos') ]] && tmpTARGET=${1/devdesk/devdeskos}

          [[ "$tmpTARGET" == 'devdeskos' ]] && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Devdeskos Wgetdd instonly mode detected"
          #[[ "${tmpTARGET:0:9}" == "devdeskos" && "${#tmpTARGET}" -gt '9' ]] && tmpTARGETMODE='0' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Devdeskos specialedition Wgetdd instonly mode detected"
          #[[ "$tmpTARGET" == 'devdeskos' ]] && tmpTARGETMODE='1' && echo "Fullgen mode detected"
          #[[ "$tmpHOST" != '2' && "$tmpTARGET" == 'devdeskos' ]] && tmpTARGETMODE=1 || tmpTARGETMODE='0' ;;
        }; } ;;

        /*) [[ "$autoDEBMIRROR0" =~ "/inst/raw/master" ]] || { IMGMIRROR0=${autoDEBMIRROR0}"/.." && tmpTARGET0=$tmpTARGET && tmpTARGET=`echo "$tmpTARGET0" |sed "s#^#$IMGMIRROR0#g"`; }; tmpTARGETMODE='0' ;;
        *) echo "$tmpTARGET" |grep -q '^http://\|^ftp://\|^https://\|^10000:/dev/\|^/dev/\|^./';[[ $? -ne '0' ]] && {
          echo "$tmpTARGET" | grep -q '[[:alnum:]]\+\/[[:alnum:]]\+:[[:alnum:]]\+\|[[:alnum:]]\+\/[[:alnum:]]\+'; [[ $? -eq '0' ]] && {
            echo "$tmpTARGET" | grep -q '[[:alnum:]]\+\/[[:alnum:]]\+:[[:alnum:]]\+'; [[ $? -eq '0' ]] && echo "docker oci app (with tag) were given" && tmpTARGETMODE=9;
            echo "$tmpTARGET" | grep -q '^[[:alnum:]]\+\/[[:alnum:]]\+$'; [[ $? -eq '0' ]] && echo "docker oci app (without tag) were given" && tmpTARGET=${tmpTARGET}:latest; tmpTARGETMODE=9;
          } || { echo "app name given, will force appinst mode" && tmpTARGETMODE=10; }
        } || {
          echo "$tmpTARGET" |grep -q '^http://\|^ftp://\|^https://';[[ $? -eq '0' ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "(trans) Raw urls detected,will override autotargetddurl results and force wgetdd instmode" && tmpTARGETMODE=0;
          # if -t were given as port:blkdevname,then enter nc servermode(rever,target)
          # if -t were given as port:ip:blkdevname,then enter nc clientmode(sender,src)
          echo "$tmpTARGET" |grep -q '^10000:/dev/';[[ $? -eq '0' ]] && echo "Port:blkdevname detected,will force nchttpsrv resmode" && tmpTARGETMODE=2;
          echo "$tmpTARGET" |grep -q '^http://.*:10000';[[ $? -eq '0' ]] && echo "Http:Port detected,will force nctarget+instmode" && tmpTARGETMODE=0; 
          echo "$tmpTARGET" |grep -q '^./.*';[[ $? -eq '0' ]] && echo "local target img detected,will force localmode" && tmpTARGETMODE=5; } ;;
      esac
      shift
      ;;
    -d|--debug)
      shift
      tmpDEBUG="$1"
      [[ "$tmpTARGET" == '' ]]  && tmpTARGET='dummy' && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "no target given, will force target as dummy"
      [[ ("$tmpDEBUG" == '1' || "$tmpDEBUG" == '' || "$tmpDEBUG" =~ 'vnc:' || "$tmpDEBUG" =~ '22:' ) && "$tmpTARGETMODE" != '1' ]] && {
        [[ "$tmpDEBUG" == '1' || "$tmpDEBUG" == '' ]] && tmpINSTWITHMANUAL='1' && FORCEINSTCTL_ARR+=('3' '4') && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Debug supports enabled in instmode,will force hold before reboot, and force reboot if lost in 5 mins in trying ssh";
        [[ "$tmpDEBUG" =~ 'vnc:' ]] && tmpINSTVNCPORT=`echo ${tmpDEBUG##vnc:}` && echo "force custom vnc port";
        [[ "$tmpDEBUG" =~ '22:' ]] && tmpINSTWITHBORE=`echo ${tmpDEBUG##22:}` && tmpINSTWITHMANUAL='1' && FORCEINSTCTL_ARR+=('3' '4') && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "Debug supports enabled in instmode,will force hold before reboot, and force reboot if lost in 5 mins in trying ssh, and enable bore";
      }
      [[ ("$tmpDEBUG" == '1' || "$tmpDEBUG" == '') && "$tmpTARGETMODE" == '1' ]] && tmpBUILDINSTTEST='1' && tmpINSTWITHMANUAL='1' && echo "Debug supports enabled in buildmode,will keep hold before go on, and localinstant boot test"
      [[ ("$tmpDEBUG" == '2' && "$tmpDEBUG" != '') && "$tmpTARGETMODE" != '1' ]] && echo -n "3rd rescue env given" && { [[ $(mount) =~ ^/dev/(sd|vd|nvme|xvd) ]] || [[ $(ls /boot 2>/dev/null) =~ grub ]] || [[ "$tmpBUILD" == '1' || "$tmpBUILD" == '11' ]] && echo ",but no rescue env detected,still forced"; }
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
    -h|--help|*)
      if [[ "$1" != 'error' ]]; then echo -ne "\nInvaild option: '$1'\n\n"; fi
      echo -ne "Usage(args are self explained):\n\t-m/--forcemirror\n\t-n/--forcenetcfgstr\n\t-b/--build\n\t-t/--target\n\t-s/--serial\n\t-g/--gene\n\t-a/--arch\n\t-d/--debug\n\n"
      exit 1;
      ;;
    esac
  done
  FORCEINSTCTL=$(IFS=,; echo "${FORCEINSTCTL_ARR[*]}")
  [[ -n "$FORCEINSTCTL" ]] && [[ $tmpTARGETMODE != 1 && $forcemaintainmode != 1 ]] && echo "instctl forced to some value,will force instctl (and post process)"


#echo -en "\n\033[36m # Checking Prerequisites: \033[0m"

printf "\n ✔ %-30s" "Checking deps ......"
if [[ "$tmpTARGET" == 'debianbase' && "$tmpTARGETMODE" == '1' ]]; then
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,xzcat,zcat,md5sum,sha1sum,sha256sum,grub-reboot;
elif [[ ( "$tmpTARGET" == 'debianct' || "$tmpTARGET" == 'devdeskct' ) && "$tmpTARGETMODE" == '4' && "$tmpBUILD" != '1' ]] ; then
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,xzcat,zcat,rsync,virt-what;
elif [[ "$tmpTARGET" == 'devdeskde' && "$tmpTARGETMODE" == '4' && "$tmpBUILD" != '1' ]] ; then
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,fdisk,xzcat,zcat;
elif [[ "$tmpTARGET" != '' && "$tmpTARGETMODE" == '9' ]]; then
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,fdisk,xzcat,zcat,qemu-img,skopeo,umoci,jq;
elif [[ "$tmpTARGET" != '' && "$tmpTARGETMODE" == '10' ]]; then
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,fdisk,xzcat,zcat,qemu-img;
else
  CheckDependence sudo,wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,fdisk,xzcat,zcat,df,openssl;
fi

[[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" != 'devdeskde' ]] && printf "\n ✔ %-30s" "Checking virttech ......"
[[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" != 'devdeskde' ]] && {
  [[ "$tmpCTVIRTTECH" == '1' ]] && echo -en "[ \033[32m force,lxc \033[0m ]";
  [[ "$tmpCTVIRTTECH" == '2' ]] && echo -en "[ \033[32m force,kvm \033[0m ]";
  [[ "$tmpCTVIRTTECH" != '1' && ( "$(virt-what|head -n1)" == "lxc" || "$(virt-what|head -n1)" == "openvz" ) ]] && tmpCTVIRTTECH='1' && echo -en "[ \033[32m auto,lxc \033[0m ]";
  [[ "$tmpCTVIRTTECH" != '2' && "$(virt-what|head -n1)" == "kvm" ]] && tmpCTVIRTTECH='2' && echo -en "[ \033[32m auto,kvm \033[0m ]";
  [[ "$tmpCTVIRTTECH" == '0' ]] && [[ "$tmpCTVIRTTECH" != '1' && "$tmpCTVIRTTECH" != '2' ]] && echo "fail,no virttech detected,will exit" && exit 1;
}

[[ ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) && "$tmpTARGET" != '' ]] && {
  printf "\n ✔ %-30s" "Checking pveinst ......"
  if command -v pveversion >/dev/null 2>&1 && pveversion >/dev/null 2>&1 && ! pveversion >/dev/null 2>&1| grep -Eq "pve-manager/7.[1-9]"; then { tmpPVEREADY='1' && echo -en "[ \033[32m ready \033[0m ]"; }; else echo -en "[ \033[32m n/a, to install \033[0m ]"; fi
}

printf "\n ✔ %-30s" "Selecting Mirror/Targets ..." 

if [[ "$tmpTARGETMODE" == '0' || "$tmpTARGETMODE" == '2' || "$tmpTARGETMODE" == '4' || ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) ]]; then
  AUTODEBMIRROR=`echo -e $(SelectDEBMirror $autoDEBMIRROR0 $autoDEBMIRROR1)|sort -n -k 2 | head -n2 | grep http | sed  -e 's#[[:space:]].*##'`
  [[ -n "$AUTODEBMIRROR" && -z "$FORCEDEBMIRROR" ]] && DEBMIRROR=$AUTODEBMIRROR && echo -en "[ \033[32m auto,${DEBMIRROR} \033[0m ]"  # || exit 1
  [[ -n "$AUTODEBMIRROR" && -n "$FORCEDEBMIRROR" ]] && DEBMIRROR=$FORCEDEBMIRROR && echo -en "[ \033[32m force,${DEBMIRROR} \033[0m ]"  # || exit 1
  [[ -z "$AUTODEBMIRROR" && -n "$FORCEDEBMIRROR" ]] && DEBMIRROR=$FORCEDEBMIRROR && echo -en "[ \033[32m force,${DEBMIRROR} \033[0m ]"  # || exit 1
  [[ -z "$AUTODEBMIRROR" && -z "$FORCEDEBMIRROR" ]] && DEBMIRROR=$autoDEBMIRROR1 && echo -en "[ \033[32m failover,${DEBMIRROR} \033[0m ]"  # || exit 1
else
  # force to main github
  DEBMIRROR=$autoDEBMIRROR0 && echo -en "[ \033[32m force,${DEBMIRROR} \033[0m ]"
fi

# get external debianmirror, default policy, just simple enough to spin up
[[ "$DEBMIRROR" =~ "github" ]] && {
  EXTDEBMIRROR="http://deb.debian.org/debian"
} || {
  EXTDEBMIRROR="http://mirrors.ustc.edu.cn/debian"
}

# check targeturl
case $tmpTARGET in
  # no need to check,targeturl is debmirror url
  '') echo "Target not given,will exit" && exit 1 ;;  
  dummy) TARGETDDURL='' ;;
  deb|debian*) TARGETDEBNAME=`echo "$tmpTARGET" | awk -F ':' '{ print $2}'` # ${IMGMIRROR/xxxxxx/upmirror}
    # no check targeturl, just define debver
    DEBVER=`echo "$tmpTARGET" | grep -oP '(?<=debian)\d+' || echo 11`
    if [[ ! "$DEBVER" =~ ^[0-9]+$ || "$DEBVER" -gt 12 || "$DEBVER" -lt 10 ]]; then echo "bad debver" && exit; fi
    TARGETDDURL=$(
      case "$TARGETDEBNAME" in
        ustc*)   echo "http://mirrors.ustc.edu.cn/debian" ;;
        *)        [[ "$DEBVER" == '10' ]] && echo "https://snapshot.debian.org/archive/debian/20231007T024024Z" || echo "$EXTDEBMIRROR" ;;
      esac
    ) ;;
  devdeskos*) [[ "$DEBMIRROR" =~ "/raw/master" ]] && { ifgap="${DEBMIRROR#*inst}";ifgap="${ifgap%raw\/master*}";ifgap="${ifgap//\//}";[[ -z "$ifgap" ]] && IMGMIRROR=${DEBMIRROR/\/inst\/raw\/master/}"/xxxxxx/raw/master" || IMGMIRROR=${DEBMIRROR/\/inst\/$ifgap\/raw\/master/}"/xxxxxx/$ifgap/raw/master"; } || IMGMIRROR=${DEBMIRROR/\/inst/}"/xxxxxx";TARGETDDURL=${IMGMIRROR/xxxxxx/1kdd}"/_build/devdeskos/binary$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n -arm64 || echo -n -amd64)/tarball"
    CheckTargeturl $TARGETDDURL"/onekeydevdeskd-01core$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz_000.chunk" ;;
  debian10r) TARGETDDURL=${IMGMIRROR/xxxxxx/1keyddhubfree-$tmpTARGET}"/"$tmpTARGET"estore/binary$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -arm64 || echo -amd64)/"$tmpTARGET"estore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz"
    [[ "$tmpTARGETMODE" == '0' ]] && CheckTargeturl $TARGETDDURL"_000" ;;
  debianct) TARGETDDURL=${IMGMIRROR/xxxxxx/1keyddhubfree-debtpl}/"$([ "$tmpCTVIRTTECH" == '1' -a "$tmpCTVIRTTECH" != '' ]  && echo lxcdebtpl || echo qemudebtpl)"/binary"$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -arm64 || echo -amd64)"/tarball/"$([ "$tmpCTVIRTTECH" == '1' -a "$tmpCTVIRTTECH" != '' ]  && echo lxcdebtpl || echo qemudebtpl)""$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).tar.xz"
    [[ "$tmpTARGETMODE" == '4' ]] && CheckTargeturl $TARGETDDURL"_000" ;;
  devdeskct|devdeskde) [[ "$DEBMIRROR" =~ "/raw/master" ]] && { ifgap="${DEBMIRROR#*inst}";ifgap="${ifgap%raw\/master*}";ifgap="${ifgap//\//}";[[ -z "$ifgap" ]] && IMGMIRROR=${DEBMIRROR/\/inst\/raw\/master/}"/xxxxxx/raw/master" || IMGMIRROR=${DEBMIRROR/\/inst\/$ifgap\/raw\/master/}"/xxxxxx/$ifgap/raw/master"; } || IMGMIRROR=${DEBMIRROR/\/inst/}"/xxxxxx";TARGETDDURL=${IMGMIRROR/xxxxxx/1kdd}"/_build/devdeskos/binary$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n -arm64 || echo -n -amd64)/tarball"
    [[ "$tmpTARGETMODE" == '4' ]] && CheckTargeturl $TARGETDDURL"/clientcore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz_000" ;;
  /*|./*|*) [[ "$tmpTARGETMODE" == '5' ]] && { ABSOLUTE_PATH=$(readlink -f "$tmpTARGET");DIR_NAME=$(dirname "$ABSOLUTE_PATH");MOUNT_POINT=$(df "$tmpTARGET" | grep -v Filesystem | awk '{print $6}');[ -z "$MOUNT_POINT" ] && exit;TARGETDDURL=${DIR_NAME#$MOUNT_POINT};UNZIP="$([[ ${tmpTARGET##*.} == 'gz' ]] && echo 1;[[ ${tmpTARGET##*.} == 'xz' ]] && echo 2)"; }
    [[ "$tmpTARGETMODE" == '0' && "$tmpTARGET" == *.iso ]] && TARGETDDURL=$tmpTARGET && CheckTargeturl $TARGETDDURL
    # wedont check "$tmpTARGETMODE" == '1,2,5'
    [[ "$tmpTARGETMODE" != '1' && "$tmpTARGETMODE" != '2' && "$tmpTARGETMODE" != '5' && "$tmpTARGET" != *.iso ]] && TARGETDDURL=$tmpTARGET && CheckTargeturl $TARGETDDURL ;;
esac

# get github/gitee/gitea/custom release rooturl
# gap: /-/
[[ "$DEBMIRROR" =~ "/raw/master" ]] && {
  ifgap="${DEBMIRROR#*inst}"
  ifgap="${ifgap%raw\/master*}"
  ifgap="${ifgap//\//}"
  [[ -z "$ifgap" ]] && RLSMIRROR=${DEBMIRROR/\/raw\/master/}"/releases/download/inital" || RLSMIRROR=${DEBMIRROR/\/$ifgap\/raw\/master/}"/releases/download/inital"
} || {
  RLSMIRROR=${DEBMIRROR}"/_build/releases/download/inital"
}

sleep 2


#echo -en "\n\033[36m # Parse and gather infos before remastering: \033[0m"

# lsattr and cont delete,then you shoud restart
umount --force $remasteringdir/initramfs/{dev/pts,dev,proc,sys} $remasteringdir/initramfs_arm64/{dev/pts,dev,proc,sys} >/dev/null 2>&1
umount --force $remasteringdir/onekeydevdeskd/01-core/{dev/pts,dev,proc,sys} $remasteringdir/onekeydevdeskd_arm64/01-core/{dev/pts,dev,proc,sys} >/dev/null 2>&1

# for inplacedd
#deepumount

# we should also umount the top mounted dir here after umount chrootsubdir?
# xxx

[[ -d $remasteringdir ]] && rm -rf $remasteringdir;

mkdir -p $remasteringdir/initramfs/files/usr/bin $remasteringdir/initramfs_arm64/files/usr/bin $remasteringdir/onekeydevdeskd/01-core $remasteringdir/onekeydevdeskd_arm64/01-core $remasteringdir/x
mkdir -p $remasteringdir/epve $remasteringdir/epve_arm64

[[ "$tmpTARGET" != 'debianbase' ]] && parsenetcfg
[[ "$tmpTARGET" != 'debianbase' && "$tmpTARGETMODE" != '9' && "$tmpTARGETMODE" != '10' ]] && parsediskcfg
trap 'echo; echo "- aborting by user, restore dns"; restoreall dnsonly;exit 1' SIGINT

[[ "$tmpTARGETMODE" != '9' && "$tmpTARGETMODE" != '10' ]] && preparepreseed
[[ "$tmpTARGETMODE" != '4' && "$tmpTARGETMODE" != '9' && "$tmpTARGETMODE" != '10' ]] && patchpreseed

#echo -en "\n\033[36m # Remastering all up... \033[0m"

# under GENMODE we reuse the downdir,but not for INSTMODE
[[ "$tmpTARGETMODE" != '1' ]] && [[ -d $downdir ]] && rm -rf $downdir;
mkdir -p $downdir/debianbase

[[ ( "$tmpTARGETMODE" != '1' && "$tmpTARGETMODE" != '5' ) || "$tmpTARGETMODE" == '4' ]] || [[ ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) && "$tmpTARGET" != '' && "$tmpPVEREADY" != '1' ]] && getbasics down
[[ "$tmpTARGETMODE" == '1' ]] && { [[ -d $topdir/../upmirror ]] && getbasics copy || getbasics down; }
#printf "\n ✔ %-30s" "Get optional/necessary deb pkg files to build a debianbase ...... "
#[[ "$tmpBUILD" != '1' && "$tmpTARGET" == 'debianbase' ]] && getoptpkgs libc,common,wgetssl,extendhd,ddprogress || echo -en "[ \033[32m not debianbase,skipping!! \033[0m ]"
#printf "\n ✔ %-30s" "Get full debs pkg files to build a debianbase: ..... "
#[[ "$tmpBUILD" != '1' && "$tmpTARGET" == 'debianbase' ]] && getfullpkgs || echo -en "[ \033[32m not debianbase,skipping!! \033[0m ]"
[[ "$tmpTARGETMODE" != '9' && "$tmpTARGETMODE" != '10' ]] || [[ ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) && "$tmpTARGET" != '' && "$tmpPVEREADY" != '1' ]] && processbasics

[[ ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) && "$tmpTARGET" != '' && "$tmpPVEREADY" != '1' ]] && {

  sleep 2 && printf "\n ✔ %-30s" "Busy installing epveall ......"

  [ -f /etc/modules-load.d/pve.conf ] && grep -vE '^\s*#|^\s*$' /etc/modules-load.d/pve.conf|while read line; do modprobe $line; done
  installdeps
  buildsetupfuns
  setupnetwork

  tar -xJf $downdir/debianbase/epvecore$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).xz -C / --no-overwrite-dir --keep-directory-symlink
  cp $downdir/debianbase/lxcdebtpl$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo _arm64).tar.xz /var/lib/vz/template/cache

  [[ -z "$tmpTGTNICIP" ]] && echo "nicip not given,will exit" && exit
  # without value other than 127.0.1.1,the criu cant get localhost ip,so we set it to 111.111.111.111 here
  if grep -q "[[:space:]]$(hostname)[[:space:]]*\($\|\s\)" /etc/hosts; then
    sed -i "/[[:space:]]$(hostname)[[:space:]]*\($\|\s\)/{
        /^[[:space:]]*$tmpTGTNICIP[[:space:]]\+$(hostname)/! s/^.*[[:space:]]\+$(hostname)/$tmpTGTNICIP $(hostname)/
    }" /etc/hosts
  else
    echo "$tmpTGTNICIP $(hostname)" >> /etc/hosts
  fi

  update-rc.d -f lxc remove >/dev/null 2>&1;update-rc.d lxc defaults >/dev/null 2>&1
  /etc/init.d/lxc start >/dev/null 2>&1
  update-rc.d -f pvedaemon remove >/dev/null 2>&1;update-rc.d pvedaemon defaults >/dev/null 2>&1
  /etc/init.d/pvedaemon start >/dev/null 2>&1

  if command -v pveversion >/dev/null 2>&1 && pveversion >/dev/null 2>&1 && ! pveversion >/dev/null 2>&1| grep -Eq "pve-manager/7.[1-9]"; then tmpPVEREADY='1'; else { echo sth error; exit 1; }; fi

  echo -en "[ \033[32m done. \033[0m ]"
}

# we also offer a efi here
mkdir -p $remasteringdir/boot # $remasteringdir/boot/grub/i386-pc $remasteringdir/boot/EFI/boot/x86_64-efi

[[ "$tmpDRYRUNREMASTER" == '0' ]] && [[ "$tmpTARGETMODE" == '0' || "$tmpTARGETMODE" == '1' || "$tmpTARGETMODE" == '2' || "$tmpTARGETMODE" == '4' || "$tmpTARGETMODE" == '5' ]] && {



  sleep 2 && printf "\n ✔ %-30s" "Busy Remastering/mutating .."

  [[ "$tmpTARGETMODE" != '0' && "$tmpTARGETMODE" != '4'  ]] && cp -f $remasteringdir/initramfs/preseed.cfg $remasteringdir/initramfs/files/preseed.cfg
  [[ "$tmpTARGETMODE" != '0' && "$tmpTARGETMODE" != '4'  ]] && cp -f $remasteringdir/initramfs_arm64/preseed.cfg $remasteringdir/initramfs_arm64/files/preseed.cfg

  if [[ "$tmpTARGETMODE" == '0' || "$tmpTARGETMODE" == '2' || "$tmpTARGETMODE" == '5' ]]; then

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


  [[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" != 'devdeskde' ]] && inplacemutating
  [[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'devdeskde' ]] && ddtoafile

  # finally showing a hint
  echo -en "[ \033[32m done. \033[0m ]"

}

# for devdesk without app, below is not needed
[[ "$tmpDRYRUNREMASTER" == '0' ]] && [[ ( "$tmpTARGETMODE" == '9' || "$tmpTARGETMODE" == '10' ) && "$tmpTARGET" != '' && "$tmpTARGET" != 'devdesk' && "$tmpPVEREADY" == '1' ]] && {
  sleep 2 && printf "\n ✔ %-30s" "Busy installing app ......"

  [[ "$tmpTARGETMODE" == '9' && "$tmpTARGET" != '' ]] && APP=$(echo $tmpTARGET | sed 's/\//-/g' | sed 's/:/-/g') || APP=$tmpTARGET
  DEF_PORT=""
  var_disk="8"
  var_cpu="1"
  var_ram="1024"
  var_os="debian"
  var_version="11"

  NSAPP=$(echo ${APP,,} | tr -d ' ') # This function sets the NSAPP variable by converting the value of the APP variable to lowercase and removing any spaces.
  REPO=${DEBMIRROR}/_build/apps
  
  [[ "$tmpTARGETMODE" == '10' && "$tmpTARGET" != '' ]] && url_check "${REPO}/${APP}/${APP}_install.sh"

  NEXTID=$(pvesh get /cluster/nextid)
  timezone=$(cat /etc/timezone)

  #header_info

  # default_settings
  [[ "$tmpTARGETMODE" == '9' && "$tmpTARGET" != '' ]] && CT_TYPE="0" || CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr1"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"

  #echo_default
  echo
  echo
  echo -e "${DGN}Using Container Type: ${BGN}$CT_TYPE${CL}"
  echo -e "${DGN}Using Container ID: ${BGN}$NEXTID${CL}"

  # ifoverride_cfgvars
  # give a chance to override cfg_vars with online .conf file
  # will dedude cfg_vars from finally appending to .conf
  if [[ "$tmpTARGETMODE" == '10' && "$tmpTARGET" != '' ]]; then
  # also url_check it? no, it is not neccsary, sould check if cfg conents were empty if url_check return true
  while read line; do
    # dont use cfg_check | while read line, cause pipeline wont return the ct_type we need
    if [[ "$line" =~ "unprivileged:" ]]; then echo CT_TYPE=$(echo "$line" | tr -d ' ' | sed 's/.*unprivileged://g');CT_TYPE=$(echo "$line" | tr -d ' ' | sed 's/.*unprivileged://g'); fi
    if [[ "$line" =~ "defport:" ]]; then echo DEF_PORT=$(echo "$line" | tr -d ' ' | sed 's/.*defport://g');DEF_PORT=$(echo "$line" | tr -d ' ' | sed 's/.*defport://g'); fi
    if [[ "$line" =~ "defsize:" ]]; then echo DISK_SIZE=$(echo "$line" | tr -d ' ' | sed 's/.*defsize://g');DISK_SIZE=$(echo "$line" | tr -d ' ' | sed 's/.*defsize://g'); fi
    if [[ "$line" =~ "defram:" ]]; then echo RAM_SIZE=$(echo "$line" | tr -d ' ' | sed 's/.*defram://g');RAM_SIZE=$(echo "$line" | tr -d ' ' | sed 's/.*defram://g'); fi
    if [[ "$line" =~ "defcore:" ]]; then echo CORE_COUNT=$(echo "$line" | tr -d ' ' | sed 's/.*defcore://g');CORE_COUNT=$(echo "$line" | tr -d ' ' | sed 's/.*defcore://g'); fi
  done < <(cfg_check "${REPO}/${APP}/${APP}.conf")
  fi

  build_container
  buildinstfuncs
  buildsetupfuns

  [[ ! -z "$CTID" ]] && {
    # This starts the container and executes <app>-install.sh
    echo "Starting LXC Container"
    pct start "$CTID"
    #echo "Started LXC Container"

    [[ "$tmpTARGETMODE" == '10' && "$tmpTARGET" != '' ]] && {
      #verb_ip6
      lxc-attach -n "$CTID" -- bash -c "$setting_up_container" || exit
      lxc-attach -n "$CTID" -- bash -c "$network_check" || exit
      #lxc-attach -n "$CTID" -- bash -c "$update_os" || exit
      lxc-attach -n "$CTID" -- bash -c "$motd_ssh" || exit
      lxc-attach -n "$CTID" -- bash -c "$customize" || exit
      lxc-attach -n "$CTID" -- bash -c "$(wget -qLO - ${REPO}/${APP}/${APP}_install.sh)" -- "${EXTDEBMIRROR}" "${RLSMIRROR}" || exit
    }

  }

  IP=$(pct exec "$CTID" ip a s dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
  # Set Description in LXC
  pct set "$CTID" -description "Thanks for Proxmox VE Helper Scripts"

  echo -e "Completed Successfully!\n"
  echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}${DEF_PORT:+:$DEF_PORT}${CL} \n"


  #set a outbound port
  read -r -p "Enable Outbound port? <y/N> " prompt </dev/tty
  if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
    if [ ! -z "$DEF_PORT" ]; then bash -c "$pvesetnat" -- add ${IP} ${DEF_PORT}; else bash -c "$pvesetnat" -- add ${IP}; fi
  else
    exit
  fi

  #[[ ! -f /usr/bin/pveinstapp ]] && tee -a /usr/bin/pveinstapp > /dev/null <<EOF $setting_up_container $network_check $update_os $motd_ssh $customize EOF
  #chmod +x /usr/bin/pveinstapp
}

#echo -en "\n\033[36m # Finishing... \033[0m"

# rewind the $(pwd)
cd $topdir/$targetdir # && CWD="$(pwd)" && echo -en "[ \033[32m cd to ${CWD##*/} \033[0m ]"

[[ "$tmpDEBUG" != "2" ]] && [[ "$tmpTARGETMODE" != "1" ]] && [[ "$tmpTARGETMODE" != '4' ]] && [[ "$tmpTARGETMODE" != '5' ]] && [[ "$tmpTARGETMODE" != '9' && "$tmpTARGETMODE" != '10' ]] && {
  printf "\n ✔ %-30s" "Copying vmlinuz ......" && [[ "$tmpBUILD" != "1" ]] && { [[ -d $instto ]] && cp -f $topdir/$downdir/debianbase/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64) $instto/vmlinuz_1kddinst && echo -en "[ \033[32m done. \033[0m ]" || exit 1; } || { cp -f $topdir/$downdir/debianbase/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64) $topdir/$remasteringdir/boot/vmlinuz_1kddinst && echo -en "[ \033[32m done. \033[0m ]" || exit 1; }
  sleep 2 && printf "\n ✔ %-30s" "Copying initrfs ......" && [[ "$tmpBUILD" != "1" ]] && { [[ -d $instto ]] && cp -f $topdir/$downdir/debianbase/initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).img $instto/initrfs_1kddinst.img && echo -en "[ \033[32m done. \033[0m ]" || exit 1; } || { cp -f $topdir/$downdir/debianbase/initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).img $topdir/$remasteringdir/boot/initrfs_1kddinst.img && echo -en "[ \033[32m done. \033[0m ]" || exit 1; }
  # sleep 2 && printf "\n ✔ %-30s" "Packaging initrfs ....." && [[ "$tmpBUILD" != '1' ]] && { ( cd $topdir/$remasteringdir/initramfs/files; find . | cpio -H newc --create --quiet | gzip -9 > $instto/initrfs_1kddinst.img ) && echo -en "[ \033[32m done. \033[0m ]"; } || { ( cd $topdir/$remasteringdir/initramfs/files; find . | cpio -o --format newc -z > $topdir/$remasteringdir/boot/initrfs_1kddinst.img )  >/dev/null 2>&1 && echo -en "[ \033[32m done. \033[0m ]"; }
  # find . -print | cpio -o -H newc --quiet | xz -f --extreme --check=crc32 > xxx
}

[[ "$tmpTARGETMODE" == '5' ]] && {
  printf "\n ✔ %-30s" "Copying vmlinuz ......" && { [[ -d $instto ]] && cat $topdir/_build/debianbase/dists/bullseye/main-debian-installer/$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n binary-arm64 || echo -n binary-amd64)/tarball/vmlinuz$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64)_* > $instto/vmlinuz_1kddinst && echo -en "[ \033[32m done. \033[0m ]"; }
  sleep 2 && printf "\n ✔ %-30s" "Copying initrfs ......" && { [[ -d $instto ]] && cat $topdir/_build/debianbase/dists/bullseye/main-debian-installer/$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n binary-arm64 || echo -n binary-amd64)/tarball/initrfs$([ "$tmpHOSTARCH" == '1' -a "$tmpHOSTARCH" != '' ]  && echo -n _arm64).img_* > $instto/initrfs_1kddinst.img && echo -en "[ \033[32m done. \033[0m ]"; }
}

# if insttest then directly reboot here



#rm -rf $remasteringdir/initramfs;
curl --max-time 5 --silent --output /dev/null https://counter.minlearn.org/{dsrkafuu:demo}&add={1}

[[ "$tmpDEBUG" != "2" ]] && [[ "$tmpTARGETMODE" != '1' || "$tmpBUILDINSTTEST" == '1' ]] && [[ "$tmpBUILD" != '1' && "$tmpBUILD" != "11" ]] && [[ "$tmpTARGETMODE" != '4' ]] && [[ "$tmpTARGETMODE" != '9' && "$tmpTARGETMODE" != '10' ]] && {

  chown root:root $GRUBDIR/$GRUBFILE
  chmod 444 $GRUBDIR/$GRUBFILE
  printf "\n ✔ %-30s" "Prepare grub-reboot for $REBOOTNO ... " && { [[ -f /usr/sbin/grub-reboot ]] && sudo grub-reboot $REBOOTNO >/dev/null 2>&1;[[ -f /usr/sbin/grub2-reboot ]] && sudo grub2-reboot $REBOOTNO >/dev/null 2>&1;[[ ! -f /usr/sbin/grub-reboot && ! -f /usr/sbin/grub2-reboot ]] && echo grub-reboot or grub2-reboot not found && exit 1; }
  # Automatically remove DISK on sigint，note,we should put it in the right place to let it would occur
  trap 'echo; echo "- aborting by user, restoreall"; restoreall;exit 1' SIGINT

  printf "\n ✔ %-30s" "Preparation done! `echo -n \" wait till auto reboot after 20s,or ctlc to interrupt \"`......"
  echo;echo -en "[ \033[32m after reboot, it will enter online $( [[ "$tmpTARGETMODE" == '0' ]] && echo install;[[ "$tmpTARGETMODE" == '2' ]] && echo restore) mode: "
  printf "\n %-20s" "`echo -en \" \033[32m if netcfg valid,open and refresh http://$( [[ "$FORCENETCFGV6ONLY" != '1' ]] && echo publicIPv4ofthisserver:80 || echo [publicIPv6ofthisserver:80]) for novncview\033[0m $([[ "$tmpINSTWITHMANUAL" != '1' ]] && echo ])  \"`"
  [[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" == '' ]] && printf "\n %-20s" "`echo -en \" \033[32m if netcfg valid,connected to sshd@publicIPofthisserver:22 without passwords\033[0m \"`"
  [[ "$tmpINSTWITHMANUAL" == '1' && "$tmpINSTWITHBORE" != '' ]] && printf "\n %-20s" "`echo -en \" \033[32m if netcfg valid,connected to sshd@publicIPofthisserver:22 or boresrvip:22 without passwords\033[0m \"`"
  [[ "$tmpINSTWITHMANUAL" == '1' ]] && printf "\n %-20s" "`echo -en \" \033[32m if netcfg unvalid,the system will roll to normal current running os after 5 mins\033[0m \033[0m ] \"`"

  echo;for time in `seq -w 20 -1 0`;do echo -n -e "\b\b$time";sleep 1;done;sudo reboot -f >/dev/null 2>&1;
}

[[ "$tmpBUILD" == "11" ]] && [[ "$tmpTARGETMODE" != "1" ]] && {
  printf "\n ✔ %-30s" "Prepare reboot ... " && { GRUBID=`bcdedit /enum ACTIVE|sed 's/\r//g'|tail -n4|head -n 1|awk -F ' ' '{ print $2}'`;bcdedit /bootsequence $GRUBID /addfirst; }
  trap 'echo; echo "- aborting by user, restoreall"; restoreall;exit 1' SIGINT
  printf "\n ✔ %-30s" "Preparation done! `echo -n \" wait till auto reboot after 20s,or ctlc to interrupt \"`......"
  echo;for time in `seq -w 20 -1 0`;do echo -n -e "\b\b$time";sleep 1;done;shutdown -t 0 -r -f >/dev/null 2>&1;
}

[[ "$tmpBUILD" == "1" ]] && [[ "$tmpTARGETMODE" != "1" ]] && {
  [[ ! -d /Volumes/EFI ]] && sudo diskutil mount /dev/disk0s1
  [[ ! -d /Volumes/EFI ]] && echo efipartiation cloudnt be mount !! && exit 1
  printf "\n ✔ %-30s" "Prepare reboot ... " && { sudo grub-mkstandalone -o /Volumes/EFI/out.efi -O x86_64-efi /vmlinuz_1kddinst=$topdir/$remasteringdir/boot/vmlinuz_1kddinst /initrfs_1kddinst.img=$topdir/$remasteringdir/boot/initrfs_1kddinst.img /boot/grub/grub.cfg=$topdir/$remasteringdir/boot/grub.new;sudo bless --mount /Volumes/EFI --setBoot --file /Volumes/EFI/out.efi --shortform; }
  trap 'echo; echo "- aborting by user, restoreall"; restoreall;exit 1' SIGINT
  printf "\n ✔ %-30s" "Preparation done! `echo -n \" wait till auto reboot after 20s,or ctlc to interrupt \"`......"
  echo;for time in `seq -w 20 -1 0`;do echo -n -e "\b\b$time";sleep 1;done;sudo reboot -f >/dev/null 2>&1;
}

[[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" != 'devdeskde' ]] && {


  printf "\n ✔ %-30s" "Preparation done! `echo -n \" press anykey to reboot, your sys are replaced \"`......"
  read -n1 </dev/tty
  sudo reboot -f >/dev/null 2>&1;

}

[[ "$tmpTARGETMODE" == '4' && "$tmpTARGET" == 'devdeskde' ]] && {

   
  # Automatically remove DISK on exit
  trap 'echo; echo "- Ejecting tmpdev disk(linux)"; \
  umount "$tmpMNT"_p2 "$tmpMNT"_p3 "$tmpMNT"_p4 "$tmpMNT"_p5 && losetup -d "$tmpDEV" && rm -rf "$tmpMNT"_p2 "$tmpMNT"_p3 "$tmpMNT"_p4 "$tmpMNT"_p5' EXIT


  # Automatically remove DISK on sigint，note,we should put it in the right place to let it would occur
  trap 'echo; echo "- aborting by user"; exit 1' SIGINT

  printf "\n ✔ %-30s" "Preparation done! `echo -n \" press anykey to esc,your sys are produced \"`"
  read -n1 </dev/tty
  exit

}

[[ "$tmpDEBUG" == "2" ]] && {

  eval "$rescuecommandstring"

  printf "\n ✔ %-30s" "Preparation done! `echo -n \" manually reboot,your sys are produced \"`"
  read -n1 </dev/tty
  exit
}



