#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_69.log"

FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_69_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_69_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_69_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_69_docker_up.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_69_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_69_attendance_conversations_domain.log"
DOMAIN_CLOSE_LOG="${LOGS_DIR}/setup_69_close_conversation_domain.log"
DOMAIN_CLOSING_SEND_LOG="${LOGS_DIR}/setup_69_closing_send_domain.log"
DOMAIN_SEND_HISTORY_LOG="${LOGS_DIR}/setup_69_send_history_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_69_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_69_domain_dashboard.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_69_domain_attendance_dashboard.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_CLOSING_RATING_SEND.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_SEND_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_ATTENDANCE_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"

echo "== Etapa 69: Envio real da mensagem de encerramento com avaliacao =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 68..."

if [ ! -f "${LOGS_DIR}/setup_68.log" ]; then
  echo "ERRO: setup_68.log nao encontrado. Conclua a Etapa 68 antes da Etapa 69."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_68.log"; then
  echo "ERRO: Etapa 68 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_68.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
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

echo "Atualizando InboxPage.tsx para enviar encerramento com origem closing_rating..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "sendAttendanceManualMessageRequest" not in text:
    raise SystemExit("Servico de envio da Etapa 67 nao encontrado em InboxPage.tsx")

if "loadSendHistory" not in text:
    raise SystemExit("Historico de envios da Etapa 67 nao encontrado em InboxPage.tsx")

pattern = r"async function handleCloseConversation\(\) \{[\s\S]*?\n  \}\n\n  async function handleCreateRating"
replacement_function = """async function handleCloseConversation() {
    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setComposerText(closingMessage);
      setNotice('Mensagem de encerramento preparada para demonstracao.');
      return;
    }

    const response = await closeAttendanceConversationRequest(token, selectedConversation.id, {
      closingMessage,
      closedByUserId: null,
      closedByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente',
      departmentName: selectedConversation.departmentName,
      ratingRequested: true
    });

    if (!response.success) {
      setNotice(response.error.message || 'Nao foi possivel encerrar atendimento.');
      return;
    }

    const preparedMessage = response.data.closure.closingMessage;

    setComposerText(preparedMessage);

    const sendResponse = await sendAttendanceManualMessageRequest(token, selectedConversation.id, {
      messageBody: preparedMessage,
      sentByUserId: null,
      sentByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente',
      departmentName: selectedConversation.departmentName,
      messageOrigin: 'closing_rating',
      quickReplyId: null,
      quickReplyTitle: null,
      dryRun: sendDryRun
    });

    await loadInbox();
    await loadMetadata(selectedConversation.id);
    await loadSendHistory(selectedConversation.id);

    if (sendResponse.success) {
      if (sendDryRun) {
        setNotice('Encerramento registrado e mensagem de avaliacao validada em dryRun.');
      } else if (sendResponse.data.send.status === 'sent') {
        setNotice('Encerramento registrado e mensagem de avaliacao enviada.');
      } else {
        setNotice(sendResponse.data.send.errorMessage || 'Encerramento registrado, mas o envio retornou falha.');
      }
    } else {
      setNotice(sendResponse.error.message || 'Encerramento registrado, mas nao foi possivel enviar a mensagem.');
    }
  }

  async function handleCreateRating"""

new_text, count = re.subn(pattern, replacement_function, text)

if count != 1:
    raise SystemExit("Nao foi possivel substituir handleCloseConversation com seguranca")

text = new_text

old_text = "Prepare a mensagem de encerramento, marque a conversa como encerrada e registre a avaliacao quando o cliente responder."
new_text_piece = "Prepare a mensagem de encerramento, envie pela central com origem closing_rating e registre a avaliacao quando o cliente responder."

text = text.replace(old_text, new_text_piece)

old_history = "{send.status}{send.dryRun ? ' - dryRun' : ''}{send.messageOrigin === 'quick_reply' ? ' - resposta rapida' : ''}"
new_history = "{send.status}{send.dryRun ? ' - dryRun' : ''}{send.messageOrigin === 'quick_reply' ? ' - resposta rapida' : ''}{send.messageOrigin === 'closing_rating' ? ' - encerramento' : ''}"

text = text.replace(old_history, new_history)

if "send.messageOrigin === 'closing_rating'" not in text:
    raise SystemExit("Marcador visual de closing_rating nao foi aplicado")

path.write_text(text)
PY

echo "Adicionando CSS da Etapa 69..."

if ! grep -q "Etapa 69 - Envio de encerramento com avaliacao" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 69 - Envio de encerramento com avaliacao */

.closure-card button {
  min-height: 42px;
}

.closure-card .rating-form button {
  background: linear-gradient(135deg, var(--lh-orange-700, #f97316), var(--lh-orange-500, #ff9f1c));
}
DOC
fi

echo "Validando frontend sem HTML injetado..."

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

echo "Validando dominio e envio dryRun de encerramento..."

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

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

DOMAIN_CLOSE_STATUS="SKIPPED"
DOMAIN_CLOSING_SEND_STATUS="SKIPPED"
DOMAIN_SEND_HISTORY_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  CLOSING_MESSAGE="Atendimento finalizado. Como voce avalia nosso atendimento de 1 a 5?"

  CLOSE_PAYLOAD="$(node -e "console.log(JSON.stringify({closingMessage:process.argv[1], closedByUserId:null, closedByName:'Validacao Etapa 69', departmentName:'Comercial', ratingRequested:true}))" "${CLOSING_MESSAGE}")"

  DOMAIN_CLOSE_STATUS="$(curl -L -s -o "${DOMAIN_CLOSE_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${CLOSE_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/close" || true)"

  if [ "${DOMAIN_CLOSE_STATUS}" != "200" ] && [ "${DOMAIN_CLOSE_STATUS}" != "201" ]; then
    echo "ERRO: close conversation falhou. Status ${DOMAIN_CLOSE_STATUS}"
    cat "${DOMAIN_CLOSE_LOG}"
    exit 1
  fi

  SEND_PAYLOAD="$(node -e "console.log(JSON.stringify({messageBody:process.argv[1], sentByUserId:null, sentByName:'Validacao Etapa 69', departmentName:'Comercial', messageOrigin:'closing_rating', quickReplyId:null, quickReplyTitle:null, dryRun:true}))" "${CLOSING_MESSAGE}")"

  DOMAIN_CLOSING_SEND_STATUS="$(curl -L -s -o "${DOMAIN_CLOSING_SEND_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${SEND_PAYLOAD}" \
    "${DOMAIN_SEND_URL}/conversations/${CONVERSATION_ID}/messages" || true)"

  if [ "${DOMAIN_CLOSING_SEND_STATUS}" != "200" ] && [ "${DOMAIN_CLOSING_SEND_STATUS}" != "201" ]; then
    echo "ERRO: closing rating send falhou. Status ${DOMAIN_CLOSING_SEND_STATUS}"
    cat "${DOMAIN_CLOSING_SEND_LOG}"
    exit 1
  fi

  if ! grep -q "closing_rating" "${DOMAIN_CLOSING_SEND_LOG}"; then
    echo "ERRO: envio nao retornou origem closing_rating."
    cat "${DOMAIN_CLOSING_SEND_LOG}"
    exit 1
  fi

  if ! grep -q "dry_run" "${DOMAIN_CLOSING_SEND_LOG}"; then
    echo "ERRO: envio de encerramento nao retornou dry_run."
    cat "${DOMAIN_CLOSING_SEND_LOG}"
    exit 1
  fi

  DOMAIN_SEND_HISTORY_STATUS="$(curl -L -s -o "${DOMAIN_SEND_HISTORY_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_SEND_URL}/conversations/${CONVERSATION_ID}/messages" || true)"

  if [ "${DOMAIN_SEND_HISTORY_STATUS}" != "200" ]; then
    echo "ERRO: send history falhou. Status ${DOMAIN_SEND_HISTORY_STATUS}"
    cat "${DOMAIN_SEND_HISTORY_LOG}"
    exit 1
  fi
else
  echo '{"skipped":"sem conversa real para encerramento"}' > "${DOMAIN_CLOSE_LOG}"
  echo '{"skipped":"sem conversa real para envio"}' > "${DOMAIN_CLOSING_SEND_LOG}"
  echo '{"skipped":"sem conversa para historico"}' > "${DOMAIN_SEND_HISTORY_LOG}"
fi

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_INBOX_PAGE_URL}" || true)"

if [ "${DOMAIN_INBOX_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina inbox nao respondeu 200."
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

echo "Gerando documentacao da Etapa 69..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Closing Rating Send

## Visao geral

Este documento registra o envio da mensagem de encerramento com avaliacao pela central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- envio da mensagem de encerramento pela central app inbox
- origem closing rating no envio
- uso do mesmo modo dryRun da central
- encerramento registrado antes do envio
- mensagem de avaliacao enviada ou validada pelo backend de envio
- historico visual indicando envio de encerramento
- feedback visual para envio validado, enviado ou com falha

## Comportamento

Comportamento:

- atendente prepara a mensagem de encerramento
- atendente clica em encerrar e preparar mensagem
- sistema registra o encerramento
- sistema chama o backend de envio com message origin closing rating
- se dryRun estiver ativo, nenhuma mensagem real e enviada
- se dryRun estiver desativado, o backend tenta enviar pela API oficial da Meta
- historico da conversa exibe o envio com indicador de encerramento

## Validacao de seguranca

Validacao:

- dryRun permanece ativo por padrao
- setup valida apenas dryRun
- envio real depende do atendente desativar dryRun na tela
- backend continua validando conta WhatsApp, token, conversa, contato e telefone

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_CLOSING_RATING_SEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- login dominio
- endpoint attendance conversations dominio
- endpoint close conversation dominio
- dryRun de envio com origem closing rating
- historico de envios
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_69_frontend_typecheck.log
- logs/setup_69_frontend_build.log
- logs/setup_69_frontend_docker_build.log
- logs/setup_69_docker_up.log
- logs/setup_69_auth_login_domain.log
- logs/setup_69_attendance_conversations_domain.log
- logs/setup_69_close_conversation_domain.log
- logs/setup_69_closing_send_domain.log
- logs/setup_69_send_history_domain.log
- logs/setup_69_domain_inbox_page.log
- logs/setup_69_domain_dashboard.log
- logs/setup_69_domain_attendance_dashboard.log
- logs/setup_69.log

## Proxima etapa sugerida

Etapa 70:

    Registro do atendente nas mensagens enviadas
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 69 - Envio real da mensagem de encerramento com avaliacao",
    "- [x] Etapa 69 - Envio real da mensagem de encerramento com avaliacao\n- [ ] Etapa 70 - Registro do atendente nas mensagens enviadas"
)

text = text.replace(
    "Etapa 69 - Envio real da mensagem de encerramento com avaliacao.",
    "Etapa 70 - Registro do atendente nas mensagens enviadas."
)

text = text.replace(
    "Etapa 68 - Envio real usando respostas rapidas.",
    "Etapa 69 - Envio real da mensagem de encerramento com avaliacao."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Envio real da mensagem de encerramento com avaliacao criado." not in text:
    text = text.replace(
        "Envio real usando respostas rapidas criado.",
        "Envio real usando respostas rapidas criado.\n\nEnvio real da mensagem de encerramento com avaliacao criado."
    )

if "- docs/ATTENDANCE_CLOSING_RATING_SEND.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_QUICK_REPLY_SEND.md",
        "- docs/ATTENDANCE_CLOSING_RATING_SEND.md\n- docs/ATTENDANCE_QUICK_REPLY_SEND.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 68 concluidas",
    "- Etapa 01 ate Etapa 69 concluidas"
)

text = text.replace(
    "- Etapa 69 - Envio real da mensagem de encerramento com avaliacao",
    "- Etapa 70 - Registro do atendente nas mensagens enviadas"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 69 - Envio real da mensagem de encerramento com avaliacao
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Integrado encerramento com avaliacao ao backend de envio da central, usando origem closing_rating, dryRun por padrao e historico visual de envio.
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
Etapa: 69
Acao: Envio real da mensagem de encerramento com avaliacao
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Close status: ${DOMAIN_CLOSE_STATUS}
Closing send status: ${DOMAIN_CLOSING_SEND_STATUS}
Send history status: ${DOMAIN_SEND_HISTORY_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Attendance dashboard status: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 69 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 70 - Registro do atendente nas mensagens enviadas"
