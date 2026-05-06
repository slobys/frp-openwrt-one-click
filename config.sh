#!/bin/sh
set -eu

# Modify frps/frpc web dashboard credentials and token.

FRPS_CONFIG="/etc/frp/frps.toml"
FRPC_CONFIG="/etc/frp/frpc.toml"
FRPS_INIT="/etc/init.d/frps"
FRPC_INIT="/etc/init.d/frpc"

warn() { printf '%s\n' "[WARN] $*" >&2; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "请使用 root 用户运行"

get_toml_string() {
    key="$1"
    file="$2"
    [ -f "$file" ] || return 0
    awk -F'"' -v key="$key" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" {print $2; exit}' "$file"
}

set_toml_string() {
    key="$1"
    value="$2"
    file="$3"
    if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
        sed -i "s/^[[:space:]]*${key}[[:space:]]*=.*/${key} = \"${value}\"/" "$file"
    else
        echo "${key} = \"${value}\"" >> "$file"
    fi
}

prompt_value() {
    prompt="$1"
    default="$2"
    printf '%s [%s]: ' "$prompt" "$default"
    read -r val || true
    printf '%s\n' "${val:-$default}"
}

restart_service() {
    svc="$1"
    if [ -x "/etc/init.d/${svc}" ]; then
        "/etc/init.d/${svc}" restart
    fi
}

menu() {
    cat <<'EOF_MENU'
请选择要修改的内容：
 1) 修改 frps 面板用户名/密码
 2) 修改 frpc 面板用户名/密码
 3) 修改 frp token
 4) 全部修改
 0) 返回
EOF_MENU
}

modify_frps_dashboard() {
    [ -f "$FRPS_CONFIG" ] || { warn "未找到 frps 配置文件"; return 1; }
    cur_user="$(get_toml_string 'webServer.user' "$FRPS_CONFIG")"
    cur_pass="$(get_toml_string 'webServer.password' "$FRPS_CONFIG")"

    echo
    echo "当前 frps 面板信息："
    echo "  用户名: ${cur_user:-未设置}"
    echo "  密码: ${cur_pass:-未设置}"
    echo
    new_user="$(prompt_value '新用户名' "${cur_user:-admin}")"
    new_pass="$(prompt_value '新密码' "${cur_pass:-}")"

    set_toml_string 'webServer.user' "$new_user" "$FRPS_CONFIG"
    set_toml_string 'webServer.password' "$new_pass" "$FRPS_CONFIG"
    restart_service frps
    echo "frps 面板账号已更新"
}

modify_frpc_dashboard() {
    [ -f "$FRPC_CONFIG" ] || { warn "未找到 frpc 配置文件"; return 1; }
    cur_user="$(get_toml_string 'webServer.user' "$FRPC_CONFIG")"
    cur_pass="$(get_toml_string 'webServer.password' "$FRPC_CONFIG")"

    echo
    echo "当前 frpc 面板信息："
    echo "  用户名: ${cur_user:-未设置}"
    echo "  密码: ${cur_pass:-未设置}"
    echo
    new_user="$(prompt_value '新用户名' "${cur_user:-admin}")"
    new_pass="$(prompt_value '新密码' "${cur_pass:-}")"

    set_toml_string 'webServer.user' "$new_user" "$FRPC_CONFIG"
    set_toml_string 'webServer.password' "$new_pass" "$FRPC_CONFIG"
    restart_service frpc
    echo "frpc 面板账号已更新"
}

modify_token() {
    cur_frps_token=""
    cur_frpc_token=""
    [ -f "$FRPS_CONFIG" ] && cur_frps_token="$(get_toml_string 'auth.token' "$FRPS_CONFIG")"
    [ -f "$FRPC_CONFIG" ] && cur_frpc_token="$(get_toml_string 'auth.token' "$FRPC_CONFIG")"

    echo
    echo "当前 token："
    [ -n "$cur_frps_token" ] && echo "  frps: ${cur_frps_token}"
    [ -n "$cur_frpc_token" ] && echo "  frpc: ${cur_frpc_token}"
    echo
    new_token="$(prompt_value '新 token' "${cur_frps_token:-${cur_frpc_token}}")"

    if [ -f "$FRPS_CONFIG" ]; then
        set_toml_string 'auth.token' "$new_token" "$FRPS_CONFIG"
        restart_service frps
    fi
    if [ -f "$FRPC_CONFIG" ]; then
        set_toml_string 'auth.token' "$new_token" "$FRPC_CONFIG"
        restart_service frpc
    fi
    echo "token 已更新，frps/frpc 已重启"
}

main() {
    menu
    printf '请选择: '
    read -r choice || exit 0

    case "$choice" in
        1) modify_frps_dashboard ;;
        2) modify_frpc_dashboard ;;
        3) modify_token ;;
        4)
            modify_frps_dashboard || true
            modify_frpc_dashboard || true
            modify_token
            ;;
        0) exit 0 ;;
        *) die "无效选择: $choice" ;;
    esac
}

main "$@"
