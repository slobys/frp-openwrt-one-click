# frp-openwrt-one-click

用于在 **软路由 / OpenWrt / iStoreOS / ImmortalWrt** 上一键安装 `frps` 和 `frpc` 的脚本项目。

默认基于 FRP `v0.68.1`，使用 OpenWrt 原生 `/etc/init.d` + `procd` 实现后台运行、崩溃自动重启、开机自启。

## 适合场景

- 家里有公网 IP，软路由作为 `frps` 服务端
- iStoreOS 同时运行 `frps + frpc`，通过 frpc 面板管理内网服务映射
- 软路由作为独立 `frpc` 客户端连接远端 frps

## 一键菜单

推荐在 OpenWrt / iStoreOS 软路由 SSH 里直接执行下面命令，进入菜单后选择安装、重启、查看日志或卸载：

```sh
wget -qO /usr/bin/frp https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/bootstrap.sh && chmod +x /usr/bin/frp && frp
```

如果系统没有 `wget`，也可以用 `curl`：

```sh
curl -fsSL https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/bootstrap.sh -o /usr/bin/frp && chmod +x /usr/bin/frp && frp
```

安装完成后，以后直接输入下面命令即可再次打开管理菜单：

```sh
frp
```

菜单功能：

```text
1) 安装 frps + frpc
2) 只安装 frps 服务端
3) 只安装 frpc 客户端
4) 重启 frps
5) 重启 frpc
6) 管理 FRP 防火墙端口
7) 查看 FRP 进程
8) 查看 FRP 日志
9) 卸载 FRP
```

## 拉取完整项目

如果你想保留完整项目文件，也可以这样运行菜单：

```sh
git clone https://github.com/slobys/frp-openwrt-one-click.git
cd frp-openwrt-one-click
chmod +x bootstrap.sh install.sh uninstall.sh firewall.sh menu.sh
sh menu.sh
```

默认菜单安装会安装：

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

## 防火墙端口管理

如果安装后面板或映射端口打不开，可以通过菜单选择 `管理 FRP 防火墙端口`。

支持：

- 放行单个端口，例如 `7500`
- 放行端口范围，例如 `60000-60999`
- 查看当前已放行的 FRP 端口
- 删除某个已放行端口
- 删除所有 `Allow-FRP-*` 规则

也可以直接运行：

```sh
# 进入交互式防火墙管理菜单
sh firewall.sh

# 查看已放行的 FRP 端口
sh firewall.sh list

# 放行单个端口
sh firewall.sh add 7500

# 放行 frpc Web 管理面板
sh firewall.sh add 7400

# 放行 frps 客户端连接端口
sh firewall.sh add 7000

# 放行远程映射端口范围
sh firewall.sh add 60000-60999

# 删除单个端口放行规则
sh firewall.sh delete 7500

# 删除端口范围放行规则
sh firewall.sh delete 60000-60999

# 删除所有 Allow-FRP-* 放行规则
sh firewall.sh clear
```

脚本会自动创建 OpenWrt 防火墙规则，等效于：

```sh
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-FRP-60000-60999'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp udp'
uci set firewall.@rule[-1].dest_port='60000-60999'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
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

菜单支持安装、重启、管理防火墙端口、查看进程、查看日志、卸载。

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
