#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

run_id() {
    local id="$1"

    case "$id" in
        025|026|027|028|029|030|031|032|033|034)
            sem_auto "$id" "particionamento e ponto de montagem dependem da arquitetura do cliente"
            ;;
        035|036|037|038|039|040|041|042|043)
            sem_auto "$id" "opcoes de montagem em fstab/mount dependem de janela e desenho operacional"
            ;;
        044)
            sticky_world_writable_item "$id"
            ;;
        045)
            chmod_item "$id" "1777" "/tmp"
            ;;
        046)
            chmod_item "$id" "1777" "/var/tmp"
            ;;
        047)
            chmod_item "$id" "1777" "/dev/shm"
            ;;
        *)
            sem_auto "$id" "item fora do grupo Filesystem"
            ;;
    esac
}

if (( $# == 0 )); then
    set -- 044 045 046 047
fi

for id in "$@"; do
    run_id "$id"
done
