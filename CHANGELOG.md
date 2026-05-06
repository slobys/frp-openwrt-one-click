# CHANGELOG

## 1.2.2

- README 主入口改为安装 `/usr/bin/frp` 管理命令，避免 `wget -qO- ... | sh` 管道模式影响交互菜单输入
- 安装后可直接执行 `frp` 打开管理菜单

## 1.2.1

- 修复通过 `wget -qO- ... | sh` 启动时菜单无法读取键盘输入的问题
- `bootstrap.sh` 现在会将菜单输入输出重新连接到 `/dev/tty`

## 1.2.0

- `firewall.sh` 新增查看已放行 FRP 端口功能：`sh firewall.sh list`
- `firewall.sh` 新增删除单个端口/端口范围功能：`sh firewall.sh delete 7500`、`sh firewall.sh delete 60000-60999`
- `firewall.sh` 新增删除所有 FRP 放行规则功能：`sh firewall.sh clear`
- 菜单中的防火墙入口升级为“管理 FRP 防火墙端口”

## 1.1.0

- 新增 `firewall.sh` 防火墙放行脚本
- 支持放行单个端口，例如 `7500`
- 支持放行端口范围，例如 `60000-60999`
- 菜单新增“放行 FRP 防火墙端口”入口
- `bootstrap.sh` 会自动下载 `firewall.sh`

## 1.0.0

- 初始版本
- 支持 OpenWrt/iStoreOS 安装 frps + frpc
- 支持 CPU 架构自动识别和手动指定
- 支持 procd 后台运行、崩溃重启、开机自启
- 支持 frps/frpc 配置文件自动生成
- 支持菜单管理和卸载脚本
