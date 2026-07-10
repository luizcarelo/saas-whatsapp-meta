#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_73.log"
DOC_FILE="${DOCS_DIR}/ATTENDANCE_AUTOMATION_SEND_FINAL_REVIEW.md"
PENDING_META_DOC="${DOCS_DIR}/PENDENCIA_META_WEBHOOK_RECEBIMENTO.md"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_73_auth_login_domain.log"
DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_73_health_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_73_attendance_conversations_domain.log"
DOMAIN_SEND_HISTORY_LOG="${LOGS_DIR}/setup_73_send_history_domain.log"
DOMAIN_FAILURES_LOG="${LOGS_DIR}/setup_73_failures_domain.log"
DOMAIN_RETRIES_LOG="${LOGS_DIR}/setup_73_retries_domain.log"
DOMAIN_AUTOMATION_RULES_LOG="${LOGS_DIR}/setup_73_automation_rules_domain.log"
DOMAIN_AUTOMATION_EXECUTIONS_LOG="${LOGS_DIR}/setup_73_automation_executions_domain.log"
DOMAIN_WEBHOOK_GET_LOG="${LOGS_DIR}/setup_73_webhook_get_domain.log"
DOMAIN_COUNTS_LOG="${LOGS_DIR}/setup_73_database_counts.log"
DOMAIN_PAGES_LOG="${LOGS_DIR}/setup_73_pages_status.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_SEND_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send"
DOMAIN_FAILURES_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send-failures"
DOMAIN_AUTOMATION_URL="${DOMAIN_BASE_URL}/api/v1/attendance-automations"
DOMAIN_WEBHOOK_URL="${DOMAIN_BASE_URL}/api/v1/webhooks/meta"

echo "== Etapa 73: Revisao final da fase de automacao e envio real =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 72..."

if [ ! -f "${LOGS_DIR}/setup_72.log" ]; then
  echo "ERRO: setup_72.log nao encontrado. Conclua a Etapa 72 antes da Etapa 73."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_72.log"; then
  echo "ERRO: Etapa 72 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_72.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${DOC_FILE}" \
  "${PENDING_META_DOC}" \
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

for tool in node docker curl python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando logs obrigatorios da fase..."

for step in 66 67 68 69 70 71 72; do
  step_log="${LOGS_DIR}/setup_${step}.log"

  if [ ! -f "${step_log}" ]; then
    echo "ERRO: log ausente: ${step_log}"
    exit 1
  fi

  if ! grep -q "Status: Concluido" "${step_log}"; then
    echo "ERRO: etapa ${step} nao esta concluida."
    cat "${step_log}"
    exit 1
  fi
done

echo "Validando documentos obrigatorios da fase..."

for doc_file in \
  "${DOCS_DIR}/ATTENDANCE_MANUAL_SEND_BACKEND.md" \
  "${DOCS_DIR}/ATTENDANCE_SEND_FRONTEND.md" \
  "${DOCS_DIR}/ATTENDANCE_QUICK_REPLY_SEND.md" \
  "${DOCS_DIR}/ATTENDANCE_CLOSING_RATING_SEND.md" \
  "${DOCS_DIR}/ATTENDANCE_SENT_MESSAGE_ATTENDANT_TRACKING.md" \
  "${DOCS_DIR}/ATTENDANCE_BASIC_AUTOMATIONS.md" \
  "${DOCS_DIR}/ATTENDANCE_SEND_FAILURES_RETRY_PANEL.md"
do
  if [ ! -f "${doc_file}" ]; then
    echo "ERRO: documento ausente: ${doc_file}"
    exit 1
  fi
done

echo "Validando backend local..."

BACKEND_READY="false"

for i in $(seq 1 20); do
  if curl -s --max-time 5 "http://127.0.0.1:3300/api/v1/health" >/dev/null 2>&1; then
    BACKEND_READY="true"
    break
  fi

  sleep 2
done

if [ "${BACKEND_READY}" != "true" ]; then
  echo "ERRO: backend local nao respondeu health."
  docker compose logs --tail=160 backend || true
  exit 1
fi

echo "Validando health publico..."

DOMAIN_HEALTH_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_HEALTH_URL}" || true)"

if [ "${DOMAIN_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health publico falhou. Status ${DOMAIN_HEALTH_STATUS}"
  cat "${DOMAIN_HEALTH_LOG}"
  exit 1
fi

echo "Efetuando login dominio..."

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

echo "Validando endpoints principais..."

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_LIST_STATUS}" != "200" ]; then
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

DOMAIN_SEND_HISTORY_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  DOMAIN_SEND_HISTORY_STATUS="$(curl -L -s -o "${DOMAIN_SEND_HISTORY_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_SEND_URL}/conversations/${CONVERSATION_ID}/messages" || true)"

  if [ "${DOMAIN_SEND_HISTORY_STATUS}" != "200" ]; then
    echo "ERRO: send history falhou. Status ${DOMAIN_SEND_HISTORY_STATUS}"
    cat "${DOMAIN_SEND_HISTORY_LOG}"
    exit 1
  fi
else
  echo '{"skipped":"sem conversa para historico"}' > "${DOMAIN_SEND_HISTORY_LOG}"
fi

DOMAIN_FAILURES_STATUS="$(curl -L -s -o "${DOMAIN_FAILURES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_FAILURES_URL}" || true)"

if [ "${DOMAIN_FAILURES_STATUS}" != "200" ]; then
  echo "ERRO: failures endpoint falhou. Status ${DOMAIN_FAILURES_STATUS}"
  cat "${DOMAIN_FAILURES_LOG}"
  exit 1
fi

DOMAIN_RETRIES_STATUS="$(curl -L -s -o "${DOMAIN_RETRIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_FAILURES_URL}/retries" || true)"

if [ "${DOMAIN_RETRIES_STATUS}" != "200" ]; then
  echo "ERRO: retries endpoint falhou. Status ${DOMAIN_RETRIES_STATUS}"
  cat "${DOMAIN_RETRIES_LOG}"
  exit 1
fi

DOMAIN_AUTOMATION_RULES_STATUS="$(curl -L -s -o "${DOMAIN_AUTOMATION_RULES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUTOMATION_URL}/rules" || true)"

if [ "${DOMAIN_AUTOMATION_RULES_STATUS}" != "200" ]; then
  echo "ERRO: automation rules endpoint falhou. Status ${DOMAIN_AUTOMATION_RULES_STATUS}"
  cat "${DOMAIN_AUTOMATION_RULES_LOG}"
  exit 1
fi

DOMAIN_AUTOMATION_EXECUTIONS_STATUS="$(curl -L -s -o "${DOMAIN_AUTOMATION_EXECUTIONS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUTOMATION_URL}/executions" || true)"

if [ "${DOMAIN_AUTOMATION_EXECUTIONS_STATUS}" != "200" ]; then
  echo "ERRO: automation executions endpoint falhou. Status ${DOMAIN_AUTOMATION_EXECUTIONS_STATUS}"
  cat "${DOMAIN_AUTOMATION_EXECUTIONS_LOG}"
  exit 1
fi

echo "Validando webhook GET com WHATSAPP_VERIFY_TOKEN..."

VERIFY_TOKEN="$(grep '^WHATSAPP_VERIFY_TOKEN=' .env | head -n 1 | cut -d '=' -f 2- | tr -d '"' | tr -d "'" || true)"

if [ -z "${VERIFY_TOKEN}" ]; then
  echo "ERRO: WHATSAPP_VERIFY_TOKEN ausente no .env"
  exit 1
fi

DOMAIN_WEBHOOK_GET_STATUS="$(curl -L -s -o "${DOMAIN_WEBHOOK_GET_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=737373" || true)"

if [ "${DOMAIN_WEBHOOK_GET_STATUS}" != "200" ]; then
  echo "ERRO: webhook GET nao validou. Status ${DOMAIN_WEBHOOK_GET_STATUS}"
  cat "${DOMAIN_WEBHOOK_GET_LOG}"
  exit 1
fi

if ! grep -q "737373" "${DOMAIN_WEBHOOK_GET_LOG}"; then
  echo "ERRO: webhook GET nao retornou challenge esperado."
  cat "${DOMAIN_WEBHOOK_GET_LOG}"
  exit 1
fi

echo "Coletando contagens finais do banco..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DOMAIN_COUNTS_LOG}"
select 'messages_total' as metric, count(*)::text as value from messages
union all
select 'messages_inbound_total' as metric, count(*)::text as value from messages where direction = 'inbound'
union all
select 'manual_sends_total' as metric, count(*)::text as value from attendance_manual_message_sends
union all
select 'manual_sends_failed' as metric, count(*)::text as value from attendance_manual_message_sends where status = 'failed'
union all
select 'manual_sends_retries' as metric, count(*)::text as value from attendance_manual_message_sends where retry_of_send_id is not null
union all
select 'automation_rules_total' as metric, count(*)::text as value from attendance_automation_rules
union all
select 'automation_executions_total' as metric, count(*)::text as value from attendance_automation_executions
union all
select 'webhook_events_total' as metric, count(*)::text as value from webhook_events;
SQL

echo "Validando paginas publicas..."

: > "${DOMAIN_PAGES_LOG}"

for page in \
  "/app/inbox" \
  "/app/send-failures" \
  "/app/dashboard" \
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

echo "Gerando documento de pendencia Meta..."

cat > "${PENDING_META_DOC}" <<'DOC'
# Pendencia Meta Webhook Recebimento

## Visao geral

Este documento registra a pendencia operacional relacionada ao recebimento real de mensagens pela API oficial da Meta.

## Status

Status:

    aguardando configuracoes ou retorno da Meta

## Situacao atual

Situacao:

- endpoint publico de webhook responde com sucesso ao GET de verificacao
- endpoint validou usando WHATSAPP VERIFY TOKEN
- variavel antiga META WEBHOOK VERIFY TOKEN foi removida do .env
- phone number consultado apresentou webhook application apontando para o endpoint correto
- testes ao vivo recentes nao receberam POST novo da Meta
- messages inbound e webhook events nao aumentaram nos testes ao vivo

## Endpoint correto

Endpoint:

    bot.lhsolucao.com.br api v1 webhooks meta

## Pontos pendentes na Meta

Pendencias:

- confirmar campo messages inscrito
- confirmar app em modo adequado
- confirmar permissao whatsapp business messaging
- confirmar WABA e phone number corretos
- confirmar ausencia de override externo inesperado
- aguardar processamento ou retorno da Meta

## Observacao

A pendencia nao bloqueia a revisao final da fase de automacao e envio real, pois o fluxo de backend, frontend, dryRun, falhas, retentativas e auditoria operacional foi validado internamente.
DOC

echo "Gerando documento final da Etapa 73..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Automation Send Final Review

## Visao geral

Este documento registra a revisao final da fase de automacao e envio real pela central de atendimento.

## Resultado

Status:

    concluido

## Escopo revisado

Escopo:

- backend de envio manual pela central
- frontend de envio real no app inbox
- envio usando respostas rapidas
- envio de encerramento com avaliacao
- registro do atendente nas mensagens enviadas
- automacoes basicas por status e departamento
- painel de falhas e retentativas de envio
- pendencia operacional de recebimento real via webhook Meta

## Etapas revisadas

Etapas:

- Etapa 66 - Backend de envio manual pela central de atendimento
- Etapa 67 - Frontend de envio real no app inbox
- Etapa 68 - Envio real usando respostas rapidas
- Etapa 69 - Envio real da mensagem de encerramento com avaliacao
- Etapa 70 - Registro do atendente nas mensagens enviadas
- Etapa 71 - Automacoes basicas por status e departamento
- Etapa 72 - Painel de falhas e retentativas de envio
- Etapa 73 - Revisao final da fase de automacao e envio real

## Validacoes executadas

Validacoes:

- logs das etapas 66 a 72
- documentos das etapas 66 a 72
- health publico
- login dominio
- listagem de conversas da central
- historico de envios da conversa
- listagem de falhas de envio
- listagem de retentativas de envio
- regras de automacao
- execucoes de automacao
- webhook GET com WHATSAPP VERIFY TOKEN
- contagens finais de banco
- paginas principais do frontend

## Resultado operacional

Resultado:

- central possui backend seguro para envio pela Meta
- app inbox envia ou valida mensagens pelo backend
- respostas rapidas usam origem quick reply
- encerramento usa origem closing rating
- mensagens enviadas registram atendente
- automacoes possuem regras e execucoes auditaveis
- falhas possuem painel e retentativa controlada
- dryRun permanece como mecanismo de seguranca operacional

## Pendencia registrada

Pendencia:

- recebimento real de mensagens via webhook Meta permanece aguardando configuracoes ou retorno da Meta

Documento da pendencia:

- docs/PENDENCIA_META_WEBHOOK_RECEBIMENTO.md

## Arquivos criados ou alterados

Arquivos:

- docs/ATTENDANCE_AUTOMATION_SEND_FINAL_REVIEW.md
- docs/PENDENCIA_META_WEBHOOK_RECEBIMENTO.md
- 00_CONTROLE.md
- MANIFESTO.md

## Logs gerados

Logs:

- logs/setup_73_auth_login_domain.log
- logs/setup_73_health_domain.log
- logs/setup_73_attendance_conversations_domain.log
- logs/setup_73_send_history_domain.log
- logs/setup_73_failures_domain.log
- logs/setup_73_retries_domain.log
- logs/setup_73_automation_rules_domain.log
- logs/setup_73_automation_executions_domain.log
- logs/setup_73_webhook_get_domain.log
- logs/setup_73_database_counts.log
- logs/setup_73_pages_status.log
- logs/setup_73.log

## Proxima etapa sugerida

Proxima etapa:

    Aguardar decisao da proxima fase do produto ou retomar pendencia Meta quando houver retorno.
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 73 - Revisao final da fase de automacao e envio real",
    "- [x] Etapa 73 - Revisao final da fase de automacao e envio real"
)

text = text.replace(
    "Etapa 73 - Revisao final da fase de automacao e envio real.",
    "Aguardar decisao da proxima fase do produto ou retomar pendencia Meta."
)

text = text.replace(
    "Etapa 72 - Painel de falhas e retentativas de envio.",
    "Etapa 73 - Revisao final da fase de automacao e envio real."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Revisao final da fase de automacao e envio real concluida." not in text:
    text = text.replace(
        "Painel de falhas e retentativas de envio criado.",
        "Painel de falhas e retentativas de envio criado.\n\nRevisao final da fase de automacao e envio real concluida."
    )

if "- docs/ATTENDANCE_AUTOMATION_SEND_FINAL_REVIEW.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_SEND_FAILURES_RETRY_PANEL.md",
        "- docs/ATTENDANCE_AUTOMATION_SEND_FINAL_REVIEW.md\n- docs/PENDENCIA_META_WEBHOOK_RECEBIMENTO.md\n- docs/ATTENDANCE_SEND_FAILURES_RETRY_PANEL.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 72 concluidas",
    "- Etapa 01 ate Etapa 73 concluidas"
)

text = text.replace(
    "- Etapa 73 - Revisao final da fase de automacao e envio real",
    "- Aguardar decisao da proxima fase do produto"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 73 - Revisao final da fase de automacao e envio real
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Concluida a revisao final da fase de automacao e envio real, validando endpoints, paginas, documentos, logs, webhook GET e registrando pendencia operacional de recebimento real via Meta.
DOC
  fi
done

echo "Registrando pendencia Meta em PENDENCIAS.md se existir..."

if [ -f "${BASE_DIR}/PENDENCIAS.md" ]; then
  cat >> "${BASE_DIR}/PENDENCIAS.md" <<'DOC'

Pendencia Meta - Recebimento real de mensagens
Status: aguardando configuracoes ou retorno da Meta
Resumo: O endpoint publico de webhook valida com WHATSAPP VERIFY TOKEN, mas os testes ao vivo ainda nao receberam POST novo da Meta. Retomar quando a Meta confirmar configuracoes de messages, WABA, phone number, modo do app e permissoes.
DOC
fi

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${PENDING_META_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 73
Acao: Revisao final da fase de automacao e envio real
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Send history status: ${DOMAIN_SEND_HISTORY_STATUS}
Failures status: ${DOMAIN_FAILURES_STATUS}
Retries status: ${DOMAIN_RETRIES_STATUS}
Automation rules status: ${DOMAIN_AUTOMATION_RULES_STATUS}
Automation executions status: ${DOMAIN_AUTOMATION_EXECUTIONS_STATUS}
Webhook GET status: ${DOMAIN_WEBHOOK_GET_STATUS}
Paginas status log: logs/setup_73_pages_status.log
Database counts log: logs/setup_73_database_counts.log
Pendencia Meta: registrada
Status: Concluido
DOC

echo ""
echo "== Etapa 73 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Pendencia Meta:"
sed -n '1,180p' "${PENDING_META_DOC}"
echo ""
echo "Proxima etapa sugerida:"
echo "Aguardar decisao da proxima fase do produto ou retomar pendencia Meta quando houver retorno."
