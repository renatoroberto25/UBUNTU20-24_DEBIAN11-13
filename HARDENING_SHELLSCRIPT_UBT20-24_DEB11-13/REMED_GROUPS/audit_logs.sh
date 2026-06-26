#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

AUDITD_READY=0

ensure_auditd_stack() {
    local id="$1"
    local packages="auditd"

    [ "$AUDITD_READY" = "1" ] && return 0
    require_root "$id" || return 1
    if ! command -v apt-get >/dev/null 2>&1; then
        emit "$id" "FAIL" "apt-get ausente"
        return 1
    fi
    if apt-cache show audispd-plugins >/dev/null 2>&1; then
        packages="$packages audispd-plugins"
    fi
    apt-get update >/dev/null 2>&1 || {
        emit "$id" "FAIL" "apt-get update falhou"
        return 1
    }
    apt-get install -y $packages >/dev/null 2>&1 || {
        emit "$id" "FAIL" "apt-get install auditd falhou"
        return 1
    }
    systemctl enable --now auditd >/dev/null 2>&1 || {
        emit "$id" "FAIL" "auditd nao habilitou/iniciou"
        return 1
    }
    AUDITD_READY=1
}

write_audit_rule() {
    local id="$1"
    local content="$2"
    local path="/etc/audit/rules.d/99-hitss-$id.rules"
    local key

    require_root "$id" || return 1
    ensure_auditd_stack "$id" || return 1
    if ! command -v augenrules >/dev/null 2>&1 || ! command -v auditctl >/dev/null 2>&1; then
        emit "$id" "FAIL" "augenrules/auditctl ausente"
        return 1
    fi
    mkdir -p /etc/audit/rules.d
    write_file_mode_item "$id" "$path" 640 "$content" || return 1
    chown root:root "$path"
    if ! augenrules --load >/dev/null 2>&1; then
        emit "$id" "FAIL" "regra escrita, mas nao foi possivel carregar via augenrules"
        return 1
    fi
    key="$(printf '%s\n' "$content" | sed -n -E 's/.*-k[[:space:]]+([^[:space:]]+).*/\1/p' | head -n 1)"
    if [ -n "$key" ] && auditctl -l 2>/dev/null | grep -Eq "(-k[[:space:]]+$key|key=$key)"; then
        emit "$id" "OK" "regra de auditoria ativa em auditctl"
        return 0
    fi
    emit "$id" "FAIL" "regra escrita, mas nao aparece ativa em auditctl"
    return 1
}

set_auditd_option() {
    local id="$1"
    local key="$2"
    local value="$3"
    local file="/etc/audit/auditd.conf"

    ensure_auditd_stack "$id" || return 1
    if [ ! -f "$file" ]; then
        emit "$id" "FAIL" "$file ausente"
        return 1
    fi
    set_kv_item "$id" "$file" "$key" "$value" || return 1
    emit "$id" "OK" "$key=$value"
}

configure_journald_persistent() {
    local id="$1"

    require_root "$id" || return 1
    mkdir -p /var/log/journal
    set_kv_item "$id" "/etc/systemd/journald.conf" "Storage" "persistent" || return 1
    systemctl restart systemd-journald >/dev/null 2>&1 || true
    emit "$id" "OK" "journald persistente configurado"
}

run_id() {
    local id="$1"

    case "$id" in
        161) sem_auto "$id" "arquitetura de logs exige desenho aprovado pelo cliente" ;;
        162) configure_journald_persistent "$id" ;;
        163) sem_auto "$id" "rsyslog envolve pacote/servico requerido pelo cliente" ;;
        164) sem_auto "$id" "rotacao de logs exige politica de retencao do cliente" ;;
        165) ensure_auditd_stack "$id" && emit "$id" "OK" "auditd instalado e ativo" ;;
        166) sem_auto "$id" "auditd no boot envolve parametro de boot e janela de mudanca" ;;
        167) set_auditd_option "$id" "max_log_file" "64" ;;
        168) set_auditd_option "$id" "max_log_file_action" "keep_logs" ;;
        169) write_audit_rule "$id" "-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change
-w /etc/localtime -p wa -k time-change" ;;
        170) write_audit_rule "$id" "-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity" ;;
        171) write_audit_rule "$id" "-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/hostname -p wa -k system-locale
-w /etc/networks -p wa -k system-locale" ;;
        173) write_audit_rule "$id" "-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session" ;;
        174) write_audit_rule "$id" "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat,chown,fchown,fchownat,lchown,setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -k perm_mod
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat,chown,fchown,fchownat,lchown,setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -k perm_mod" ;;
        175) write_audit_rule "$id" "-a always,exit -F arch=b64 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EACCES -k access
-a always,exit -F arch=b64 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EPERM -k access
-a always,exit -F arch=b32 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EACCES -k access
-a always,exit -F arch=b32 -S creat,open,openat,open_by_handle_at,truncate,ftruncate -F exit=-EPERM -k access" ;;
        176) sem_auto "$id" "execucoes privilegiadas exigem descoberta de binarios SUID/SGID no host" ;;
        177) write_audit_rule "$id" "-a always,exit -F arch=b64 -S mount,umount2 -k mounts
-a always,exit -F arch=b32 -S mount,umount2 -k mounts" ;;
        178) write_audit_rule "$id" "-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat,rmdir -k delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat,rmdir -k delete" ;;
        179) write_audit_rule "$id" "-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modules
-a always,exit -F arch=b32 -S init_module,finit_module,delete_module -k modules" ;;
        180) write_audit_rule "$id" "-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope" ;;
        181) sem_auto "$id" "audit immutable so deve ser aplicado em producao apos aprovar/revisar regras" ;;
        *) sem_auto "$id" "item fora do grupo Auditoria e Logs" ;;
    esac
}

if (( $# == 0 )); then
    set -- 165 167 168 169 170 171 173 174 175 177 178 179 180
fi

for id in "$@"; do
    run_id "$id"
done
