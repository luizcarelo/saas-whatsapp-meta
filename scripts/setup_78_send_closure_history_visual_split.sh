#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_78.log"

FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_78_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_78_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_78_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_78_docker_up.log"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_78_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_78_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_78_attendance_conversations_domain.log"
DOMAIN_SEND_FAILURES_LOG="${LOGS_DIR}/setup_78_send_failures_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_78_status_model_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_78_domain_inbox_page.log"
DOMAIN_SETTINGS_PAGE_LOG="${LOGS_DIR}/setup_78_domain_attendance_settings_page.log"
DOMAIN_FAILURES_PAGE_LOG="${LOGS_DIR}/setup_78_domain_send_failures_page.log"
DOMAIN_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_78_domain_attendance_dashboard_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_SEND_CLOSURE_HISTORY_VISUAL_SPLIT.md"
DOC_CHECKLIST="${DOCS_DIR}/ATTENDANCE_SEND_CLOSURE_HISTORY_CHECKLIST.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_FAILURES_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send-failures"
DOMAIN_STATUS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-status"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_SETTINGS_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-settings"
DOMAIN_FAILURES_PAGE_URL="${DOMAIN_BASE_URL}/app/send-failures"
DOMAIN_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"

echo "== Etapa 78: Separacao visual de envio encerramento e historico =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 77..."

if [ ! -f "${LOGS_DIR}/setup_77.log" ]; then
  echo "ERRO: setup_77.log nao encontrado. Conclua a Etapa 77 antes da Etapa 78."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_77.log"; then
  echo "ERRO: Etapa 77 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_77.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
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

for tool in node npm docker curl python3 grep sed; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
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

echo "Validando ausencia de HTML injetado antes da alteracao..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML injetado encontrado antes da alteracao."
  exit 1
fi

echo "Aplicando CSS seguro da separacao visual..."

if ! grep -q "Etapa 78 - Separacao visual de envio encerramento e historico" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 78 - Separacao visual de envio encerramento e historico */

.inbox-thread,
.messages-panel,
.conversation-thread {
  display: grid;
  gap: 14px;
}

.message-composer,
.inbox-composer,
.composer-card {
  border: 2px solid rgba(7, 87, 200, 0.18);
  position: sticky;
}

.message-composer::before,
.inbox-composer::before,
.composer-card::before {
  color: var(--lh-blue-950, #04204f);
  content: "Envio de mensagem";
  display: block;
  font-size: 12px;
  font-weight: 950;
  letter-spacing: 0.03em;
  margin-bottom: 8px;
  text-transform: uppercase;
}

.quick-replies-card {
  border-left: 5px solid var(--lh-blue-600, #2563eb);
}

.quick-replies-card::before {
  color: var(--lh-blue-950, #04204f);
  content: "Respostas rapidas";
  display: block;
  font-size: 12px;
  font-weight: 950;
  letter-spacing: 0.03em;
  margin-bottom: 10px;
  text-transform: uppercase;
}

.closure-card {
  border-left: 5px solid var(--lh-red-600, #dc2626);
}

.closure-card::before {
  color: var(--lh-blue-950, #04204f);
  content: "Encerramento e avaliacao";
  display: block;
  font-size: 12px;
  font-weight: 950;
  letter-spacing: 0.03em;
  margin-bottom: 10px;
  text-transform: uppercase;
}

.send-history-card {
  border-left: 5px solid #7c3aed;
}

.send-history-card::before {
  color: var(--lh-blue-950, #04204f);
  content: "Historico de envios";
  display: block;
  font-size: 12px;
  font-weight: 950;
  letter-spacing: 0.03em;
  margin-bottom: 10px;
  text-transform: uppercase;
}

.send-history-list article {
  position: relative;
}

.send-history-list article::before {
  background: #7c3aed;
  border-radius: 999px;
  content: "";
  height: 8px;
  left: 10px;
  position: absolute;
  top: 14px;
  width: 8px;
}

.send-history-list article {
  padding-left: 28px;
}

.status-card,
.assignee-card,
.notes-card,
.tags-card {
  border-left: 5px solid #0f766e;
}

.status-card::before,
.assignee-card::before,
.notes-card::before,
.tags-card::before {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-size: 12px;
  font-weight: 950;
  letter-spacing: 0.03em;
  margin-bottom: 10px;
  text-transform: uppercase;
}

.status-card::before {
  content: "Status operacional";
}

.assignee-card::before {
  content: "Responsavel";
}

.notes-card::before {
  content: "Notas internas";
}

.tags-card::before {
  content: "Tags";
}

.send-failure-list header span,
.status-pill[data-status="failed"],
.attendance-status[data-status="failed"] {
  background: #fee2e2;
  color: #991b1b;
}

.status-pill[data-status="dry_run"],
.attendance-status[data-status="dry_run"] {
  background: #fef3c7;
  color: #92400e;
}

.inbox-visual-guide {
  margin-bottom: 4px;
}

.inbox-visual-guide::after {
  color: var(--lh-muted, #6b7280);
  content: "Fluxo operacional separado para reduzir confusao entre atendimento, envio, encerramento e historico.";
  display: block;
  font-size: 12px;
  font-weight: 800;
  grid-column: 1 / -1;
  padding: 2px 6px 0;
  text-align: center;
  text-transform: none;
}

@media (max-width: 900px) {
  .message-composer,
  .inbox-composer,
  .composer-card {
    position: static;
  }
}
DOC
fi

echo "Gerando relatorio de trechos relevantes do InboxPage..."

grep -nEi "composer|quick|reply|resposta|closure|encerr|rating|avali|history|historico|dryRun|failed|falha|retry|retent" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  > "${LOGS_DIR}/setup_78_inbox_relevant_lines.log" || true

echo "Validando ausencia de HTML injetado depois da alteracao..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML injetado encontrado depois da alteracao."
  exit 1
fi

if grep -R "/app/inboxVoltar" \
  "${FRONTEND_DIR}/src/pages" \
  "${FRONTEND_DIR}/src/components"
then
  echo "ERRO: ancora corrompida encontrada."
  exit 1
fi

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

DOMAIN_SEND_FAILURES_STATUS="$(curl -L -s -o "${DOMAIN_SEND_FAILURES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_FAILURES_URL}" || true)"

if [ "${DOMAIN_SEND_FAILURES_STATUS}" != "200" ]; then
  echo "ERRO: send failures endpoint falhou. Status ${DOMAIN_SEND_FAILURES_STATUS}"
  cat "${DOMAIN_SEND_FAILURES_LOG}"
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

echo "Validando paginas principais..."

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_INBOX_PAGE_URL}" || true)"

if [ "${DOMAIN_INBOX_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina inbox nao respondeu 200."
  exit 1
fi

DOMAIN_SETTINGS_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_SETTINGS_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_SETTINGS_PAGE_URL}" || true)"

if [ "${DOMAIN_SETTINGS_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina attendance settings nao respondeu 200."
  exit 1
fi

DOMAIN_FAILURES_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_FAILURES_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_FAILURES_PAGE_URL}" || true)"

if [ "${DOMAIN_FAILURES_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina send failures nao respondeu 200."
  exit 1
fi

DOMAIN_DASHBOARD_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_PAGE_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina attendance dashboard nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 78..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Send Closure History Visual Split

## Visao geral

Este documento registra a separacao visual de envio, encerramento e historico no app inbox.

## Resultado

Status:

    concluido

## Objetivo

Objetivo:

- separar visualmente envio de mensagem
- separar visualmente respostas rapidas
- separar visualmente encerramento e avaliacao
- separar visualmente historico de envios
- destacar status operacional e dados laterais
- reduzir confusao entre status de atendimento e status de envio

## Estrategia aplicada

Estrategia:

- refino por CSS
- sem alteracao de regra de negocio
- sem alteracao de banco
- sem alteracao de backend
- sem envio real
- sem inserir JSX novo no arquivo inbox

## Areas reforcadas

Areas:

- Envio de mensagem
- Respostas rapidas
- Encerramento e avaliacao
- Historico de envios
- Status operacional
- Responsavel
- Notas internas
- Tags

## Limites da etapa

Limites:

- a etapa melhora separacao visual
- a etapa nao transforma componentes internos
- a etapa nao cria edicao nova
- a etapa nao altera fluxo de envio
- a etapa nao resolve pendencia Meta

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/styles.css
- docs/ATTENDANCE_SEND_CLOSURE_HISTORY_VISUAL_SPLIT.md
- docs/ATTENDANCE_SEND_CLOSURE_HISTORY_CHECKLIST.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- frontend sem HTML injetado
- ausencia de ancora corrompida
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- health dominio
- login dominio
- endpoint attendance conversations
- endpoint send failures
- endpoint status model
- rota app inbox
- rota app attendance settings
- rota app send failures
- rota app attendance dashboard

## Proxima etapa sugerida

Etapa 79:

    Revisao de dados sinteticos e limpeza operacional
DOC

cat > "${DOC_CHECKLIST}" <<'DOC'
# Attendance Send Closure History Checklist

## Visao geral

Este documento registra o checklist para revisar a separacao visual aplicada na Etapa 78.

## Checklist

Itens:

- confirmar que o composer aparece como area de envio
- confirmar que respostas rapidas aparecem em bloco separado
- confirmar que encerramento e avaliacao aparecem em bloco separado
- confirmar que historico de envios aparece em bloco separado
- confirmar que status operacional nao parece status de envio
- confirmar que falhas e dryRun possuem destaque visual
- confirmar que a tela permanece responsiva
- confirmar que nenhum fluxo de envio foi alterado
- confirmar que nenhum dado real foi modificado
- confirmar que a pendencia Meta continua separada

## Observacoes

Observacoes:

- a separacao foi aplicada por CSS para reduzir risco
- ajustes estruturais internos podem ser feitos em etapa futura
- dados sinteticos serao revisados na etapa seguinte
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 78 - Separacao visual de envio encerramento e historico",
    "- [x] Etapa 78 - Separacao visual de envio encerramento e historico\n- [ ] Etapa 79 - Revisao de dados sinteticos e limpeza operacional"
)

text = text.replace(
    "Etapa 78 - Separacao visual de envio encerramento e historico.",
    "Etapa 79 - Revisao de dados sinteticos e limpeza operacional."
)

text = text.replace(
    "Etapa 77 - Criacao da tela attendance settings.",
    "Etapa 78 - Separacao visual de envio encerramento e historico."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Separacao visual de envio encerramento e historico criada." not in text:
    text += "\nSeparacao visual de envio encerramento e historico criada.\n"

for doc in [
    "- docs/ATTENDANCE_SEND_CLOSURE_HISTORY_VISUAL_SPLIT.md",
    "- docs/ATTENDANCE_SEND_CLOSURE_HISTORY_CHECKLIST.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 77 concluidas",
    "- Etapa 01 ate Etapa 78 concluidas"
)

text = text.replace(
    "- Etapa 78 - Separacao visual de envio encerramento e historico",
    "- Etapa 79 - Revisao de dados sinteticos e limpeza operacional"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 78 - Separacao visual de envio encerramento e historico
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Aplicada separacao visual por CSS no app inbox para distinguir envio, respostas rapidas, encerramento, avaliacao, historico de envios e dados operacionais, sem alterar regra de negocio.
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
Etapa: 78
Acao: Separacao visual de envio encerramento e historico
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Send failures status: ${DOMAIN_SEND_FAILURES_STATUS}
Status model status: ${DOMAIN_STATUS_MODEL_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Attendance settings page status: ${DOMAIN_SETTINGS_PAGE_STATUS}
Send failures page status: ${DOMAIN_FAILURES_PAGE_STATUS}
Attendance dashboard page status: ${DOMAIN_DASHBOARD_PAGE_STATUS}
Relevant lines log: logs/setup_78_inbox_relevant_lines.log
Status: Concluido
DOC

echo ""
echo "== Etapa 78 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 79 - Revisao de dados sinteticos e limpeza operacional"
