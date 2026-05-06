#!/bin/sh
set -eu

# Download the FRP OpenWrt one-click project scripts to /tmp and launch menu.sh.

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master}"
WORKDIR="${WORKDIR:-/tmp/frp-openwrt-one-click}"
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

for file in install.sh uninstall.sh firewall.sh menu.sh; do
    log "下载 ${file}"
    download "${REPO_RAW}/${file}?v=${CACHE_BUST}" "$file"
    chmod +x "$file"
done

log "启动 FRP 管理菜单"

# If launched from a pipe, stdin may not be the keyboard. Reconnect all stdio
# to the real terminal when available, then launch the interactive menu.
if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    exec < /dev/tty > /dev/tty 2>&1
fi

exec sh ./menu.sh
