# frp-openwrt-one-click

用于在 **VPS/云服务器** 和 **OpenWrt/iStoreOS/软路由** 上安装和管理 `frps`/`frpc`。

- 默认 FRP 版本：`0.68.1`
- 支持两级菜单：一级选择平台，二级管理安装

## 一键安装

```sh
bash <(curl -Ls https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/bootstrap.sh)
```

国内服务器：

```sh
bash <(curl -Ls https://gitee.com/naiyou88/frp-openwrt-one-click/raw/master/bootstrap.sh)
```

以后再次打开菜单：

```sh
frp
```

强制更新：

```sh
FRP_FORCE_UPDATE=1 frp
```

## 一级菜单

```text
1) 在服务器上安装
2) 在软路由上安装
0) 退出
```

## 服务器二级菜单

```text
1) 安装 frps
2) 重启 frps
3) 查看 frps 状态
4) 管理防火墙端口
5) 查看面板信息
6) 修改面板账号/密码
7) 查看 frps 日志
8) 卸载 FRP
0) 返回上级菜单
```

- 适用于 VPS/云服务器，使用 `systemd` 管理服务
- 防火墙基于 `iptables`
- 安装后自动检测公网 IP 并输出面板地址

## 软路由二级菜单

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
0) 返回上级菜单
```

- 适用于 OpenWrt/iStoreOS，使用 `/etc/init.d` + `procd`
- 防火墙基于 `uci`
- 安装后输出 LAN/WAN/公网 IP 和面板信息

## 默认端口

```text
frps 客户端连接端口: 7000
frps Dashboard:      7500
frpc Web 面板:       7400
frps 远程映射端口:   60000-60999
```

## 注意

- 需要 root 权限运行。
- 安装脚本不会自动放行防火墙端口。
- 公网访问面板或映射端口前，请在菜单里手动放行。
- `frps` 默认限制远程映射端口为 `60000-60999`。
