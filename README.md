# 一键安装 Frp内网穿透

用于在 **VPS/云服务器** 和 **OpenWrt/iStoreOS/软路由** 上一键安装和管理 `frps` / `frpc`。

- 支持服务器端 `frps` 和客户端 `frpc` 部署
- 支持软路由 / OpenWrt / iStoreOS 安装和管理
- 支持菜单一键更新 `frps` / `frpc`，更新时保留现有配置
- 默认 FRP 版本：`0.68.1`

## 一键安装

```sh
bash <(curl -Ls https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/bootstrap.sh)
```

国内服务器：

```sh
bash <(curl -Ls https://gitee.com/naiyou88/frp-openwrt-one-click/raw/master/bootstrap-gitee.sh)
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
2) 一键更新 frps
3) 重启 frps
4) 查看 frps 状态
5) 管理防火墙端口
6) 查看面板信息
7) 修改面板账号/密码
8) 查看 frps 日志
9) 卸载 FRP
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
4) 一键更新 frps + frpc
5) 只更新 frps
6) 只更新 frpc
7) 重启 frps
8) 重启 frpc
9) 管理 FRP 防火墙端口
10) 查看面板信息
11) 修改面板账号/密码
12) 查看 FRP 进程
13) 查看 FRP 日志
14) 卸载 FRP
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
- 更新功能只替换二进制文件，不覆盖 `/etc/frp/*.toml` 配置；也可手动指定版本：`sh update.sh --version 0.68.1 --both`。
