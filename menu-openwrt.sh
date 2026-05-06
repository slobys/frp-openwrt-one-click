#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

while true; do
    clear 2>/dev/null || true
    cat <<'EOF_MENU'
========================================
 FRP OpenWrt/iStoreOS 一键管理菜单
========================================
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
========================================
EOF_MENU
    printf '请选择: '
    read -r choice || exit 0
    case "$choice" in
        1) sh "$DIR/install-openwrt.sh" --both ;;
        2) sh "$DIR/install-openwrt.sh" --frps-only ;;
        3) sh "$DIR/install-openwrt.sh" --frpc-only ;;
        4) /etc/init.d/frps restart ;;
        5) /etc/init.d/frpc restart ;;
        6) sh "$DIR/firewall-openwrt.sh" ;;
        7) sh "$DIR/info.sh" ;;
        8) sh "$DIR/config.sh" ;;
        9) ps | grep '[f]rp' || true ;;
        10) logread | grep frp || true ;;
        11) exec sh "$DIR/uninstall-openwrt.sh" ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
    echo
    printf '按回车继续...'
    read -r _ || true
done
