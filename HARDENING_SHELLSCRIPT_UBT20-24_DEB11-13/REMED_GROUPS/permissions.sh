#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

protect_file() {
    local id="$1"
    local path="$2"
    local mode="$3"

    set_owner_mode_item "$id" "$path" root root "$mode"
}

remove_world_write_local() {
    local id="$1"
    local path old_mode changed=0

    require_root "$id" || return 1
    while IFS= read -r -d '' path; do
        old_mode="$(stat -c '%a' "$path" 2>/dev/null || true)"
        if [ -n "$old_mode" ]; then
            ensure_rollback_file
            printf '%s|chmod|%s|%s|\n' "$id" "$path" "$old_mode" >> "$ROLLBACK_FILE"
        fi
        chmod o-w "$path" 2>/dev/null || true
        changed=1
    done < <(find / -xdev \( -type f -o -type d \) -not -path '/tmp/*' -not -path '/var/tmp/*' -not -path '/dev/shm/*' -perm -0002 -print0 2>/dev/null)
    if (( changed == 1 )); then
        emit "$id" "OK" "escrita global removida em objetos world-writable locais"
    else
        emit "$id" "OK" "nenhum objeto world-writable local encontrado"
    fi
}

run_id() {
    local id="$1"

    case "$id" in
        185) protect_file "$id" "/etc/passwd" 644 ;;
        186) protect_file "$id" "/etc/passwd-" 644 ;;
        187) protect_file "$id" "/etc/shadow" 000 ;;
        188) protect_file "$id" "/etc/shadow-" 000 ;;
        189) protect_file "$id" "/etc/gshadow-" 000 ;;
        190) protect_file "$id" "/etc/gshadow" 000 ;;
        191) protect_file "$id" "/etc/group" 644 ;;
        192) protect_file "$id" "/etc/group-" 644 ;;
        194) protect_file "$id" "/etc/security/opasswd" 600 ;;
        195) sem_auto "$id" "arquivos orfaos exigem decisao sobre owner correto" ;;
        196) remove_world_write_local "$id" ;;
        197) sem_auto "$id" "arquivos sem grupo exigem decisao sobre grupo correto" ;;
        198) sem_auto "$id" "SUID/SGID exige revisao e aprovacao por binario" ;;
        *) sem_auto "$id" "item fora do grupo Permissoes" ;;
    esac
}

if (( $# == 0 )); then
    set -- 185 186 187 188 189 190 191 192 194 196
fi

for id in "$@"; do
    run_id "$id"
done
