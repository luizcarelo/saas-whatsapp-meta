#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_76.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_76_inbox_visual_reorganization.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_INBOX_VISUAL_REORGANIZATION.md"
DOC_CHECKLIST="${DOCS_DIR}/ATTENDANCE_INBOX_VISUAL_CHECKLIST.md"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_76_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_76_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_76_attendance_conversations_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_76_status_model_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_76_domain_inbox_page.log"
DOMAIN_SEND_FAILURES_PAGE_LOG="${LOGS_DIR}/setup_76_domain_send_failures_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_76_domain_dashboard.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_76_domain_attendance_dashboard.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_STATUS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-status"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_SEND_FAILURES_PAGE_URL="${DOMAIN_BASE_URL}/app/send-failures"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_ATTENDANCE_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"

echo "== Fix Etapa 76: Reorganizacao visual do app inbox =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${DOC_FILE}" \
  "${DOC_CHECKLIST}" \
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

for tool in node docker curl python3 grep; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando Etapa 75..."

if [ ! -f "${LOGS_DIR}/setup_75.log" ]; then
  echo "ERRO: setup_75.log nao encontrado."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_75.log"; then
  echo "ERRO: Etapa 75 nao esta concluida."
  cat "${LOGS_DIR}/setup_75.log"
  exit 1
fi

echo "Validando arquivos do frontend..."

if [ ! -f "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" ]; then
  echo "ERRO: InboxPage.tsx nao encontrado."
  exit 1
fi

if [ ! -f "${FRONTEND_DIR}/src/styles.css" ]; then
  echo "ERRO: styles.css nao encontrado."
  exit 1
fi

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML injetado encontrado no frontend."
  exit 1
fi

echo "Validando marcador visual da Etapa 76..."

if ! grep -q "inbox-visual-guide" "${FRONTEND_DIR}/src/styles.css"; then
  echo "ERRO: CSS da Etapa 76 nao encontrado em styles.css."
  exit 1
fi

echo "Validando health dominio..."

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

echo "Validando endpoints de apoio..."

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_LIST_STATUS}" != "200" ]; then
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

DOMAIN_STATUS_MODEL_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MODEL_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_STATUS_URL}/model" || true)"

if [ "${DOMAIN_STATUS_MODEL_STATUS}" != "200" ]; then
  echo "ERRO: attendance status model falhou. Status ${DOMAIN_STATUS_MODEL_STATUS}"
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

echo "Validando paginas..."

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_INBOX_PAGE_URL}" || true)"

if [ "${DOMAIN_INBOX_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina inbox nao respondeu 200."
  exit 1
fi

DOMAIN_SEND_FAILURES_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_SEND_FAILURES_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_SEND_FAILURES_PAGE_URL}" || true)"

if [ "${DOMAIN_SEND_FAILURES_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina send failures nao respondeu 200."
  exit 1
fi

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: dashboard nao respondeu 200."
  exit 1
fi

DOMAIN_ATTENDANCE_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_ATTENDANCE_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: attendance dashboard nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 76..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Inbox Visual Reorganization

## Visao geral

Este documento registra a reorganizacao visual inicial do app inbox.

## Resultado

Status:

    concluido

## Objetivo

Objetivo:

- reduzir a sensacao de bagunca no modulo Atendimento
- separar visualmente conversas, mensagens e dados operacionais
- preparar o app inbox para refino funcional posterior
- preservar endpoints e regras ja validadas
- melhorar legibilidade em telas grandes e menores

## Organizacao visual aplicada

Organizacao:

- guia visual superior com tres areas do atendimento
- area de conversas e filtros
- area de mensagens e envio
- area de dados operacionais
- composer com destaque e comportamento sticky
- historico de envios mais compacto
- cards laterais com melhor separacao visual
- responsividade para telas menores

## Areas do app inbox

Areas:

- Conversas e filtros
- Mensagens e envio
- Dados operacionais

## Limites da etapa

Limites:

- nao altera regras de negocio
- nao altera endpoints
- nao altera banco de dados
- nao remove componentes existentes
- nao executa envio real
- nao resolve pendencia Meta

## Observacao do fix

A primeira execucao aplicou CSS, realizou typecheck, build e rebuild do frontend, mas parou na validacao final por variavel de URL nao definida no script.

Este fix concluiu validacoes, documentacao, controle e manifesto.

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_INBOX_VISUAL_REORGANIZATION.md
- docs/ATTENDANCE_INBOX_VISUAL_CHECKLIST.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- frontend sem HTML injetado
- health dominio
- login dominio
- endpoint attendance conversations
- endpoint attendance status model
- rota app inbox
- rota app send failures
- rota app dashboard
- rota app attendance dashboard

## Proxima etapa sugerida

Etapa 77:

    Criacao da tela attendance settings
DOC

cat > "${DOC_CHECKLIST}" <<'DOC'
# Attendance Inbox Visual Checklist

## Visao geral

Este documento registra o checklist visual para revisar o app inbox apos a reorganizacao da Etapa 76.

## Checklist

Itens:

- confirmar se a lista de conversas esta visualmente separada
- confirmar se mensagens ficam na area central
- confirmar se dados operacionais ficam na lateral
- confirmar se composer continua acessivel
- confirmar se respostas rapidas continuam acessiveis
- confirmar se encerramento continua acessivel
- confirmar se historico de envios continua legivel
- confirmar se tela responde bem em desktop
- confirmar se tela responde bem em resolucoes menores
- confirmar se dryRun esta claro quando exibido
- confirmar se status operacional nao se mistura com status de envio

## Observacoes

Observacoes:

- esta etapa melhora a apresentacao, mas ainda nao reestrutura profundamente os componentes
- a separacao mais forte de configuracoes sera tratada na etapa attendance settings
- a separacao visual de envio, encerramento e historico sera tratada em etapa posterior
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 76 - Reorganizacao visual do app inbox",
    "- [x] Etapa 76 - Reorganizacao visual do app inbox\n- [ ] Etapa 77 - Criacao da tela attendance settings"
)

text = text.replace(
    "Etapa 76 - Reorganizacao visual do app inbox.",
    "Etapa 77 - Criacao da tela attendance settings."
)

text = text.replace(
    "Etapa 75 - Padronizacao dos status de atendimento.",
    "Etapa 76 - Reorganizacao visual do app inbox."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Reorganizacao visual do app inbox criada." not in text:
    text += "\nReorganizacao visual do app inbox criada.\n"

for doc in [
    "- docs/ATTENDANCE_INBOX_VISUAL_REORGANIZATION.md",
    "- docs/ATTENDANCE_INBOX_VISUAL_CHECKLIST.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 75 concluidas",
    "- Etapa 01 ate Etapa 76 concluidas"
)

text = text.replace(
    "- Etapa 76 - Reorganizacao visual do app inbox",
    "- Etapa 77 - Criacao da tela attendance settings"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 76 - Reorganizacao visual do app inbox
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Concluida reorganizacao visual inicial do app inbox, separando conversas, mensagens e dados operacionais, com melhorias responsivas, composer destacado e checklist visual de validacao.
DOC
  fi
done

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${DOC_CHECKLIST}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 76
Acao: Reorganizacao visual do app inbox
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Status model status: ${DOMAIN_STATUS_MODEL_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Send failures page status: ${DOMAIN_SEND_FAILURES_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Attendance dashboard status: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Fix: Etapa 76 - Reorganizacao visual do app inbox
Data: $(date '+%Y-%m-%d %H:%M:%S')
Motivo: primeira execucao parou por variavel DOMAIN_INBOX_PAGE_URL ausente.
Acao: validadas paginas e endpoints, gerados documentos e setup_76.log, atualizados controle, manifesto e documentos auxiliares.
Status: Concluido
DOC

echo ""
echo "== Etapa 76 corrigida e concluida com sucesso =="
echo ""
sed -n '1,220p' "${DOC_FILE}"
