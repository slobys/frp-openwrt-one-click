#!/bin/sh
set -eu

# Uninstall frps from server (systemd-based).

KEEP_CONFIG="0"
SCRIPT_DIR="/usr/lib/frp-openwrt-one-click"
OLD_SCRIPT_DIR="/tmp/frp-openwrt-one-click"
DOWNLOAD_DIR="/tmp/frp-openwrt-download"
LAUNCHER="/usr/bin/frp"

usage() {
    cat <<'EOF_USAGE'
用法:
  sh uninstall-server.sh [选项]

选项:
  --keep-config   保留 /etc/frp 配置
  -h, --help      显示帮助
EOF_USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --keep-config) KEEP_CONFIG="1" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "[ERROR] 未知参数: $1" >&2; exit 1 ;;
    esac
    shift
done

[ "$(id -u)" = "0" ] || { echo "[ERROR] 请使用 root 用户运行" >&2; exit 1; }

# Stop and remove systemd service
if [ -f /etc/systemd/system/frps.service ]; then
    systemctl stop frps 2>/dev/null || true
    systemctl disable frps 2>/dev/null || true
    rm -f /etc/systemd/system/frps.service
    systemctl daemon-reload
fi

killall frps 2>/dev/null || true
rm -f /usr/bin/frps

if [ "$KEEP_CONFIG" != "1" ]; then
    rm -rf /etc/frp
fi

rm -f "$LAUNCHER"
rm -rf "$SCRIPT_DIR" "$OLD_SCRIPT_DIR" "$DOWNLOAD_DIR"

echo "FRP 已卸载，并已清理管理命令、菜单脚本和临时残留"
[ "$KEEP_CONFIG" = "1" ] && echo "已保留配置目录：/etc/frp"
