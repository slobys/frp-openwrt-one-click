#!/bin/sh
set -eu

# Download FRP OpenWrt one-click project scripts once, then launch menu.sh.

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master}"
WORKDIR="${WORKDIR:-/usr/lib/frp-openwrt-one-click}"
FRP_FORCE_UPDATE="${FRP_FORCE_UPDATE:-0}"
SCRIPT_BUNDLE_VERSION="1.3.5"
VERSION_FILE=".bundle-version"
CACHE_BUST="${CACHE_BUST:-$(date +%s 2>/dev/null || echo fresh)}"

log() { printf '%s\n' "==> $*"; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

download() {
    url="$1"
    dest="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$dest" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$dest" "$url"
    else
        die "缺少下载工具：请先安装 wget 或 curl"
    fi
}

mkdir -p "$WORKDIR"
cd "$WORKDIR"

LOCAL_BUNDLE_VERSION=""
[ -f "$VERSION_FILE" ] && LOCAL_BUNDLE_VERSION="$(cat "$VERSION_FILE" 2>/dev/null || true)"
if [ "$LOCAL_BUNDLE_VERSION" != "$SCRIPT_BUNDLE_VERSION" ]; then
    FRP_FORCE_UPDATE="1"
fi

for file in install.sh uninstall.sh firewall.sh menu.sh; do
    if [ -s "$file" ] && [ "$FRP_FORCE_UPDATE" != "1" ]; then
        log "使用本地 ${file}"
    else
        log "下载 ${file}"
        download "${REPO_RAW}/${file}?v=${CACHE_BUST}" "$file"
        chmod +x "$file"
    fi
done

printf '%s\n' "$SCRIPT_BUNDLE_VERSION" > "$VERSION_FILE"

log "启动 FRP 管理菜单"

# If launched from a pipe, stdin may not be the keyboard. Reconnect all stdio
# to the real terminal when available, then launch the interactive menu.
if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    exec < /dev/tty > /dev/tty 2>&1
fi

exec sh ./menu.sh
