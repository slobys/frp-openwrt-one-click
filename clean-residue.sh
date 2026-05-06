#!/bin/sh
set -eu

# Clean temporary FRP one-click residue only.
# Full uninstall from menu option 9 removes launcher/scripts.

OLD_SCRIPT_DIR="/tmp/frp-openwrt-one-click"
DOWNLOAD_DIR="/tmp/frp-openwrt-download"
LAUNCHER="/usr/bin/frp"
SCRIPT_DIR="/usr/lib/frp-openwrt-one-click"

usage() {
    cat <<'EOF_USAGE'
用法:
  sh clean-residue.sh [选项]

说明:
  只清理临时残留，不删除 frp 快捷菜单和本地菜单脚本。
  如果想彻底卸载并删除 /usr/bin/frp、菜单脚本，请在菜单里选择 9) 卸载 FRP。

会清理:
  /tmp/frp-openwrt-one-click
  /tmp/frp-openwrt-download

不会删除:
  /usr/bin/frp
  /usr/lib/frp-openwrt-one-click
  /usr/bin/frps
  /usr/bin/frpc
  /etc/frp
  /etc/init.d/frps
  /etc/init.d/frpc

选项:
  -y, --yes   不询问，直接清理
  -h, --help  显示帮助
EOF_USAGE
}

ASSUME_YES="0"
while [ "$#" -gt 0 ]; do
    case "$1" in
        -y|--yes) ASSUME_YES="1" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "[ERROR] 未知参数: $1" >&2; exit 1 ;;
    esac
    shift
done

[ "$(id -u)" = "0" ] || { echo "[ERROR] 请使用 root 用户运行" >&2; exit 1; }

echo "将清理以下临时残留："
echo "  $OLD_SCRIPT_DIR"
echo "  $DOWNLOAD_DIR"
echo

echo "不会删除："
echo "  $LAUNCHER"
echo "  $SCRIPT_DIR"
echo "  /usr/bin/frps"
echo "  /usr/bin/frpc"
echo "  /etc/frp"
echo "  /etc/init.d/frps"
echo "  /etc/init.d/frpc"
echo

if [ "$ASSUME_YES" != "1" ]; then
    printf '确认清理临时残留？输入 yes 继续: '
    read -r confirm || true
    case "$confirm" in
        yes|YES|y|Y) ;;
        *) echo "已取消"; exit 0 ;;
    esac
fi

rm -rf "$OLD_SCRIPT_DIR" "$DOWNLOAD_DIR"

echo "FRP 临时残留已清理完成，frp 快捷菜单仍然可用"
