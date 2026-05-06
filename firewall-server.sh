#!/bin/sh
set -eu

# VPS/server firewall helper for FRP ports (iptables).
# iptables uses colon (:) for port ranges.

DEFAULT_PORT="60000:60999"

log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

usage() {
    cat <<'EOF_USAGE'
用法:
  sh firewall-server.sh             进入交互菜单
  sh firewall-server.sh add 7500      放行单个端口
  sh firewall-server.sh add 60000:60999
  sh firewall-server.sh delete 7500   删除放行
  sh firewall-server.sh list          查看 FRP 放行规则
  sh firewall-server.sh clear         删除所有 FRP 规则
EOF_USAGE
}

require_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户运行"
}

require_iptables() {
    command -v iptables >/dev/null 2>&1 || die "缺少 iptables"
}

save_iptables() {
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save >/dev/null 2>&1 || true
    elif command -v iptables-save >/dev/null 2>&1; then
        mkdir -p /etc/iptables 2>/dev/null || true
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || warn "建议安装 iptables-persistent 以持久化规则"
    fi
}

validate_port() {
    port="$1"
    case "$port" in ''|*[!0-9]*) return 1 ;; esac
    [ "$port" -ge 1 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null
}

validate_port_spec() {
    spec="$1"
    case "$spec" in
        *:*) start="${spec%%:*}"; end="${spec##*:}"
             validate_port "$start" && validate_port "$end" && [ "$start" -le "$end" ] ;;
        *-*) start="${spec%-*}"; end="${spec#*-}"
             validate_port "$start" && validate_port "$end" && [ "$start" -le "$end" ] ;;
        *) validate_port "$spec" ;;
    esac
}

chain_exists() {
    iptables -L FRP_ACCEPT >/dev/null 2>&1
}

list_rules() {
    if chain_exists; then
        log "当前 FRP 放行规则："
        iptables -L FRP_ACCEPT -n --line-numbers 2>/dev/null || true
    else
        log "当前没有 FRP 放行规则"
    fi
}

add_rule() {
    spec="$1"
    validate_port_spec "$spec" || die "端口格式无效: ${spec}"

    if ! chain_exists; then
        iptables -N FRP_ACCEPT
        iptables -I INPUT -j FRP_ACCEPT
    fi

    log "放行端口: ${spec} (tcp/udp)"
    iptables -A FRP_ACCEPT -p tcp --dport "${spec}" -j ACCEPT
    iptables -A FRP_ACCEPT -p udp --dport "${spec}" -j ACCEPT
    log "已放行: ${spec}"
    save_iptables
}

delete_rule() {
    spec="$1"
    validate_port_spec "$spec" || die "端口格式无效: ${spec}"

    if ! chain_exists; then
        warn "没有 FRP 放行规则"
        return 0
    fi

    log "删除端口规则: ${spec}"
    while :; do
        line="$(iptables -L FRP_ACCEPT -n --line-numbers 2>/dev/null \
            | awk -v s="$spec" '$0 ~ "dpt:"s {print $1; exit}')"
        [ -n "$line" ] || break
        iptables -D FRP_ACCEPT "$line"
    done
    log "已删除: ${spec}"
    save_iptables
}

clear_rules() {
    if ! chain_exists; then
        log "没有 FRP 放行规则"
        return 0
    fi
    iptables -D INPUT -j FRP_ACCEPT 2>/dev/null || true
    iptables -F FRP_ACCEPT 2>/dev/null || true
    iptables -X FRP_ACCEPT 2>/dev/null || true
    log "已删除所有 FRP 放行规则"
    save_iptables
}

prompt_port_spec() {
    printf '请输入端口，例如 7500 或 60000:60999 [默认: %s]: ' "$DEFAULT_PORT" >&2
    read -r spec || true
    printf '%s\n' "${spec:-$DEFAULT_PORT}"
}

interactive() {
    cat <<'EOF_MENU'
请选择防火墙操作：
 1) 放行端口
 2) 查看 FRP 放行规则
 3) 删除某个放行端口
 4) 删除所有 FRP 规则
 0) 返回
EOF_MENU
    printf '请选择 [默认: 1]: '
    read -r choice || true
    choice="${choice:-1}"
    case "$choice" in
        1)
            cat <<'EOF_MENU'
请选择：1) 7000  2) 7500  3) 60000:60999  4) 自定义
EOF_MENU
            printf '请选择 [默认: 1]: '
            read -r c || true
            case "${c:-1}" in
                1) add_rule 7000 ;;
                2) add_rule 7500 ;;
                3) add_rule 60000:60999 ;;
                4) add_rule "$(prompt_port_spec)" ;;
                *) die "无效选择" ;;
            esac ;;
        2) list_rules ;;
        3)
            printf '请输入要删除的端口，例如 7500 或 60000:60999: '
            read -r spec || true
            [ -n "$spec" ] || die "端口不能为空"
            delete_rule "$spec"
            ;;
        4)
            printf '确认删除所有 FRP 规则？输入 yes 继续: '
            read -r confirm || true
            case "$confirm" in yes|YES|y|Y) clear_rules ;; *) echo "已取消" ;; esac
            ;;
        0) exit 0 ;;
        *) die "无效选择: $choice" ;;
    esac
}

main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
    esac
    require_root
    require_iptables
    case "${1:-}" in
        '') interactive ;;
        add) shift; [ "$#" -gt 0 ] || die "缺少端口"; add_rule "$1" ;;
        delete|del) shift; [ "$#" -gt 0 ] || die "缺少端口"; delete_rule "$1" ;;
        list|ls) list_rules ;;
        clear) clear_rules ;;
        *) add_rule "$1" ;;
    esac
}

main "$@"
