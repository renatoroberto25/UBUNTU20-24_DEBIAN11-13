#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

SSHD_CONFIG="/etc/ssh/sshd_config"

sshd_config_present() {
    local id="$1"

    if [ ! -f "$SSHD_CONFIG" ]; then
        sem_auto "$id" "$SSHD_CONFIG ausente"
        return 1
    fi
}

validate_sshd_config() {
    local id="$1"

    if command -v sshd >/dev/null 2>&1; then
        if ! sshd -t >/dev/null 2>&1; then
            emit "$id" "FAIL" "sshd_config ficou invalido; usar rollback"
            return 1
        fi
    fi
}

set_sshd_option() {
    local id="$1"
    local key="$2"
    local value="$3"

    sshd_config_present "$id" || return 0
    set_space_kv_item "$id" "$SSHD_CONFIG" "$key" "$value" || return 1
    validate_sshd_config "$id" || return 1
    emit "$id" "OK" "$key $value"
}

set_sshd_options() {
    local id="$1"
    shift
    local kv key value

    sshd_config_present "$id" || return 0
    for kv in "$@"; do
        key="${kv%% *}"
        value="${kv#* }"
        set_space_kv_item "$id" "$SSHD_CONFIG" "$key" "$value" || return 1
    done
    validate_sshd_config "$id" || return 1
    emit "$id" "OK" "diretivas SSH aplicadas"
}

secure_ssh_permissions() {
    local id="$1"
    local changed=0

    require_root "$id" || return 1
    if [ -d /etc/ssh ]; then
        set_owner_mode_item "$id" /etc/ssh root root 755 >/dev/null || return 1
        changed=1
    fi
    if [ -f "$SSHD_CONFIG" ]; then
        set_owner_mode_item "$id" "$SSHD_CONFIG" root root 600 >/dev/null || return 1
        changed=1
    fi
    if (( changed == 1 )); then
        emit "$id" "OK" "permissoes seguras aplicadas em /etc/ssh"
    else
        sem_auto "$id" "/etc/ssh ausente"
    fi
}

run_id() {
    local id="$1"

    case "$id" in
        109) secure_ssh_permissions "$id" ;;
        110) sem_auto "$id" "Allow/DenyUsers ou Allow/DenyGroups dependem da politica de acesso do cliente" ;;
        111) set_sshd_option "$id" "SyslogFacility" "AUTHPRIV" ;;
        112) set_sshd_option "$id" "X11Forwarding" "no" ;;
        113) set_sshd_option "$id" "MaxAuthTries" "4" ;;
        114) set_sshd_option "$id" "IgnoreRhosts" "yes" ;;
        115) set_sshd_option "$id" "HostbasedAuthentication" "no" ;;
        117) set_sshd_option "$id" "PermitEmptyPasswords" "no" ;;
        118) set_sshd_option "$id" "PermitUserEnvironment" "no" ;;
        119) set_sshd_option "$id" "UsePAM" "yes" ;;
        120)
            set_sshd_options "$id" "ClientAliveInterval 300" "ClientAliveCountMax 3"
            ;;
        121) set_sshd_option "$id" "LoginGraceTime" "60" ;;
        122)
            set_sshd_options "$id" "MaxStartups 10:30:60" "MaxSessions 10"
            ;;
        123) set_sshd_option "$id" "AllowTcpForwarding" "no" ;;
        124) sem_auto "$id" "Banner legal exige texto/caminho aprovado pelo cliente" ;;
        125|126|127|128)
            sem_auto "$id" "algoritmos SSH exigem lista aprovada e validacao de compatibilidade"
            ;;
        129) sem_auto "$id" "ForceCommand/Chroot depende de caso de uso e desenho operacional" ;;
        *) sem_auto "$id" "item fora do grupo SSH Hardening" ;;
    esac
}

if (( $# == 0 )); then
    set -- 109 111 112 113 114 115 117 118 119 120 121 122 123
fi

for id in "$@"; do
    run_id "$id"
done
