#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLLBACK_DIR="${HITSS_ROLLBACK_DIR:-$SCRIPT_DIR/../logs/remed/rollback}"
ROLLBACK_FILE="${HITSS_ROLLBACK_FILE:-$ROLLBACK_DIR/rollback-manual.manifest}"
RUN_ID="${HITSS_REMED_RUN_ID:-manual}"

ensure_rollback_file() {
    mkdir -p "$ROLLBACK_DIR"
    touch "$ROLLBACK_FILE"
}

emit() {
    local id="$1"
    local status="$2"
    local msg="$3"

    printf '[%s] %s | %s\n' "$id" "$status" "$msg"
}

is_root() {
    [ "$(id -u)" -eq 0 ]
}

require_root() {
    local id="$1"

    if ! is_root; then
        emit "$id" "FAIL" "execute como root"
        return 1
    fi
}

backup_file() {
    local id="$1"
    local target="$2"
    local safe backup

    ensure_rollback_file
    if [ ! -e "$target" ]; then
        printf '%s|remove_file|%s||\n' "$id" "$target" >> "$ROLLBACK_FILE"
        return 0
    fi
    safe="$(printf '%s' "$target" | sed 's#[/: ]#_#g')"
    backup="$ROLLBACK_DIR/${RUN_ID}_${id}${safe}.bak"
    cp -p "$target" "$backup"
    printf '%s|restore_file|%s|%s|\n' "$id" "$target" "$backup" >> "$ROLLBACK_FILE"
}

record_sysctl_rollback() {
    local id="$1"
    local key="$2"
    local old

    ensure_rollback_file
    old="$(sysctl -n "$key" 2>/dev/null || true)"
    printf '%s|sysctl|%s|%s|\n' "$id" "$key" "$old" >> "$ROLLBACK_FILE"
}

record_file_meta_rollback() {
    local id="$1"
    local target="$2"
    local mode owner group

    [ -e "$target" ] || return 0
    ensure_rollback_file
    mode="$(stat -c '%a' "$target" 2>/dev/null || true)"
    owner="$(stat -c '%U' "$target" 2>/dev/null || true)"
    group="$(stat -c '%G' "$target" 2>/dev/null || true)"
    printf '%s|file_meta|%s|%s:%s:%s|\n' "$id" "$target" "$owner" "$group" "$mode" >> "$ROLLBACK_FILE"
}

set_sysctl_item() {
    local id="$1"
    local key="$2"
    local value="$3"

    set_sysctl_value "$id" "$key" "$value" || return 1
    emit "$id" "OK" "$key=$value"
}

set_sysctl_value() {
    local id="$1"
    local key="$2"
    local value="$3"
    local file="/etc/sysctl.d/99-hitss-hardening.conf"

    require_root "$id" || return 1
    backup_file "$id" "$file"
    record_sysctl_rollback "$id" "$key"
    touch "$file"
    if grep -Eq "^[[:space:]]*$key[[:space:]]*=" "$file"; then
        sed -i -E "s|^[[:space:]]*$key[[:space:]]*=.*|$key = $value|" "$file"
    else
        printf '%s = %s\n' "$key" "$value" >> "$file"
    fi
    sysctl -w "$key=$value" >/dev/null 2>&1 || true
}

block_module_item() {
    local id="$1"
    local module="$2"
    local conf="/etc/modprobe.d/hitss-hardening-$module.conf"

    require_root "$id" || return 1
    backup_file "$id" "$conf"
    printf 'blacklist %s\ninstall %s /bin/true\n' "$module" "$module" > "$conf"
    modprobe -r "$module" >/dev/null 2>&1 || true
    emit "$id" "OK" "modulo $module bloqueado"
}

chmod_item() {
    local id="$1"
    local mode="$2"
    local path="$3"
    local old_mode

    require_root "$id" || return 1
    if [ ! -e "$path" ]; then
        emit "$id" "SEM_AUTO" "$path ausente"
        return 0
    fi
    old_mode="$(stat -c '%a' "$path" 2>/dev/null || true)"
    if [ -n "$old_mode" ]; then
        ensure_rollback_file
        printf '%s|chmod|%s|%s|\n' "$id" "$path" "$old_mode" >> "$ROLLBACK_FILE"
    fi
    chmod "$mode" "$path"
    emit "$id" "OK" "chmod $mode $path"
}

set_owner_mode_item() {
    local id="$1"
    local path="$2"
    local owner="$3"
    local group="$4"
    local mode="$5"

    require_root "$id" || return 1
    if [ ! -e "$path" ]; then
        emit "$id" "SEM_AUTO" "$path ausente"
        return 0
    fi
    record_file_meta_rollback "$id" "$path"
    chown "$owner:$group" "$path"
    chmod "$mode" "$path"
    emit "$id" "OK" "chown $owner:$group chmod $mode $path"
}

ensure_file_item() {
    local id="$1"
    local path="$2"
    local owner="$3"
    local group="$4"
    local mode="$5"

    require_root "$id" || return 1
    backup_file "$id" "$path"
    touch "$path"
    chown "$owner:$group" "$path" 2>/dev/null || chown root:root "$path"
    chmod "$mode" "$path"
}

remove_file_item() {
    local id="$1"
    local path="$2"

    require_root "$id" || return 1
    backup_file "$id" "$path"
    rm -f "$path"
}

set_kv_item() {
    local id="$1"
    local file="$2"
    local key="$3"
    local value="$4"

    require_root "$id" || return 1
    backup_file "$id" "$file"
    touch "$file"
    if grep -Eq "^[[:space:]]*$key[[:space:]]*=" "$file"; then
        sed -i -E "s|^[[:space:]]*$key[[:space:]]*=.*|$key = $value|" "$file"
    else
        printf '%s = %s\n' "$key" "$value" >> "$file"
    fi
}

set_space_kv_item() {
    local id="$1"
    local file="$2"
    local key="$3"
    local value="$4"

    require_root "$id" || return 1
    backup_file "$id" "$file"
    touch "$file"
    if grep -Eq "^[[:space:]]*#?[[:space:]]*$key[[:space:]]+" "$file"; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*$key[[:space:]]+.*|$key $value|" "$file"
    else
        printf '%s %s\n' "$key" "$value" >> "$file"
    fi
}

write_file_item() {
    local id="$1"
    local path="$2"
    local content="$3"

    require_root "$id" || return 1
    backup_file "$id" "$path"
    printf '%s\n' "$content" > "$path"
}

append_unique_line_item() {
    local id="$1"
    local path="$2"
    local line="$3"

    require_root "$id" || return 1
    backup_file "$id" "$path"
    touch "$path"
    grep -Fxq "$line" "$path" 2>/dev/null || printf '%s\n' "$line" >> "$path"
}

write_file_mode_item() {
    local id="$1"
    local path="$2"
    local mode="$3"
    local content="$4"

    write_file_item "$id" "$path" "$content" || return 1
    chmod "$mode" "$path"
}

sticky_world_writable_item() {
    local id="$1"
    local path old_mode

    require_root "$id" || return 1
    while IFS= read -r -d '' path; do
        old_mode="$(stat -c '%a' "$path" 2>/dev/null || true)"
        if [ -n "$old_mode" ]; then
            ensure_rollback_file
            printf '%s|chmod|%s|%s|\n' "$id" "$path" "$old_mode" >> "$ROLLBACK_FILE"
        fi
        chmod +t "$path" 2>/dev/null || true
    done < <(find / -xdev -type d -perm -0002 ! -perm -1000 -print0 2>/dev/null)
    emit "$id" "OK" "sticky bit aplicado em diretorios world-writable do filesystem local"
}

sem_auto() {
    local id="$1"
    local msg="$2"

    emit "$id" "SEM_AUTO" "$msg"
}

contains_id() {
    local needle="$1"
    shift

    for id in "$@"; do
        [ "$id" = "$needle" ] && return 0
    done
    return 1
}
