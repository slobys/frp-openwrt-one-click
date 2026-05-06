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
 7) 查看 FRP 进程
 8) 查看 FRP 日志
 9) 卸载 FRP
 0) 退出
========================================
EOF_MENU
    printf '请选择: '
    read -r choice || exit 0
    case "$choice" in
        1) sh "$DIR/install.sh" --both ;;
        2) sh "$DIR/install.sh" --frps-only ;;
        3) sh "$DIR/install.sh" --frpc-only ;;
        4) /etc/init.d/frps restart ;;
        5) /etc/init.d/frpc restart ;;
        6) sh "$DIR/firewall.sh" ;;
        7) ps | grep '[f]rp' || true ;;
        8) logread | grep frp || true ;;
        9) sh "$DIR/uninstall.sh" ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
    echo
    printf '按回车继续...'
    read -r _ || true
done
