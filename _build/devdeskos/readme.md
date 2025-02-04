[演示与特性](#演示与特性) | [下载安装及用法](#下载安装及用法) | [服务及支持](#服务及支持)

1kdd: 最小化开发发布后端
=====

1kdd是一套学习编程语言的最小实践环境选型方案,并相关管理工具和相关脚本，最终组合实现的一套"一键开发桌面理念"系统存在。   

 * 作为一套"虚拟机管理器"的系统最小核心，基于精简+headless的pve，devdeskos实现了一套vmm in ram的统一透明ve后端。    
 * 作为一套"学习编程的最小实践环境"的选型方案，基于vescript等脚本，devdeskos整合了一键安装开发类，数据库类lxc apps，作为初步的应用商店扩展和商店apps存在。    

> 1kdd也指代:1keystokedd,1keydowndd,1keynotedevdesk,1keydevabledocker,1keydiskdump,1keydeepindsm,1keydebiandist,1keydebiandesk,1keydevdeploy,1keydebugdemo,1key desk dock,1key datacenter and desk,1key dir disk,1key deconterized desk,1kilometer distance to dev,1key for dev over dev(second dev),1k dev and deploy in os cases,etc ..

项目地址：[https://github.com/minlearn/1kdd](https://github.com/minlearn/1kdd)

演示与特性✨
-----

onekeydevdesk支持一键dd和构建devdeskos，devdeskos是onekeydevdesk的shell os，作为构建+集成范例存在。支持左栏清爽模式/即时切换暗黑主题/一屏式容器创建向导，集成pbs服务和存储（ 安装演示：[https://www.bilibili.com/video/BV1pr4y1j75w/](https://www.bilibili.com/video/BV1pr4y1j75w/) ）,原生lxc vnc桌面（ 安装演示：[https://www.bilibili.com/video/BV1PV4y1o7f2/](https://www.bilibili.com/video/BV1PV4y1o7f2/) ），512m小内存可安装，支持headless部署和分离式前端pveman ( 安装演示: [https://www.bilibili.com/video/BV1eRt7eTE5A/](https://www.bilibili.com/video/BV1eRt7eTE5A/) )，todo: 可社交分享联合的虚拟机实例，支持docker，集成serverless,支持容器级debugger接入和edtior ide  

onekeydevdesk支持一键安装/生成lxc app，目前采用ve-script方案，todo:未来将做成web端appstore形式  

![](https://github.com/minlearn/minlearnprogramming/raw/master/_build/assets/devdeskos.png)


下载安装及用法📄
-----

> 注：以下尽量在debian系linux云主机或本地虚拟机下完成,rh系centos/rocky/alma不推荐  

 * 安装devdeskos：脚本运行后会重启进入dd过程，进入后，如有网络直接访问ip:80，会看到vnc进度，如果要进一步查看问题访问ip:8000。目标os安装后，会自动扩展磁盘空间和调整网络。（安装演示：[https://www.bilibili.com/video/BV17B4y1b79Y/](https://www.bilibili.com/video/BV17B4y1b79Y/) 和 [https://www.bilibili.com/video/BV1HSndezEaq/](https://www.bilibili.com/video/BV1HSndezEaq/) ） 
```
wget -qO- inst.sh|bash -s - -t 目标值(以下3选1)
                               * devdesk:   是live方式安装的headless devdeskos+gui devdeskos双启动
                               * devdeskde: 是d到本地文件的独立桌面版devdeskos
                               * devdeskct: 是转换openvz/lxc根文件系统的容器版devdeskos
``` 
  
> 恢复完成后的系统，```linux用户名为root密码为inst.sh```，windows保留原包密码。(注意不指定为inst.sh,注意，指定时密码小于6位或8位可能不符合某些os要求会导致失败)   

 * 安装lxc app: 在pve主机shell里输入  
```
pveinst 应用名 应用nat端口(可选)
```  

这里收集了一些lxc app速查：

| 基础类            | 开发类        | 云应用      | 工具类       | os类     | 其它  | 
| :------:         | :-:          | :-:        | :-:         | :-:      | :-:  | 
| mysql57          | gitea        | nextcloud  | chrome      | debiande | ...  | 
| mongodb          | code-server  | discuss    | cloudflared | redriod  | ...  | 
| postgresql       | ...          | wordpress  | ...         | osxkvm   | ...  | 
| redis            | ...          | ...        | ...         | ...      | ...  | 
| mariadb          | ...          | ...        | ...         | ...      | ...  | 

> 更多第三方lxc apps及仓库[《https://minlearn.org/1kdd/1kddapps》](https://minlearn.org/1kdd/1kddapps)

服务及支持👀
-----

项目及项目关联（见文尾），可为分免费部分和服务性收费部分，大部分免费公益性服务，仅对要求作者动手的服务收费，项目和社区维护需要长期付出大量精力，请捐助或付费支持作者：  

如何支持：

 * 本人长期接有偿付费dd含解决疑难机型DD问题和定制dd镜像服务/定制pve lxc app服务，价格各60元起，不成功不收费，附加10元可加群：  
`怎么联系: 点击如下作者个人tg地址，简单说明需求或说明来意即可，不要说你好，在吗。直接说事`  
[minlearn_1keydd](https://t.me/minlearn_1keydd)

 * 本人维护有一个tg群和一个内部论坛，直接捐赠打赏60元/10U起加群,可终身免费咨询inst+1kdd技术支持+给discuss提issue+更多不定期福利，你可任意捐助打赏我任意数值虚拟币：  
`怎么捐助/付款: 用支持tron链的钱包或交易所APP扫描下列钱包地址(走链将u转成trx手续费最低，交易所内转0手续)，将支付截图或交易HASH发送到上面tg地址后，等待作者将你tg邀入群和内部社区`  
BINA: [TTdYbcFMBLHSsw9yrrdRn8jMAFFC7U4Byp](https://tronscan.io/#/address/TTdYbcFMBLHSsw9yrrdRn8jMAFFC7U4Byp)，内部id：878248518  
OKEX: [TPvrETkN21H8fagFjyYAECihyRhrRAMCTR](https://tronscan.io/#/address/TPvrETkN21H8fagFjyYAECihyRhrRAMCTR)，内部id：292251340602744832  
![](https://github.com/minlearn/minlearnprogramming/raw/master/_build/assets/donate.png)

* 项目买断
`10000u = inst+1kdd+discuss全套ci构建源码, 全部协助转让`

-----

此项目关联 https://github.com/minlearn/ 下所有项目，主体为 https://github.com/minlearn/minlearnprogramming/ 和 https://github.com/minlearn/1kdd ，这是一套为配合我在《minlearnprogramming》最小编程/统一开发的想法的综合项目。  
本项目长期保存

