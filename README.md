# frp-openwrt-one-click

用于在 **软路由 / OpenWrt / iStoreOS / ImmortalWrt** 上一键安装 `frps` 和 `frpc` 的脚本项目。

默认基于 FRP `v0.68.1`，使用 OpenWrt 原生 `/etc/init.d` + `procd` 实现后台运行、崩溃自动重启、开机自启。

## 适合场景

- 家里有公网 IP，软路由作为 `frps` 服务端
- iStoreOS 同时运行 `frps + frpc`，通过 frpc 面板管理内网服务映射
- 软路由作为独立 `frpc` 客户端连接远端 frps

## 一键安装

在 OpenWrt / iStoreOS 软路由 SSH 里直接执行：

```sh
wget -O /tmp/frp-install.sh https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/install.sh && sh /tmp/frp-install.sh
```

如果系统没有 `wget`，也可以用 `curl`：

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/install.sh -o /tmp/frp-install.sh && sh /tmp/frp-install.sh
```

指定安装模式示例：

```sh
# 只安装 frps 服务端
wget -O /tmp/frp-install.sh https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/install.sh && sh /tmp/frp-install.sh --frps-only

# 只安装 frpc 客户端
wget -O /tmp/frp-install.sh https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/install.sh && sh /tmp/frp-install.sh --frpc-only
```

## 拉取完整项目

如果你想使用菜单、卸载脚本和完整文档：

```sh
git clone https://github.com/slobys/frp-openwrt-one-click.git
cd frp-openwrt-one-click
chmod +x install.sh uninstall.sh menu.sh
sh install.sh
```

默认会安装：

- `frps`：服务端，Dashboard 端口 `7500`
- `frpc`：客户端，Web 管理端口 `7400`
- 配置目录：`/etc/frp`
- 程序路径：`/usr/bin/frps`、`/usr/bin/frpc`

## 安装模式

```sh
# 安装 frps + frpc（默认）
sh install.sh --both

# 只安装 frps 服务端
sh install.sh --frps-only

# 只安装 frpc 客户端
sh install.sh --frpc-only

# 指定 FRP 版本
sh install.sh --version 0.68.1

# CPU 架构识别失败时手动指定
sh install.sh --arch arm64
```

## 默认访问地址

### frps Dashboard

```text
http://你的软路由IP:7500
账号：admin
密码：naiyou_admin_2026
```

### frpc Web 管理面板

```text
http://你的软路由IP:7400
账号：admin
密码：naiyou_frpc_2026
```

> 安装后建议立即修改 token 和面板密码。

## 自定义 token / 密码 / 端口

脚本支持用环境变量覆盖默认值：

```sh
FRP_TOKEN='your_strong_token' \
FRPS_DASHBOARD_PASSWORD='your_frps_password' \
FRPC_DASHBOARD_PASSWORD='your_frpc_password' \
sh install.sh --both
```

更多常用变量：

```sh
FRPS_BIND_PORT=7000
FRPS_DASHBOARD_PORT=7500
FRPC_SERVER_ADDR=127.0.0.1
FRPC_SERVER_PORT=7000
FRPC_DASHBOARD_PORT=7400
ALLOW_PORT_START=60000
ALLOW_PORT_END=60999
```

独立 frpc 连接远端 frps 示例：

```sh
FRPC_SERVER_ADDR='你的公网服务器IP或域名' \
FRPC_SERVER_PORT='7000' \
FRP_TOKEN='和服务端一致的token' \
sh install.sh --frpc-only
```

## CPU 架构

脚本会自动根据 `uname -m` 映射 FRP 包架构：

- `x86_64` → `amd64`
- `aarch64` / `arm64` → `arm64`
- `armv7l` / `armv6l` → `arm`
- `mipsel` / `mipsle` → `mipsle`
- `mips64el` / `mips64le` → `mips64le`
- `riscv64` → `riscv64`

如果自动识别失败：

```sh
sh install.sh --arch arm64
```

## 常用管理命令

```sh
/etc/init.d/frps start      # 启动 frps
/etc/init.d/frps stop       # 停止 frps
/etc/init.d/frps restart    # 重启 frps
/etc/init.d/frps enable     # 设置开机自启
/etc/init.d/frps disable    # 取消开机自启

/etc/init.d/frpc start
/etc/init.d/frpc stop
/etc/init.d/frpc restart
/etc/init.d/frpc enable
/etc/init.d/frpc disable

ps | grep frp               # 查看进程
logread | grep frp          # 查看日志
```

## 菜单管理

```sh
sh menu.sh
```

菜单支持安装、重启、查看进程、查看日志、卸载。

## 卸载

```sh
sh uninstall.sh
```

保留配置卸载：

```sh
sh uninstall.sh --keep-config
```

## 安全提醒

- 默认 token 和密码来自示例，公开环境请务必修改。
- `frps` 默认只允许客户端映射 `60000-60999` 端口，避免随意开放端口。
- 如果需要从公网访问 `7000` 或映射端口，请确认 OpenWrt 防火墙已经放行对应端口。
