#!/bin/sh
set -eu

# OpenWrt/iStoreOS firewall helper for FRP ports.

RULE_PREFIX="Allow-FRP"
DEFAULT_PORT="60000-60999"

log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

usage() {
    cat <<'EOF_USAGE'
用法:
  sh firewall.sh                 进入交互菜单
  sh firewall.sh add 7500         放行单个端口
  sh firewall.sh add 60000-60999  放行端口范围
  sh firewall.sh delete 7500      删除单个端口放行规则
  sh firewall.sh delete 60000-60999
  sh firewall.sh list             查看已放行的 FRP 端口
  sh firewall.sh clear            删除所有 Allow-FRP-* 规则

兼容旧用法:
  sh firewall.sh 7500             等同于 sh firewall.sh add 7500
  sh firewall.sh 60000-60999      等同于 sh firewall.sh add 60000-60999
EOF_USAGE
}

require_root() {
    [ "$(id -u)" = "0" ] || die "请使用 root 用户运行"
}

require_openwrt_firewall() {
    command -v uci >/dev/null 2>&1 || die "缺少 uci，当前系统不像 OpenWrt/iStoreOS"
    [ -x /etc/init.d/firewall ] || die "找不到 /etc/init.d/firewall"
}

restart_firewall() {
    uci commit firewall
    /etc/init.d/firewall restart
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

rule_sections_by_name() {
    name="$1"
    uci show firewall 2>/dev/null | sed -n "s/^\(firewall\.@rule\[[0-9][0-9]*\]\)\.name='${name}'$/\1/p"
}

frp_rule_sections() {
    uci show firewall 2>/dev/null | sed -n "s/^\(firewall\.@rule\[[0-9][0-9]*\]\)\.name='${RULE_PREFIX}[^']*'$/\1/p"
}

rule_sections_by_port() {
    spec="$1"
    frp_rule_sections | while IFS= read -r section; do
        [ -n "$section" ] || continue
        port="$(uci -q get "${section}.dest_port" || true)"
        [ "$port" = "$spec" ] && printf '%s\n' "$section"
    done
}

confirm_yes() {
    case "$1" in
        YES|yes|Y|y) return 0 ;;
        *) return 1 ;;
    esac
}

rule_exists() {
    name="$1"
    [ -n "$(rule_sections_by_name "$name")" ]
}

show_rule() {
    section="$1"
    name="$(uci -q get "${section}.name" || true)"
    port="$(uci -q get "${section}.dest_port" || true)"
    proto="$(uci -q get "${section}.proto" || true)"
    src="$(uci -q get "${section}.src" || true)"
    target="$(uci -q get "${section}.target" || true)"
    [ -n "$name" ] || return 0
    printf '  - %s | 端口: %s | 协议: %s | 来源: %s | 动作: %s\n' "$name" "$port" "$proto" "$src" "$target"
}

list_rules() {
    sections="$(frp_rule_sections)"
    if [ -z "$sections" ]; then
        log "当前没有 Allow-FRP-* 放行规则"
        return 0
    fi

    log "当前已放行的 FRP 防火墙规则："
    printf '%s\n' "$sections" | while IFS= read -r section; do
        show_rule "$section"
    done
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
    restart_firewall
    log "已放行: ${spec}"
}

delete_rule() {
    spec="$1"
    name="$(port_rule_name "$spec")"

    validate_port_spec "$spec" || die "端口格式无效: ${spec}。请输入单个端口 7500 或范围 60000-60999"

    if [ -z "$(rule_sections_by_name "$name")" ] && [ -z "$(rule_sections_by_port "$spec")" ]; then
        warn "未找到端口规则: ${spec}（规则名 ${name} 或 dest_port=${spec}）"
        return 0
    fi

    log "删除防火墙放行规则: ${spec}"
    while :; do
        section="$( { rule_sections_by_name "$name"; rule_sections_by_port "$spec"; } | sed -n '1p')"
        [ -n "$section" ] || break
        rule_name="$(uci -q get "${section}.name" || true)"
        rule_port="$(uci -q get "${section}.dest_port" || true)"
        log "删除 ${rule_name} (${rule_port})"
        uci delete "$section"
    done
    restart_firewall
    log "已删除: ${spec}"
}

clear_rules() {
    sections="$(frp_rule_sections)"
    if [ -z "$sections" ]; then
        log "当前没有 Allow-FRP-* 放行规则"
        return 0
    fi

    log "删除所有 Allow-FRP-* 防火墙规则"
    while :; do
        section="$(frp_rule_sections | sed -n '1p')"
        [ -n "$section" ] || break
        uci delete "$section"
    done
    restart_firewall
    log "已删除所有 FRP 放行规则"
}

prompt_port_spec() {
    printf '请输入端口，例如 7500 或 60000-60999 [默认: %s]: ' "$DEFAULT_PORT"
    read -r spec || true
    spec="${spec:-$DEFAULT_PORT}"
    printf '%s\n' "$spec"
}

add_interactive() {
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
        5) add_rule "$(prompt_port_spec)" ;;
        *) die "无效选择: $choice" ;;
    esac
}

delete_interactive() {
    list_rules
    echo
    cat <<EOF_MENU
请选择要删除的放行规则：
  1) frps 服务端连接端口 7000
  2) frps Dashboard 面板端口 7500
  3) frpc Web 管理面板端口 7400
  4) frps 默认远程映射端口范围 60000-60999
  5) 自定义单个端口或端口范围
  6) 删除所有 Allow-FRP-* 规则
EOF_MENU
    printf '请选择: '
    read -r choice || true

    case "$choice" in
        1) delete_rule 7000 ;;
        2) delete_rule 7500 ;;
        3) delete_rule 7400 ;;
        4) delete_rule 60000-60999 ;;
        5) delete_rule "$(prompt_port_spec)" ;;
        6)
            printf '确认删除所有 Allow-FRP-* 规则？输入 yes 继续: '
            read -r confirm || true
            confirm_yes "$confirm" || die "已取消"
            clear_rules
            ;;
        *) die "无效选择: $choice" ;;
    esac
}

interactive() {
    cat <<EOF_MENU
请选择防火墙操作：
  1) 放行端口
  2) 查看已放行的 FRP 端口
  3) 删除已放行的端口
  4) 删除所有 Allow-FRP-* 规则
  0) 返回/退出
EOF_MENU
    printf '请选择 [默认: 1]: '
    read -r choice || true
    choice="${choice:-1}"

    case "$choice" in
        1) add_interactive ;;
        2) list_rules ;;
        3) delete_interactive ;;
        4)
            list_rules
            printf '确认删除所有 Allow-FRP-* 规则？输入 yes 继续: '
            read -r confirm || true
            confirm_yes "$confirm" || die "已取消"
            clear_rules
            ;;
        0) exit 0 ;;
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
    require_openwrt_firewall

    case "${1:-}" in
        '')
            interactive
            ;;
        add)
            shift
            [ "$#" -gt 0 ] || die "缺少端口，例如: sh firewall.sh add 7500"
            add_rule "$1"
            ;;
        delete|del|remove|rm)
            shift
            [ "$#" -gt 0 ] || die "缺少端口，例如: sh firewall.sh delete 7500"
            delete_rule "$1"
            ;;
        list|ls|show)
            list_rules
            ;;
        clear)
            clear_rules
            ;;
        *)
            # Backward compatibility: sh firewall.sh 7500
            add_rule "$1"
            ;;
    esac
}

main "$@"
