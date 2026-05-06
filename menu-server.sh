#!/bin/sh
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

while true; do
    clear 2>/dev/null || true
    cat <<'EOF_MENU'
========================================
 FRP 服务器一键管理菜单
========================================
 1) 安装 frps
 2) 重启 frps
 3) 查看 frps 状态
 4) 管理防火墙端口
 5) 查看面板信息
 6) 修改面板账号/密码
 7) 查看 frps 日志
 8) 卸载 FRP
 0) 返回上级菜单
========================================
EOF_MENU
    printf '请选择: '
    read -r choice || exit 0
    case "$choice" in
        1) sh "$DIR/install-server.sh" ;;
        2) systemctl restart frps ;;
        3) systemctl status frps ;;
        4) sh "$DIR/firewall-server.sh" ;;
        5) sh "$DIR/info.sh" ;;
        6) sh "$DIR/config.sh" ;;
        7) journalctl -u frps -n 50 --no-pager ;;
        8) exec sh "$DIR/uninstall-server.sh" ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
    echo
    printf '按回车继续...'
    read -r _ || true
done
