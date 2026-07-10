#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
REPORT_FILE="${LOGS_DIR}/diagnose_inbound_messages.log"
DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"

echo "== Diagnostico de recebimento de mensagens WhatsApp =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"

: > "${REPORT_FILE}"

log() {
  echo "$1" | tee -a "${REPORT_FILE}"
}

log "Data: $(date '+%Y-%m-%d %H:%M:%S')"
log ""
log "== 1. Containers =="
docker compose ps | tee -a "${REPORT_FILE}"

log ""
log "== 2. Health backend local =="
curl -s -i --max-time 10 "http://127.0.0.1:3300/api/v1/health" | tee -a "${REPORT_FILE}" || true

log ""
log "== 3. Busca por rotas e codigo de webhook no backend =="
grep -RIn \
  "webhook\|hub.challenge\|hub.verify_token\|x-hub-signature\|x-hub-signature-256\|whatsapp_business_account\|messages" \
  apps/backend/src \
  | sed -n '1,240p' \
  | tee -a "${REPORT_FILE}" || true

log ""
log "== 4. Variaveis relacionadas a Meta e webhook sem exibir segredos =="

for env_file in .env apps/backend/.env apps/backend/.env.production apps/backend/.env.local; do
  if [ -f "${env_file}" ]; then
    log "Arquivo: ${env_file}"
    grep -Ein "META|WHATSAPP|WEBHOOK|VERIFY|GRAPH|PHONE_NUMBER" "${env_file}" \
      | sed -E 's/(=).*/=***REDACTED***/' \
      | tee -a "${REPORT_FILE}" || true
  fi
done

log ""
log "== 5. Logs recentes do backend relacionados a webhook/meta/message/error =="
docker compose logs --tail=500 backend \
  | grep -Ei "webhook|meta|whatsapp|message|mensagem|signature|assinatura|error|erro|exception|forbidden|unauthorized|bad request" \
  | sed -n '1,260p' \
  | tee -a "${REPORT_FILE}" || true

log ""
log "== 6. Teste de rotas provaveis de webhook com GET sem token real =="
for path in \
  "/api/v1/meta/webhook" \
  "/api/v1/meta/webhooks" \
  "/api/v1/webhooks/meta" \
  "/api/v1/webhooks/whatsapp" \
  "/api/v1/whatsapp/webhook" \
  "/api/v1/whatsapp/webhooks"
do
  log "Testando ${DOMAIN_BASE_URL}${path}"
  curl -s -i --max-time 15 \
    "${DOMAIN_BASE_URL}${path}?hub.mode=subscribe&hub.verify_token=diagnostico&hub.challenge=123456" \
    | sed -n '1,20p' \
    | tee -a "${REPORT_FILE}" || true
  log ""
done

log ""
log "== 7. Tabelas relacionadas a mensagens no banco =="
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}"
select table_name
from information_schema.tables
where table_schema = 'public'
  and (
    table_name ilike '%message%'
    or table_name ilike '%conversation%'
    or table_name ilike '%webhook%'
    or table_name ilike '%whatsapp%'
  )
order by table_name;
SQL

log ""
log "== 8. Contagem recente em tabelas provaveis =="
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}"
do $$
declare
  r record;
  sql text;
begin
  for r in
    select table_name
    from information_schema.tables
    where table_schema = 'public'
      and (
        table_name ilike '%message%'
        or table_name ilike '%conversation%'
        or table_name ilike '%webhook%'
        or table_name ilike '%whatsapp%'
      )
    order by table_name
  loop
    sql := format('select %L as table_name, count(*) as total from %I', r.table_name, r.table_name);
    execute sql;
  end loop;
end $$;
SQL

log ""
log "== 9. Ultimas mensagens se existir tabela messages ou Message =="
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}" || true
select 'messages' as source, *
from messages
order by created_at desc
limit 5;
SQL

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}" || true
select 'Message' as source, *
from "Message"
order by "createdAt" desc
limit 5;
SQL

log ""
log "== 10. Ultimas conversas =="
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}" || true
select *
from conversations
order by updated_at desc
limit 5;
SQL

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee -a "${REPORT_FILE}" || true
select *
from "Conversation"
order by "updatedAt" desc
limit 5;
SQL

log ""
log "== Diagnostico concluido =="
log "Relatorio: ${REPORT_FILE}"
