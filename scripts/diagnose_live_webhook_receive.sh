#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
REPORT_FILE="${LOGS_DIR}/diagnose_live_webhook_receive.log"
BACKEND_LIVE_LOG="${LOGS_DIR}/diagnose_live_webhook_backend_tail.log"
DB_BEFORE_FILE="${LOGS_DIR}/diagnose_live_webhook_db_before.log"
DB_AFTER_FILE="${LOGS_DIR}/diagnose_live_webhook_db_after.log"
DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
WEBHOOK_URL="${DOMAIN_BASE_URL}/api/v1/webhooks/meta"
WAIT_SECONDS="${1:-90}"

echo "== Diagnostico ao vivo de recebimento WhatsApp =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"

: > "${REPORT_FILE}"
: > "${BACKEND_LIVE_LOG}"
: > "${DB_BEFORE_FILE}"
: > "${DB_AFTER_FILE}"

log() {
  echo "$1" | tee -a "${REPORT_FILE}"
}

log "Data: $(date '+%Y-%m-%d %H:%M:%S')"
log "Janela de monitoramento: ${WAIT_SECONDS} segundos"
log ""

log "== 1. Containers =="
docker compose ps | tee -a "${REPORT_FILE}"

log ""
log "== 2. Health backend local =="
curl -s -i --max-time 10 "http://127.0.0.1:3300/api/v1/health" | tee -a "${REPORT_FILE}" || true

log ""
log "== 3. Identificando verify token sem exibir segredo =="

VERIFY_TOKEN=""

if [ -f ".env" ]; then
  VERIFY_TOKEN="$(grep -E '^(META_WEBHOOK_VERIFY_TOKEN|WHATSAPP_VERIFY_TOKEN)=' .env | head -n 1 | cut -d '=' -f 2- | tr -d '"' | tr -d "'" || true)"
fi

if [ -z "${VERIFY_TOKEN}" ] && [ -f "apps/backend/.env" ]; then
  VERIFY_TOKEN="$(grep -E '^(META_WEBHOOK_VERIFY_TOKEN|WHATSAPP_VERIFY_TOKEN)=' apps/backend/.env | head -n 1 | cut -d '=' -f 2- | tr -d '"' | tr -d "'" || true)"
fi

if [ -z "${VERIFY_TOKEN}" ]; then
  log "ERRO: verify token nao encontrado em .env nem apps/backend/.env"
  exit 1
fi

log "Verify token encontrado: SIM"
log "Tamanho do verify token: ${#VERIFY_TOKEN}"

log ""
log "== 4. Teste GET do webhook com token real =="
WEBHOOK_GET_STATUS="$(curl -L -s -o "${LOGS_DIR}/diagnose_live_webhook_get_real_token.log" -w "%{http_code}" --max-time 20 \
  "${WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=987654321" || true)"

log "Webhook GET status: ${WEBHOOK_GET_STATUS}"
log "Webhook GET body:"
cat "${LOGS_DIR}/diagnose_live_webhook_get_real_token.log" | tee -a "${REPORT_FILE}"
log ""

if [ "${WEBHOOK_GET_STATUS}" != "200" ]; then
  log "ALERTA: webhook nao validou com o token real localizado."
  log "Isso indica possivel divergencia entre token do .env e token usado pelo backend/container."
fi

log ""
log "== 5. Contagem antes do teste =="

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_BEFORE_FILE}" | tee -a "${REPORT_FILE}"
select 'messages_total' as metric, count(*)::text as value from messages
union all
select 'messages_inbound_total' as metric, count(*)::text as value from messages where direction = 'inbound'
union all
select 'webhook_events_total' as metric, count(*)::text as value from webhook_events
union all
select 'webhook_events_received' as metric, count(*)::text as value from webhook_events where status = 'received'
union all
select 'webhook_events_processed' as metric, count(*)::text as value from webhook_events where status = 'processed'
union all
select 'webhook_events_failed' as metric, count(*)::text as value from webhook_events where status = 'failed';
SQL

log ""
log "== 6. Ultimas mensagens inbound antes do teste =="

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}"
select id, conversation_id, contact_id, whatsapp_account_id, direction, type, body, status, created_at
from messages
where direction = 'inbound'
order by created_at desc
limit 5;
SQL

log ""
log "== 7. Ultimos webhook_events antes do teste =="

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}"
select id, event_type, status, created_at, updated_at
from webhook_events
order by created_at desc
limit 5;
SQL

log ""
log "== 8. Monitoramento ao vivo =="
log "Agora envie uma mensagem real pelo WhatsApp para o numero conectado ao app."
log "O script vai aguardar ${WAIT_SECONDS} segundos e capturar logs do backend."
log ""

(
  timeout "${WAIT_SECONDS}" docker compose logs -f backend \
    | grep -Ei "webhook|meta|whatsapp|message|mensagem|signature|assinatura|received|processed|failed|error|erro|exception|forbidden|unauthorized|bad request" \
    > "${BACKEND_LIVE_LOG}" 2>&1
) || true

log "Monitoramento encerrado."
log ""

log "== 9. Logs capturados durante a janela =="
if [ -s "${BACKEND_LIVE_LOG}" ]; then
  sed -n '1,260p' "${BACKEND_LIVE_LOG}" | tee -a "${REPORT_FILE}"
else
  log "Nenhum log relacionado a webhook/meta/message foi capturado durante a janela."
fi

log ""
log "== 10. Contagem depois do teste =="

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_AFTER_FILE}" | tee -a "${REPORT_FILE}"
select 'messages_total' as metric, count(*)::text as value from messages
union all
select 'messages_inbound_total' as metric, count(*)::text as value from messages where direction = 'inbound'
union all
select 'webhook_events_total' as metric, count(*)::text as value from webhook_events
union all
select 'webhook_events_received' as metric, count(*)::text as value from webhook_events where status = 'received'
union all
select 'webhook_events_processed' as metric, count(*)::text as value from webhook_events where status = 'processed'
union all
select 'webhook_events_failed' as metric, count(*)::text as value from webhook_events where status = 'failed';
SQL

log ""
log "== 11. Comparativo antes/depois =="

python3 <<'PY' | tee -a "${REPORT_FILE}"
from pathlib import Path

before_path = Path("logs/diagnose_live_webhook_db_before.log")
after_path = Path("logs/diagnose_live_webhook_db_after.log")

def parse(path):
    data = {}
    for line in path.read_text().splitlines():
        if "|" not in line:
            continue
        parts = [item.strip() for item in line.split("|")]
        if len(parts) >= 2 and parts[0] and parts[0] != "metric" and not parts[0].startswith("-"):
            try:
                data[parts[0]] = int(parts[1])
            except ValueError:
                pass
    return data

before = parse(before_path)
after = parse(after_path)

keys = sorted(set(before) | set(after))

for key in keys:
    b = before.get(key, 0)
    a = after.get(key, 0)
    diff = a - b
    print(f"{key}: antes={b} depois={a} diferenca={diff}")
PY

log ""
log "== 12. Novas mensagens inbound recentes =="

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}"
select id, conversation_id, contact_id, whatsapp_account_id, direction, type, body, status, created_at
from messages
where direction = 'inbound'
order by created_at desc
limit 10;
SQL

log ""
log "== 13. Novos webhook_events recentes =="

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}"
select id, event_type, status, error_message, created_at, updated_at
from webhook_events
order by created_at desc
limit 10;
SQL

log ""
log "== 14. Interpretacao rapida =="
log "Se messages_inbound_total aumentou: a mensagem chegou ao banco."
log "Se webhook_events_total aumentou mas messages_inbound_total nao: webhook chegou, mas processamento da mensagem falhou ou nao gerou mensagem."
log "Se nenhum contador aumentou e nao houve log: a Meta provavelmente nao chamou este backend."
log "Se webhook GET status nao foi 200: revise verify token usado no painel Meta e no container backend."
log ""
log "== Diagnostico ao vivo concluido =="
log "Relatorio: ${REPORT_FILE}"
