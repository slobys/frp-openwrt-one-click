#!/bin/sh
set -eu

# FRP OpenWrt/iStoreOS one-click installer
# Installs frps and/or frpc with procd init.d services.

SCRIPT_VERSION="1.3.3"
FRP_VERSION="${FRP_VERSION:-0.68.1}"
INSTALL_MODE="both"
TMP_ROOT="/tmp/frp-openwrt-download"
FRP_DIR="/etc/frp"
FRPS_BIN="/usr/bin/frps"
FRPC_BIN="/usr/bin/frpc"
FRPS_CONFIG="${FRP_DIR}/frps.toml"
FRPC_CONFIG="${FRP_DIR}/frpc.toml"
FRPS_INIT="/etc/init.d/frps"
FRPC_INIT="/etc/init.d/frpc"

# Defaults can be overridden by environment variables before running the script.
FRPS_BIND_ADDR="${FRPS_BIND_ADDR:-0.0.0.0}"
FRPS_BIND_PORT="${FRPS_BIND_PORT:-7000}"
FRPS_DASHBOARD_ADDR="${FRPS_DASHBOARD_ADDR:-0.0.0.0}"
FRPS_DASHBOARD_PORT="${FRPS_DASHBOARD_PORT:-7500}"
FRPS_DASHBOARD_USER="${FRPS_DASHBOARD_USER:-}"
FRPS_DASHBOARD_PASSWORD="${FRPS_DASHBOARD_PASSWORD:-}"
FRP_TOKEN="${FRP_TOKEN:-}"
ALLOW_PORT_START="${ALLOW_PORT_START:-60000}"
ALLOW_PORT_END="${ALLOW_PORT_END:-60999}"

FRPC_SERVER_ADDR="${FRPC_SERVER_ADDR:-127.0.0.1}"
FRPC_SERVER_PORT="${FRPC_SERVER_PORT:-7000}"
FRPC_DASHBOARD_PORT="${FRPC_DASHBOARD_PORT:-7400}"
FRPC_DASHBOARD_USER="${FRPC_DASHBOARD_USER:-}"
FRPC_DASHBOARD_PASSWORD="${FRPC_DASHBOARD_PASSWORD:-}"

log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

usage() {
    cat <<EOF_USAGE
FRP OpenWrt/iStoreOS 一键安装脚本 v${SCRIPT_VERSION}

用法:
  sh install.sh [选项]

选项:
  --both          安装 frps + frpc（默认，适合 iStoreOS 同机运行）
  --frps-only     只安装服务端 frps
  --frpc-only     只安装客户端 frpc
  --version VER   指定 FRP 版本（默认: ${FRP_VERSION}）
  --arch ARCH     手动指定 FRP 架构，如 arm64/amd64/arm/mipsle
  -h, --help      显示帮助

说明:
  安装时可自定义 frps/frpc Web 面板端口、用户名、密码。
  用户名、密码和 token 默认随机生成，安装完成后会输出可复制信息。

环境变量示例:
  FRP_TOKEN='your_token' FRPS_DASHBOARD_PASSWORD='new_pass' sh install.sh
  FRPC_SERVER_ADDR='1.2.3.4' FRPC_SERVER_PORT='7000' sh install.sh --frpc-only
EOF_USAGE
}

require_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户运行：sh install.sh"
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

set_config_var() {
    local var_name="$1"
    local value="$2"
    case "$var_name" in
        FRPS_DASHBOARD_PORT) FRPS_DASHBOARD_PORT="$value" ;;
        FRPS_DASHBOARD_USER) FRPS_DASHBOARD_USER="$value" ;;
        FRPS_DASHBOARD_PASSWORD) FRPS_DASHBOARD_PASSWORD="$value" ;;
        FRPC_DASHBOARD_PORT) FRPC_DASHBOARD_PORT="$value" ;;
        FRPC_DASHBOARD_USER) FRPC_DASHBOARD_USER="$value" ;;
        FRPC_DASHBOARD_PASSWORD) FRPC_DASHBOARD_PASSWORD="$value" ;;
        FRPC_SERVER_ADDR) FRPC_SERVER_ADDR="$value" ;;
        FRPC_SERVER_PORT) FRPC_SERVER_PORT="$value" ;;
        FRP_TOKEN) FRP_TOKEN="$value" ;;
        *) die "内部错误：未知配置变量 ${var_name}" ;;
    esac
}

prompt_value() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="$3"
    local value=""

    printf '%s [默认: %s]: ' "$prompt_text" "$default_value"
    read -r value || true
    value="${value:-$default_value}"
    set_config_var "$var_name" "$value"
}

prompt_port() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="$3"
    local value=""

    while :; do
        printf '%s [默认: %s]: ' "$prompt_text" "$default_value"
        read -r value || true
        value="${value:-$default_value}"
        if validate_port "$value"; then
            set_config_var "$var_name" "$value"
            return 0
        fi
        warn "端口无效：${value}，请输入 1-65535 之间的数字"
    done
}

configure_dashboard() {
    local need_frps="$1"
    local need_frpc="$2"

    [ -n "$FRP_TOKEN" ] || FRP_TOKEN="frp_$(random_hex 24)"

    if [ "$need_frps" = "1" ]; then
        [ -n "$FRPS_DASHBOARD_USER" ] || FRPS_DASHBOARD_USER="admin_$(random_hex 4)"
        [ -n "$FRPS_DASHBOARD_PASSWORD" ] || FRPS_DASHBOARD_PASSWORD="frps_$(random_hex 12)"
        echo
        log "配置 frps Web Dashboard"
        prompt_port FRPS_DASHBOARD_PORT "frps Dashboard 端口" "$FRPS_DASHBOARD_PORT"
        prompt_value FRPS_DASHBOARD_USER "frps Dashboard 用户名" "$FRPS_DASHBOARD_USER"
        prompt_value FRPS_DASHBOARD_PASSWORD "frps Dashboard 密码" "$FRPS_DASHBOARD_PASSWORD"
    fi

    if [ "$need_frpc" = "1" ]; then
        [ -n "$FRPC_DASHBOARD_USER" ] || FRPC_DASHBOARD_USER="admin_$(random_hex 4)"
        [ -n "$FRPC_DASHBOARD_PASSWORD" ] || FRPC_DASHBOARD_PASSWORD="frpc_$(random_hex 12)"
        echo
        log "配置 frpc Web 管理面板"
        if [ "$need_frps" != "1" ]; then
            # frpc-only: also ask where the remote frps is
            log "配置远端 frps 连接信息"
            prompt_value FRPC_SERVER_ADDR "远端 frps 服务器地址" "$FRPC_SERVER_ADDR"
            prompt_port FRPC_SERVER_PORT "远端 frps 端口" "$FRPC_SERVER_PORT"
            prompt_value FRP_TOKEN "frp token（需与远端一致）" "$FRP_TOKEN"
            echo
        fi
        prompt_port FRPC_DASHBOARD_PORT "frpc Web 管理面板端口" "$FRPC_DASHBOARD_PORT"
        prompt_value FRPC_DASHBOARD_USER "frpc Web 管理面板用户名" "$FRPC_DASHBOARD_USER"
        prompt_value FRPC_DASHBOARD_PASSWORD "frpc Web 管理面板密码" "$FRPC_DASHBOARD_PASSWORD"
    fi
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
        armv7l|armv7*) printf '%s\n' "arm" ;;
        armv6l|armv6*) printf '%s\n' "arm" ;;
        i386|i686) printf '%s\n' "386" ;;
        mips64el|mips64le) printf '%s\n' "mips64le" ;;
        mips64) printf '%s\n' "mips64" ;;
        mipsel|mipsle) printf '%s\n' "mipsle" ;;
        mips) printf '%s\n' "mips" ;;
        riscv64) printf '%s\n' "riscv64" ;;
        *)
            die "暂不识别当前 CPU 架构: $(uname -m)。请用 --arch 手动指定，例如 --arch arm64"
            ;;
    esac
}

get_lan_ip() {
    local ip=""
    if command -v uci >/dev/null 2>&1; then
        ip="$(uci get network.lan.ipaddr 2>/dev/null || true)"
    fi
    [ -n "$ip" ] || ip="0.0.0.0"
    printf '%s\n' "$ip"
}

get_wan_ip() {
    local ip=""
    if command -v uci >/dev/null 2>&1; then
        ip="$(uci -q get network.wan.ipaddr 2>/dev/null || true)"
    fi
    if [ -z "$ip" ] && command -v ip >/dev/null 2>&1; then
        ip="$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \([0-9.][0-9.]*\).*/\1/p' | sed -n '1p')"
    fi
    [ -n "$ip" ] || ip="未知"
    printf '%s\n' "$ip"
}

get_public_ip() {
    local ip=""
    local url
    for url in \
        https://api.ipify.org \
        https://ipv4.icanhazip.com \
        https://ifconfig.me/ip
    do
        if command -v wget >/dev/null 2>&1; then
            ip="$(wget -qO- --timeout=5 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
        elif command -v curl >/dev/null 2>&1; then
            ip="$(curl -fsSL --connect-timeout 5 --max-time 8 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
        fi
        case "$ip" in
            *.*.*.*) printf '%s\n' "$ip"; return 0 ;;
        esac
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

install_bins() {
    local need_frps="$1"
    local need_frpc="$2"

    [ "$need_frps" = "1" ] && {
        cp "${FRP_EXTRACT_DIR}/frps" "$FRPS_BIN"
        chmod +x "$FRPS_BIN"
        log "frps 版本: $($FRPS_BIN -v)"
    }

    [ "$need_frpc" = "1" ] && {
        cp "${FRP_EXTRACT_DIR}/frpc" "$FRPC_BIN"
        chmod +x "$FRPC_BIN"
        log "frpc 版本: $($FRPC_BIN -v)"
    }
}

write_frps_config() {
    mkdir -p "$FRP_DIR"
    cat > "$FRPS_CONFIG" <<EOF_FRPS
# =========================
# frps 服务端基础配置模板
# 适合：家里有公网 IP，软路由作为 frps 服务端
# =========================

bindAddr = "${FRPS_BIND_ADDR}"
bindPort = ${FRPS_BIND_PORT}

auth.method = "token"
auth.token = "${FRP_TOKEN}"

# frps Web Dashboard: http://软路由IP:${FRPS_DASHBOARD_PORT}
webServer.addr = "${FRPS_DASHBOARD_ADDR}"
webServer.port = ${FRPS_DASHBOARD_PORT}
webServer.user = "${FRPS_DASHBOARD_USER}"
webServer.password = "${FRPS_DASHBOARD_PASSWORD}"

# 限制 frpc 可以使用的远程端口范围
allowPorts = [
  { start = ${ALLOW_PORT_START}, end = ${ALLOW_PORT_END} }
]
EOF_FRPS
}

read_token_from_frps() {
    if [ -f "$FRPS_CONFIG" ]; then
        awk -F'"' '/auth.token/ {print $2; exit}' "$FRPS_CONFIG"
    else
        printf '%s\n' "$FRP_TOKEN"
    fi
}

write_frpc_config() {
    local lan_ip="$1"
    local token
    token="$(read_token_from_frps)"
    [ -n "$token" ] || token="$FRP_TOKEN"

    mkdir -p "$FRP_DIR"
    cat > "$FRPC_CONFIG" <<EOF_FRPC
# =========================
# frpc 客户端配置
# 场景：iStoreOS 同时运行 frps + frpc，或作为独立客户端连接远端 frps
# =========================

serverAddr = "${FRPC_SERVER_ADDR}"
serverPort = ${FRPC_SERVER_PORT}

auth.method = "token"
auth.token = "${token}"

# frpc Web 管理面板: http://${lan_ip}:${FRPC_DASHBOARD_PORT}
webServer.addr = "${lan_ip}"
webServer.port = ${FRPC_DASHBOARD_PORT}
webServer.user = "${FRPC_DASHBOARD_USER}"
webServer.password = "${FRPC_DASHBOARD_PASSWORD}"

# Store 动态管理功能：可在 frpc 面板里新增、修改、删除代理
[store]
path = "${FRP_DIR}/frpc_store.json"
EOF_FRPC
}

write_frps_init() {
    cat > "$FRPS_INIT" <<'EOF_FRPS_INIT'
#!/bin/sh /etc/rc.common

START=99
STOP=10

USE_PROCD=1
PROG=/usr/bin/frps
CONFIG=/etc/frp/frps.toml

start_service() {
    procd_open_instance
    procd_set_param command $PROG -c $CONFIG
    procd_set_param respawn 3600 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall frps 2>/dev/null || true
}
EOF_FRPS_INIT
    chmod +x "$FRPS_INIT"
}

write_frpc_init() {
    cat > "$FRPC_INIT" <<'EOF_FRPC_INIT'
#!/bin/sh /etc/rc.common

START=98
STOP=10

USE_PROCD=1
PROG=/usr/bin/frpc
CONFIG=/etc/frp/frpc.toml

start_service() {
    procd_open_instance
    procd_set_param command $PROG -c $CONFIG
    procd_set_param respawn 3600 5 5
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}

stop_service() {
    killall frpc 2>/dev/null || true
}
EOF_FRPC_INIT
    chmod +x "$FRPC_INIT"
}

enable_and_restart() {
    local service="$1"
    "/etc/init.d/${service}" enable
    "/etc/init.d/${service}" restart
}

print_summary() {
    local lan_ip="$1"
    local wan_ip="$2"
    local public_ip="$3"
    echo
    log "安装完成"
    echo "LAN IP: ${lan_ip}"
    echo "WAN IP: ${wan_ip}"
    echo "公网出口 IP: ${public_ip}"

    echo
    echo "================ 可复制访问信息 ================"
    if [ "$INSTALL_MODE" = "both" ] || [ "$INSTALL_MODE" = "frps" ]; then
        echo "frps Dashboard（LAN）: http://${lan_ip}:${FRPS_DASHBOARD_PORT}"
        if [ "$wan_ip" != "未知" ]; then
            echo "frps Dashboard（WAN）: http://${wan_ip}:${FRPS_DASHBOARD_PORT}"
        fi
        if [ "$public_ip" != "未知" ]; then
            echo "frps Dashboard（公网出口）: http://${public_ip}:${FRPS_DASHBOARD_PORT}"
        fi
        echo "frps 用户名: ${FRPS_DASHBOARD_USER}"
        echo "frps 密码: ${FRPS_DASHBOARD_PASSWORD}"
        echo "frps 客户端连接端口: ${FRPS_BIND_PORT}"
        echo "frps token: ${FRP_TOKEN}"
        echo "frps 允许映射端口: ${ALLOW_PORT_START}-${ALLOW_PORT_END}"
    fi

    if [ "$INSTALL_MODE" = "both" ] || [ "$INSTALL_MODE" = "frpc" ]; then
        echo
        echo "frpc Web 面板（LAN）: http://${lan_ip}:${FRPC_DASHBOARD_PORT}"
        if [ "$wan_ip" != "未知" ]; then
            echo "frpc Web 面板（WAN）: http://${wan_ip}:${FRPC_DASHBOARD_PORT}"
        fi
        if [ "$public_ip" != "未知" ]; then
            echo "frpc Web 面板（公网出口）: http://${public_ip}:${FRPC_DASHBOARD_PORT}"
        fi
        echo "frpc 用户名: ${FRPC_DASHBOARD_USER}"
        echo "frpc 密码: ${FRPC_DASHBOARD_PASSWORD}"
        echo "frpc 连接服务端: ${FRPC_SERVER_ADDR}:${FRPC_SERVER_PORT}"
    fi
    echo "================================================="
    echo
    echo "常用命令："
    echo "  /etc/init.d/frps start|stop|restart|enable|disable"
    echo "  /etc/init.d/frpc start|stop|restart|enable|disable"
    echo "  logread | grep frp"
}

main() {
    parse_args "$@"
    require_root
    need_cmd uname
    need_cmd tar

    local arch lan_ip wan_ip public_ip need_frps need_frpc
    arch="$(detect_arch)"
    lan_ip="$(get_lan_ip)"
    wan_ip="$(get_wan_ip)"
    public_ip="$(get_public_ip)"
    need_frps="0"
    need_frpc="0"

    case "$INSTALL_MODE" in
        both) need_frps="1"; need_frpc="1" ;;
        frps) need_frps="1" ;;
        frpc) need_frpc="1" ;;
        *) die "无效安装模式: $INSTALL_MODE" ;;
    esac

    configure_dashboard "$need_frps" "$need_frpc"

    download_frp "$arch"
    install_bins "$need_frps" "$need_frpc"

    if [ "$need_frps" = "1" ]; then
        write_frps_config
        write_frps_init
        enable_and_restart frps
        log "frps 已设置开机自启，并已后台运行"
    fi

    if [ "$need_frpc" = "1" ]; then
        write_frpc_config "$lan_ip"
        write_frpc_init
        enable_and_restart frpc
        log "frpc 已设置开机自启，并已后台运行"
    fi

    print_summary "$lan_ip" "$wan_ip" "$public_ip"
}

main "$@"
