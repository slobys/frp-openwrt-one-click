#!/bin/sh
set -eu

# Update installed frps/frpc binaries without touching existing config files.

SCRIPT_VERSION="1.0.0"
FRP_VERSION="${FRP_VERSION:-}"
FALLBACK_FRP_VERSION="0.68.1"
INSTALL_MODE="auto"
TMP_ROOT="/tmp/frp-openwrt-update"
FRPS_BIN="/usr/bin/frps"
FRPC_BIN="/usr/bin/frpc"

log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

usage() {
    cat <<EOF_USAGE
FRP 一键更新脚本 v${SCRIPT_VERSION}

用法:
  sh update.sh [选项]

选项:
  --both          更新 frps + frpc
  --frps-only     只更新 frps
  --frpc-only     只更新 frpc
  --version VER   指定 FRP 版本（例如: 0.68.1）
  --arch ARCH     手动指定 FRP 架构
  -h, --help      显示帮助

说明:
  只替换 /usr/bin/frps 和 /usr/bin/frpc 二进制文件，不覆盖 /etc/frp/*.toml 配置。
  未指定版本时会尝试获取 GitHub 最新版，失败则使用 ${FALLBACK_FRP_VERSION}。
EOF_USAGE
}

require_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户运行"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

parse_args() {
    MANUAL_ARCH=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --both) INSTALL_MODE="both" ;;
            --frps-only) INSTALL_MODE="frps" ;;
            --frpc-only) INSTALL_MODE="frpc" ;;
            --version)
                shift
                [ "$#" -gt 0 ] || die "--version 需要版本号"
                FRP_VERSION="$1"
                ;;
            --arch)
                shift
                [ "$#" -gt 0 ] || die "--arch 需要架构名"
                MANUAL_ARCH="$1"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *) die "未知参数: $1" ;;
        esac
        shift
    done
}

detect_arch() {
    if [ -n "${MANUAL_ARCH:-}" ]; then
        printf '%s\n' "$MANUAL_ARCH"
        return 0
    fi

    case "$(uname -m)" in
        x86_64|amd64) printf '%s\n' "amd64" ;;
        aarch64|arm64) printf '%s\n' "arm64" ;;
        armv7l|armv7*|armv6l|armv6*) printf '%s\n' "arm" ;;
        i386|i686) printf '%s\n' "386" ;;
        mips64el|mips64le) printf '%s\n' "mips64le" ;;
        mips64) printf '%s\n' "mips64" ;;
        mipsel|mipsle) printf '%s\n' "mipsle" ;;
        mips) printf '%s\n' "mips" ;;
        riscv64) printf '%s\n' "riscv64" ;;
        *) die "暂不识别当前 CPU 架构: $(uname -m)。请用 --arch 手动指定，例如 --arch arm64" ;;
    esac
}

get_latest_version() {
    local version=""
    if command -v curl >/dev/null 2>&1; then
        version="$(curl -fsSL --connect-timeout 5 --max-time 10 https://api.github.com/repos/fatedier/frp/releases/latest 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/p' | sed -n '1p' || true)"
    elif command -v wget >/dev/null 2>&1; then
        version="$(wget -qO- --timeout=8 https://api.github.com/repos/fatedier/frp/releases/latest 2>/dev/null | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\([^"]*\)".*/\1/p' | sed -n '1p' || true)"
    fi
    printf '%s\n' "$version"
}

resolve_version() {
    if [ -n "$FRP_VERSION" ]; then
        printf '%s\n' "$FRP_VERSION"
        return 0
    fi

    printf '%s\n' "==> 获取 FRP 最新版本..." >&2
    FRP_VERSION="$(get_latest_version)"
    if [ -z "$FRP_VERSION" ]; then
        FRP_VERSION="$FALLBACK_FRP_VERSION"
        warn "获取最新版本失败，使用默认版本 ${FRP_VERSION}。如需指定版本：sh update.sh --version 0.68.1"
    fi
    printf '%s\n' "$FRP_VERSION"
}

current_version() {
    local bin="$1"
    [ -x "$bin" ] || { printf '%s\n' "未安装"; return 0; }
    "$bin" -v 2>/dev/null | sed -n '1p' || printf '%s\n' "未知"
}

select_targets() {
    NEED_FRPS="0"
    NEED_FRPC="0"
    case "$INSTALL_MODE" in
        both) NEED_FRPS="1"; NEED_FRPC="1" ;;
        frps) NEED_FRPS="1" ;;
        frpc) NEED_FRPC="1" ;;
        auto)
            [ -x "$FRPS_BIN" ] && NEED_FRPS="1"
            [ -x "$FRPC_BIN" ] && NEED_FRPC="1"
            [ "$NEED_FRPS" = "1" ] || [ "$NEED_FRPC" = "1" ] || die "未检测到已安装的 frps/frpc，请先安装或指定 --frps-only / --frpc-only"
            ;;
        *) die "无效更新模式: $INSTALL_MODE" ;;
    esac
}

download_file() {
    local url="$1"
    local dest="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$dest" "$url"
    else
        curl -fL -o "$dest" "$url"
    fi
}

download_frp() {
    local arch="$1"
    local pkg="frp_${FRP_VERSION}_linux_${arch}.tar.gz"
    local base="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${pkg}"
    local url="$base"

    rm -rf "$TMP_ROOT"
    mkdir -p "$TMP_ROOT"
    cd "$TMP_ROOT"

    log "下载 FRP ${FRP_VERSION} (${arch})"
    if ! download_file "$url" "$pkg"; then
        rm -f "$pkg"
        url="https://ghfast.top/${base}"
        log "GitHub 下载失败，切换到镜像下载"
        download_file "$url" "$pkg"
    fi

    log "解压 ${pkg}"
    tar -zxf "$pkg"
    FRP_EXTRACT_DIR="${TMP_ROOT}/frp_${FRP_VERSION}_linux_${arch}"
    [ -d "$FRP_EXTRACT_DIR" ] || die "解压目录不存在: $FRP_EXTRACT_DIR"
}

backup_bin() {
    local bin="$1"
    if [ -f "$bin" ]; then
        cp "$bin" "${bin}.bak.$(date +%Y%m%d%H%M%S 2>/dev/null || echo old)"
    fi
}

install_bin() {
    local name="$1"
    local dest="$2"
    [ -f "${FRP_EXTRACT_DIR}/${name}" ] || die "安装包内未找到 ${name}"
    backup_bin "$dest"
    cp "${FRP_EXTRACT_DIR}/${name}" "$dest"
    chmod +x "$dest"
    log "${name} 已更新到版本: $($dest -v)"
}

restart_service() {
    local service="$1"
    if [ -x "/etc/init.d/${service}" ]; then
        "/etc/init.d/${service}" restart
    elif command -v systemctl >/dev/null 2>&1 && systemctl is-enabled "$service" >/dev/null 2>&1; then
        systemctl restart "$service"
    else
        warn "未找到 ${service} 服务，请手动重启"
        return 0
    fi
}

main() {
    parse_args "$@"
    require_root
    need_cmd uname
    need_cmd tar
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        die "缺少下载工具：请先安装 wget 或 curl"
    fi

    select_targets
    FRP_VERSION="$(resolve_version)"
    arch="$(detect_arch)"

    echo
    log "当前 frps 版本: $(current_version "$FRPS_BIN")"
    log "当前 frpc 版本: $(current_version "$FRPC_BIN")"
    log "目标 FRP 版本: ${FRP_VERSION}"

    download_frp "$arch"

    if [ "$NEED_FRPS" = "1" ]; then
        install_bin frps "$FRPS_BIN"
        restart_service frps
    fi
    if [ "$NEED_FRPC" = "1" ]; then
        install_bin frpc "$FRPC_BIN"
        restart_service frpc
    fi

    echo
    log "更新完成。配置文件未被覆盖：/etc/frp/*.toml"
}

main "$@"
