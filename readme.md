[演示与特性](#演示与特性) | [下载安装及用法](#下载安装及用法) | [服务及支持](#服务及支持)

inst: 省事一键DD重装/恢复和打包🚀🚀🎉🎉
=====

inst是一套可在线一键安装os的脚本和os最小核心，及一套完整的dd方案。   

 * 作为在线安装脚本部分，基于debianinstaller,inst.sh可将你的日用linux变成可一键安装和dump的linux版本。    
 * 作为最小核心部分，基于livelinux,inst.sh可将你的日用linux接入liverecovery,并变成liverun的linux版本。    

> inst也是一整套完整的dd方案：比如它还包含构建部分，备份部分,etc ..

项目地址：[https://github.com/minlearn/inst](https://github.com/minlearn/inst)

演示与特性✨
-----

inst.sh支持linux/windows/osx三平台和多目标,支持双架构amd,arm(arm windows为目标的安装不支持)双网栈ipv4,ipv6，支持自建源,支持多种在线安装方式(nativedi,wgetdd,liveuntar,nc restore,inplace dd)及丰富的可调试信息，双进度显示(vnc,web)，支持自扩硬盘和智能嵌入静态ip参数(包括/32这样的特殊掩码支持)，支持免d坏模式，可达成90%的linux成功率,80%的other os成功率  

![](https://github.com/minlearn/minlearnprogramming/raw/master/_build/assets/inst.png)

inst支持一键dd其它多种os，如，支持win uefi/bios gpt二合一兼容，无视机型差别和无须手动，毫无修改毫无感知地以同一效果运行（安装演示：[https://www.bilibili.com/video/BV17B4y1b79Y/](https://www.bilibili.com/video/BV17B4y1b79Y/) ）,支持dsm直接安装在云主机上，dsm无须嵌套虚拟化支持>2T硬盘作为启动硬盘（安装演示：[https://www.bilibili.com/video/BV1ug411N7tn/](https://www.bilibili.com/video/BV1ug411N7tn/) ）,支持osx使用标准全套kvm驱动和bios机型配置，需要安装在支持嵌套虚拟化的2C2G以上云主机上（1c1.5g/2c2g给osx, 2c2g/3c3g给osx母鸡留1c1g最好），与本地组matedesk，win11类同。不做说明的情况下，上述镜像均为脚本内置镜像，第三方gz镜像并不提供开放托管和安装。  

inst支持扩展，包括az,servarica,oracle/oracle arm,ksle,bwg10g512m,及接入无限增加的机型和系统：   
更多演示和特性请看和项目文档库[《https://inst.sh》](https://minlearn.org/inst/)



下载安装及用法📄
-----

> 注：以下尽量在debian系linux云主机或本地虚拟机下完成,rh系centos/rocky/alma不推荐  

基本用法:  

 * 简单前端交互模式  
`wget -qO- inst.sh | bash`   

 * 恢复模式,指定安装目标os镜像：debian是原生方式安装的纯净debian,dummy是空目标仅供调试模式用,自定义镜像是dd方式安装的raw系统硬盘格式经过gzip/xz打包后托管的http/https地址（安装演示：[https://www.bilibili.com/video/BV17B4y1b79Y/](https://www.bilibili.com/video/BV17B4y1b79Y/) ），或者qcow2格式的cloudimage托管的http/https地址（安装演示：[https://www.bilibili.com/video/BV1HSndezEaq/](https://www.bilibili.com/video/BV1HSndezEaq/) ）  
`wget -qO- inst.sh | bash -s - -t debian,dummy,或自定gz/xz/qcow2镜像`  

> 脚本运行后会重启进入dd过程，进入后，如有网络直接访问ip:80，会看到vnc进度，如果要进一步查看问题访问ip:8000。如无网络5分钟后会重启,并进入DD前的正常系统。免破坏系统。
> 目标os安装后，会自动扩展磁盘空间和调整网络,```linux用户名为root密码为inst.sh```，windows保留原包密码。 
> [《这里收集了一些第三方dd镜像仓库》](https://minlearn.org/inst/instrepos/) 

 * 打包模式,一键打包硬盘,透露为vps托管的http .gz包，可供恢复模式用,此模式下不破坏硬盘原系统仅实现打包服务（安装演示：[https://www.bilibili.com/video/BV1P4pqe8EVK/](https://www.bilibili.com/video/BV1P4pqe8EVK/) ）  
`wget -qO- inst.sh | bash -s - -t 10000:/dev/sda`  

> 上面命令为打包硬盘sda,也可仅打包一个分区  

高级用法:  

 * 指定debian镜像源  
`wget -qO- inst.sh | bash -s - -m github/gitee/xxxx ......`  

 * 指定第一张网卡名  
`wget -qO- inst.sh | bash -s - -i enp0s1 ......`  

 * 指定静态网络配置  
`wget -qO- inst.sh | bash -s - -n ip/cidr,gateway .....`  

 * 指定第一个硬盘名(你也可以填分区名把镜像d到仅一个分区里)  
`wget -qO- inst.sh | bash -s - -p sda ......`  

 * 指定用户密码(不指定为inst.sh,注意，密码小于6位或8位可能不符合某些os要求会导致失败)  
`wget -qO- inst.sh | bash -s - -w mypass ......`  

 * 指定dd完成后动作(不扩盘,不注入静态ip,不重启,不清盘)  
`wget -qO- inst.sh | bash -s - -o 1:noexpanddisk/2:noinjectnetcfg/3:noreboot/4:nopreclean ......` 

 * 开启DEBUG模式，此模式dd时打开一个network-console,可配合dummy目标Dryrun进入救援，也可附在其它target后dd出问题时进入ssh调试  
`wget -qO- inst.sh | bash -s - -d`  

> DEBUG模式下以```用户名为sshd密码为空```登录ssh  

windows/osx下用法(实验):   

 * 需下载并预先安装instsupports,win安装完后打开桌面上生成的cygwin快捷方式输入脚本执行,osx安装完后在bash里输入脚本执行,(参数用法都大体与linux类似,不需-n默认强制静态) （安装演示：[https://www.bilibili.com/video/BV1xe411q78P/](https://www.bilibili.com/video/BV1xe411q78P/) [https://www.bilibili.com/video/BV1S44y1F7o6/](https://www.bilibili.com/video/BV1S44y1F7o6/) ）   
[https://github.com/minlearn/1keyddhubfree-debianbase/raw/master/wininstsupports.zip](https://github.com/minlearn/1keyddhubfree-debianbase/raw/master/wininstsupports.zip)  
[https://github.com/minlearn/1keyddhubfree-debianbase/raw/master/osxinstsupports.zip](https://github.com/minlearn/1keyddhubfree-debianbase/raw/master/osxinstsupports.zip)  

自托管inst:   

 * 方法1：fork本仓库，然后修改你fork到仓库的inst.sh头部变量定义区的automirror0,automirror1中的minlearn为你的用户名，用 "https://github.com/你的github用户名/inst/raw/master/inst.sh" 脚本地址调用脚本即可  
 * 方法2：通过docker,建立托管后，用"你的托管顶层地址/inst/inst.sh"脚本地址调用脚本即可:  
`docker run -d --name myinst -e m=你的托管顶层地址 -p 80:80 minlearn/inst`  


服务及支持👀
-----

项目及项目关联(见文尾)，可为分免费部分和服务性收费部分  

| 项目                      | 是否免费 | 说明 |
| :------:                 | :-:     | :-: |
| inst.sh                  |  √      | 拥有常见vps和独服机型上DD常见系统能力，可解决你DD中大部分问题，提供常见内建镜像 |
| 1kdd                     |  √      | 已经开放的1kdd全部功能 |
| discuss                  |  √      | 在cf上运行的自建轻量联合主机社区程序，可免费克隆源码自建节点 |
| DD服务/DD镜像定制          |  ×      | 本人长期接有偿付费dd/定制镜像服务，解决疑难机型DD问题并总结DD方案1次60元/10U起，定制镜像服务1次60元/10U起，可送加群服务 |
| 1kdd定制                 |  ×      | 定制1kdd增加功能，可送加群服务 |
| discuss定制              |  ×      | 定制discuss增加功能，可送加群服务 |
| 加内部群和社区             |  ×      | 本人维护有一个tg群和一个内部论坛，直接捐赠打赏60元/10U起加群,可终身免费咨询inst+1kdd技术支持+给discuss提issue+更多不定期福利 |
| 项目买断                  |  ×      | 10000u = inst+1kdd+discuss全套ci构建源码+github帐号及仓库, 全部协助转让 |
| ...                      | ...     | ... |

项目和社区维护需要长期付出大量精力，请捐助或付费支持作者  

如何支持：

 * 本人长期接有偿付费dd含解决疑难机型DD问题和定制镜像服务，价格各60元起：  
`怎么联系: 点击如下作者个人tg地址，简单说明需求或说明来意即可，不要说你好，在吗。直接说事`  
[minlearn_1keydd](https://t.me/minlearn_1keydd)

 * 或任意捐助打赏我任意数值虚拟币，直接打赏60rmb/10u可送加群服务：  
`怎么捐助/付款: 用支持tron链的钱包或交易所APP扫描下列钱包地址(走链将u转成trx手续费最低，交易所内转0手续)，将支付截图或交易HASH发送到上面tg地址后，等待作者将你tg邀入群和内部社区`  
BINA: [TTdYbcFMBLHSsw9yrrdRn8jMAFFC7U4Byp](https://tronscan.io/#/address/TTdYbcFMBLHSsw9yrrdRn8jMAFFC7U4Byp)，内部id：878248518  
OKEX: [TPvrETkN21H8fagFjyYAECihyRhrRAMCTR](https://tronscan.io/#/address/TPvrETkN21H8fagFjyYAECihyRhrRAMCTR)，内部id：292251340602744832  
![](https://github.com/minlearn/minlearnprogramming/raw/master/_build/assets/donate.png)

-----

此项目关联 https://github.com/minlearn/下所有项目，主体为https://github.com/minlearn/minlearnprogramming/ 和 https://github.com/minlearn/1kdd ，这是一套为配合我在《minlearnprogramming》最小编程/统一开发的想法的综合项目。
本项目长期保存

