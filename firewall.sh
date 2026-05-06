#!/bin/sh
set -eu

# OpenWrt/iStoreOS firewall helper for FRP ports.

RULE_PREFIX="Allow-FRP"
DEFAULT_PORT="60000-60999"

log() { printf '%s\n' "==> $*"; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

usage() {
    cat <<'EOF_USAGE'
用法:
  sh firewall.sh [端口或端口范围]

示例:
  sh firewall.sh 7500
  sh firewall.sh 7400
  sh firewall.sh 7000
  sh firewall.sh 60000-60999

不带参数运行时会进入交互模式。
EOF_USAGE
}

require_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户运行"
}

validate_port() {
    port="$1"
    case "$port" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null
}

validate_port_spec() {
    spec="$1"
    case "$spec" in
        *-*)
            start="${spec%-*}"
            end="${spec#*-}"
            validate_port "$start" || return 1
            validate_port "$end" || return 1
            [ "$start" -le "$end" ]
            ;;
        *)
            validate_port "$spec"
            ;;
    esac
}

port_rule_name() {
    spec="$1"
    safe_spec="$(printf '%s' "$spec" | tr -c 'A-Za-z0-9_' '-')"
    printf '%s-%s\n' "$RULE_PREFIX" "$safe_spec"
}

rule_exists() {
    name="$1"
    uci show firewall 2>/dev/null | grep -q "\.name='${name}'"
}

add_rule() {
    spec="$1"
    name="$(port_rule_name "$spec")"

    validate_port_spec "$spec" || die "端口格式无效: ${spec}。请输入单个端口 7500 或范围 60000-60999"

    if rule_exists "$name"; then
        log "防火墙规则已存在: ${name} (${spec})"
        return 0
    fi

    log "放行 WAN 入站端口: ${spec} (tcp/udp)"
    uci add firewall rule >/dev/null
    uci set firewall.@rule[-1].name="$name"
    uci set firewall.@rule[-1].src='wan'
    uci set firewall.@rule[-1].proto='tcp udp'
    uci set firewall.@rule[-1].dest_port="$spec"
    uci set firewall.@rule[-1].target='ACCEPT'
    uci commit firewall
    /etc/init.d/firewall restart
    log "已放行: ${spec}"
}

interactive() {
    cat <<EOF_MENU
请选择要放行的端口：
  1) frps 服务端连接端口 7000
  2) frps Dashboard 面板端口 7500
  3) frpc Web 管理面板端口 7400
  4) frps 默认远程映射端口范围 60000-60999
  5) 自定义单个端口或端口范围
EOF_MENU
    printf '请选择 [默认: 4]: '
    read -r choice || true
    choice="${choice:-4}"

    case "$choice" in
        1) add_rule 7000 ;;
        2) add_rule 7500 ;;
        3) add_rule 7400 ;;
        4) add_rule 60000-60999 ;;
        5)
            printf '请输入端口，例如 7500 或 60000-60999 [默认: %s]: ' "$DEFAULT_PORT"
            read -r spec || true
            spec="${spec:-$DEFAULT_PORT}"
            add_rule "$spec"
            ;;
        *) die "无效选择: $choice" ;;
    esac
}

main() {
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
    esac

    require_root
    command -v uci >/dev/null 2>&1 || die "缺少 uci，当前系统不像 OpenWrt/iStoreOS"
    [ -x /etc/init.d/firewall ] || die "找不到 /etc/init.d/firewall"

    if [ "$#" -gt 0 ]; then
        add_rule "$1"
    else
        interactive
    fi
}

main "$@"
