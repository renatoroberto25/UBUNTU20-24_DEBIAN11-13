#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

PWQUALITY="/etc/security/pwquality.conf"
FAILLOCK="/etc/security/faillock.conf"
LOGIN_DEFS="/etc/login.defs"

set_pwquality_multi() {
    local id="$1"
    shift
    local kv key value

    for kv in "$@"; do
        key="${kv%% *}"
        value="${kv#* }"
        set_kv_item "$id" "$PWQUALITY" "$key" "$value" || return 1
    done
    emit "$id" "OK" "pwquality atualizado"
}

set_faillock_option() {
    local id="$1"
    local key="$2"
    local value="$3"

    set_kv_item "$id" "$FAILLOCK" "$key" "$value" || return 1
    emit "$id" "OK" "$key=$value"
}

set_login_defs_option() {
    local id="$1"
    local key="$2"
    local value="$3"

    set_space_kv_item "$id" "$LOGIN_DEFS" "$key" "$value" || return 1
    emit "$id" "OK" "$key $value"
}

write_profile_snippet() {
    local id="$1"
    local path="$2"
    local content="$3"
    local msg="$4"

    write_file_mode_item "$id" "$path" 644 "$content" || return 1
    emit "$id" "OK" "$msg"
}

run_id() {
    local id="$1"

    case "$id" in
        130|131|132|133|134|139)
            sem_auto "$id" "alteracao de stack PAM deve seguir padrao aprovado do cliente"
            ;;
        135) set_pwquality_multi "$id" "minlen 14" ;;
        136) set_pwquality_multi "$id" "minclass 4" ;;
        137) set_pwquality_multi "$id" "maxrepeat 3" "maxsequence 3" ;;
        138) set_pwquality_multi "$id" "dictcheck 1" ;;
        140) sem_auto "$id" "historico de senhas depende da stack PAM/pwhistory aprovada" ;;
        141) set_faillock_option "$id" "deny" "5" ;;
        142) set_faillock_option "$id" "unlock_time" "900" ;;
        143) set_login_defs_option "$id" "PASS_MAX_DAYS" "365" ;;
        144) set_login_defs_option "$id" "PASS_MIN_DAYS" "1" ;;
        145) set_login_defs_option "$id" "PASS_WARN_AGE" "7" ;;
        146) sem_auto "$id" "INACTIVE em contas existentes altera ciclo de vida de usuarios" ;;
        147) sem_auto "$id" "corrigir datas de senha exige avaliacao por conta" ;;
        148) sem_auto "$id" "UID 0 extra exige decisao de remocao/correcao por conta" ;;
        149) sem_auto "$id" "GID 0 extra exige decisao de remocao/correcao por grupo" ;;
        150) sem_auto "$id" "bloqueio de contas de sistema exige lista de excecoes do cliente" ;;
        151) append_unique_line_item "$id" "/etc/shells" "/usr/sbin/nologin" && emit "$id" "OK" "/usr/sbin/nologin registrado em /etc/shells" ;;
        152) sem_auto "$id" "PATH do root depende do perfil/shell administrado pelo cliente" ;;
        153) write_profile_snippet "$id" "/etc/profile.d/99-hitss-umask.sh" "umask 027" "umask padrao restritiva configurada" ;;
        154) write_profile_snippet "$id" "/etc/profile.d/99-hitss-tmout.sh" "readonly TMOUT=900
export TMOUT" "timeout de shell configurado" ;;
        *) sem_auto "$id" "item fora do grupo Senhas e Contas" ;;
    esac
}

if (( $# == 0 )); then
    set -- 135 136 137 138 141 142 143 144 145 151 153 154
fi

for id in "$@"; do
    run_id "$id"
done
