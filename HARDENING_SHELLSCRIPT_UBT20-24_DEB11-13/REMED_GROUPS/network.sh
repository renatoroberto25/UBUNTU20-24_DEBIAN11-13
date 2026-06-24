#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

run_id() {
    local id="$1"

    case "$id" in
        091)
            set_sysctl_value "$id" "net.ipv4.ip_forward" "0" && emit "$id" "OK" "ip forwarding desabilitado"
            ;;
        092)
            set_sysctl_value "$id" "net.ipv4.conf.all.send_redirects" "0" || return 1
            set_sysctl_value "$id" "net.ipv4.conf.default.send_redirects" "0" || return 1
            emit "$id" "OK" "send_redirects desabilitado"
            ;;
        093)
            set_sysctl_value "$id" "net.ipv4.conf.all.accept_source_route" "0" || return 1
            set_sysctl_value "$id" "net.ipv4.conf.default.accept_source_route" "0" || return 1
            emit "$id" "OK" "source route bloqueado"
            ;;
        094)
            set_sysctl_value "$id" "net.ipv4.conf.all.accept_redirects" "0" || return 1
            set_sysctl_value "$id" "net.ipv4.conf.default.accept_redirects" "0" || return 1
            set_sysctl_value "$id" "net.ipv4.conf.all.secure_redirects" "0" || return 1
            set_sysctl_value "$id" "net.ipv4.conf.default.secure_redirects" "0" || return 1
            emit "$id" "OK" "ICMP redirects desabilitados"
            ;;
        095)
            set_sysctl_value "$id" "net.ipv4.conf.all.rp_filter" "1" || return 1
            set_sysctl_value "$id" "net.ipv4.conf.default.rp_filter" "1" || return 1
            emit "$id" "OK" "rp_filter habilitado"
            ;;
        096)
            set_sysctl_value "$id" "net.ipv4.icmp_echo_ignore_broadcasts" "1" && emit "$id" "OK" "broadcast ICMP ignorado"
            ;;
        097)
            set_sysctl_value "$id" "net.ipv4.icmp_ignore_bogus_error_responses" "1" && emit "$id" "OK" "bogus ICMP ignorado"
            ;;
        098)
            set_sysctl_value "$id" "net.ipv4.tcp_syncookies" "1" && emit "$id" "OK" "tcp_syncookies habilitado"
            ;;
        099)
            sem_auto "$id" "IPv6 deve ser desabilitado ou endurecido conforme politica do cliente"
            ;;
        102)
            sem_auto "$id" "wireless/bluetooth dependem de necessidade operacional do host"
            ;;
        *)
            sem_auto "$id" "item fora do grupo Rede"
            ;;
    esac
}

if (( $# == 0 )); then
    set -- 091 092 093 094 095 096 097 098
fi

for id in "$@"; do
    run_id "$id"
done
