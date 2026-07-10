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

FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_76_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_76_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_76_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_76_docker_up.log"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_76_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_76_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_76_attendance_conversations_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_76_status_model_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_76_domain_inbox_page.log"
DOMAIN_SEND_FAILURES_PAGE_LOG="${LOGS_DIR}/setup_76_domain_send_failures_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_76_domain_dashboard.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_76_domain_attendance_dashboard.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_INBOX_VISUAL_REORGANIZATION.md"
DOC_CHECKLIST="${DOCS_DIR}/ATTENDANCE_INBOX_VISUAL_CHECKLIST.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_STATUS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-status"

echo "== Etapa 76: Reorganizacao visual do app inbox =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 75..."

if [ ! -f "${LOGS_DIR}/setup_75.log" ]; then
  echo "ERRO: setup_75.log nao encontrado. Conclua a Etapa 75 antes da Etapa 76."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_75.log"; then
  echo "ERRO: Etapa 75 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_75.log"
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

for tool in node npm docker curl python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

if [ ! -f "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" ]; then
  echo "ERRO: InboxPage.tsx nao encontrado."
  exit 1
fi

echo "Aplicando marcadores visuais seguros no InboxPage..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "Etapa 76 - layout refinado" not in text:
    text = text.replace(
        "Central de atendimento",
        "Central de atendimento"
    )

    marker = "{notice ? <div className=\"form-message\">{notice}</div> : null}"
    if marker in text and "inbox-visual-guide" not in text:
        replacement = marker + """

      <section className="inbox-visual-guide" aria-label="Etapa 76 - layout refinado">
        <span>Conversas e filtros</span>
        <span>Mensagens e envio</span>
        <span>Dados operacionais</span>
      </section>"""
        text = text.replace(marker, replacement, 1)

path.write_text(text)
PY

echo "Aplicando CSS de reorganizacao visual..."

if ! grep -q "Etapa 76 - Reorganizacao visual do app inbox" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 76 - Reorganizacao visual do app inbox */

.inbox-visual-guide {
  align-items: center;
  background: linear-gradient(135deg, rgba(7, 87, 200, 0.08), rgba(220, 38, 38, 0.08));
  border: 1px solid rgba(7, 87, 200, 0.16);
  border-radius: 18px;
  color: var(--lh-blue-950, #04204f);
  display: grid;
  font-size: 12px;
  font-weight: 950;
  gap: 10px;
  grid-template-columns: 1fr 1fr 1fr;
  letter-spacing: 0.02em;
  padding: 10px 14px;
  text-transform: uppercase;
}

.inbox-visual-guide span {
  background: #ffffff;
  border: 1px solid rgba(4, 32, 79, 0.08);
  border-radius: 999px;
  box-shadow: 0 10px 26px rgba(4, 32, 79, 0.08);
  padding: 8px 10px;
  text-align: center;
}

.inbox-shell {
  display: grid;
  gap: 20px;
}

.inbox-hero {
  overflow: hidden;
  position: relative;
}

.inbox-hero::after {
  background: radial-gradient(circle at center, rgba(255, 255, 255, 0.28), transparent 60%);
  content: "";
  height: 220px;
  pointer-events: none;
  position: absolute;
  right: -70px;
  top: -90px;
  width: 220px;
}

.inbox-grid,
.inbox-layout,
.attendance-layout {
  align-items: start;
  display: grid;
  gap: 16px;
  grid-template-columns: minmax(260px, 320px) minmax(0, 1fr) minmax(280px, 360px);
}

.conversation-list,
.inbox-conversations,
.conversations-panel {
  min-height: 540px;
}

.conversation-list,
.inbox-conversations,
.conversations-panel,
.conversation-thread,
.messages-panel,
.inbox-thread,
.attendance-side-panel,
.metadata-panel,
.inbox-details,
.quick-replies-card,
.closure-card,
.send-history-card {
  border-radius: 22px;
}

.conversation-list,
.inbox-conversations,
.conversations-panel {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  overflow: hidden;
}

.conversation-list button,
.inbox-conversations button,
.conversations-panel button {
  border-radius: 16px;
}

.conversation-thread,
.messages-panel,
.inbox-thread {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  min-height: 620px;
  overflow: hidden;
}

.message-list,
.messages-list,
.chat-messages {
  background:
    linear-gradient(rgba(248, 250, 252, 0.92), rgba(248, 250, 252, 0.92)),
    radial-gradient(circle at top left, rgba(37, 99, 235, 0.10), transparent 30%),
    radial-gradient(circle at bottom right, rgba(220, 38, 38, 0.08), transparent 30%);
  border-radius: 18px;
}

.composer-card,
.message-composer,
.inbox-composer {
  background: #ffffff;
  border: 1px solid rgba(4, 32, 79, 0.10);
  border-radius: 20px;
  bottom: 12px;
  box-shadow: 0 18px 45px rgba(4, 32, 79, 0.16);
  position: sticky;
  z-index: 4;
}

.composer-card textarea,
.message-composer textarea,
.inbox-composer textarea {
  border-radius: 16px;
  min-height: 84px;
}

.attendance-side-panel,
.metadata-panel,
.inbox-details {
  display: grid;
  gap: 14px;
  position: sticky;
  top: 18px;
}

.quick-replies-card,
.closure-card,
.send-history-card,
.notes-card,
.tags-card,
.assignee-card,
.status-card {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  box-shadow: 0 12px 34px rgba(4, 32, 79, 0.10);
  overflow: hidden;
}

.quick-replies-card,
.closure-card {
  padding: 16px;
}

.quick-replies-card button,
.closure-card button,
.status-card button,
.assignee-card button {
  min-height: 40px;
}

.send-history-list {
  display: grid;
  gap: 10px;
  max-height: 300px;
  overflow: auto;
  padding-right: 4px;
}

.send-history-list article {
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 12px;
}

.inbox-panel-title {
  align-items: flex-start;
  border-bottom: 1px solid rgba(4, 32, 79, 0.08);
  display: flex;
  gap: 8px;
  justify-content: space-between;
  padding-bottom: 10px;
}

.inbox-panel-title strong {
  color: var(--lh-blue-950, #04204f);
  font-size: 15px;
}

.inbox-panel-title span {
  color: var(--lh-muted, #6b7280);
  font-size: 12px;
  font-weight: 800;
}

.status-pill,
.conversation-status,
.attendance-status {
  border-radius: 999px;
  display: inline-flex;
  font-size: 12px;
  font-weight: 950;
  line-height: 1;
  padding: 7px 10px;
}

.status-pill[data-status="novo"],
.attendance-status[data-status="novo"] {
  background: #dbeafe;
  color: #1d4ed8;
}

.status-pill[data-status="em_atendimento"],
.attendance-status[data-status="em_atendimento"] {
  background: #dcfce7;
  color: #166534;
}

.status-pill[data-status="aguardando_cliente"],
.attendance-status[data-status="aguardando_cliente"] {
  background: #fef3c7;
  color: #92400e;
}

.status-pill[data-status="encerrado"],
.attendance-status[data-status="encerrado"] {
  background: #fee2e2;
  color: #991b1b;
}

.form-message {
  border-radius: 16px;
}

@media (max-width: 1280px) {
  .inbox-grid,
  .inbox-layout,
  .attendance-layout {
    grid-template-columns: minmax(240px, 300px) minmax(0, 1fr);
  }

  .attendance-side-panel,
  .metadata-panel,
  .inbox-details {
    grid-column: 1 / -1;
    position: static;
  }
}

@media (max-width: 900px) {
  .inbox-visual-guide {
    grid-template-columns: 1fr;
  }

  .inbox-grid,
  .inbox-layout,
  .attendance-layout {
    grid-template-columns: 1fr;
  }

  .conversation-list,
  .inbox-conversations,
  .conversations-panel,
  .conversation-thread,
  .messages-panel,
  .inbox-thread {
    min-height: auto;
  }

  .composer-card,
  .message-composer,
  .inbox-composer {
    bottom: 0;
  }
}
DOC
fi

echo "Validando ausencia de HTML injetado no frontend..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML injetado encontrado no frontend."
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

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
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
Resumo: Aplicado refino visual inicial no app inbox, separando conversas, mensagens e dados operacionais, com melhorias responsivas, composer destacado e checklist visual de validacao.
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

echo ""
echo "== Etapa 76 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 77 - Criacao da tela attendance settings"
