#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_79.log"

DOC_FILE="${DOCS_DIR}/SYNTHETIC_DATA_OPERATIONAL_REVIEW.md"
DOC_PLAN="${DOCS_DIR}/SYNTHETIC_DATA_CLEANUP_PLAN.md"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_79_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_79_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_79_attendance_conversations_domain.log"
DOMAIN_FAILURES_LOG="${LOGS_DIR}/setup_79_send_failures_domain.log"
DOMAIN_AUDIT_LOG="${LOGS_DIR}/setup_79_audit_domain.log"
DOMAIN_PAGES_LOG="${LOGS_DIR}/setup_79_pages_status.log"

DB_TABLES_LOG="${LOGS_DIR}/setup_79_database_tables.log"
DB_COUNTS_LOG="${LOGS_DIR}/setup_79_database_counts.log"
DB_SYNTHETIC_SUMMARY_LOG="${LOGS_DIR}/setup_79_synthetic_summary.log"
DB_SYNTHETIC_MESSAGES_LOG="${LOGS_DIR}/setup_79_synthetic_messages.log"
DB_SYNTHETIC_CONVERSATIONS_LOG="${LOGS_DIR}/setup_79_synthetic_conversations.log"
DB_SYNTHETIC_SENDS_LOG="${LOGS_DIR}/setup_79_synthetic_manual_sends.log"
DB_SYNTHETIC_WEBHOOKS_LOG="${LOGS_DIR}/setup_79_synthetic_webhook_events.log"
DB_SYNTHETIC_ACCOUNTS_LOG="${LOGS_DIR}/setup_79_synthetic_whatsapp_accounts.log"
DB_CLEANUP_SQL_PREVIEW="${LOGS_DIR}/setup_79_cleanup_sql_preview.sql"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_FAILURES_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send-failures"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit/summary"

echo "== Etapa 79: Revisao de dados sinteticos e limpeza operacional =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 78..."

if [ ! -f "${LOGS_DIR}/setup_78.log" ]; then
  echo "ERRO: setup_78.log nao encontrado. Conclua a Etapa 78 antes da Etapa 79."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_78.log"; then
  echo "ERRO: Etapa 78 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_78.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${DOC_FILE}" \
  "${DOC_PLAN}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md" \
  "${BASE_DIR}/CONTEXTO_PROJETO.md" \
  "${BASE_DIR}/CHANGELOG.md" \
  "${BASE_DIR}/DECISOES_TECNICAS.md" \
  "${BASE_DIR}/PENDENCIAS.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

for tool in node docker curl python3 grep sed; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando health publico..."

DOMAIN_HEALTH_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_HEALTH_URL}" || true)"

if [ "${DOMAIN_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health dominio falhou. Status ${DOMAIN_HEALTH_STATUS}"
  cat "${DOMAIN_HEALTH_LOG}"
  exit 1
fi

echo "Validando login dominio..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: credenciais da Etapa 24 ausentes."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

echo "Validando endpoints operacionais..."

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_LIST_STATUS}" != "200" ]; then
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

DOMAIN_FAILURES_STATUS="$(curl -L -s -o "${DOMAIN_FAILURES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_FAILURES_URL}" || true)"

if [ "${DOMAIN_FAILURES_STATUS}" != "200" ]; then
  echo "ERRO: send failures falhou. Status ${DOMAIN_FAILURES_STATUS}"
  cat "${DOMAIN_FAILURES_LOG}"
  exit 1
fi

DOMAIN_AUDIT_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}" || true)"

if [ "${DOMAIN_AUDIT_STATUS}" != "200" ]; then
  echo "AVISO: operational audit summary nao respondeu 200. Status ${DOMAIN_AUDIT_STATUS}" | tee -a "${LOG_FILE}.warnings"
fi

echo "Mapeando tabelas relacionadas..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_TABLES_LOG}"
select table_name
from information_schema.tables
where table_schema = 'public'
  and (
    table_name ilike '%message%'
    or table_name ilike '%conversation%'
    or table_name ilike '%attendance%'
    or table_name ilike '%webhook%'
    or table_name ilike '%whatsapp%'
    or table_name ilike '%audit%'
  )
order by table_name;
SQL

echo "Coletando contagens gerais..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_COUNTS_LOG}"
select 'conversations_total' as metric, count(id)::text as value from conversations
union all
select 'messages_total' as metric, count(id)::text as value from messages
union all
select 'messages_inbound_total' as metric, count(id)::text as value from messages where direction = 'inbound'
union all
select 'messages_outbound_total' as metric, count(id)::text as value from messages where direction = 'outbound'
union all
select 'manual_sends_total' as metric, count(id)::text as value from attendance_manual_message_sends
union all
select 'manual_sends_failed' as metric, count(id)::text as value from attendance_manual_message_sends where status = 'failed'
union all
select 'manual_sends_dry_run' as metric, count(id)::text as value from attendance_manual_message_sends where dry_run = true
union all
select 'webhook_events_total' as metric, count(id)::text as value from webhook_events
union all
select 'whatsapp_accounts_total' as metric, count(id)::text as value from whatsapp_accounts
union all
select 'whatsapp_accounts_deleted' as metric, count(id)::text as value from whatsapp_accounts where deleted_at is not null;
SQL

echo "Identificando candidatos sinteticos por marcadores conhecidos..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_SYNTHETIC_SUMMARY_LOG}"
select 'messages_body_sintetico' as area, count(id)::text as total
from messages
where body ilike '%teste%'
   or body ilike '%etapa%'
   or body ilike '%sintetica%'
   or body ilike '%validad%'
union all
select 'manual_sends_sintetico' as area, count(id)::text as total
from attendance_manual_message_sends
where message_body ilike '%teste%'
   or message_body ilike '%etapa%'
   or message_body ilike '%sintetica%'
   or message_body ilike '%validad%'
   or attendant_source = 'validation'
   or dry_run = true
union all
select 'conversations_sintetico' as area, count(c.id)::text as total
from conversations c
left join messages m on m.conversation_id = c.id
where m.body ilike '%teste%'
   or m.body ilike '%etapa%'
   or m.body ilike '%sintetica%'
   or m.body ilike '%validad%'
union all
select 'webhook_events_sintetico' as area, count(id)::text as total
from webhook_events
where event_type ilike '%test%'
   or coalesce(error_message, '') ilike '%teste%'
union all
select 'whatsapp_accounts_sintetico' as area, count(id)::text as total
from whatsapp_accounts
where phone_number_id ilike '%test%'
   or phone_number_id ilike '%local%'
   or phone_number_id ilike '%restore%'
   or phone_number_id ilike '%fix%'
   or phone_number_id ilike '%frontend%'
   or waba_id ilike '%test%'
   or waba_id ilike '%local%'
   or waba_id ilike '%restore%'
   or waba_id ilike '%fix%'
   or waba_id ilike '%frontend%';
SQL

echo "Listando mensagens candidatas sinteticas..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_SYNTHETIC_MESSAGES_LOG}"
select
  id,
  conversation_id,
  direction,
  type,
  left(coalesce(body, ''), 140) as body_preview,
  status,
  created_at
from messages
where body ilike '%teste%'
   or body ilike '%etapa%'
   or body ilike '%sintetica%'
   or body ilike '%validad%'
order by created_at desc
limit 80;
SQL

echo "Listando conversas relacionadas a candidatos sinteticos..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_SYNTHETIC_CONVERSATIONS_LOG}"
select distinct
  c.id,
  c.contact_id,
  c.whatsapp_account_id,
  c.status,
  c.created_at,
  c.updated_at
from conversations c
join messages m on m.conversation_id = c.id
where m.body ilike '%teste%'
   or m.body ilike '%etapa%'
   or m.body ilike '%sintetica%'
   or m.body ilike '%validad%'
order by c.updated_at desc
limit 80;
SQL

echo "Listando envios manuais candidatos sinteticos..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_SYNTHETIC_SENDS_LOG}"
select
  id,
  conversation_id,
  left(coalesce(message_body, ''), 140) as message_preview,
  provider,
  status,
  dry_run,
  attendant_source,
  retry_of_send_id,
  created_at
from attendance_manual_message_sends
where message_body ilike '%teste%'
   or message_body ilike '%etapa%'
   or message_body ilike '%sintetica%'
   or message_body ilike '%validad%'
   or attendant_source = 'validation'
   or dry_run = true
order by created_at desc
limit 120;
SQL

echo "Listando webhook events candidatos sinteticos..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_SYNTHETIC_WEBHOOKS_LOG}"
select
  id,
  event_type,
  status,
  coalesce(error_message, '') as error_message,
  created_at,
  updated_at
from webhook_events
where event_type ilike '%test%'
   or coalesce(error_message, '') ilike '%teste%'
order by created_at desc
limit 80;
SQL

echo "Listando contas WhatsApp candidatas sinteticas ou restauradas..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_SYNTHETIC_ACCOUNTS_LOG}"
select
  id,
  waba_id,
  phone_number_id,
  display_phone_number,
  verified_name,
  status,
  created_at,
  updated_at,
  deleted_at
from whatsapp_accounts
where phone_number_id ilike '%test%'
   or phone_number_id ilike '%local%'
   or phone_number_id ilike '%restore%'
   or phone_number_id ilike '%fix%'
   or phone_number_id ilike '%frontend%'
   or waba_id ilike '%test%'
   or waba_id ilike '%local%'
   or waba_id ilike '%restore%'
   or waba_id ilike '%fix%'
   or waba_id ilike '%frontend%'
   or deleted_at is not null
order by created_at desc
limit 120;
SQL

echo "Gerando preview SQL seguro sem execucao de limpeza..."

cat > "${DB_CLEANUP_SQL_PREVIEW}" <<'SQL'
-- Preview de limpeza operacional
-- Nao executar sem aprovacao explicita.
-- Este arquivo existe apenas para revisar criterios.
-- Nenhuma limpeza foi executada pela Etapa 79.

begin;

-- Exemplo de estrategia futura:
-- 1. exportar candidatos
-- 2. validar manualmente IDs
-- 3. executar soft delete quando a tabela suportar deleted_at
-- 4. preservar dados reais e historicos de auditoria
-- 5. registrar execucao em documento e log

rollback;
SQL

echo "Validando paginas principais..."

: > "${DOMAIN_PAGES_LOG}"

for page in \
  "/app/inbox" \
  "/app/attendance-settings" \
  "/app/send-failures" \
  "/app/attendance-dashboard" \
  "/app/audit"
do
  status="$(curl -L -s -o /dev/null -w "%{http_code}" --max-time 30 "${DOMAIN_BASE_URL}${page}" || true)"
  echo "${page} ${status}" | tee -a "${DOMAIN_PAGES_LOG}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: pagina ${page} nao respondeu 200."
    exit 1
  fi
done

echo "Gerando documentacao da Etapa 79..."

cat > "${DOC_FILE}" <<'DOC'
# Synthetic Data Operational Review

## Visao geral

Este documento registra a revisao operacional de dados sinteticos e de validacao.

## Resultado

Status:

    concluido

## Objetivo

Objetivo:

- identificar dados criados em testes e validacoes
- separar candidatos sinteticos de dados reais
- evitar limpeza destrutiva sem aprovacao
- preparar plano seguro de limpeza operacional
- manter historico e auditoria preservados

## Estrategia aplicada

Estrategia:

- revisao somente leitura
- nenhuma remocao executada
- nenhuma alteracao em banco executada
- logs de candidatos gerados
- plano de limpeza futura criado
- validacao de endpoints e paginas mantida

## Marcadores usados

Marcadores:

- teste
- etapa
- sintetica
- validad
- validation
- dryRun
- local
- restore
- fix
- frontend

## Areas revisadas

Areas:

- conversations
- messages
- attendance manual message sends
- webhook events
- whatsapp accounts
- paginas operacionais
- endpoints operacionais

## Logs gerados

Logs:

- logs/setup_79_database_tables.log
- logs/setup_79_database_counts.log
- logs/setup_79_synthetic_summary.log
- logs/setup_79_synthetic_messages.log
- logs/setup_79_synthetic_conversations.log
- logs/setup_79_synthetic_manual_sends.log
- logs/setup_79_synthetic_webhook_events.log
- logs/setup_79_synthetic_whatsapp_accounts.log
- logs/setup_79_cleanup_sql_preview.sql
- logs/setup_79_pages_status.log
- logs/setup_79.log

## Decisao operacional

Decisao:

- nao apagar dados nesta etapa
- revisar candidatos antes de qualquer limpeza real
- executar limpeza real somente em etapa futura com aprovacao explicita
- preferir soft delete quando existir suporte
- preservar eventos de auditoria e rastreabilidade

## Proxima etapa sugerida

Etapa 80:

    Revisao final do modulo Atendimento refinado
DOC

cat > "${DOC_PLAN}" <<'DOC'
# Synthetic Data Cleanup Plan

## Visao geral

Este documento registra o plano seguro para limpeza futura de dados sinteticos.

## Principios

Principios:

- nao remover dados reais
- nao remover dados sem backup
- nao remover dados sem relatorio previo
- nao remover dados sem aprovacao explicita
- preservar auditoria
- preservar rastreabilidade
- usar soft delete quando disponivel

## Criterios de candidato sintetico

Criterios:

- textos contendo teste
- textos contendo etapa
- textos contendo sintetica
- textos contendo validad
- registros com attendant source validation
- envios com dryRun
- contas com local no identificador
- contas com restore no identificador
- contas com fix no identificador
- contas com frontend no identificador

## Criterios de exclusao da limpeza

Exclusoes:

- mensagens reais de clientes
- mensagens inbound recentes sem marcador sintetico
- contas WhatsApp reais ativas
- eventos de auditoria necessarios para rastreabilidade
- dados relacionados a pendencia Meta
- dados sem marcador claro

## Processo futuro recomendado

Processo:

- revisar logs da Etapa 79
- aprovar lista de IDs
- gerar backup antes da limpeza
- executar limpeza em modo dryRun
- validar contagens
- executar limpeza real apenas com aceite
- atualizar documentos auxiliares
- registrar log final

## Status

Status:

    plano criado e aguardando aprovacao futura
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 79 - Revisao de dados sinteticos e limpeza operacional",
    "- [x] Etapa 79 - Revisao de dados sinteticos e limpeza operacional\n- [ ] Etapa 80 - Revisao final do modulo Atendimento refinado"
)

text = text.replace(
    "Etapa 79 - Revisao de dados sinteticos e limpeza operacional.",
    "Etapa 80 - Revisao final do modulo Atendimento refinado."
)

text = text.replace(
    "Etapa 78 - Separacao visual de envio encerramento e historico.",
    "Etapa 79 - Revisao de dados sinteticos e limpeza operacional."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Revisao de dados sinteticos e limpeza operacional concluida." not in text:
    text += "\nRevisao de dados sinteticos e limpeza operacional concluida.\n"

for doc in [
    "- docs/SYNTHETIC_DATA_OPERATIONAL_REVIEW.md",
    "- docs/SYNTHETIC_DATA_CLEANUP_PLAN.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 78 concluidas",
    "- Etapa 01 ate Etapa 79 concluidas"
)

text = text.replace(
    "- Etapa 79 - Revisao de dados sinteticos e limpeza operacional",
    "- Etapa 80 - Revisao final do modulo Atendimento refinado"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 79 - Revisao de dados sinteticos e limpeza operacional
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Realizada revisao somente leitura de dados sinteticos, com relatorios de candidatos, plano seguro de limpeza futura e preservacao de dados reais e auditoria.
DOC
  fi
done

echo "Registrando pendencia de limpeza real futura..."

if [ -f "${BASE_DIR}/PENDENCIAS.md" ]; then
  cat >> "${BASE_DIR}/PENDENCIAS.md" <<'DOC'

Pendencia - Limpeza real de dados sinteticos
Status: aguardando aprovacao explicita
Resumo: A Etapa 79 identificou candidatos sinteticos e gerou plano de limpeza. A remocao real deve ocorrer apenas apos revisao manual dos logs e aceite explicito.
DOC
fi

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${DOC_PLAN}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 79
Acao: Revisao de dados sinteticos e limpeza operacional
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Send failures status: ${DOMAIN_FAILURES_STATUS}
Operational audit status: ${DOMAIN_AUDIT_STATUS}
Database tables log: logs/setup_79_database_tables.log
Database counts log: logs/setup_79_database_counts.log
Synthetic summary log: logs/setup_79_synthetic_summary.log
Synthetic messages log: logs/setup_79_synthetic_messages.log
Synthetic conversations log: logs/setup_79_synthetic_conversations.log
Synthetic manual sends log: logs/setup_79_synthetic_manual_sends.log
Synthetic webhook events log: logs/setup_79_synthetic_webhook_events.log
Synthetic whatsapp accounts log: logs/setup_79_synthetic_whatsapp_accounts.log
Cleanup SQL preview: logs/setup_79_cleanup_sql_preview.sql
Pages status log: logs/setup_79_pages_status.log
Limpeza real executada: nao
Status: Concluido
DOC

echo ""
echo "== Etapa 79 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 80 - Revisao final do modulo Atendimento refinado"
