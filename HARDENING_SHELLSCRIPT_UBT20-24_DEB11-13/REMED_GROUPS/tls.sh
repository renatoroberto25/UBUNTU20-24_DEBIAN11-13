#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

run_id() {
    local id="$1"

    case "$id" in
        108)
            sem_auto "$id" "TLS minimo 1.2 depende dos servicos, bibliotecas e compatibilidade do cliente"
            ;;
        *)
            sem_auto "$id" "item fora do grupo Criptografia TLS"
            ;;
    esac
}

if (( $# == 0 )); then
    set -- 108
fi

for id in "$@"; do
    run_id "$id"
done
