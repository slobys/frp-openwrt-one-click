#!/bin/sh
set -eu

# Clean FRP one-click launcher/script residue only.
# This is intentionally NOT wired into menu.sh to avoid accidental cleanup.

SCRIPT_DIR="/usr/lib/frp-openwrt-one-click"
OLD_SCRIPT_DIR="/tmp/frp-openwrt-one-click"
DOWNLOAD_DIR="/tmp/frp-openwrt-download"
LAUNCHER="/usr/bin/frp"

usage() {
    cat <<'EOF_USAGE'
用法:
  sh clean-residue.sh [选项]

说明:
  清理 frp-openwrt-one-click 管理脚本残留，不删除 /etc/frp 配置，也不卸载 frps/frpc 程序。
  清理后 /usr/bin/frp 会被删除，frp 快捷菜单将不可用；如需再次使用，请重新执行一键安装命令。

会清理:
  /usr/bin/frp
  /usr/lib/frp-openwrt-one-click
  /tmp/frp-openwrt-one-click
  /tmp/frp-openwrt-download

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

echo "将清理以下 FRP 管理脚本残留："
echo "  $LAUNCHER"
echo "  $SCRIPT_DIR"
echo "  $OLD_SCRIPT_DIR"
echo "  $DOWNLOAD_DIR"
echo
echo "注意：清理后 frp 快捷菜单将不可用。"
echo

echo "不会删除："
echo "  /usr/bin/frps"
echo "  /usr/bin/frpc"
echo "  /etc/frp"
echo "  /etc/init.d/frps"
echo "  /etc/init.d/frpc"
echo

if [ "$ASSUME_YES" != "1" ]; then
    printf '确认清理？输入 yes 继续: '
    read -r confirm || true
    case "$confirm" in
        yes|YES|y|Y) ;;
        *) echo "已取消"; exit 0 ;;
    esac
fi

rm -f "$LAUNCHER"
rm -rf "$SCRIPT_DIR" "$OLD_SCRIPT_DIR" "$DOWNLOAD_DIR"

echo "FRP 管理脚本残留已清理完成"
echo
echo "如需重新安装 frp 快捷菜单，请执行："
echo "wget -qO /usr/bin/frp https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master/bootstrap.sh && chmod +x /usr/bin/frp && frp"
