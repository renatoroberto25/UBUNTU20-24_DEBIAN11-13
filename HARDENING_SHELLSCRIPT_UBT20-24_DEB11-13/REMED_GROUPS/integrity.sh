#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

schedule_aide_check() {
    local id="$1"
    local path="/etc/cron.daily/hitss-aide-check"
    local content='#!/bin/sh
aide.wrapper --check >/var/log/aide/aide-check.log 2>&1'

    write_file_mode_item "$id" "$path" 755 "$content" || return 1
    emit "$id" "OK" "verificacao diaria do AIDE agendada"
}

protect_audit_binaries() {
    local id="$1"
    local b p changed=0

    require_root "$id" || return 1
    for b in auditctl aureport ausearch autrace auditd augenrules; do
        p="$(command -v "$b" 2>/dev/null || true)"
        [ -n "$p" ] || continue
        record_file_meta_rollback "$id" "$p"
        chown root:root "$p"
        chmod go-w "$p"
        changed=1
    done
    if (( changed == 1 )); then
        emit "$id" "OK" "binarios de auditoria protegidos"
    else
        sem_auto "$id" "binarios de auditoria nao encontrados"
    fi
}

run_id() {
    local id="$1"

    case "$id" in
        182) sem_auto "$id" "instalar/inicializar AIDE envolve pacote e baseline inicial" ;;
        183) schedule_aide_check "$id" ;;
        184) protect_audit_binaries "$id" ;;
        *) sem_auto "$id" "item fora do grupo Integridade" ;;
    esac
}

if (( $# == 0 )); then
    set -- 183 184
fi

for id in "$@"; do
    run_id "$id"
done
