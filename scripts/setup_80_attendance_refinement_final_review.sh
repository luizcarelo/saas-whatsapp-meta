#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_80.log"
DOC_FILE="${DOCS_DIR}/ATTENDANCE_REFINEMENT_FINAL_REVIEW.md"
DOC_NEXT="${DOCS_DIR}/ATTENDANCE_REFINEMENT_NEXT_DECISIONS.md"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_80_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_80_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_80_attendance_conversations_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_80_status_model_domain.log"
DOMAIN_DEPARTMENTS_LOG="${LOGS_DIR}/setup_80_departments_domain.log"
DOMAIN_QUICK_REPLIES_LOG="${LOGS_DIR}/setup_80_quick_replies_domain.log"
DOMAIN_AUTOMATION_RULES_LOG="${LOGS_DIR}/setup_80_automation_rules_domain.log"
DOMAIN_FAILURES_LOG="${LOGS_DIR}/setup_80_send_failures_domain.log"
DOMAIN_RETRIES_LOG="${LOGS_DIR}/setup_80_send_retries_domain.log"
DOMAIN_AUDIT_LOG="${LOGS_DIR}/setup_80_audit_summary_domain.log"
DOMAIN_WEBHOOK_GET_LOG="${LOGS_DIR}/setup_80_webhook_get_domain.log"
DOMAIN_PAGES_LOG="${LOGS_DIR}/setup_80_pages_status.log"
DB_COUNTS_LOG="${LOGS_DIR}/setup_80_database_counts.log"
DOCS_CHECK_LOG="${LOGS_DIR}/setup_80_docs_check.log"
STEPS_CHECK_LOG="${LOGS_DIR}/setup_80_steps_check.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_STATUS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-status"
DOMAIN_AUTOMATIONS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-automations"
DOMAIN_FAILURES_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send-failures"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit/summary"
DOMAIN_WEBHOOK_URL="${DOMAIN_BASE_URL}/api/v1/webhooks/meta"

echo "== Etapa 80: Revisao final do modulo Atendimento refinado =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${DOC_FILE}" \
  "${DOC_NEXT}" \
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

echo "Validando etapas 74 a 79..."

: > "${STEPS_CHECK_LOG}"

for step in 74 75 76 77 78 79; do
  step_log="${LOGS_DIR}/setup_${step}.log"

  if [ ! -f "${step_log}" ]; then
    echo "ERRO: log ausente: ${step_log}" | tee -a "${STEPS_CHECK_LOG}"
    exit 1
  fi

  if ! grep -q "Status: Concluido" "${step_log}"; then
    echo "ERRO: Etapa ${step} nao esta concluida." | tee -a "${STEPS_CHECK_LOG}"
    cat "${step_log}"
    exit 1
  fi

  echo "OK: Etapa ${step} concluida" | tee -a "${STEPS_CHECK_LOG}"
done

echo "Validando documentos da fase de refino..."

: > "${DOCS_CHECK_LOG}"

for doc_file in \
  "docs/ATTENDANCE_MODULE_REFINEMENT_PLAN.md" \
  "docs/ATTENDANCE_DOMAIN_BOUNDARIES.md" \
  "docs/ATTENDANCE_SCREEN_REORGANIZATION.md" \
  "docs/ATTENDANCE_STATUS_MODEL.md" \
  "docs/ATTENDANCE_REFINEMENT_ROADMAP.md" \
  "docs/ATTENDANCE_STATUS_STANDARDIZATION.md" \
  "docs/ATTENDANCE_STATUS_COMPATIBILITY_MAP.md" \
  "docs/ATTENDANCE_INBOX_VISUAL_REORGANIZATION.md" \
  "docs/ATTENDANCE_INBOX_VISUAL_CHECKLIST.md" \
  "docs/ATTENDANCE_SETTINGS_PAGE.md" \
  "docs/ATTENDANCE_SETTINGS_CHECKLIST.md" \
  "docs/ATTENDANCE_SEND_CLOSURE_HISTORY_VISUAL_SPLIT.md" \
  "docs/ATTENDANCE_SEND_CLOSURE_HISTORY_CHECKLIST.md" \
  "docs/SYNTHETIC_DATA_OPERATIONAL_REVIEW.md" \
  "docs/SYNTHETIC_DATA_CLEANUP_PLAN.md" \
  "docs/PENDENCIA_META_WEBHOOK_RECEBIMENTO.md"
do
  if [ -f "${doc_file}" ]; then
    echo "OK: ${doc_file}" | tee -a "${DOCS_CHECK_LOG}"
  else
    echo "AUSENTE: ${doc_file}" | tee -a "${DOCS_CHECK_LOG}"
    exit 1
  fi
done

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

echo "Validando endpoints principais do atendimento..."

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

DOMAIN_STATUS_MODEL_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MODEL_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_STATUS_URL}/model" || true)"

DOMAIN_DEPARTMENTS_STATUS="$(curl -L -s -o "${DOMAIN_DEPARTMENTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/departments" || true)"

DOMAIN_QUICK_REPLIES_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies" || true)"

DOMAIN_AUTOMATION_RULES_STATUS="$(curl -L -s -o "${DOMAIN_AUTOMATION_RULES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUTOMATIONS_URL}/rules" || true)"

DOMAIN_FAILURES_STATUS="$(curl -L -s -o "${DOMAIN_FAILURES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_FAILURES_URL}" || true)"

DOMAIN_RETRIES_STATUS="$(curl -L -s -o "${DOMAIN_RETRIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_FAILURES_URL}/retries" || true)"

DOMAIN_AUDIT_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}" || true)"

for pair in \
  "attendance-conversations:${DOMAIN_ATTENDANCE_LIST_STATUS}" \
  "status-model:${DOMAIN_STATUS_MODEL_STATUS}" \
  "departments:${DOMAIN_DEPARTMENTS_STATUS}" \
  "quick-replies:${DOMAIN_QUICK_REPLIES_STATUS}" \
  "automation-rules:${DOMAIN_AUTOMATION_RULES_STATUS}" \
  "send-failures:${DOMAIN_FAILURES_STATUS}" \
  "send-retries:${DOMAIN_RETRIES_STATUS}" \
  "audit-summary:${DOMAIN_AUDIT_STATUS}"
do
  name="${pair%%:*}"
  status="${pair##*:}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: endpoint ${name} falhou com status ${status}"
    exit 1
  fi
done

echo "Validando webhook GET com WHATSAPP_VERIFY_TOKEN..."

VERIFY_TOKEN="$(grep '^WHATSAPP_VERIFY_TOKEN=' .env | head -n 1 | cut -d '=' -f 2- | tr -d '"' | tr -d "'" || true)"

if [ -z "${VERIFY_TOKEN}" ]; then
  echo "ERRO: WHATSAPP_VERIFY_TOKEN ausente no .env"
  exit 1
fi

DOMAIN_WEBHOOK_GET_STATUS="$(curl -L -s -o "${DOMAIN_WEBHOOK_GET_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=808080" || true)"

if [ "${DOMAIN_WEBHOOK_GET_STATUS}" != "200" ]; then
  echo "ERRO: webhook GET falhou. Status ${DOMAIN_WEBHOOK_GET_STATUS}"
  cat "${DOMAIN_WEBHOOK_GET_LOG}"
  exit 1
fi

if ! grep -q "808080" "${DOMAIN_WEBHOOK_GET_LOG}"; then
  echo "ERRO: webhook GET nao retornou challenge esperado."
  cat "${DOMAIN_WEBHOOK_GET_LOG}"
  exit 1
fi

echo "Coletando contagens finais do banco..."

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
select 'automation_rules_total' as metric, count(id)::text as value from attendance_automation_rules
union all
select 'automation_executions_total' as metric, count(id)::text as value from attendance_automation_executions
union all
select 'status_catalog_total' as metric, count(id)::text as value from attendance_status_catalog
union all
select 'status_compatibility_total' as metric, count(id)::text as value from attendance_status_compatibility_map
union all
select 'webhook_events_total' as metric, count(id)::text as value from webhook_events
union all
select 'whatsapp_accounts_total' as metric, count(id)::text as value from whatsapp_accounts
union all
select 'whatsapp_accounts_deleted' as metric, count(id)::text as value from whatsapp_accounts where deleted_at is not null;
SQL

echo "Validando paginas principais..."

: > "${DOMAIN_PAGES_LOG}"

for page in \
  "/app/inbox" \
  "/app/attendance-settings" \
  "/app/send-failures" \
  "/app/attendance-dashboard" \
  "/app/dashboard" \
  "/app/audit"
do
  status="$(curl -L -s -o /dev/null -w "%{http_code}" --max-time 30 "${DOMAIN_BASE_URL}${page}" || true)"
  echo "${page} ${status}" | tee -a "${DOMAIN_PAGES_LOG}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: pagina ${page} nao respondeu 200."
    exit 1
  fi
done

echo "Gerando documento final da Etapa 80..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Refinement Final Review

## Visao geral

Este documento registra a revisao final do modulo Atendimento refinado.

## Resultado

Status:

    concluido

## Escopo revisado

Escopo:

- refino estrutural do modulo Atendimento
- padronizacao de status
- reorganizacao visual do app inbox
- criacao da tela attendance settings
- separacao visual de envio, encerramento e historico
- revisao de dados sinteticos
- preservacao da pendencia Meta

## Etapas revisadas

Etapas:

- Etapa 74 - Refino estrutural do modulo Atendimento
- Etapa 75 - Padronizacao dos status de atendimento
- Etapa 76 - Reorganizacao visual do app inbox
- Etapa 77 - Criacao da tela attendance settings
- Etapa 78 - Separacao visual de envio encerramento e historico
- Etapa 79 - Revisao de dados sinteticos e limpeza operacional
- Etapa 80 - Revisao final do modulo Atendimento refinado

## Resultado operacional

Resultado:

- Atendimento possui fronteiras de dominio documentadas
- status foram separados por grupos funcionais
- app inbox recebeu melhorias visuais
- attendance settings centraliza configuracoes
- envio, encerramento e historico foram separados visualmente
- dados sinteticos foram revisados sem limpeza destrutiva
- pendencia Meta segue documentada e separada

## Validacoes executadas

Validacoes:

- logs das etapas 74 a 79
- documentos da fase de refino
- health publico
- login dominio
- endpoints principais do atendimento
- status model
- departments
- quick replies
- automation rules
- send failures
- send retries
- audit summary
- webhook GET com WHATSAPP VERIFY TOKEN
- contagens finais do banco
- paginas principais

## Decisoes finais

Decisoes:

- fase de refino do modulo Atendimento concluida
- limpeza real de dados sinteticos permanece pendente de aprovacao explicita
- recebimento real via Meta permanece pendente de retorno ou configuracao da Meta
- proximas evolucoes devem ser planejadas como nova fase funcional

## Arquivos criados ou alterados

Arquivos:

- docs/ATTENDANCE_REFINEMENT_FINAL_REVIEW.md
- docs/ATTENDANCE_REFINEMENT_NEXT_DECISIONS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Logs gerados

Logs:

- logs/setup_80_steps_check.log
- logs/setup_80_docs_check.log
- logs/setup_80_health_domain.log
- logs/setup_80_auth_login_domain.log
- logs/setup_80_attendance_conversations_domain.log
- logs/setup_80_status_model_domain.log
- logs/setup_80_departments_domain.log
- logs/setup_80_quick_replies_domain.log
- logs/setup_80_automation_rules_domain.log
- logs/setup_80_send_failures_domain.log
- logs/setup_80_send_retries_domain.log
- logs/setup_80_audit_summary_domain.log
- logs/setup_80_webhook_get_domain.log
- logs/setup_80_database_counts.log
- logs/setup_80_pages_status.log
- logs/setup_80.log

## Proxima etapa sugerida

Proxima etapa:

    Planejar nova fase funcional ou retomar pendencias Meta e limpeza real quando houver aprovacao.
DOC

cat > "${DOC_NEXT}" <<'DOC'
# Attendance Refinement Next Decisions

## Visao geral

Este documento registra decisoes pendentes apos a revisao final do modulo Atendimento refinado.

## Decisoes pendentes

Decisoes:

- definir nova fase funcional do produto
- decidir se a limpeza real de dados sinteticos sera executada
- retomar pendencia Meta quando houver retorno ou configuracao confirmada
- avaliar edicao real na tela attendance settings
- avaliar refatoracao interna de componentes do inbox
- avaliar consolidacao de configuracoes avancadas de automacao

## Pendencias preservadas

Pendencias:

- recebimento real de mensagens via webhook Meta
- limpeza real de dados sinteticos
- edicao de configuracoes em attendance settings
- separacao estrutural interna mais profunda dos componentes do inbox

## Recomendacao

Recomendacao:

- nao executar limpeza real sem aprovacao explicita
- nao mexer na pendencia Meta ate receber retorno ou confirmar configuracoes
- iniciar nova fase com planejamento antes de alterar codigo
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 80 - Revisao final do modulo Atendimento refinado",
    "- [x] Etapa 80 - Revisao final do modulo Atendimento refinado"
)

text = text.replace(
    "Etapa 80 - Revisao final do modulo Atendimento refinado.",
    "Planejar nova fase funcional ou retomar pendencias Meta e limpeza real quando houver aprovacao."
)

text = text.replace(
    "Etapa 79 - Revisao de dados sinteticos e limpeza operacional.",
    "Etapa 80 - Revisao final do modulo Atendimento refinado."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Revisao final do modulo Atendimento refinado concluida." not in text:
    text += "\nRevisao final do modulo Atendimento refinado concluida.\n"

for doc in [
    "- docs/ATTENDANCE_REFINEMENT_FINAL_REVIEW.md",
    "- docs/ATTENDANCE_REFINEMENT_NEXT_DECISIONS.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 79 concluidas",
    "- Etapa 01 ate Etapa 80 concluidas"
)

text = text.replace(
    "- Etapa 80 - Revisao final do modulo Atendimento refinado",
    "- Planejar nova fase funcional ou retomar pendencias Meta e limpeza real quando houver aprovacao"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 80 - Revisao final do modulo Atendimento refinado
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Concluida revisao final do modulo Atendimento refinado, validando etapas 74 a 79, documentos, endpoints, paginas, webhook GET, contagens finais e pendencias preservadas.
DOC
  fi
done

if [ -f "${BASE_DIR}/PENDENCIAS.md" ]; then
  cat >> "${BASE_DIR}/PENDENCIAS.md" <<'DOC'

Pendencias pos-refino do Atendimento
Status: preservadas
Resumo: Permanecem pendentes a configuracao ou retorno da Meta para recebimento real, a eventual limpeza real de dados sinteticos com aprovacao explicita e futuras evolucoes da tela attendance settings.
DOC
fi

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${DOC_NEXT}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 80
Acao: Revisao final do modulo Atendimento refinado
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Status model status: ${DOMAIN_STATUS_MODEL_STATUS}
Departments status: ${DOMAIN_DEPARTMENTS_STATUS}
Quick replies status: ${DOMAIN_QUICK_REPLIES_STATUS}
Automation rules status: ${DOMAIN_AUTOMATION_RULES_STATUS}
Send failures status: ${DOMAIN_FAILURES_STATUS}
Send retries status: ${DOMAIN_RETRIES_STATUS}
Audit summary status: ${DOMAIN_AUDIT_STATUS}
Webhook GET status: ${DOMAIN_WEBHOOK_GET_STATUS}
Steps check log: logs/setup_80_steps_check.log
Docs check log: logs/setup_80_docs_check.log
Database counts log: logs/setup_80_database_counts.log
Pages status log: logs/setup_80_pages_status.log
Pendencia Meta: preservada
Limpeza real sinteticos: nao executada
Status: Concluido
DOC

echo ""
echo "== Etapa 80 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Planejar nova fase funcional ou retomar pendencias Meta e limpeza real quando houver aprovacao."
