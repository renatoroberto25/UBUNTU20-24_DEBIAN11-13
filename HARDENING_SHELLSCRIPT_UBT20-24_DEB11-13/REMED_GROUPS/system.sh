#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib.sh"

configure_postfix_local_only() {
    local id="$1"
    local file="/etc/postfix/main.cf"

    require_root "$id" || return 1
    if [ ! -f "$file" ]; then
        emit "$id" "OK" "postfix ausente"
        return 0
    fi
    set_kv_item "$id" "$file" "inet_interfaces" "loopback-only" || return 1
    systemctl restart postfix >/dev/null 2>&1 || true
    emit "$id" "OK" "postfix configurado como local-only"
}

enforce_apt_signature_checks() {
    local id="$1"
    local file="/etc/apt/apt.conf.d/99-hitss-no-insecure"
    local content

    content='Acquire::AllowInsecureRepositories "false";
Acquire::AllowDowngradeToInsecureRepositories "false";
APT::Get::AllowUnauthenticated "false";'
    write_file_item "$id" "$file" "$content" || return 1
    sanitize_apt_trusted_sources "$id" || return 1
    emit "$id" "OK" "APT configurado para rejeitar repositorios inseguros"
}

sanitize_apt_trusted_sources() {
    local id="$1"
    local src

    require_root "$id" || return 1
    while IFS= read -r -d '' src; do
        if grep -Eiq '(^|[[:space:]\[])trusted[[:space:]]*=[[:space:]]*yes|^[[:space:]]*Trusted:[[:space:]]*yes' "$src"; then
            backup_file "$id" "$src"
            sed -i -E 's/([[:space:]\[]trusted[[:space:]]*=[[:space:]]*)yes/\1no/Ig; s/^([[:space:]]*Trusted:[[:space:]]*)yes[[:space:]]*$/\1no/I' "$src"
        fi
    done < <(find /etc/apt/sources.list /etc/apt/sources.list.d -type f -print0 2>/dev/null)
}

restrict_cron_at() {
    local id="$1"
    local cron_group="root"

    require_root "$id" || return 1
    getent group crontab >/dev/null 2>&1 && cron_group="crontab"
    ensure_file_item "$id" "/etc/cron.allow" root "$cron_group" 640 || return 1
    remove_file_item "$id" "/etc/cron.deny" || return 1
    ensure_file_item "$id" "/etc/at.allow" root root 640 || return 1
    remove_file_item "$id" "/etc/at.deny" || return 1
    emit "$id" "OK" "cron e at restritos por allow-list"
}

run_id() {
    local id="$1"

    case "$id" in
        056) sem_auto "$id" "remocao de prelink envolve pacote e decisao operacional" ;;
        057) sem_auto "$id" "xinetd depende de requisito de servico do cliente" ;;
        058) sem_auto "$id" "ativar time sync exige escolha do mecanismo aprovado" ;;
        059) sem_auto "$id" "fontes NTP confiaveis devem ser definidas pelo cliente" ;;
        060) sem_auto "$id" "NTP no boot depende do mecanismo de time sync escolhido" ;;
        061) sem_auto "$id" "remocao de X11 depende do perfil do host" ;;
        062) sem_auto "$id" "avahi depende de requisito de descoberta de rede" ;;
        063) sem_auto "$id" "CUPS depende de requisito de impressao" ;;
        064|065|066|067|068|069|070|071|072|073|074)
            sem_auto "$id" "remocao/desabilitacao de servico servidor depende do papel do host"
            ;;
        075) configure_postfix_local_only "$id" ;;
        076|077|078)
            sem_auto "$id" "desabilitar servico depende de requisito operacional do cliente"
            ;;
        079|080|081|082|083)
            sem_auto "$id" "remocao de cliente/pacote depende de uso aprovado pelo cliente"
            ;;
        084) sem_auto "$id" "servicos superfluos exigem lista aprovada pelo cliente" ;;
        085) sem_auto "$id" "TFTP envolve pacote/servico e papel do host" ;;
        086) sem_auto "$id" "politica polkit precisa de baseline aprovado pelo cliente" ;;
        087) enforce_apt_signature_checks "$id" ;;
        088) sem_auto "$id" "aplicar patches exige janela de mudanca do cliente" ;;
        089) sem_auto "$id" "time sync unico exige escolha do mecanismo a manter" ;;
        090) restrict_cron_at "$id" ;;
        *) sem_auto "$id" "item fora do grupo Sistema" ;;
    esac
}

if (( $# == 0 )); then
    set -- 075 087 090
fi

for id in "$@"; do
    run_id "$id"
done
