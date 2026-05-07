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
 2) 一键更新 frps
 3) 重启 frps
 4) 查看 frps 状态
 5) 管理防火墙端口
 6) 查看面板信息
 7) 修改面板账号/密码
 8) 查看 frps 日志
 9) 卸载 FRP
 0) 返回上级菜单
========================================
EOF_MENU
    printf '请选择: '
    read -r choice || exit 0
    case "$choice" in
        1) sh "$DIR/install-server.sh" ;;
        2) sh "$DIR/update.sh" --frps-only ;;
        3) systemctl restart frps ;;
        4) systemctl status frps ;;
        5) sh "$DIR/firewall-server.sh" ;;
        6) sh "$DIR/info.sh" ;;
        7) sh "$DIR/config.sh" ;;
        8) journalctl -u frps -n 50 --no-pager ;;
        9) exec sh "$DIR/uninstall-server.sh" ;;
        0) exit 0 ;;
        *) echo "无效选择" ;;
    esac
    echo
    printf '按回车继续...'
    read -r _ || true
done
