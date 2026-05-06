#!/bin/sh
set -eu

KEEP_CONFIG="0"
KEEP_SCRIPTS="0"
SCRIPT_DIR="/usr/lib/frp-openwrt-one-click"
OLD_SCRIPT_DIR="/tmp/frp-openwrt-one-click"
DOWNLOAD_DIR="/tmp/frp-openwrt-download"
LAUNCHER="/usr/bin/frp"

usage() {
    cat <<'EOF_USAGE'
用法:
  sh uninstall.sh [选项]

选项:
  --keep-config   保留 /etc/frp 配置
  --keep-scripts  保留 /usr/bin/frp 和菜单脚本
  -h, --help      显示帮助
EOF_USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --keep-config) KEEP_CONFIG="1" ;;
        --keep-scripts) KEEP_SCRIPTS="1" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "[ERROR] 未知参数: $1" >&2; exit 1 ;;
    esac
    shift
done

[ "$(id -u)" = "0" ] || { echo "[ERROR] 请使用 root 用户运行" >&2; exit 1; }

for svc in frpc frps; do
    if [ -x "/etc/init.d/${svc}" ]; then
        "/etc/init.d/${svc}" stop 2>/dev/null || true
        "/etc/init.d/${svc}" disable 2>/dev/null || true
        rm -f "/etc/init.d/${svc}"
    fi
    killall "$svc" 2>/dev/null || true
    rm -f "/usr/bin/${svc}"
done

if [ "$KEEP_CONFIG" != "1" ]; then
    rm -rf /etc/frp
fi

rm -rf "$DOWNLOAD_DIR"

if [ "$KEEP_SCRIPTS" != "1" ]; then
    rm -f "$LAUNCHER"
    rm -rf "$SCRIPT_DIR" "$OLD_SCRIPT_DIR"
fi

echo "FRP 已卸载"
[ "$KEEP_CONFIG" = "1" ] && echo "已保留配置目录：/etc/frp"
[ "$KEEP_SCRIPTS" = "1" ] && echo "已保留菜单脚本：${LAUNCHER}、${SCRIPT_DIR}"
