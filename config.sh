#!/bin/sh
set -eu

# Modify frps/frpc web dashboard credentials and token.
# Automatically detects server (systemd) vs OpenWrt (procd).

FRPS_CONFIG="/etc/frp/frps.toml"
FRPC_CONFIG="/etc/frp/frpc.toml"

warn() { printf '%s\n' "[WARN] $*" >&2; }
die() { printf '%s\n' "[ERROR] $*" >&2; exit 1; }

[ "$(id -u)" = "0" ] || die "请使用 root 用户运行"

is_openwrt() {
    command -v uci >/dev/null 2>&1
}

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
    printf '%s: ' "$prompt" >&2
    read -r val || true
    printf '%s\n' "${val:-$default}"
}

restart_frps() {
    if is_openwrt && [ -x /etc/init.d/frps ]; then
        /etc/init.d/frps restart
    elif command -v systemctl >/dev/null 2>&1 && systemctl is-enabled frps >/dev/null 2>&1; then
        systemctl restart frps
    fi
}

restart_frpc() {
    if is_openwrt && [ -x /etc/init.d/frpc ]; then
        /etc/init.d/frpc restart
    fi
}

menu() {
    if is_openwrt; then
        cat <<'EOF_MENU'
请选择要修改的内容：
 1) 修改 frps 面板用户名/密码
 2) 修改 frpc 面板用户名/密码
 3) 修改 frp token
 4) 全部修改
 0) 返回
EOF_MENU
    else
        cat <<'EOF_MENU'
请选择要修改的内容：
 1) 修改 frps 面板用户名/密码
 2) 修改 frp token
 3) 全部修改
 0) 返回
EOF_MENU
    fi
}

modify_frps_dashboard() {
    [ -f "$FRPS_CONFIG" ] || { warn "未找到 frps 配置文件"; return 1; }
    cur_user="$(get_toml_string 'webServer.user' "$FRPS_CONFIG")"
    cur_pass="$(get_toml_string 'webServer.password' "$FRPS_CONFIG")"

    echo
    echo "===== 修改 frps 面板账号 ====="
    echo "当前用户名: ${cur_user:-未设置}"
    new_user="$(prompt_value '新用户名' "${cur_user:-admin}")"
    echo "当前密码: ${cur_pass:-未设置}"
    new_pass="$(prompt_value '新密码' "${cur_pass:-}")"

    set_toml_string 'webServer.user' "$new_user" "$FRPS_CONFIG"
    set_toml_string 'webServer.password' "$new_pass" "$FRPS_CONFIG"
    restart_frps
    echo "frps 面板账号已更新"
}

modify_frpc_dashboard() {
    [ -f "$FRPC_CONFIG" ] || { warn "未找到 frpc 配置文件"; return 1; }
    cur_user="$(get_toml_string 'webServer.user' "$FRPC_CONFIG")"
    cur_pass="$(get_toml_string 'webServer.password' "$FRPC_CONFIG")"

    echo
    echo "===== 修改 frpc 面板账号 ====="
    echo "当前用户名: ${cur_user:-未设置}"
    new_user="$(prompt_value '新用户名' "${cur_user:-admin}")"
    echo "当前密码: ${cur_pass:-未设置}"
    new_pass="$(prompt_value '新密码' "${cur_pass:-}")"

    set_toml_string 'webServer.user' "$new_user" "$FRPC_CONFIG"
    set_toml_string 'webServer.password' "$new_pass" "$FRPC_CONFIG"
    restart_frpc
    echo "frpc 面板账号已更新"
}

modify_token() {
    cur_frps_token=""
    cur_frpc_token=""
    [ -f "$FRPS_CONFIG" ] && cur_frps_token="$(get_toml_string 'auth.token' "$FRPS_CONFIG")"
    is_openwrt && [ -f "$FRPC_CONFIG" ] && cur_frpc_token="$(get_toml_string 'auth.token' "$FRPC_CONFIG")"
    cur_token="${cur_frps_token:-${cur_frpc_token}}"

    echo
    echo "===== 修改 frp token ===="
    [ -n "$cur_frps_token" ] && [ -n "$cur_frpc_token" ] && [ "$cur_frps_token" != "$cur_frpc_token" ] && echo "注意：当前 frps 和 frpc 的 token 不一致"
    echo "当前 token: ${cur_token}"
    new_token="$(prompt_value '新 token' "$cur_token")"

    if [ -f "$FRPS_CONFIG" ]; then
        set_toml_string 'auth.token' "$new_token" "$FRPS_CONFIG"
        restart_frps
    fi
    if is_openwrt && [ -f "$FRPC_CONFIG" ]; then
        set_toml_string 'auth.token' "$new_token" "$FRPC_CONFIG"
        restart_frpc
    fi
    echo "token 已更新，服务已重启"
}

main() {
    menu
    printf '请选择: '
    read -r choice || exit 0

    if is_openwrt; then
        case "$choice" in
            1) modify_frps_dashboard ;;
            2) modify_frpc_dashboard ;;
            3) modify_token ;;
            4) modify_frps_dashboard || true; modify_frpc_dashboard || true; modify_token ;;
            0) exit 0 ;;
            *) die "无效选择: $choice" ;;
        esac
    else
        case "$choice" in
            1) modify_frps_dashboard ;;
            2) modify_token ;;
            3) modify_frps_dashboard || true; modify_token ;;
            0) exit 0 ;;
            *) die "无效选择: $choice" ;;
        esac
    fi
}

main "$@"
