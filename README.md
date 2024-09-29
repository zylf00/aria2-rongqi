# 在玩具平台搭建 Aria2 离线下载器

## 项目介绍

在 **Node.js**, **Python**, **Java** 环境的游戏玩具平台搭建 **Aria2** 离线下载器，并且支持集成哪吒探针

## 安装与使用

根据所需的运行环境，请下载对应文件夹内的文件并上传至服务器，确保赋予相应的权限。修改配置文件中的变量后，即可运行。

## 下载完成后自动将文件上传到网盘

本项目支持在下载完成后，自动使用 **Rclone** 将文件上传至网盘并删除本地文件。默认情况下此功能未启用，若需要启用，请按照以下步骤操作：

- **步骤 1: 上传 Rclone 配置文件
  - 注意：**玩具平台本身无法直接配置 Rclone，你需要在其他平台上完成 Rclone 的网盘挂载，提取 `rclone.conf` 文件，上传到这里。
  - 将配置文件上传到这个文件夹：
  - /home/container/.config/rclone


- **步骤 2: 修改 Aria2 配置文件
  - 在 /home/container/aria2c/aria2.conf 中找到如下配置项：
  - on-download-complete=/home/container/aria2/clean.sh
   - 将 clean.sh 替换为 upload.sh 以启用自动上传功能


- **步骤 3: 修改脚本配置文件
   - 在 /home/container/aria2c/script.conf 中根据需要修改相关配置，文件中有中文注释指导配置修改。首次使用建议只修改网盘名称：
   - 网盘名称(RCLONE 配置时填写的 name)
   - drive-name=OneDrive


## 项目引用
- **Aria2** 使用的是 P3TERX 大佬的 [Aria2-Pro-Core](https://github.com/P3TERX/Aria2-Pro-Core) 和完美配置。
  - 项目地址: [P3TERX/aria2.conf](https://github.com/P3TERX/aria2.conf)
  
- **哪吒监控客户端** 和代码思路借鉴自 eooce 的 [Sing-box](https://github.com/eooce/Sing-box)。
  - 项目地址: [eooce/Sing-box](https://github.com/eooce/Sing-box)



## 免责声明

本程序仅供学习和了解，禁止用于任何商业用途，下载后请于 24 小时内删除所有相关文件。所有文字、数据及图片均为其所属版权所有者所有，若进行转载，请注明来源。

使用本程序时，请确保遵守所在国家及服务器所在地的法律法规，程序作者不对使用者的任何违规行为负责。
