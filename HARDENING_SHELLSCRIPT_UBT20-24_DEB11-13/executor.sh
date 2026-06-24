#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$SCRIPT_DIR"
AUDIT_DIR="$BASE_DIR/AUDIT_SH"
REMED_DIR="$BASE_DIR/REMED_SH"
LOG_DIR="$BASE_DIR/logs"
LOG_AUDIT="$LOG_DIR/audit"
LOG_REMED="$LOG_DIR/remed"
HITSS_LOG_FILE="/var/log/hitss-hardening.log"
HITSS_VERSION="HARDENING HITSS DEBLIKE v1.2.4"
HITSS_ORIGIN="VIA EXECUCAO LOCAL AUTOMACAO SHELLSCRIPT"
HITSS_FAMILY="DEB_LIKE"
HOSTNAME="$(hostname -s)"
DATE="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$LOG_AUDIT" "$LOG_REMED"

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

run_remed_scripts() {
    local DIR="$1"
    local LOGFILE="$2"
    local IDS_FILE="${3:-}"
    local -a scripts=()
    : > "$LOGFILE"
    if [ -n "$IDS_FILE" ]; then
        while IFS= read -r id; do
            if [ -f "$DIR/$id.sh" ]; then
                scripts+=("$DIR/$id.sh")
            else
                printf "%-30s SEM_AUTO\n" "$id.sh" | tee -a "$LOGFILE"
                TOTAL_REMED_SKIP=$((TOTAL_REMED_SKIP + 1))
            fi
            done < "$IDS_FILE"
    else
        mapfile -t scripts < <(collect_scripts "$DIR")
    fi
    if (( ${#scripts[@]} == 0 )); then
        echo "Nenhum script de remediacao encontrado para executar."
        return 0
    fi
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
    menu)
        echo "1) Audit"
        echo "2) Remediacao dos itens reprovados"
        echo "3) Full (Audit -> Remed -> Audit)"
        echo "4) Itens nao remediados (ultimo audit-post)"
        echo "5) Remediacao completa"
        read -rp "Escolha: " opt
        case "$opt" in
            1) run_audit ;;
            2) run_remed ;;
            3) run_full ;;
            4) report_unfixed ;;
            5) run_remed_all ;;
            *) exit 1 ;;
        esac
        ;;
    *)
        echo "Uso: $0 {audit|remed|remed-all|full|report|menu}"
        exit 1
        ;;
esac
