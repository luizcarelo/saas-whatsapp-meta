#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

PAGE_FILE="${FRONTEND_DIR}/src/pages/attendance-settings/AttendanceSettingsPage.tsx"
DOC_FILE="${DOCS_DIR}/ATTENDANCE_SETTINGS_PAGE.md"
DOC_CHECKLIST="${DOCS_DIR}/ATTENDANCE_SETTINGS_CHECKLIST.md"

LOG_FILE="${LOGS_DIR}/setup_77.log"
FINISH_LOG_FILE="${LOGS_DIR}/finish_77_attendance_settings_page.log"

FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_77_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_77_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_77_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_77_docker_up.log"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_77_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_77_auth_login_domain.log"
DOMAIN_DEPARTMENTS_LOG="${LOGS_DIR}/setup_77_departments_domain.log"
DOMAIN_QUICK_REPLIES_LOG="${LOGS_DIR}/setup_77_quick_replies_domain.log"
DOMAIN_AUTOMATION_RULES_LOG="${LOGS_DIR}/setup_77_automation_rules_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_77_status_model_domain.log"
DOMAIN_SETTINGS_PAGE_LOG="${LOGS_DIR}/setup_77_domain_attendance_settings_page.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_77_domain_inbox_page.log"
DOMAIN_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_77_domain_attendance_dashboard_page.log"
DOMAIN_FAILURES_PAGE_LOG="${LOGS_DIR}/setup_77_domain_send_failures_page.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_AUTOMATIONS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-automations"
DOMAIN_STATUS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-status"
DOMAIN_SETTINGS_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-settings"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"
DOMAIN_FAILURES_PAGE_URL="${DOMAIN_BASE_URL}/app/send-failures"

echo "== Fechamento seguro da Etapa 77 =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${PAGE_FILE}" \
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

echo "Validando etapa anterior..."

if [ ! -f "${LOGS_DIR}/setup_76.log" ]; then
  echo "ERRO: setup_76.log nao encontrado."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_76.log"; then
  echo "ERRO: Etapa 76 nao esta concluida."
  cat "${LOGS_DIR}/setup_76.log"
  exit 1
fi

echo "Validando arquivo da tela settings..."

if [ ! -f "${PAGE_FILE}" ]; then
  echo "ERRO: AttendanceSettingsPage.tsx nao encontrado."
  exit 1
fi

if grep -n "fai-ChatInputEntity" "${PAGE_FILE}"; then
  echo "ERRO: HTML injetado encontrado."
  exit 1
fi

if grep -n "/app/inboxVoltar" "${PAGE_FILE}"; then
  echo "ERRO: ancora corrompida encontrada."
  exit 1
fi

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/attendance-settings/AttendanceSettingsPage.tsx")
text = path.read_text()

required_parts = [
    'href="/app/inbox"',
    "Voltar para atendimento",
    "AttendanceSettingsPage",
    "attendance-settings-shell",
]

missing = [part for part in required_parts if part not in text]

if missing:
    raise SystemExit("ERRO: partes ausentes em AttendanceSettingsPage.tsx: " + ", ".join(missing))

print("OK: AttendanceSettingsPage contem ancora e estrutura esperada.")
PY

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_FRONTEND_BUILD_LOG}"

echo "Subindo frontend e proxy..."

docker compose up -d frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

sleep 8

echo "Validando dominio..."

DOMAIN_HEALTH_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_HEALTH_URL}" || true)"

if [ "${DOMAIN_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health dominio falhou. Status ${DOMAIN_HEALTH_STATUS}"
  cat "${DOMAIN_HEALTH_LOG}"
  exit 1
fi

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

DOMAIN_DEPARTMENTS_STATUS="$(curl -L -s -o "${DOMAIN_DEPARTMENTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/departments" || true)"

if [ "${DOMAIN_DEPARTMENTS_STATUS}" != "200" ]; then
  echo "ERRO: departments endpoint falhou. Status ${DOMAIN_DEPARTMENTS_STATUS}"
  cat "${DOMAIN_DEPARTMENTS_LOG}"
  exit 1
fi

DOMAIN_QUICK_REPLIES_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies" || true)"

if [ "${DOMAIN_QUICK_REPLIES_STATUS}" != "200" ]; then
  echo "ERRO: quick replies endpoint falhou. Status ${DOMAIN_QUICK_REPLIES_STATUS}"
  cat "${DOMAIN_QUICK_REPLIES_LOG}"
  exit 1
fi

DOMAIN_AUTOMATION_RULES_STATUS="$(curl -L -s -o "${DOMAIN_AUTOMATION_RULES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUTOMATIONS_URL}/rules" || true)"

if [ "${DOMAIN_AUTOMATION_RULES_STATUS}" != "200" ]; then
  echo "ERRO: automation rules endpoint falhou. Status ${DOMAIN_AUTOMATION_RULES_STATUS}"
  cat "${DOMAIN_AUTOMATION_RULES_LOG}"
  exit 1
fi

DOMAIN_STATUS_MODEL_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MODEL_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_STATUS_URL}/model" || true)"

if [ "${DOMAIN_STATUS_MODEL_STATUS}" != "200" ]; then
  echo "ERRO: status model endpoint falhou. Status ${DOMAIN_STATUS_MODEL_STATUS}"
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

DOMAIN_SETTINGS_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_SETTINGS_PAGE_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_SETTINGS_PAGE_URL}" || true)"
DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_INBOX_PAGE_URL}" || true)"
DOMAIN_DASHBOARD_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_PAGE_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_DASHBOARD_PAGE_URL}" || true)"
DOMAIN_FAILURES_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_FAILURES_PAGE_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_FAILURES_PAGE_URL}" || true)"

for pair in \
  "attendance-settings:${DOMAIN_SETTINGS_PAGE_STATUS}" \
  "inbox:${DOMAIN_INBOX_PAGE_STATUS}" \
  "attendance-dashboard:${DOMAIN_DASHBOARD_PAGE_STATUS}" \
  "send-failures:${DOMAIN_FAILURES_PAGE_STATUS}"
do
  name="${pair%%:*}"
  status="${pair##*:}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: pagina ${name} nao respondeu 200. Status ${status}"
    exit 1
  fi
done

echo "Gerando documentacao da Etapa 77..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Settings Page

## Visao geral

Este documento registra a criacao da tela attendance settings.

## Resultado

Status:

    concluido

## Objetivo

Objetivo:

- retirar configuracoes do fluxo principal do app inbox
- centralizar departamentos
- centralizar respostas rapidas
- exibir automacoes de atendimento
- exibir status padronizados
- preparar futuras configuracoes do modulo Atendimento

## Tela criada

Tela:

- app attendance settings

## Conteudo da tela

Conteudo:

- resumo de departamentos ativos
- resumo de respostas rapidas ativas
- resumo de automacoes ativas
- resumo de automacoes em dryRun
- lista de departamentos
- lista de respostas rapidas
- lista de automacoes
- modelo de status padronizado
- roadmap de refinamentos pendentes

## Observacao

A primeira tentativa da Etapa 77 parou no typecheck por JSX invalido. O arquivo foi corrigido e este fechamento validou o estado atual sem reintroduzir tags corrompidas.

## Limites da etapa

Limites:

- nao altera regras de negocio
- nao altera banco de dados
- nao cria edicao ainda
- nao envia mensagem real
- nao altera automacoes
- nao resolve pendencia Meta

## Arquivos criados ou alterados

Arquivos:

- apps frontend src pages attendance settings AttendanceSettingsPage tsx
- apps frontend src services attendance settings service ts
- apps frontend src app routes tsx
- apps frontend src components layout Sidebar tsx
- apps frontend src styles css
- docs ATTENDANCE SETTINGS PAGE md
- docs ATTENDANCE SETTINGS CHECKLIST md
- 00 CONTROLE md
- MANIFESTO md

## Validacoes executadas

Validacoes:

- ausencia de HTML injetado
- ausencia de ancora corrompida
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- health dominio
- login dominio
- endpoint departments
- endpoint quick replies
- endpoint automation rules
- endpoint status model
- rota app attendance settings
- rota app inbox
- rota app attendance dashboard
- rota app send failures

## Proxima etapa sugerida

Etapa 78:

    Separacao visual de envio encerramento e historico
DOC

cat > "${DOC_CHECKLIST}" <<'DOC'
# Attendance Settings Checklist

## Visao geral

Este documento registra o checklist para revisar a tela attendance settings.

## Checklist

Itens:

- confirmar acesso pelo menu lateral
- confirmar acesso pela rota app attendance settings
- confirmar listagem de departamentos
- confirmar listagem de respostas rapidas
- confirmar listagem de automacoes
- confirmar exibicao dos status padronizados
- confirmar cards de resumo
- confirmar botao de atualizar configuracoes
- confirmar link de retorno ao atendimento
- confirmar responsividade
- confirmar que nao ha envio real nessa tela

## Observacoes

Observacoes:

- esta etapa cria visualizacao e organizacao
- edicao de configuracoes deve ser planejada em etapa futura
- configuracoes avancadas de automacao devem permanecer controladas
DOC

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 77 - Criacao da tela attendance settings",
    "- [x] Etapa 77 - Criacao da tela attendance settings\n- [ ] Etapa 78 - Separacao visual de envio encerramento e historico"
)

text = text.replace(
    "Etapa 77 - Criacao da tela attendance settings.",
    "Etapa 78 - Separacao visual de envio encerramento e historico."
)

text = text.replace(
    "Etapa 76 - Reorganizacao visual do app inbox.",
    "Etapa 77 - Criacao da tela attendance settings."
)

path.write_text(text)
PY

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Tela attendance settings criada." not in text:
    text += "\nTela attendance settings criada.\n"

for doc in [
    "- docs/ATTENDANCE_SETTINGS_PAGE.md",
    "- docs/ATTENDANCE_SETTINGS_CHECKLIST.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 76 concluidas",
    "- Etapa 01 ate Etapa 77 concluidas"
)

text = text.replace(
    "- Etapa 77 - Criacao da tela attendance settings",
    "- Etapa 78 - Separacao visual de envio encerramento e historico"
)

path.write_text(text)
PY

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 77 - Criacao da tela attendance settings
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Concluido fechamento seguro da tela attendance settings, validando JSX atual, typecheck, build, endpoints, rotas, documentacao e controle.
DOC
  fi
done

cat > "${LOG_FILE}" <<DOC
Etapa: 77
Acao: Criacao da tela attendance settings
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Departments status: ${DOMAIN_DEPARTMENTS_STATUS}
Quick replies status: ${DOMAIN_QUICK_REPLIES_STATUS}
Automation rules status: ${DOMAIN_AUTOMATION_RULES_STATUS}
Status model status: ${DOMAIN_STATUS_MODEL_STATUS}
Attendance settings page status: ${DOMAIN_SETTINGS_PAGE_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Attendance dashboard page status: ${DOMAIN_DASHBOARD_PAGE_STATUS}
Send failures page status: ${DOMAIN_FAILURES_PAGE_STATUS}
Status: Concluido
DOC

cat > "${FINISH_LOG_FILE}" <<DOC
Fechamento seguro: Etapa 77
Data: $(date '+%Y-%m-%d %H:%M:%S')
Acao: Validado estado atual da tela attendance settings e gerado setup_77.log.
Status: Concluido
DOC

echo ""
echo "== Etapa 77 fechada com sucesso =="
cat "${LOG_FILE}"
