# frp-openwrt-one-click

用于在 **OpenWrt / iStoreOS / ImmortalWrt / 软路由** 上一键安装和管理 `frps`、`frpc`。

- 默认 FRP 版本：`0.68.1`
- 服务管理：OpenWrt `/etc/init.d` + `procd`
- 支持开机自启、后台运行、崩溃自动重启
- 支持菜单安装、卸载、重启、查看日志、防火墙端口管理

## 一键安装

SSH 登录软路由后执行：

```sh
wget -qO /usr/bin/frp https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/bootstrap.sh && chmod +x /usr/bin/frp && frp
```

备用 `curl` 命令：

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/bootstrap.sh -o /usr/bin/frp && chmod +x /usr/bin/frp && frp
```

以后再次打开菜单，直接执行：

```sh
frp
```

如果刚更新过项目，建议强制刷新一次本地菜单脚本：

```sh
FRP_FORCE_UPDATE=1 frp
```

## 卸载

菜单里选择 `9) 卸载 FRP`。

卸载会同时清理 `frps/frpc`、服务、配置、`/usr/bin/frp` 管理命令、本地菜单脚本和临时残留。

## 菜单功能

```text
1) 安装 frps + frpc
2) 只安装 frps 服务端
3) 只安装 frpc 客户端
4) 重启 frps
5) 重启 frpc
6) 管理 FRP 防火墙端口
7) 查看面板信息
8) 修改面板账号/密码
9) 查看 FRP 进程
10) 查看 FRP 日志
11) 卸载 FRP
0) 退出
```

## 安装时会做什么

安装脚本会自动：

- 识别 CPU 架构并下载对应 FRP 程序
- 安装 `frps` / `frpc` 到 `/usr/bin/`
- 生成配置到 `/etc/frp/`
- 创建 `/etc/init.d/frps`、`/etc/init.d/frpc`
- 设置开机自启并启动服务
- 检测 LAN IP、WAN IP、公网出口 IP
- 输出可直接复制的面板地址、用户名、密码、token
- 可通过菜单随时查看 frps/frpc 面板信息

安装时可自定义：

- frps Dashboard 端口、用户名、密码
- frpc Web 面板端口、用户名、密码

用户名、密码和 token 默认随机生成。

## 默认端口

```text
frps 客户端连接端口: 7000
frps Dashboard:      7500
frpc Web 面板:       7400
frps 远程映射端口:   60000-60999
```

## 防火墙端口管理

如果面板或映射端口打不开，进入菜单选择：

```text
6) 管理 FRP 防火墙端口
```

支持：

- 放行单个端口，例如 `7500`
- 放行端口范围，例如 `60000-60999`
- 查看已放行的 FRP 端口
- 删除某个已放行端口
- 删除所有 `Allow-FRP-*` 规则

## 修改面板账号/密码

进入菜单选择：

```text
8) 修改面板账号/密码
```

可以修改：

- frps 面板用户名/密码
- frpc 面板用户名/密码
- frp token

修改后自动重启对应服务。

## 常用服务命令

```sh
/etc/init.d/frps start|stop|restart|enable|disable
/etc/init.d/frpc start|stop|restart|enable|disable
ps | grep frp
logread | grep frp
```

## 注意

- 需要 root 权限运行。
- 安装脚本不会自动放行防火墙端口，避免误开放公网端口。
- 如果需要从公网访问面板或映射端口，请在菜单里手动放行。
- `frps` 默认只限制 frpc 可申请的远程映射端口范围为 `60000-60999`，这不是防火墙放行。
- 实际公网开放端口请按需手动放行，建议优先只放行正在使用的单个端口。 
