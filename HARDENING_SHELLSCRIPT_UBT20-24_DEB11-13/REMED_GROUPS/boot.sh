#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

secure_bootloader_permissions() {
    local id="$1"
    local changed=0
    local f

    require_root "$id" || return 1
    for f in /boot/grub/grub.cfg /boot/grub2/grub.cfg; do
        if [ -f "$f" ]; then
            set_owner_mode_item "$id" "$f" root root 600 >/dev/null || return 1
            changed=1
        fi
    done
    if (( changed == 1 )); then
        emit "$id" "OK" "permissoes seguras aplicadas no arquivo do bootloader"
    else
        emit "$id" "SEM_AUTO" "arquivo de configuracao do bootloader nao encontrado"
    fi
}

run_id() {
    local id="$1"

    case "$id" in
        048) sem_auto "$id" "autofs depende do papel do host e do uso de montagem sob demanda" ;;
        049) sem_auto "$id" "senha de bootloader exige definicao/fornecimento de segredo pelo cliente" ;;
        050) secure_bootloader_permissions "$id" ;;
        051) sem_auto "$id" "autenticacao em single user depende da politica de boot aprovada" ;;
        *) sem_auto "$id" "item fora do grupo Seguranca de Boot" ;;
    esac
}

if (( $# == 0 )); then
    set -- 050
fi

for id in "$@"; do
    run_id "$id"
done
