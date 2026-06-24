#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

run_id() {
    local id="$1"

    case "$id" in
        193) append_unique_line_item "$id" "/etc/shells" "/usr/sbin/nologin" && emit "$id" "OK" "/usr/sbin/nologin registrado em /etc/shells" ;;
        *) sem_auto "$id" "item fora do grupo Sistema e Contas" ;;
    esac
}

if (( $# == 0 )); then
    set -- 193
fi

for id in "$@"; do
    run_id "$id"
done
