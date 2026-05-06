#!/bin/sh
set -eu

# Download the FRP OpenWrt one-click project scripts to /tmp and launch menu.sh.

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master}"
WORKDIR="${WORKDIR:-/tmp/frp-openwrt-one-click}"

log() { printf '%s\n' "==> $*"; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

download() {
    url="$1"
    dest="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$dest" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fL -o "$dest" "$url"
    else
        die "缺少下载工具：请先安装 wget 或 curl"
    fi
}

mkdir -p "$WORKDIR"
cd "$WORKDIR"

for file in install.sh uninstall.sh firewall.sh menu.sh; do
    log "下载 ${file}"
    download "${REPO_RAW}/${file}" "$file"
    chmod +x "$file"
done

log "启动 FRP 管理菜单"
exec sh ./menu.sh
