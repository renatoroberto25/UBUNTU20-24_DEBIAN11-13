#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$SCRIPT_DIR"
AUDIT_DIR="$BASE_DIR/AUDIT_SH"
REMED_DIR="$BASE_DIR/REMED_SH"
REMED_GROUP_DIR="$BASE_DIR/REMED_GROUPS"
LOG_DIR="$BASE_DIR/logs"
LOG_AUDIT="$LOG_DIR/audit"
LOG_REMED="$LOG_DIR/remed"
LOG_ROLLBACK="$LOG_REMED/rollback"
HITSS_LOG_FILE="/var/log/hitss-hardening.log"
HITSS_VERSION="HARDENING HITSS DEBLIKE v1.2.4"
HITSS_ORIGIN="VIA EXECUCAO LOCAL AUTOMACAO SHELLSCRIPT"
HITSS_FAMILY="DEB_LIKE"
HOSTNAME="$(hostname -s)"
DATE="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$LOG_AUDIT" "$LOG_REMED" "$LOG_ROLLBACK"

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_REMED_OK=0
TOTAL_REMED_MANUAL=0
TOTAL_REMED_FAIL=0
TOTAL_REMED_SKIP=0
AUDIT_RESULT_CSV="$LOG_AUDIT/audit-current.csv"

os_release() {
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        printf '%s %s' "${PRETTY_NAME:-$NAME}" "${VERSION_ID:-}"
    else
        uname -s
    fi
}

os_major() {
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        printf '%s' "${VERSION_ID:-}"
    fi
}

hitss_stamp() {
    local action="$1"
    local status="$2"
    local logfile="${3:-}"
    local now os version

    now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    os="$(os_release)"
    version="$(os_major)"

    if [ "$(id -u)" -eq 0 ]; then
        touch "$HITSS_LOG_FILE"
        chmod 0600 "$HITSS_LOG_FILE"
        {
            printf '%s - %s - %s - %s - host: %s' "$now" "$action" "$HITSS_VERSION" "$HITSS_ORIGIN" "$HOSTNAME"
            printf ' - os: %s - version: %s - family: %s - status: %s' "$os" "${version:-unknown}" "$HITSS_FAMILY" "$status"
            [ -n "$logfile" ] && printf ' - logfile: %s' "$logfile"
            printf '\n'
        } >> "$HITSS_LOG_FILE"
    else
        echo "WARN: sem root, nao foi possivel escrever em $HITSS_LOG_FILE"
    fi
}

collect_scripts() {
    local DIR="$1"
    shopt -s nullglob
    local arr=("$DIR"/*.sh)
    shopt -u nullglob
    (( ${#arr[@]} > 0 )) || return 1
    IFS=$'\n' printf "%s\n" "${arr[@]}" | sort -V
}

run_audit_scripts() {
    local DIR="$1"
    local LOGFILE="$2"
    local -a scripts=()
    : > "$LOGFILE"
    mapfile -t scripts < <(collect_scripts "$DIR")
    if (( ${#scripts[@]} == 0 )); then
        echo "Nenhum script encontrado em $DIR"
        return 1
    fi
    for shfile in "${scripts[@]}"; do
        local name current_id line output
        name="$(basename "$shfile")"
        echo ">> $name"
        output="$(bash "$shfile" 2>&1 | tee -a "$LOGFILE")"
        current_id=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^\[[0-9]+\] ]]; then
                current_id="$(sed -n 's/^\[\([0-9]\+\)\].*/\1/p' <<<"$line")"
            elif [[ "$line" == "PASS" && -n "$current_id" ]]; then
                TOTAL_PASS=$((TOTAL_PASS + 1))
                printf "%s,%s,APROVADO\n" "$HOSTNAME" "$current_id" >> "$AUDIT_RESULT_CSV"
            elif [[ "$line" == "FAIL" && -n "$current_id" ]]; then
                TOTAL_FAIL=$((TOTAL_FAIL + 1))
                printf "%s,%s,REPROVADO\n" "$HOSTNAME" "$current_id" >> "$AUDIT_RESULT_CSV"
            fi
        done <<< "$output"
    done
}

failed_ids_from_csv() {
    local csv="$1"
    awk -F, 'NR > 1 && $3 == "REPROVADO" { printf "%03d\n", $2 }' "$csv" | sort -u
}

remed_group_for_id() {
    local id="$1"
    local num

    num=$((10#$id))
    if (( num >= 1 && num <= 24 )); then
        echo "kernel"
    elif (( num >= 25 && num <= 47 )); then
        echo "filesystem"
    elif (( num >= 48 && num <= 51 )); then
        echo "boot"
    elif (( num >= 56 && num <= 90 )); then
        echo "system"
    elif (( num >= 91 && num <= 102 )); then
        echo "network"
    elif (( num == 108 )); then
        echo "tls"
    elif (( num >= 109 && num <= 129 )); then
        echo "ssh"
    else
        return 1
    fi
}

record_remed_status() {
    local label="$1"
    local status="$2"

    case "$status" in
        OK)
            TOTAL_REMED_OK=$((TOTAL_REMED_OK + 1))
            ;;
        MANUAL)
            TOTAL_REMED_MANUAL=$((TOTAL_REMED_MANUAL + 1))
            ;;
        SEM_AUTO)
            TOTAL_REMED_SKIP=$((TOTAL_REMED_SKIP + 1))
            ;;
        *)
            status="FAIL"
            TOTAL_REMED_FAIL=$((TOTAL_REMED_FAIL + 1))
            ;;
    esac
    printf "%-30s %s\n" "$label" "$status"
}

run_group_remed_script() {
    local shfile="$1"
    local LOGFILE="$2"
    shift 2
    local name output rc line parsed id status label

    name="$(basename "$shfile")"
    parsed=0

    set +e
    output="$(bash "$shfile" "$@" 2>&1)"
    rc=$?
    set -e

    printf '>> %s %s\n%s\n' "$name" "$*" "$output" >> "$LOGFILE"
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([0-9]+)\][[:space:]]+(OK|FAIL|MANUAL|SEM_AUTO)([[:space:]]*\|.*)?$ ]]; then
            id="$(printf "%03d" "$((10#${BASH_REMATCH[1]}))")"
            status="${BASH_REMATCH[2]}"
            label="$name:$id"
            record_remed_status "$label" "$status"
            parsed=1
        fi
    done <<< "$output"

    if (( parsed == 0 && rc != 0 )); then
        if (( $# > 0 )); then
            for id in "$@"; do
                record_remed_status "$name:$id" "FAIL"
            done
        else
            record_remed_status "$name" "FAIL"
        fi
    fi
}

run_remed_scripts() {
    local DIR="$1"
    local LOGFILE="$2"
    local IDS_FILE="${3:-}"
    local -a scripts=()
    local -a groups=()
    local -A group_ids=()
    local group id shfile run_id rollback_file

    : > "$LOGFILE"
    run_id="${DATE}-${HOSTNAME}"
    rollback_file="$LOG_ROLLBACK/rollback-${run_id}.manifest"
    : > "$rollback_file"
    export HITSS_REMED_RUN_ID="$run_id"
    export HITSS_ROLLBACK_FILE="$rollback_file"
    export HITSS_ROLLBACK_DIR="$LOG_ROLLBACK"

    if [ -n "$IDS_FILE" ]; then
        while IFS= read -r id; do
            if group="$(remed_group_for_id "$id" 2>/dev/null)" && [ -f "$REMED_GROUP_DIR/$group.sh" ]; then
                if [[ -z "${group_ids[$group]:-}" ]]; then
                    groups+=("$group")
                fi
                group_ids[$group]="${group_ids[$group]:-} $id"
            elif [ -f "$DIR/$id.sh" ]; then
                scripts+=("$DIR/$id.sh")
            else
                printf "%-30s SEM_AUTO\n" "$id.sh" | tee -a "$LOGFILE"
                TOTAL_REMED_SKIP=$((TOTAL_REMED_SKIP + 1))
            fi
            done < "$IDS_FILE"
    else
        if [ -d "$REMED_GROUP_DIR" ]; then
            for group in kernel filesystem boot system network tls ssh; do
                [ -f "$REMED_GROUP_DIR/$group.sh" ] && groups+=("$group")
            done
        fi
        mapfile -t scripts < <(collect_scripts "$DIR")
    fi
    if (( ${#groups[@]} == 0 && ${#scripts[@]} == 0 )); then
        echo "Nenhum script de remediacao encontrado para executar."
        return 0
    fi
    for group in "${groups[@]}"; do
        shfile="$REMED_GROUP_DIR/$group.sh"
        if [ -f "$shfile" ]; then
            # shellcheck disable=SC2086
            run_group_remed_script "$shfile" "$LOGFILE" ${group_ids[$group]:-}
        fi
    done
    for shfile in "${scripts[@]}"; do
        local name output rc status
        name="$(basename "$shfile")"
        set +e
        output="$(bash "$shfile" 2>&1)"
        rc=$?
        set -e
        printf '>> %s\n%s\n' "$name" "$output" >> "$LOGFILE"
        if grep -q '^MANUAL[[:space:]]*|' <<< "$output"; then
            status="MANUAL"
            TOTAL_REMED_MANUAL=$((TOTAL_REMED_MANUAL + 1))
        elif (( rc != 0 )) || grep -q '^FAIL[[:space:]]*|' <<< "$output"; then
            status="FAIL"
            TOTAL_REMED_FAIL=$((TOTAL_REMED_FAIL + 1))
        else
            status="OK"
            TOTAL_REMED_OK=$((TOTAL_REMED_OK + 1))
        fi
        printf "%-30s %s\n" "$name" "$status"
    done
    echo "Rollback manifest: $rollback_file" >> "$LOGFILE"
}

summary() {
    local total percent
    total=$((TOTAL_PASS + TOTAL_FAIL))
    percent=0
    (( total > 0 )) && percent=$(( (TOTAL_PASS * 100) / total ))
    echo ""
    echo "Resumo:"
    echo "PASS : $TOTAL_PASS"
    echo "FAIL : $TOTAL_FAIL"
    echo "Aderencia: ${percent}%"
}

remed_summary() {
    echo ""
    echo "Resumo remediacao:"
    echo "OK     : $TOTAL_REMED_OK"
    echo "MANUAL : $TOTAL_REMED_MANUAL"
    echo "FAIL   : $TOTAL_REMED_FAIL"
    echo "SEM_AUTO: $TOTAL_REMED_SKIP"
}

report_unfixed() {
    local last_post
    last_post=$(ls -1t "$LOG_AUDIT"/audit-post-* 2>/dev/null | head -n 1)
    if [[ -z "$last_post" ]]; then
        echo "Nenhum log audit-post encontrado."
        return 1
    fi
    echo "Ultimo log: $last_post"
    echo ""
    echo "Itens sem remediacao:"
    awk '
        /^\[[0-9]+]/ { item=$0; next }
        /^[[:space:]]*FAIL[[:space:]]*$/ && item != "" { print item }
    ' "$last_post"
}

run_rollback() {
    local manifest="${1:-}"
    local item action target value extra

    if [ -z "$manifest" ]; then
        manifest="$(ls -1t "$LOG_ROLLBACK"/rollback-*.manifest 2>/dev/null | head -n 1)"
    fi
    if [ -z "$manifest" ] || [ ! -f "$manifest" ]; then
        echo "Nenhum manifesto de rollback encontrado."
        return 1
    fi
    if [ "$(id -u)" -ne 0 ]; then
        echo "FAIL | execute como root"
        return 1
    fi

    echo "=== ROLLBACK ==="
    echo "Manifesto: $manifest"
    tac "$manifest" | while IFS='|' read -r item action target value extra; do
        case "$action" in
            restore_file)
                if [ -f "$value" ]; then
                    cp -p "$value" "$target"
                    printf '[%s] OK | restaurado %s\n' "$item" "$target"
                else
                    printf '[%s] FAIL | backup ausente para %s\n' "$item" "$target"
                fi
                ;;
            remove_file)
                if [ -e "$target" ]; then
                    rm -f "$target"
                    printf '[%s] OK | removido %s\n' "$item" "$target"
                else
                    printf '[%s] OK | %s ja estava ausente\n' "$item" "$target"
                fi
                ;;
            chmod)
                if [ -n "$value" ] && [ -e "$target" ]; then
                    chmod "$value" "$target"
                    printf '[%s] OK | chmod %s %s\n' "$item" "$value" "$target"
                else
                    printf '[%s] MANUAL | nao foi possivel restaurar modo de %s\n' "$item" "$target"
                fi
                ;;
            file_meta)
                if [ -e "$target" ]; then
                    IFS=':' read -r value_user value_group value_mode <<< "$value"
                    [ -n "${value_user:-}" ] && [ -n "${value_group:-}" ] && chown "$value_user:$value_group" "$target"
                    [ -n "${value_mode:-}" ] && chmod "$value_mode" "$target"
                    printf '[%s] OK | metadata restaurada %s\n' "$item" "$target"
                else
                    printf '[%s] MANUAL | arquivo ausente para restaurar metadata: %s\n' "$item" "$target"
                fi
                ;;
            sysctl)
                if [ -n "$value" ]; then
                    sysctl -w "$target=$value" >/dev/null 2>&1 || true
                    printf '[%s] OK | sysctl %s=%s\n' "$item" "$target" "$value"
                else
                    printf '[%s] MANUAL | valor anterior de %s nao registrado\n' "$item" "$target"
                fi
                ;;
        esac
    done
}

run_audit() {
    TOTAL_PASS=0; TOTAL_FAIL=0
    AUDIT_RESULT_CSV="$LOG_AUDIT/audit-current.csv"
    printf "host,id,status\n" > "$AUDIT_RESULT_CSV"
    LOG="$LOG_AUDIT/audit-${HOSTNAME}-${DATE}.log"
    hitss_stamp "AUDIT" "START" "$LOG"
    echo "=== AUDIT ==="
    run_audit_scripts "$AUDIT_DIR" "$LOG"
    summary
    hitss_stamp "AUDIT" "END pass=$TOTAL_PASS fail=$TOTAL_FAIL" "$LOG"
    echo "Log: $LOG"
}

run_remed() {
    local ids_file
    if [ ! -s "$LOG_AUDIT/audit-current.csv" ]; then
        echo "Nenhum audit-current.csv encontrado. Execute primeiro: $0 audit"
        return 1
    fi
    ids_file="$LOG_REMED/failed-${HOSTNAME}-${DATE}.ids"
    failed_ids_from_csv "$LOG_AUDIT/audit-current.csv" > "$ids_file"
    if [ ! -s "$ids_file" ]; then
        echo "Nenhum item REPROVADO no ultimo audit."
        return 0
    fi
    TOTAL_REMED_OK=0; TOTAL_REMED_MANUAL=0; TOTAL_REMED_FAIL=0; TOTAL_REMED_SKIP=0
    LOG="$LOG_REMED/remed-${HOSTNAME}-${DATE}.log"
    hitss_stamp "REMEDIATION" "START" "$LOG"
    echo "=== REMEDIACAO DOS ITENS REPROVADOS ==="
    run_remed_scripts "$REMED_DIR" "$LOG" "$ids_file"
    remed_summary
    hitss_stamp "REMEDIATION" "END ok=$TOTAL_REMED_OK manual=$TOTAL_REMED_MANUAL fail=$TOTAL_REMED_FAIL sem_auto=$TOTAL_REMED_SKIP" "$LOG"
    echo "Log: $LOG"
}

run_remed_all() {
    TOTAL_REMED_OK=0; TOTAL_REMED_MANUAL=0; TOTAL_REMED_FAIL=0; TOTAL_REMED_SKIP=0
    LOG="$LOG_REMED/remed-all-${HOSTNAME}-${DATE}.log"
    hitss_stamp "REMEDIATION_ALL" "START" "$LOG"
    echo "=== REMEDIACAO COMPLETA ==="
    run_remed_scripts "$REMED_DIR" "$LOG"
    remed_summary
    hitss_stamp "REMEDIATION_ALL" "END ok=$TOTAL_REMED_OK manual=$TOTAL_REMED_MANUAL fail=$TOTAL_REMED_FAIL sem_auto=$TOTAL_REMED_SKIP" "$LOG"
    echo "Log: $LOG"
}

run_full() {
    LOG_PRE="$LOG_AUDIT/audit-pre-${HOSTNAME}-${DATE}.log"
    LOG_R="$LOG_REMED/remed-${HOSTNAME}-${DATE}.log"
    LOG_POST="$LOG_AUDIT/audit-post-${HOSTNAME}-${DATE}.log"
    IDS_FILE="$LOG_REMED/failed-pre-${HOSTNAME}-${DATE}.ids"
    hitss_stamp "FULL" "START" "$LOG_PRE"
    echo "=== AUDIT PRE ==="
    TOTAL_PASS=0; TOTAL_FAIL=0
    AUDIT_RESULT_CSV="$LOG_AUDIT/audit-pre-current.csv"
    printf "host,id,status\n" > "$AUDIT_RESULT_CSV"
    run_audit_scripts "$AUDIT_DIR" "$LOG_PRE"
    pre_pass=$TOTAL_PASS
    pre_fail=$TOTAL_FAIL
    failed_ids_from_csv "$AUDIT_RESULT_CSV" > "$IDS_FILE"
    summary
    hitss_stamp "AUDIT" "END pre_pass=$pre_pass pre_fail=$pre_fail" "$LOG_PRE"
    echo ""
    echo "=== REMEDIACAO DOS ITENS REPROVADOS ==="
    TOTAL_REMED_OK=0; TOTAL_REMED_MANUAL=0; TOTAL_REMED_FAIL=0; TOTAL_REMED_SKIP=0
    hitss_stamp "REMEDIATION" "START" "$LOG_R"
    if [ -s "$IDS_FILE" ]; then
        run_remed_scripts "$REMED_DIR" "$LOG_R" "$IDS_FILE"
    else
        : > "$LOG_R"
        echo "Nenhum item REPROVADO no audit pre."
    fi
    remed_summary
    hitss_stamp "REMEDIATION" "END ok=$TOTAL_REMED_OK manual=$TOTAL_REMED_MANUAL fail=$TOTAL_REMED_FAIL sem_auto=$TOTAL_REMED_SKIP" "$LOG_R"
    echo ""
    echo "=== AUDIT POS ==="
    TOTAL_PASS=0; TOTAL_FAIL=0
    AUDIT_RESULT_CSV="$LOG_AUDIT/audit-post-current.csv"
    printf "host,id,status\n" > "$AUDIT_RESULT_CSV"
    run_audit_scripts "$AUDIT_DIR" "$LOG_POST"
    post_pass=$TOTAL_PASS
    post_fail=$TOTAL_FAIL
    summary
    hitss_stamp "AUDIT" "END post_pass=$post_pass post_fail=$post_fail" "$LOG_POST"
    hitss_stamp "FULL" "END pre_fail=$pre_fail post_fail=$post_fail" "$LOG_POST"
    echo ""
    echo "Comparativo:"
    echo "Antes : PASS $pre_pass | FAIL $pre_fail"
    echo "Depois: PASS $post_pass | FAIL $post_fail"
    improvement=$((pre_fail - post_fail))
    if (( improvement > 0 )); then
        echo "Melhoria em $improvement controles"
    elif (( improvement == 0 )); then
        echo "Sem alteracao"
    else
        echo "Regressao detectada"
    fi
    echo ""
    echo "Logs:"
    echo "PRE  : $LOG_PRE"
    echo "REMED: $LOG_R"
    echo "POST : $LOG_POST"
}

case "${1:-menu}" in
    audit)   run_audit ;;
    remed)   run_remed ;;
    remed-all) run_remed_all ;;
    full)    run_full ;;
    report)  report_unfixed ;;
    rollback) run_rollback "${2:-}" ;;
    menu)
        echo "1) Audit"
        echo "2) Remediacao dos itens reprovados"
        echo "3) Full (Audit -> Remed -> Audit)"
        echo "4) Itens nao remediados (ultimo audit-post)"
        echo "5) Remediacao completa"
        echo "6) Rollback da ultima remediacao"
        read -rp "Escolha: " opt
        case "$opt" in
            1) run_audit ;;
            2) run_remed ;;
            3) run_full ;;
            4) report_unfixed ;;
            5) run_remed_all ;;
            6) run_rollback ;;
            *) exit 1 ;;
        esac
        ;;
    *)
        echo "Uso: $0 {audit|remed|remed-all|full|report|rollback|menu}"
        exit 1
        ;;
esac
