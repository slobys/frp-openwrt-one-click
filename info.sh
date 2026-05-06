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

is_openwrt() {
    command -v uci >/dev/null 2>&1
}

is_server() {
    command -v systemctl >/dev/null 2>&1 && ! is_openwrt
}

get_display_ip() {
    if is_openwrt; then
        uci -q get network.lan.ipaddr 2>/dev/null || echo "未知"
    else
        for url in https://api.ipify.org https://ipv4.icanhazip.com; do
            ip=""
            if command -v curl >/dev/null 2>&1; then
                ip="$(curl -fsSL --connect-timeout 3 --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
            elif command -v wget >/dev/null 2>&1; then
                ip="$(wget -qO- --timeout=5 "$url" 2>/dev/null | tr -d '[:space:]' || true)"
            fi
            case "$ip" in *.*.*.*) printf '%s\n' "$ip"; return 0 ;; esac
        done
        echo "未知"
    fi
}

service_status() {
    svc="$1"
    if is_openwrt; then
        if [ -x "/etc/init.d/${svc}" ] && pgrep "$svc" >/dev/null 2>&1; then
            printf '运行中\n'
        elif [ -x "/etc/init.d/${svc}" ]; then
            printf '未运行\n'
        else
            printf '未安装\n'
        fi
    else
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            printf '运行中\n'
        elif [ -f /etc/systemd/system/${svc}.service ]; then
            printf '未运行\n'
        else
            printf '未安装\n'
        fi
    fi
}

print_frps() {
    ip="$1"
    if [ ! -f "$FRPS_CONFIG" ]; then
        echo "frps: 未安装"
        return 0
    fi
    port="$(get_toml_number 'webServer.port' "$FRPS_CONFIG")"
    user="$(get_toml_string 'webServer.user' "$FRPS_CONFIG")"
    password="$(get_toml_string 'webServer.password' "$FRPS_CONFIG")"
    bind_port="$(get_toml_number 'bindPort' "$FRPS_CONFIG")"
    token="$(get_toml_string 'auth.token' "$FRPS_CONFIG")"

    echo "================ frps 面板信息 ================"
    echo "状态: $(service_status frps)"
    echo "面板地址: http://${ip}:${port:-7500}"
    echo "用户名: ${user:-未设置}"
    echo "密码: ${password:-未设置}"
    echo "客户端连接端口: ${bind_port:-7000}"
    echo "token: ${token:-未设置}"
}

print_frpc() {
    ip="$1"
    if [ ! -f "$FRPC_CONFIG" ]; then
        return 0
    fi
    port="$(get_toml_number 'webServer.port' "$FRPC_CONFIG")"
    user="$(get_toml_string 'webServer.user' "$FRPC_CONFIG")"
    password="$(get_toml_string 'webServer.password' "$FRPC_CONFIG")"

    echo
    echo "================ frpc 面板信息 ================"
    echo "状态: $(service_status frpc)"
    echo "面板地址: http://${ip}:${port:-7400}"
    echo "用户名: ${user:-未设置}"
    echo "密码: ${password:-未设置}"
}

main() {
    ip="$(get_display_ip)"

    if is_openwrt; then
        echo "环境: 软路由"
        echo "LAN IP: ${ip}"
    else
        echo "环境: 服务器"
        echo "公网 IP: ${ip}"
    fi
    echo
    print_frps "$ip"

    # Only show frpc on OpenWrt
    if is_openwrt; then
        print_frpc "$ip"
    fi

    echo
    printf '%s' "配置文件："
    [ -f "$FRPS_CONFIG" ] && printf '%s' " ${FRPS_CONFIG}"
    [ -f "$FRPC_CONFIG" ] && printf '%s' " ${FRPC_CONFIG}"
    echo
}

main "$@"
