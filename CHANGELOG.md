# CHANGELOG

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
