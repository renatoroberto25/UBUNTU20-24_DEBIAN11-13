#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

home_entries() {
    awk -F: '$3>=1000 && $1!="nobody" {print $1 ":" $6}' /etc/passwd
}

fix_home_owner() {
    local id="$1"
    local entry user home changed=0

    require_root "$id" || return 1
    while IFS= read -r entry; do
        user="${entry%%:*}"
        home="${entry#*:}"
        [ -d "$home" ] || continue
        record_file_meta_rollback "$id" "$home"
        chown "$user:$user" "$home" 2>/dev/null || chown "$user" "$home" 2>/dev/null || true
        changed=1
    done < <(home_entries)
    if (( changed == 1 )); then
        emit "$id" "OK" "ownership dos homes ajustado"
    else
        sem_auto "$id" "nenhum diretorio home local encontrado"
    fi
}

fix_home_modes() {
    local id="$1"
    local entry home changed=0

    require_root "$id" || return 1
    while IFS= read -r entry; do
        home="${entry#*:}"
        [ -d "$home" ] || continue
        record_file_meta_rollback "$id" "$home"
        chmod 750 "$home" 2>/dev/null || true
        changed=1
    done < <(home_entries)
    if (( changed == 1 )); then
        emit "$id" "OK" "permissoes dos homes ajustadas para 750"
    else
        sem_auto "$id" "nenhum diretorio home local encontrado"
    fi
}

fix_dotfiles() {
    local id="$1"
    local entry home path old_mode changed=0

    require_root "$id" || return 1
    while IFS= read -r entry; do
        home="${entry#*:}"
        [ -d "$home" ] || continue
        while IFS= read -r -d '' path; do
            old_mode="$(stat -c '%a' "$path" 2>/dev/null || true)"
            if [ -n "$old_mode" ]; then
                ensure_rollback_file
                printf '%s|chmod|%s|%s|\n' "$id" "$path" "$old_mode" >> "$ROLLBACK_FILE"
            fi
            chmod go-w "$path" 2>/dev/null || true
            changed=1
        done < <(find "$home" -maxdepth 1 -type f -name '.*' -perm /022 -print0 2>/dev/null)
    done < <(home_entries)
    if (( changed == 1 )); then
        emit "$id" "OK" "dotfiles sem escrita indevida para grupo/outros"
    else
        emit "$id" "OK" "nenhum dotfile inseguro encontrado"
    fi
}

run_id() {
    local id="$1"

    case "$id" in
        199) sem_auto "$id" "criar home ausente exige confirmar usuario e caminho esperado" ;;
        200) fix_home_owner "$id" ;;
        201) fix_home_modes "$id" ;;
        202) fix_dotfiles "$id" ;;
        203) sem_auto "$id" "remover/proteger .forward .netrc .rhosts depende de politica e uso legado" ;;
        *) sem_auto "$id" "item fora do grupo Home" ;;
    esac
}

if (( $# == 0 )); then
    set -- 200 201 202
fi

for id in "$@"; do
    run_id "$id"
done
