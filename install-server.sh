#!/bin/sh
set -eu

# FRP server (VPS) one-click installer
# Installs frps only with systemd service.

SCRIPT_VERSION="2.0.0"
FRP_VERSION="${FRP_VERSION:-0.68.1}"
TMP_ROOT="/tmp/frp-openwrt-download"
FRP_DIR="/etc/frp"
FRPS_BIN="/usr/bin/frps"
FRPS_CONFIG="${FRP_DIR}/frps.toml"
SERVICE_FILE="/etc/systemd/system/frps.service"

FRPS_BIND_ADDR="${FRPS_BIND_ADDR:-0.0.0.0}"
FRPS_BIND_PORT="${FRPS_BIND_PORT:-7000}"
FRPS_DASHBOARD_ADDR="${FRPS_DASHBOARD_ADDR:-0.0.0.0}"
FRPS_DASHBOARD_PORT="${FRPS_DASHBOARD_PORT:-7500}"
FRPS_DASHBOARD_USER="${FRPS_DASHBOARD_USER:-}"
FRPS_DASHBOARD_PASSWORD="${FRPS_DASHBOARD_PASSWORD:-}"
FRP_TOKEN="${FRP_TOKEN:-}"
ALLOW_PORT_START="${ALLOW_PORT_START:-60000}"
ALLOW_PORT_END="${ALLOW_PORT_END:-60999}"

log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

usage() {
    cat <<EOF_USAGE
FRP 服务器一键安装脚本 v${SCRIPT_VERSION}

用法:
  sh install-server.sh [选项]

选项:
  --version VER   指定 FRP 版本（默认: ${FRP_VERSION}）
  --arch ARCH     手动指定 FRP 架构
  -h, --help      显示帮助

说明:
  在 VPS/云服务器上安装 frps 服务端，使用 systemd 管理。
  安装时可自定义面板端口、用户名、密码，默认随机生成。
EOF_USAGE
}

require_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户运行"
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

random_hex() {
    local len="$1"
    local value=""
    if [ -r /dev/urandom ] && command -v hexdump >/dev/null 2>&1; then
        value="$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | hexdump -ve '/1 "%02x"' | cut -c "1-${len}" || true)"
    fi
    [ -n "$value" ] || value="$(date +%s 2>/dev/null || echo 2026)$$"
    printf '%s\n' "$value"
}

validate_port() {
    local port="$1"
    case "$port" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null
}

prompt_value() {
    local prompt_text="$1"
    local default_value="$2"
    local value=""
    printf '%s [默认: %s]: ' "$prompt_text" "$default_value" >&2
    read -r value || true
    printf '%s\n' "${value:-$default_value}"
}

prompt_port() {
    local prompt_text="$1"
    local default_value="$2"
    local value=""
    while :; do
        printf '%s [默认: %s]: ' "$prompt_text" "$default_value" >&2
        read -r value || true
        value="${value:-$default_value}"
        if validate_port "$value"; then
            printf '%s\n' "$value"
            return 0
        fi
        warn "端口无效：${value}，请输入 1-65535 之间的数字"
    done
}

detect_arch() {
    local manual_arch="${1:-}"
    [ -n "$manual_arch" ] && { printf '%s\n' "$manual_arch"; return 0; }
    case "$(uname -m)" in
        x86_64|amd64) printf '%s\n' "amd64" ;;
        aarch64|arm64) printf '%s\n' "arm64" ;;
        armv7l|armv7*) printf '%s\n' "arm" ;;
        i386|i686) printf '%s\n' "386" ;;
        riscv64) printf '%s\n' "riscv64" ;;
        *) die "暂不识别当前 CPU 架构: $(uname -m)。请用 --arch 手动指定" ;;
    esac
}

get_public_ip() {
    local ip=""
    for url in https://api.ipify.org https://ipv4.icanhazip.com https://ifconfig.me/ip; do
        if command -v curl >/dev/null 2>&1; then
            ip="$(curl -fsSL --connect-timeout 5 --max-time 8 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
        elif command -v wget >/dev/null 2>&1; then
            ip="$(wget -qO- --timeout=5 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
        fi
        case "$ip" in *.*.*.*) printf '%s\n' "$ip"; return 0 ;; esac
    done
    printf '%s\n' "未知"
}

download_frp() {
    local arch="$1"
    local pkg="frp_${FRP_VERSION}_linux_${arch}.tar.gz"
    local url="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${pkg}"

    rm -rf "$TMP_ROOT"
    mkdir -p "$TMP_ROOT"
    cd "$TMP_ROOT"

    log "下载 FRP ${FRP_VERSION} (${arch})"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$pkg" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fL -o "$pkg" "$url"
    else
        die "缺少下载工具：请先安装 wget 或 curl"
    fi

    log "解压 ${pkg}"
    tar -zxf "$pkg"
    FRP_EXTRACT_DIR="${TMP_ROOT}/frp_${FRP_VERSION}_linux_${arch}"
    [ -d "$FRP_EXTRACT_DIR" ] || die "解压目录不存在: $FRP_EXTRACT_DIR"
}

install_frps_bin() {
    cp "${FRP_EXTRACT_DIR}/frps" "$FRPS_BIN"
    chmod +x "$FRPS_BIN"
    log "frps 版本: $($FRPS_BIN -v)"
}

write_frps_config() {
    mkdir -p "$FRP_DIR"
    cat > "$FRPS_CONFIG" <<EOF_FRPS
bindAddr = "${FRPS_BIND_ADDR}"
bindPort = ${FRPS_BIND_PORT}

auth.method = "token"
auth.token = "${FRP_TOKEN}"

webServer.addr = "${FRPS_DASHBOARD_ADDR}"
webServer.port = ${FRPS_DASHBOARD_PORT}
webServer.user = "${FRPS_DASHBOARD_USER}"
webServer.password = "${FRPS_DASHBOARD_PASSWORD}"

allowPorts = [
  { start = ${ALLOW_PORT_START}, end = ${ALLOW_PORT_END} }
]
EOF_FRPS
}

write_systemd_service() {
    cat > "$SERVICE_FILE" <<EOF_SERVICE
[Unit]
Description=frps server
After=network.target

[Service]
Type=simple
ExecStart=${FRPS_BIN} -c ${FRPS_CONFIG}
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF_SERVICE
    systemctl daemon-reload
    systemctl enable frps
    systemctl restart frps
    log "frps systemd 服务已设置开机自启"
}

print_summary() {
    local public_ip="$1"
    echo
    log "安装完成"
    echo "公网 IP: ${public_ip}"
    echo
    echo "================ 可复制访问信息 ================"
    echo "frps Dashboard: http://${public_ip}:${FRPS_DASHBOARD_PORT}"
    echo "frps 用户名: ${FRPS_DASHBOARD_USER}"
    echo "frps 密码: ${FRPS_DASHBOARD_PASSWORD}"
    echo "frps 客户端连接端口: ${FRPS_BIND_PORT}"
    echo "frps token: ${FRP_TOKEN}"
    echo "================================================="
    echo
    echo "常用命令："
    echo "  systemctl start|stop|restart|status frps"
    echo "  journalctl -u frps -f"
}

parse_args() {
    local manual_arch=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --version) shift; [ "$#" -gt 0 ] || die "--version 需要版本号"; FRP_VERSION="$1" ;;
            --arch) shift; [ "$#" -gt 0 ] || die "--arch 需要架构名"; manual_arch="$1" ;;
            -h|--help) usage; exit 0 ;;
            *) die "未知参数: $1" ;;
        esac
        shift
    done
    printf '%s\n' "${manual_arch:-}"
}

configure_dashboard() {
    echo
    log "配置 frps Web Dashboard"
    FRP_TOKEN="${FRP_TOKEN:-frp_$(random_hex 24)}"
    FRPS_DASHBOARD_USER="${FRPS_DASHBOARD_USER:-admin_$(random_hex 4)}"
    FRPS_DASHBOARD_PASSWORD="${FRPS_DASHBOARD_PASSWORD:-frps_$(random_hex 12)}"
    FRPS_DASHBOARD_PORT="$(prompt_port 'frps Dashboard 端口' "$FRPS_DASHBOARD_PORT")"
    FRPS_DASHBOARD_USER="$(prompt_value 'frps Dashboard 用户名' "$FRPS_DASHBOARD_USER")"
    FRPS_DASHBOARD_PASSWORD="$(prompt_value 'frps Dashboard 密码' "$FRPS_DASHBOARD_PASSWORD")"
}

main() {
    local manual_arch
    manual_arch="$(parse_args "$@")"
    require_root
    need_cmd uname
    need_cmd tar

    local arch public_ip
    arch="$(detect_arch "$manual_arch")"

    configure_dashboard
    public_ip="$(get_public_ip)"

    download_frp "$arch"
    install_frps_bin
    write_frps_config
    write_systemd_service

    print_summary "$public_ip"
}

main "$@"
