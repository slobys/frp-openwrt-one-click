#!/bin/sh
set -eu

# Download FRP OpenWrt one-click project scripts once, then launch menu.sh.

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/slobys/frp-openwrt-one-click/master}"
REPO_GITEE="${REPO_GITEE:-https://gitee.com/naiyou88/frp-openwrt-one-click/raw/master}"

# If first arg is "gitee", use Gitee directly and persist preference
if [ "${1:-}" = "gitee" ]; then
    REPO_RAW="$REPO_GITEE"
    shift
    mkdir -p /usr/lib/frp-openwrt-one-click
    touch /usr/lib/frp-openwrt-one-click/.gitee
fi
[ -f /usr/lib/frp-openwrt-one-click/.gitee ] && REPO_RAW="$REPO_GITEE"
WORKDIR="${WORKDIR:-/usr/lib/frp-openwrt-one-click}"
FRP_FORCE_UPDATE="${FRP_FORCE_UPDATE:-0}"
SCRIPT_BUNDLE_VERSION="2.3.9"
VERSION_FILE=".bundle-version"
CACHE_BUST="${CACHE_BUST:-$(date +%s 2>/dev/null || echo fresh)}"
PRINTED=""

log() { printf '%s\n' "==> $*"; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

download() {
    url="$1"
    dest="$2"
    if command -v wget >/dev/null 2>&1; then
        if ! wget -q --timeout=2 --tries=1 -O "$dest" "$url" 2>/dev/null; then
            if [ -z "${GITEE_SWITCHED:-}" ]; then
                GITEE_SWITCHED=1
                REPO_RAW="$REPO_GITEE"
                url="${REPO_RAW}/${file}?v=${CACHE_BUST}"
                log "GitHub 较慢，切换至 Gitee 国内源"
                wget -q -O "$dest" "$url"
            fi
        fi
    elif command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL --max-time 4 -o "$dest" "$url" 2>/dev/null; then
            if [ -z "${GITEE_SWITCHED:-}" ]; then
                GITEE_SWITCHED=1
                REPO_RAW="$REPO_GITEE"
                url="${REPO_RAW}/${file}?v=${CACHE_BUST}"
                log "GitHub 较慢，切换至 Gitee 国内源"
                curl -fsSL -o "$dest" "$url"
            fi
        fi
    else
        die "缺少下载工具：请先安装 wget 或 curl"
    fi
}

printf '%s\n' "==> 启动 FRP 管理菜单"

# If run via bash <(curl ...), self-install as /usr/bin/frp for future use
if [ ! -f /usr/bin/frp ]; then
    if command -v wget >/dev/null 2>&1; then
        wget -q -O /usr/bin/frp "${REPO_RAW}/bootstrap.sh" 2>/dev/null || true
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL -o /usr/bin/frp "${REPO_RAW}/bootstrap.sh" 2>/dev/null || true
    fi
    [ -s /usr/bin/frp ] && chmod +x /usr/bin/frp || true
fi

mkdir -p "$WORKDIR"
cd "$WORKDIR"

LOCAL_BUNDLE_VERSION=""
[ -f "$VERSION_FILE" ] && LOCAL_BUNDLE_VERSION="$(cat "$VERSION_FILE" 2>/dev/null || true)"
if [ "$LOCAL_BUNDLE_VERSION" != "$SCRIPT_BUNDLE_VERSION" ]; then
    FRP_FORCE_UPDATE="1"
fi

for file in install-openwrt.sh install-server.sh update.sh uninstall-openwrt.sh uninstall-server.sh firewall-openwrt.sh firewall-server.sh info.sh config.sh menu-openwrt.sh menu-server.sh menu.sh; do
    if [ -s "$file" ] && [ "$FRP_FORCE_UPDATE" != "1" ]; then
        :
    else
        [ "$PRINTED" = "1" ] || { log "正在更新脚本..."; PRINTED="1"; }
        download "${REPO_RAW}/${file}?v=${CACHE_BUST}" "$file"
        chmod +x "$file"
    fi
done

[ "${PRINTED:-0}" = "1" ] && log "更新完成"

printf '%s\n' "$SCRIPT_BUNDLE_VERSION" > "$VERSION_FILE"

# If launched from a pipe, stdin may not be the keyboard. Reconnect all stdio
# to the real terminal when available, then launch the interactive menu.
if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    exec < /dev/tty > /dev/tty 2>&1
fi

exec sh ./menu.sh
