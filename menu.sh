#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

while true; do
    clear 2>/dev/null || true
    cat <<'EOF_MENU'
========================================
 FRP 一键管理菜单
========================================
 1) 在服务器上安装
 2) 在软路由上安装
 0) 退出
========================================
EOF_MENU
    printf '请选择: '
    read -r choice || exit 0
    case "$choice" in
        1) sh "$DIR/menu-server.sh" ;;
        2) sh "$DIR/menu-openwrt.sh" ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
done
