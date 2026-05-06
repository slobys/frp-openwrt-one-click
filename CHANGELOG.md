# CHANGELOG

## 1.3.3

- `frp` 管理命令改为使用持久化脚本目录 `/usr/lib/frp-openwrt-one-click`
- 再次执行 `frp` 时默认使用本地脚本，不再每次重复下载
- 如需强制更新脚本，可执行 `FRP_FORCE_UPDATE=1 frp`

## 1.3.2

- 安装 frps 后自动放行远程映射端口范围 `60000-60999`
- 若已存在相同 `dest_port` 防火墙规则则自动跳过，避免重复添加
- 可通过 `AUTO_OPEN_FIREWALL=0 sh install.sh` 关闭自动放行

## 1.3.1

- 修复安装后菜单脚本丢失的问题：FRP 下载解压目录从 `/tmp/frp-openwrt-one-click` 改为 `/tmp/frp-openwrt-download`，避免安装时删除菜单目录
- 调整安装总结输出逻辑，避免 `set -e` 下条件输出导致总结提前中断

## 1.3.0

- 安装 frps/frpc 时支持交互式自定义 Web 面板端口、用户名和密码
- frps/frpc 面板用户名和密码默认随机生成
- frp token 默认随机生成
- 安装完成后自动检测 LAN IP、WAN IP、公网出口 IP，并输出可直接复制的访问地址和账号信息

## 1.2.5

- 修复自定义端口输入时提示文字被一起传入校验函数的问题
- `prompt_port_spec` 现在将提示输出到 stderr，stdout 只返回端口值

## 1.2.4

- `bootstrap.sh` 下载子脚本时增加缓存刷新参数，避免 OpenWrt 端拿到 GitHub raw 旧缓存

## 1.2.3

- 修复删除旧防火墙规则失败的问题：现在删除时会同时匹配规则名和 `dest_port`
- 兼容手动创建的规则，例如 `Allow-FRP-Remote-Ports` + `dest_port=60000-60999`
- 删除所有规则的确认支持 `yes/y/YES/Y`
- `bootstrap.sh` 下载脚本时改为安静模式，减少菜单显示被下载进度干扰

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
