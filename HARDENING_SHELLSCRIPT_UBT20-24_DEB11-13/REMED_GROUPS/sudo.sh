#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

write_sudoers_dropin() {
    local id="$1"
    local path="$2"
    local line="$3"

    require_root "$id" || return 1
    write_file_mode_item "$id" "$path" 440 "$line" || return 1
    if command -v visudo >/dev/null 2>&1; then
        if ! visudo -cf "$path" >/dev/null 2>&1; then
            emit "$id" "FAIL" "sudoers invalido; usar rollback"
            return 1
        fi
    fi
}

restrict_su() {
    local id="$1"
    local file="/etc/pam.d/su"

    require_root "$id" || return 1
    if [ ! -f "$file" ]; then
        sem_auto "$id" "$file ausente"
        return 0
    fi
    if ! getent group sudo >/dev/null 2>&1; then
        sem_auto "$id" "grupo sudo ausente; grupo autorizado deve ser definido pelo cliente"
        return 0
    fi
    append_unique_line_item "$id" "$file" "auth required pam_wheel.so use_uid group=sudo" || return 1
    emit "$id" "OK" "su restrito ao grupo sudo"
}

run_id() {
    local id="$1"

    case "$id" in
        155) sem_auto "$id" "administradores sudoers devem ser definidos pela politica do cliente" ;;
        156) write_sudoers_dropin "$id" "/etc/sudoers.d/99-hitss-156" "Defaults use_pty" && emit "$id" "OK" "sudo use_pty habilitado" ;;
        157) write_sudoers_dropin "$id" "/etc/sudoers.d/99-hitss-157" 'Defaults logfile="/var/log/sudo.log"' && emit "$id" "OK" "log de sudo configurado" ;;
        158) sem_auto "$id" "reautenticacao depende de revisar sudoers existente" ;;
        159) write_sudoers_dropin "$id" "/etc/sudoers.d/99-hitss-159" "Defaults timestamp_timeout=5" && emit "$id" "OK" "timeout sudo configurado" ;;
        160) restrict_su "$id" ;;
        *) sem_auto "$id" "item fora do grupo Sudo" ;;
    esac
}

if (( $# == 0 )); then
    set -- 156 157 159 160
fi

for id in "$@"; do
    run_id "$id"
done
