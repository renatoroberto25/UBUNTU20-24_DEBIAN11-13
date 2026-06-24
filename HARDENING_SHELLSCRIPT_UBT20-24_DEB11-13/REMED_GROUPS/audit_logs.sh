#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

write_audit_rule() {
    local id="$1"
    local content="$2"
    local path="/etc/audit/rules.d/99-hitss-$id.rules"

    require_root "$id" || return 1
    mkdir -p /etc/audit/rules.d
    write_file_mode_item "$id" "$path" 640 "$content" || return 1
    command -v augenrules >/dev/null 2>&1 && augenrules --load >/dev/null 2>&1 || true
    emit "$id" "OK" "regra de auditoria aplicada em $path"
}

set_auditd_option() {
    local id="$1"
    local key="$2"
    local value="$3"
    local file="/etc/audit/auditd.conf"

    if [ ! -f "$file" ]; then
        sem_auto "$id" "$file ausente; auditd nao parece instalado"
        return 0
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
        165) sem_auto "$id" "instalar auditd e habilitar servico depende de pacote/janela" ;;
        166) sem_auto "$id" "auditd no boot envolve parametro de boot e janela de mudanca" ;;
        167) set_auditd_option "$id" "max_log_file" "64" ;;
        168) set_auditd_option "$id" "max_log_file_action" "keep_logs" ;;
        169) write_audit_rule "$id" "-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change" ;;
        170) write_audit_rule "$id" "-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity" ;;
        171) write_audit_rule "$id" "-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/hostname -p wa -k system-locale" ;;
        173) write_audit_rule "$id" "-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/run/utmp -p wa -k session" ;;
        174) write_audit_rule "$id" "-a always,exit -F arch=b64 -S chmod,chown,fchmod,fchown -k perm_mod" ;;
        175) write_audit_rule "$id" "-a always,exit -F arch=b64 -S open,openat,creat -F exit=-EACCES -k access
-a always,exit -F arch=b64 -S open,openat,creat -F exit=-EPERM -k access" ;;
        176) sem_auto "$id" "execucoes privilegiadas exigem descoberta de binarios SUID/SGID no host" ;;
        177) write_audit_rule "$id" "-a always,exit -F arch=b64 -S mount,umount2 -k mounts" ;;
        178) write_audit_rule "$id" "-a always,exit -F arch=b64 -S unlink,rename,rmdir,unlinkat,renameat -k delete" ;;
        179) write_audit_rule "$id" "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modules" ;;
        180) write_audit_rule "$id" "-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope" ;;
        181) sem_auto "$id" "audit immutable so deve ser aplicado em producao apos aprovar/revisar regras" ;;
        *) sem_auto "$id" "item fora do grupo Auditoria e Logs" ;;
    esac
}

if (( $# == 0 )); then
    set -- 162 167 168 169 170 171 173 174 175 177 178 179 180
fi

for id in "$@"; do
    run_id "$id"
done
