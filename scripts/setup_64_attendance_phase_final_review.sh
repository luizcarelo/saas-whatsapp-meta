#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_64.log"
SUMMARY_FILE="${LOGS_DIR}/setup_64_phase_summary.log"
DOC_FILE="${DOCS_DIR}/ATTENDANCE_PHASE_FINAL_REVIEW.md"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_64_auth_login_domain.log"
DOMAIN_ATTENDANCE_CONVERSATIONS_LOG="${LOGS_DIR}/setup_64_attendance_conversations_domain.log"
DOMAIN_ATTENDANCE_DEPARTMENTS_LOG="${LOGS_DIR}/setup_64_attendance_departments_domain.log"
DOMAIN_ATTENDANCE_QUICK_REPLIES_LOG="${LOGS_DIR}/setup_64_attendance_quick_replies_domain.log"
DOMAIN_ATTENDANCE_TAGS_LOG="${LOGS_DIR}/setup_64_attendance_tags_domain.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_64_attendance_dashboard_domain.log"

DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_64_domain_inbox_page.log"
DOMAIN_ATTENDANCE_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_64_domain_attendance_dashboard_page.log"
DOMAIN_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_64_domain_dashboard_page.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_64_domain_audit_page.log"
DOMAIN_PROFILE_PAGE_LOG="${LOGS_DIR}/setup_64_domain_profile_page.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_ATTENDANCE_DASHBOARD_URL="${DOMAIN_BASE_URL}/api/v1/attendance-dashboard/summary"

DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_ATTENDANCE_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"
DOMAIN_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_PROFILE_PAGE_URL="${DOMAIN_BASE_URL}/app/profile"

echo "== Etapa 64: Revisao final da fase de atendimento profissional =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups dos documentos de controle..."

for file in \
  "${DOC_FILE}" \
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

for tool in node curl docker python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ] || [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: credenciais admin incompletas."
  exit 1
fi

: > "${SUMMARY_FILE}"

echo "Validando documentos da fase 10..." | tee -a "${SUMMARY_FILE}"

REQUIRED_DOCS=(
  "docs/NEXT_FUNCTIONAL_PHASE_PLAN.md"
  "docs/VISUAL_IDENTITY_AND_ATTENDANCE_PLAN.md"
  "docs/ATTENDANCE_OPERATIONAL_FLOW.md"
  "docs/VISUAL_IDENTITY_LOGOS_FAVICON.md"
  "docs/RESPONSIVE_ATTENDANCE_CENTER_LAYOUT.md"
  "docs/CONVERSATION_OPERATIONAL_STATUS.md"
  "docs/ATTENDANCE_DEPARTMENTS_QUEUES.md"
  "docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md"
  "docs/ATTENDANCE_QUICK_REPLIES.md"
  "docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md"
  "docs/ATTENDANCE_CLOSURE_RATING.md"
  "docs/ATTENDANCE_DASHBOARD.md"
)

for doc in "${REQUIRED_DOCS[@]}"; do
  if [ ! -f "${BASE_DIR}/${doc}" ]; then
    echo "ERRO: documento obrigatorio ausente: ${doc}"
    exit 1
  fi

  echo "OK: ${doc}" | tee -a "${SUMMARY_FILE}"
done

echo "" | tee -a "${SUMMARY_FILE}"
echo "Validando logs principais das etapas 54 a 63..." | tee -a "${SUMMARY_FILE}"

for step in 54 55 56 57 58 59 60 61 62 63; do
  step_log="${LOGS_DIR}/setup_${step}.log"

  if [ ! -f "${step_log}" ]; then
    echo "ERRO: log ausente: ${step_log}"
    exit 1
  fi

  if ! grep -q "Status: Concluido" "${step_log}"; then
    echo "ERRO: log nao indica conclusao: ${step_log}"
    cat "${step_log}"
    exit 1
  fi

  echo "OK: logs/setup_${step}.log" | tee -a "${SUMMARY_FILE}"
done

echo "" | tee -a "${SUMMARY_FILE}"
echo "Validando containers..." | tee -a "${SUMMARY_FILE}"

docker compose ps | tee -a "${SUMMARY_FILE}"

echo "Validando dominio e endpoints de atendimento..."

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

DOMAIN_ATTENDANCE_CONVERSATIONS_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_CONVERSATIONS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_CONVERSATIONS_STATUS}" != "200" ]; then
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_CONVERSATIONS_STATUS}"
  cat "${DOMAIN_ATTENDANCE_CONVERSATIONS_LOG}"
  exit 1
fi

DOMAIN_ATTENDANCE_DEPARTMENTS_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_DEPARTMENTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/departments" || true)"

if [ "${DOMAIN_ATTENDANCE_DEPARTMENTS_STATUS}" != "200" ]; then
  echo "ERRO: attendance departments falhou. Status ${DOMAIN_ATTENDANCE_DEPARTMENTS_STATUS}"
  cat "${DOMAIN_ATTENDANCE_DEPARTMENTS_LOG}"
  exit 1
fi

DOMAIN_ATTENDANCE_QUICK_REPLIES_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_QUICK_REPLIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies" || true)"

if [ "${DOMAIN_ATTENDANCE_QUICK_REPLIES_STATUS}" != "200" ]; then
  echo "ERRO: attendance quick replies falhou. Status ${DOMAIN_ATTENDANCE_QUICK_REPLIES_STATUS}"
  cat "${DOMAIN_ATTENDANCE_QUICK_REPLIES_LOG}"
  exit 1
fi

DOMAIN_ATTENDANCE_TAGS_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_TAGS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/tags" || true)"

if [ "${DOMAIN_ATTENDANCE_TAGS_STATUS}" != "200" ]; then
  echo "ERRO: attendance tags falhou. Status ${DOMAIN_ATTENDANCE_TAGS_STATUS}"
  cat "${DOMAIN_ATTENDANCE_TAGS_LOG}"
  exit 1
fi

DOMAIN_ATTENDANCE_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: attendance dashboard falhou. Status ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}"
  cat "${DOMAIN_ATTENDANCE_DASHBOARD_LOG}"
  exit 1
fi

if ! grep -q "conversations" "${DOMAIN_ATTENDANCE_DASHBOARD_LOG}"; then
  echo "ERRO: attendance dashboard nao retornou conversations."
  cat "${DOMAIN_ATTENDANCE_DASHBOARD_LOG}"
  exit 1
fi

echo "Validando rotas frontend da fase..."

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_INBOX_PAGE_URL}" || true)"

DOMAIN_ATTENDANCE_DASHBOARD_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_URL}" || true)"

DOMAIN_DASHBOARD_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_PAGE_URL}" || true)"

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

DOMAIN_PROFILE_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_PROFILE_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_PROFILE_PAGE_URL}" || true)"

for item in \
  "inbox:${DOMAIN_INBOX_PAGE_STATUS}" \
  "attendance-dashboard:${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_STATUS}" \
  "dashboard:${DOMAIN_DASHBOARD_PAGE_STATUS}" \
  "audit:${DOMAIN_AUDIT_PAGE_STATUS}" \
  "profile:${DOMAIN_PROFILE_PAGE_STATUS}"
do
  name="${item%%:*}"
  status="${item##*:}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: rota ${name} retornou status ${status}"
    exit 1
  fi
done

echo "" | tee -a "${SUMMARY_FILE}"
echo "Status dos endpoints finais:" | tee -a "${SUMMARY_FILE}"
echo "Login: ${DOMAIN_LOGIN_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Attendance conversations: ${DOMAIN_ATTENDANCE_CONVERSATIONS_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Attendance departments: ${DOMAIN_ATTENDANCE_DEPARTMENTS_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Attendance quick replies: ${DOMAIN_ATTENDANCE_QUICK_REPLIES_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Attendance tags: ${DOMAIN_ATTENDANCE_TAGS_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Attendance dashboard: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}" | tee -a "${SUMMARY_FILE}"

echo "" | tee -a "${SUMMARY_FILE}"
echo "Status das telas finais:" | tee -a "${SUMMARY_FILE}"
echo "Inbox: ${DOMAIN_INBOX_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Attendance dashboard: ${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Dashboard: ${DOMAIN_DASHBOARD_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Audit: ${DOMAIN_AUDIT_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Profile: ${DOMAIN_PROFILE_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"

echo "Gerando documentacao final da fase..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Phase Final Review

## Visao geral

Este documento registra a revisao final da fase de atendimento profissional.

## Resultado

Status:

    concluido

## Nome da fase

Fase 10 - Experiencia visual e atendimento profissional

## Escopo revisado

Escopo:

- identidade visual com logos e favicon
- layout responsivo da central de atendimento
- central app inbox
- status operacional de conversas
- departamentos e filas
- atribuicao de responsavel
- nome do atendente
- respostas rapidas por departamento
- notas internas
- tags de conversa
- encerramento com avaliacao
- dashboard de atendimento

## Documentos revisados

Documentos:

- docs/NEXT_FUNCTIONAL_PHASE_PLAN.md
- docs/VISUAL_IDENTITY_AND_ATTENDANCE_PLAN.md
- docs/ATTENDANCE_OPERATIONAL_FLOW.md
- docs/VISUAL_IDENTITY_LOGOS_FAVICON.md
- docs/RESPONSIVE_ATTENDANCE_CENTER_LAYOUT.md
- docs/CONVERSATION_OPERATIONAL_STATUS.md
- docs/ATTENDANCE_DEPARTMENTS_QUEUES.md
- docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md
- docs/ATTENDANCE_QUICK_REPLIES.md
- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md
- docs/ATTENDANCE_CLOSURE_RATING.md
- docs/ATTENDANCE_DASHBOARD.md

## Validacoes executadas

Validacoes:

- documentos da fase 10
- logs setup 54 ate setup 63 com Status Concluido
- docker compose ps
- login dominio
- attendance conversations
- attendance departments
- attendance quick replies
- attendance tags
- attendance dashboard summary
- rota app inbox
- rota app attendance dashboard
- rota app dashboard
- rota app audit
- rota app profile

## Logs gerados

Logs:

- logs/setup_64_phase_summary.log
- logs/setup_64_auth_login_domain.log
- logs/setup_64_attendance_conversations_domain.log
- logs/setup_64_attendance_departments_domain.log
- logs/setup_64_attendance_quick_replies_domain.log
- logs/setup_64_attendance_tags_domain.log
- logs/setup_64_attendance_dashboard_domain.log
- logs/setup_64_domain_inbox_page.log
- logs/setup_64_domain_attendance_dashboard_page.log
- logs/setup_64_domain_dashboard_page.log
- logs/setup_64_domain_audit_page.log
- logs/setup_64_domain_profile_page.log
- logs/setup_64.log

## Conclusao

A fase de atendimento profissional foi encerrada com sucesso.

O sistema agora possui base visual, operacional e funcional para atendimento profissional com filas, departamentos, responsaveis, respostas rapidas, notas internas, tags, encerramento com avaliacao e dashboard.

## Proxima etapa sugerida

Etapa 65:

    Planejar proxima fase de automacao e envio real pela central de atendimento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 64 - Revisao final da fase de atendimento profissional",
    "- [x] Etapa 64 - Revisao final da fase de atendimento profissional\n- [ ] Etapa 65 - Planejamento da proxima fase de automacao e envio real pela central de atendimento"
)

text = text.replace(
    "Etapa 64 - Revisao final da fase de atendimento profissional.",
    "Etapa 65 - Planejar proxima fase de automacao e envio real pela central de atendimento."
)

text = text.replace(
    "Etapa 63 - Criar dashboard de atendimento.",
    "Etapa 64 - Revisao final da fase de atendimento profissional."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Revisao final da fase de atendimento profissional concluida." not in text:
    text = text.replace(
        "Dashboard de atendimento criado.",
        "Dashboard de atendimento criado.\n\nRevisao final da fase de atendimento profissional concluida."
    )

if "- docs/ATTENDANCE_PHASE_FINAL_REVIEW.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_DASHBOARD.md",
        "- docs/ATTENDANCE_PHASE_FINAL_REVIEW.md\n- docs/ATTENDANCE_DASHBOARD.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 63 concluidas",
    "- Etapa 01 ate Etapa 64 concluidas"
)

text = text.replace(
    "- Etapa 64 - Revisao final da fase de atendimento profissional",
    "- Etapa 65 - Planejamento da proxima fase de automacao e envio real pela central de atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 64 - Revisao final da fase de atendimento profissional
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Revisada e encerrada a fase de atendimento profissional, validando documentos, logs, endpoints, telas e dashboard de atendimento.
DOC
  fi
done

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 64
Acao: Revisao final da fase de atendimento profissional
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_CONVERSATIONS_STATUS}
Attendance departments status: ${DOMAIN_ATTENDANCE_DEPARTMENTS_STATUS}
Attendance quick replies status: ${DOMAIN_ATTENDANCE_QUICK_REPLIES_STATUS}
Attendance tags status: ${DOMAIN_ATTENDANCE_TAGS_STATUS}
Attendance dashboard status: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Attendance dashboard page status: ${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_STATUS}
Dashboard page status: ${DOMAIN_DASHBOARD_PAGE_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Profile page status: ${DOMAIN_PROFILE_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 64 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Resumo tecnico:"
cat "${SUMMARY_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 65 - Planejar proxima fase de automacao e envio real pela central de atendimento"
