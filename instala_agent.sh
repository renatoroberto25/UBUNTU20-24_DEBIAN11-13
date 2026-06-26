#!/bin/bash
set -euo pipefail
# Configurações
FLAG_FILE="/var/lib/tenable/nessusagent/.first-boot-done"
T_KEY="${T_KEY:-45b85b603d4f4ed07d445151eacc6db46715a19318c42da539327de707dedbac }"
T_HOST="${T_HOST:-sensor.cloud.tenable.com}"
T_PORT="${T_PORT:-443}"
T_GROUPS="${T_GROUPS:-LINUX_DEFAULT}"
HNAME="${HNAME:-$(hostname -s 2>/dev/null || hostname)}"
CLI="/opt/nessus_agent/sbin/nessuscli"
log() { echo "[$1] $2"; }
# 1. Instalação (se necessário)
if [ ! -x "$CLI" ]; then
  log "INFO" "Instalando Tenable Agent em $HNAME"
  curl -fsSL -G -H "X-Key: $T_KEY" --data-urlencode "name=$HNAME" \
    --data-urlencode "groups=$T_GROUPS" "https://$T_HOST/install/agent" | bash
  sleep 5
fi

# 2. Garantir que o serviço está rodando
systemctl enable --now nessusagent >/dev/null 2>&1 || service nessusagent start >/dev/null 2>&1

# 3. Verificação de Vínculo (Link)
STATUS=$($CLI agent status 2>&1 || true)

if [[ ! "$STATUS" =~ "Linked to: $T_HOST:$T_PORT" ]]; then
  log "WARN" "Configurando link com Tenable..."
  [[ "$STATUS" =~ "Linked to:" && ! "$STATUS" =~ "Linked to: None" ]] && $CLI agent unlink --force
  $CLI agent link --key="$T_KEY" --host="$T_HOST" --port="$T_PORT" --groups="$T_GROUPS" --name="$HNAME"
  sleep 5
fi

# 4. Loop de espera de conexão (máx 2 min)
for i in {1..12}; do
  STATUS=$($CLI agent status 2>&1 || true)
  if [[ "$STATUS" =~ "Link status: Connected" ]]; then
    log "OK" "Agent conectado com sucesso!"
    mkdir -p "$(dirname "$FLAG_FILE")"
    touch "$FLAG_FILE"
    log "OK" "Flag de bootstrap registrada em $FLAG_FILE"
    echo "$STATUS"
    exit 0
  fi
  log "INFO" "Aguardando conexão ($i/12)..."
  sleep 10
done

log "ERRO" "Agent não conectou a tempo."
echo "$STATUS"
exit 1