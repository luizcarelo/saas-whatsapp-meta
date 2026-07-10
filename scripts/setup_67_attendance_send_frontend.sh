#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_67.log"

FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_67_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_67_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_67_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_67_docker_up.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_67_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_67_attendance_conversations_domain.log"
DOMAIN_SEND_DRY_RUN_LOG="${LOGS_DIR}/setup_67_send_dry_run_domain.log"
DOMAIN_SEND_HISTORY_LOG="${LOGS_DIR}/setup_67_send_history_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_67_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_67_domain_dashboard.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_67_domain_attendance_dashboard.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_SEND_FRONTEND.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_SEND_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_ATTENDANCE_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"

echo "== Etapa 67: Frontend de envio real no app inbox =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Validando conclusao da Etapa 66..."

if [ ! -f "${LOGS_DIR}/setup_66.log" ]; then
  echo "ERRO: setup_66.log nao encontrado. Conclua a Etapa 66 antes da Etapa 67."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_66.log"; then
  echo "ERRO: Etapa 66 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_66.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/types/attendance-send.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance-send.service.ts" \
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

echo "Criando types frontend de envio..."

cat > "${FRONTEND_DIR}/src/types/attendance-send.types.ts" <<'DOC'
export type AttendanceSendItem = {
  id: string;
  conversationId: string;
  contactId: string | null;
  contactPhone: string | null;
  whatsappAccountId: string | null;
  phoneNumberId: string | null;
  messageBody: string;
  sentByUserId: string | null;
  sentByName: string;
  departmentName: string;
  conversationStatus: string;
  messageOrigin: string;
  provider: string;
  providerMessageId: string | null;
  status: string;
  errorMessage: string | null;
  dryRun: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceSendManualData = {
  send: AttendanceSendItem;
};

export type AttendanceSendHistoryData = {
  sends: AttendanceSendItem[];
};
DOC

echo "Criando service frontend de envio..."

cat > "${FRONTEND_DIR}/src/services/attendance-send.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AttendanceSendHistoryData,
  AttendanceSendManualData
} from '../types/attendance-send.types';

export async function sendAttendanceManualMessageRequest(
  token: string,
  conversationId: string,
  payload: {
    messageBody: string;
    sentByUserId?: string | null;
    sentByName: string;
    departmentName: string;
    messageOrigin: string;
    dryRun: boolean;
  }
) {
  return apiRequest<AttendanceSendManualData>('/attendance-send/conversations/' + conversationId + '/messages', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceSendHistoryRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceSendHistoryData>('/attendance-send/conversations/' + conversationId + '/messages', {
    method: 'GET',
    token
  });
}
DOC

echo "Atualizando InboxPage.tsx..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "attendance-send.service" not in text:
    text = text.replace(
        "import { useAuthStore } from '../../stores/auth.store';",
        "import {\n  listAttendanceSendHistoryRequest,\n  sendAttendanceManualMessageRequest\n} from '../../services/attendance-send.service';\nimport { useAuthStore } from '../../stores/auth.store';"
    )

if "AttendanceSendItem" not in text:
    if "attendance-closure.types" in text:
        text = text.replace(
            "} from '../../types/attendance-closure.types';",
            "} from '../../types/attendance-closure.types';\nimport type { AttendanceSendItem } from '../../types/attendance-send.types';"
        )
    else:
        text = text.replace(
            "import type { AttendanceDashboardSummary } from '../../types/attendance-dashboard.types';",
            "import type { AttendanceDashboardSummary } from '../../types/attendance-dashboard.types';\nimport type { AttendanceSendItem } from '../../types/attendance-send.types';"
        )

if "const [sendHistory" not in text:
    anchor = "const [ratingComment, setRatingComment] = useState('');"
    if anchor not in text:
        anchor = "const [notice, setNotice] = useState('');"
    text = text.replace(
        anchor,
        anchor + "\n  const [sendHistory, setSendHistory] = useState<AttendanceSendItem[]>([]);\n  const [sendDryRun, setSendDryRun] = useState(true);\n  const [sendingMessage, setSendingMessage] = useState(false);"
    )

if "async function loadSendHistory" not in text:
    insert_before = "async function loadInbox()"
    method = """async function loadSendHistory(conversationId: string) {
    const token = getToken();

    if (!token || !conversationId || conversationId.startsWith('demo-')) {
      setSendHistory([]);
      return;
    }

    const response = await listAttendanceSendHistoryRequest(token, conversationId);

    if (response.success) {
      setSendHistory(response.data.sends);
    }
  }

  """
    text = text.replace(insert_before, method + insert_before)

if "void loadSendHistory(selectedConversation.id)" not in text:
    marker = "const visibleConversations = useMemo(() => {"
    hook = """useEffect(() => {
    if (selectedConversation.id) {
      void loadSendHistory(selectedConversation.id);
    }
  }, [selectedConversation.id]);

  """
    text = text.replace(marker, hook + marker)

if "async function handleSendComposerMessage" not in text:
    marker = "async function handleCloseConversation()"
    if marker not in text:
      marker = "async function handleCreateQuickReply"
    method = """async function handleSendComposerMessage() {
    const token = getToken();
    const messageBody = composerText.trim();

    if (!messageBody) {
      setNotice('Digite uma mensagem antes de enviar.');
      return;
    }

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setNotice('Mensagem validada localmente para demonstracao.');
      return;
    }

    setSendingMessage(true);

    const response = await sendAttendanceManualMessageRequest(token, selectedConversation.id, {
      messageBody,
      sentByUserId: null,
      sentByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente',
      departmentName: selectedConversation.departmentName,
      messageOrigin: 'manual',
      dryRun: sendDryRun
    });

    if (response.success) {
      await loadSendHistory(selectedConversation.id);

      if (sendDryRun) {
        setNotice('Envio validado em modo dryRun. Nenhuma mensagem real foi enviada.');
      } else if (response.data.send.status === 'sent') {
        setComposerText('');
        setNotice('Mensagem enviada com sucesso.');
      } else {
        setNotice(response.data.send.errorMessage || 'Envio registrado com falha.');
      }
    } else {
      setNotice(response.error.message || 'Nao foi possivel enviar a mensagem.');
    }

    setSendingMessage(false);
  }

  """
    text = text.replace(marker, method + marker)

old_button = '<button type="button">Enviar</button>'
new_button = """<button disabled={sendingMessage} onClick={() => void handleSendComposerMessage()} type="button">
              {sendingMessage ? 'Enviando...' : sendDryRun ? 'Validar envio' : 'Enviar'}
            </button>"""

if old_button in text:
    text = text.replace(old_button, new_button, 1)

if "className=\"send-history-panel\"" not in text:
    old_block = """          </footer>
        </main>"""
    new_block = """          </footer>

          <section className="send-history-panel">
            <label className="send-dry-run-toggle">
              <input
                checked={sendDryRun}
                onChange={(event) => setSendDryRun(event.target.checked)}
                type="checkbox"
              />
              Modo dryRun ativo para validar sem envio real
            </label>

            <div className="inbox-panel-title">
              <strong>Historico de envios da central</strong>
              <span>Mensagens enviadas ou validadas pelo backend de atendimento</span>
            </div>

            <div className="send-history-list">
              {sendHistory.length ? sendHistory.map((send) => (
                <article key={send.id}>
                  <div>
                    <strong>{send.sentByName}</strong>
                    <span>{send.status}{send.dryRun ? ' - dryRun' : ''}</span>
                  </div>
                  <p>{send.messageBody}</p>
                  <small>{send.createdAt}</small>
                  {send.errorMessage ? <em>{send.errorMessage}</em> : null}
                </article>
              )) : <small>Nenhum envio registrado para esta conversa.</small>}
            </div>
          </section>
        </main>"""
    if old_block not in text:
        raise SystemExit("Nao foi possivel localizar fechamento do main da conversa")
    text = text.replace(old_block, new_block, 1)

path.write_text(text)
PY

echo "Adicionando CSS do envio pela central..."

if ! grep -q "Etapa 67 - Frontend de envio real" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 67 - Frontend de envio real no app inbox */

.send-history-panel {
  background: #f8fafc;
  border-top: 1px solid #e5e7eb;
  display: grid;
  gap: 12px;
  padding: 14px 16px;
}

.send-dry-run-toggle {
  align-items: center;
  color: #374151;
  display: flex;
  font-size: 13px;
  font-weight: 900;
  gap: 8px;
}

.send-dry-run-toggle input {
  height: 16px;
  width: 16px;
}

.send-history-list {
  display: grid;
  gap: 10px;
  max-height: 260px;
  overflow: auto;
}

.send-history-list article {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  display: grid;
  gap: 6px;
  padding: 10px;
}

.send-history-list article div {
  align-items: center;
  display: flex;
  gap: 8px;
  justify-content: space-between;
}

.send-history-list strong {
  color: var(--lh-blue-950, #04204f);
}

.send-history-list span {
  background: #eff6ff;
  border-radius: 999px;
  color: var(--lh-blue-800, #0757c8);
  font-size: 12px;
  font-weight: 950;
  padding: 5px 8px;
}

.send-history-list p {
  color: #374151;
  margin: 0;
  white-space: pre-wrap;
}

.send-history-list small {
  color: var(--lh-muted, #6b7280);
}

.send-history-list em {
  color: var(--lh-red-700, #b91c1c);
  font-style: normal;
  font-weight: 800;
}
DOC
fi

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-send.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-send.types.ts" \
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

echo "Validando dominio e backend de envio..."

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

DOMAIN_SEND_DRY_RUN_STATUS="SKIPPED"
DOMAIN_SEND_HISTORY_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  SEND_PAYLOAD="$(node -e "console.log(JSON.stringify({messageBody:'Validacao frontend dry run Etapa 67', sentByUserId:null, sentByName:'Validacao Etapa 67', departmentName:'Comercial', messageOrigin:'manual', dryRun:true}))")"

  DOMAIN_SEND_DRY_RUN_STATUS="$(curl -L -s -o "${DOMAIN_SEND_DRY_RUN_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${SEND_PAYLOAD}" \
    "${DOMAIN_SEND_URL}/conversations/${CONVERSATION_ID}/messages" || true)"

  if [ "${DOMAIN_SEND_DRY_RUN_STATUS}" != "200" ] && [ "${DOMAIN_SEND_DRY_RUN_STATUS}" != "201" ]; then
    echo "ERRO: send dry run falhou. Status ${DOMAIN_SEND_DRY_RUN_STATUS}"
    cat "${DOMAIN_SEND_DRY_RUN_LOG}"
    exit 1
  fi

  if ! grep -q "dry_run" "${DOMAIN_SEND_DRY_RUN_LOG}"; then
    echo "ERRO: send dry run nao retornou dry_run."
    cat "${DOMAIN_SEND_DRY_RUN_LOG}"
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
  echo '{"skipped":"sem conversa real para dry run"}' > "${DOMAIN_SEND_DRY_RUN_LOG}"
  echo '{"skipped":"sem conversa real para historico"}' > "${DOMAIN_SEND_HISTORY_LOG}"
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

echo "Gerando documentacao da Etapa 67..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Send Frontend

## Visao geral

Este documento registra a criacao do frontend de envio real no app inbox.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- types frontend para envios da central
- service frontend para envio manual pela central
- service frontend para historico de envios
- botao Enviar conectado ao backend attendance send
- modo dryRun ativo por padrao
- opcao visual para ativar ou desativar dryRun
- historico visual de envios da conversa
- feedback visual de validacao, envio ou falha
- validacao frontend para mensagem vazia

## Comportamento do envio

Comportamento:

- quando dryRun esta ativo, o sistema valida o envio sem enviar mensagem real
- quando dryRun esta desativado, o backend tenta enviar pela API oficial da Meta
- todo envio aparece no historico visual da conversa
- falhas sao exibidas no painel de historico
- o atendente e registrado no envio

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/attendance-send.types.ts
- apps/frontend/src/services/attendance-send.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_SEND_FRONTEND.md
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
- endpoint attendance send dryRun dominio
- endpoint attendance send history dominio
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_67_frontend_typecheck.log
- logs/setup_67_frontend_build.log
- logs/setup_67_frontend_docker_build.log
- logs/setup_67_docker_up.log
- logs/setup_67_auth_login_domain.log
- logs/setup_67_attendance_conversations_domain.log
- logs/setup_67_send_dry_run_domain.log
- logs/setup_67_send_history_domain.log
- logs/setup_67_domain_inbox_page.log
- logs/setup_67_domain_dashboard.log
- logs/setup_67_domain_attendance_dashboard.log
- logs/setup_67.log

## Proxima etapa sugerida

Etapa 68:

    Envio real usando respostas rapidas
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 67 - Frontend de envio real no app inbox",
    "- [x] Etapa 67 - Frontend de envio real no app inbox\n- [ ] Etapa 68 - Envio real usando respostas rapidas"
)

text = text.replace(
    "Etapa 67 - Frontend de envio real no app inbox.",
    "Etapa 68 - Envio real usando respostas rapidas."
)

text = text.replace(
    "Etapa 66 - Backend de envio manual pela central de atendimento.",
    "Etapa 67 - Frontend de envio real no app inbox."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Frontend de envio real no app inbox criado." not in text:
    text = text.replace(
        "Backend de envio manual pela central de atendimento criado.",
        "Backend de envio manual pela central de atendimento criado.\n\nFrontend de envio real no app inbox criado."
    )

if "- docs/ATTENDANCE_SEND_FRONTEND.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_MANUAL_SEND_BACKEND.md",
        "- docs/ATTENDANCE_SEND_FRONTEND.md\n- docs/ATTENDANCE_MANUAL_SEND_BACKEND.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 66 concluidas",
    "- Etapa 01 ate Etapa 67 concluidas"
)

text = text.replace(
    "- Etapa 67 - Frontend de envio real no app inbox",
    "- Etapa 68 - Envio real usando respostas rapidas"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 67 - Frontend de envio real no app inbox
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Conectado o app inbox ao backend attendance send, com botao de envio, modo dryRun por padrao e historico visual de envios da conversa.
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
Etapa: 67
Acao: Frontend de envio real no app inbox
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Send dry run status: ${DOMAIN_SEND_DRY_RUN_STATUS}
Send history status: ${DOMAIN_SEND_HISTORY_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Attendance dashboard status: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 67 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 68 - Envio real usando respostas rapidas"
