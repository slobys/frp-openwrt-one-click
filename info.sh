#!/bin/sh
set -eu

FRPS_CONFIG="/etc/frp/frps.toml"
FRPC_CONFIG="/etc/frp/frpc.toml"

get_toml_string() {
    key="$1"
    file="$2"
    [ -f "$file" ] || return 0
    awk -F'"' -v key="$key" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" {print $2; exit}' "$file"
}

get_toml_number() {
    key="$1"
    file="$2"
    [ -f "$file" ] || return 0
    awk -v key="$key" '$0 ~ "^[[:space:]]*" key "[[:space:]]*=" {gsub(/[[:space:]]/, "", $0); split($0, a, "="); print a[2]; exit}' "$file"
}

get_lan_ip() {
    ip=""
    if command -v uci >/dev/null 2>&1; then
        ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
    fi
    [ -n "$ip" ] || ip="软路由IP"
    printf '%s\n' "$ip"
}

service_status() {
    svc="$1"
    if [ -x "/etc/init.d/${svc}" ]; then
        if pgrep "$svc" >/dev/null 2>&1; then
            printf '运行中\n'
        elif ps | grep "[${svc%${svc#?}}]${svc#?}" >/dev/null 2>&1; then
            printf '运行中\n'
        else
            printf '未运行\n'
        fi
    else
        printf '未安装\n'
    fi
}

print_frps_info() {
    lan_ip="$1"
    if [ ! -f "$FRPS_CONFIG" ]; then
        echo "frps: 未检测到配置文件 ${FRPS_CONFIG}"
        return 0
    fi

    port="$(get_toml_number 'webServer.port' "$FRPS_CONFIG")"
    user="$(get_toml_string 'webServer.user' "$FRPS_CONFIG")"
    password="$(get_toml_string 'webServer.password' "$FRPS_CONFIG")"
    bind_port="$(get_toml_number 'bindPort' "$FRPS_CONFIG")"
    token="$(get_toml_string 'auth.token' "$FRPS_CONFIG")"

    echo "================ frps 面板信息 ================"
    echo "状态: $(service_status frps)"
    echo "面板地址: http://${lan_ip}:${port:-7500}"
    echo "用户名: ${user:-未设置}"
    echo "密码: ${password:-未设置}"
    echo "客户端连接端口: ${bind_port:-7000}"
    echo "token: ${token:-未设置}"
}

print_frpc_info() {
    lan_ip="$1"
    if [ ! -f "$FRPC_CONFIG" ]; then
        echo "frpc: 未检测到配置文件 ${FRPC_CONFIG}"
        return 0
    fi

    port="$(get_toml_number 'webServer.port' "$FRPC_CONFIG")"
    user="$(get_toml_string 'webServer.user' "$FRPC_CONFIG")"
    password="$(get_toml_string 'webServer.password' "$FRPC_CONFIG")"
    server_addr="$(get_toml_string 'serverAddr' "$FRPC_CONFIG")"
    server_port="$(get_toml_number 'serverPort' "$FRPC_CONFIG")"
    token="$(get_toml_string 'auth.token' "$FRPC_CONFIG")"

    echo
    echo "================ frpc 面板信息 ================"
    echo "状态: $(service_status frpc)"
    echo "面板地址: http://${lan_ip}:${port:-7400}"
    echo "用户名: ${user:-未设置}"
    echo "密码: ${password:-未设置}"
    echo "连接服务端: ${server_addr:-未设置}:${server_port:-未设置}"
    echo "token: ${token:-未设置}"
}

main() {
    lan_ip="$(get_lan_ip)"
    echo "LAN IP: ${lan_ip}"
    echo
    print_frps_info "$lan_ip"
    print_frpc_info "$lan_ip"
    echo
    echo "配置文件："
    echo "  ${FRPS_CONFIG}"
    echo "  ${FRPC_CONFIG}"
}

main "$@"
