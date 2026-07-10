#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_56.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_56_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_56_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_56_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_56_docker_up.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_56_auth_login_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_56_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_56_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_56_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/RESPONSIVE_ATTENDANCE_CENTER_LAYOUT.md"

DOMAIN_SCHEME="https"
DOMAIN_HOST="bot.lhsolucao.com.br"
DOMAIN_BASE_URL="${DOMAIN_SCHEME}://${DOMAIN_HOST}"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 56: Layout responsivo profissional da central de atendimento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/pages/inbox"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
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

echo "Criando InboxPage.tsx com geracao segura..."

python3 <<'PY'
from pathlib import Path

lt = chr(60)
gt = chr(62)

content = f"""import {{ useMemo, useState }} from 'react';

type InboxConversation = {{
  id: string;
  contactName: string;
  phone: string;
  department: string;
  status: string;
  owner: string;
  priority: string;
  unread: number;
  sla: string;
  lastMessage: string;
  lastTime: string;
}};

const conversations: InboxConversation[] = [
  {{
    id: 'conv-001',
    contactName: 'Cliente Comercial',
    phone: '5521999990001',
    department: 'Comercial',
    status: 'novo',
    owner: 'Sem responsavel',
    priority: 'alta',
    unread: 3,
    sla: '8 min',
    lastMessage: 'Gostaria de receber uma proposta.',
    lastTime: '09:42'
  }},
  {{
    id: 'conv-002',
    contactName: 'Cliente Suporte',
    phone: '5521999990002',
    department: 'Suporte',
    status: 'em atendimento',
    owner: 'Luiz',
    priority: 'media',
    unread: 1,
    sla: '22 min',
    lastMessage: 'Estou com duvida sobre a integracao.',
    lastTime: '09:15'
  }},
  {{
    id: 'conv-003',
    contactName: 'Cliente Financeiro',
    phone: '5521999990003',
    department: 'Financeiro',
    status: 'aguardando cliente',
    owner: 'Equipe Financeira',
    priority: 'normal',
    unread: 0,
    sla: '1 h',
    lastMessage: 'Enviei o comprovante.',
    lastTime: '08:51'
  }}
];

const queueTabs = [
  'Fila geral',
  'Sem responsavel',
  'Comercial',
  'Suporte',
  'Financeiro',
  'Aguardando cliente',
  'Em atraso'
];

const quickReplies = [
  'Ola. Como posso ajudar?',
  'Pode me informar seu nome completo?',
  'Vou encaminhar seu atendimento para o departamento responsavel.',
  'Seu atendimento foi finalizado. Avalie de 1 a 5.'
];

export function InboxPage() {{
  const [selectedQueue, setSelectedQueue] = useState('Fila geral');
  const [selectedConversationId, setSelectedConversationId] = useState(conversations[0].id);

  const selectedConversation = useMemo(() => {{
    return conversations.find((item) => item.id === selectedConversationId) || conversations[0];
  }}, [selectedConversationId]);

  const visibleConversations = useMemo(() => {{
    if (selectedQueue === 'Fila geral') {{
      return conversations;
    }}

    if (selectedQueue === 'Sem responsavel') {{
      return conversations.filter((item) => item.owner === 'Sem responsavel');
    }}

    if (selectedQueue === 'Em atraso') {{
      return conversations.filter((item) => item.priority === 'alta');
    }}

    return conversations.filter((item) => item.department === selectedQueue || item.status === selectedQueue.toLowerCase());
  }}, [selectedQueue]);

  return (
    {lt}section className="inbox-shell"{gt}
      {lt}section className="inbox-hero"{gt}
        {lt}div{gt}
          {lt}span{gt}Central de atendimento{lt}/span{gt}
          {lt}h1{gt}Atendimento profissional WhatsApp{lt}/h1{gt}
          {lt}p{gt}Organize conversas por fila, departamento, responsavel, SLA e status operacional em qualquer tamanho de tela.{lt}/p{gt}
        {lt}/div{gt}

        {lt}div className="inbox-hero-brand"{gt}
          {lt}img alt="LH Solucao Chat Bot" src="/assets/lh_chatbot_favicon.png" /{gt}
          {lt}strong{gt}LH Solucao{lt}/strong{gt}
          {lt}small{gt}Chat Bot Meta{lt}/small{gt}
        {lt}/div{gt}
      {lt}/section{gt}

      {lt}section className="inbox-metrics"{gt}
        {lt}article{gt}
          {lt}span{gt}Abertas{lt}/span{gt}
          {lt}strong{gt}18{lt}/strong{gt}
          {lt}p{gt}Conversas em andamento{lt}/p{gt}
        {lt}/article{gt}

        {lt}article{gt}
          {lt}span{gt}Sem responsavel{lt}/span{gt}
          {lt}strong{gt}4{lt}/strong{gt}
          {lt}p{gt}Aguardando distribuicao{lt}/p{gt}
        {lt}/article{gt}

        {lt}article{gt}
          {lt}span{gt}SLA medio{lt}/span{gt}
          {lt}strong{gt}12 min{lt}/strong{gt}
          {lt}p{gt}Primeira resposta{lt}/p{gt}
        {lt}/article{gt}

        {lt}article{gt}
          {lt}span{gt}Avaliacao{lt}/span{gt}
          {lt}strong{gt}4.8{lt}/strong{gt}
          {lt}p{gt}Media prevista{lt}/p{gt}
        {lt}/article{gt}
      {lt}/section{gt}

      {lt}section className="inbox-workspace"{gt}
        {lt}aside className="inbox-queues"{gt}
          {lt}div className="inbox-panel-title"{gt}
            {lt}strong{gt}Filas{lt}/strong{gt}
            {lt}span{gt}Departamentos e status{lt}/span{gt}
          {lt}/div{gt}

          {lt}div className="inbox-queue-list"{gt}
            {{queueTabs.map((queue) => (
              {lt}button
                className={{queue === selectedQueue ? 'active' : ''}}
                key={{queue}}
                onClick={{() => setSelectedQueue(queue)}}
                type="button"
              {gt}
                {{queue}}
              {lt}/button{gt}
            ))}}
          {lt}/div{gt}
        {lt}/aside{gt}

        {lt}aside className="inbox-conversation-list"{gt}
          {lt}div className="inbox-panel-title"{gt}
            {lt}strong{gt}Conversas{lt}/strong{gt}
            {lt}span{gt}{{visibleConversations.length}} itens nesta fila{lt}/span{gt}
          {lt}/div{gt}

          {lt}div className="inbox-search"{gt}
            {lt}input placeholder="Buscar por nome ou telefone" /{gt}
          {lt}/div{gt}

          {lt}div className="inbox-conversation-items"{gt}
            {{visibleConversations.map((conversation) => (
              {lt}button
                className={{conversation.id === selectedConversationId ? 'active' : ''}}
                key={{conversation.id}}
                onClick={{() => setSelectedConversationId(conversation.id)}}
                type="button"
              {gt}
                {lt}div{gt}
                  {lt}strong{gt}{{conversation.contactName}}{lt}/strong{gt}
                  {lt}span{gt}{{conversation.lastMessage}}{lt}/span{gt}
                  {lt}small{gt}{{conversation.department}} · {{conversation.owner}}{lt}/small{gt}
                {lt}/div{gt}

                {lt}em{gt}{{conversation.lastTime}}{lt}/em{gt}

                {{conversation.unread ? (
                  {lt}b{gt}{{conversation.unread}}{lt}/b{gt}
                ) : null}}
              {lt}/button{gt}
            ))}}
          {lt}/div{gt}
        {lt}/aside{gt}

        {lt}main className="inbox-chat"{gt}
          {lt}header className="inbox-chat-header"{gt}
            {lt}div{gt}
              {lt}strong{gt}{{selectedConversation.contactName}}{lt}/strong{gt}
              {lt}span{gt}{{selectedConversation.phone}}{lt}/span{gt}
            {lt}/div{gt}

            {lt}div className="inbox-chat-badges"{gt}
              {lt}span{gt}{{selectedConversation.department}}{lt}/span{gt}
              {lt}span{gt}{{selectedConversation.status}}{lt}/span{gt}
              {lt}span{gt}SLA {{selectedConversation.sla}}{lt}/span{gt}
            {lt}/div{gt}
          {lt}/header{gt}

          {lt}section className="inbox-message-area"{gt}
            {lt}article className="message-bubble inbound"{gt}
              {lt}span{gt}Cliente{lt}/span{gt}
              {lt}p{gt}{{selectedConversation.lastMessage}}{lt}/p{gt}
            {lt}/article{gt}

            {lt}article className="message-bubble internal"{gt}
              {lt}span{gt}Nota interna{lt}/span{gt}
              {lt}p{gt}Atendimento pronto para receber historico, tags e observacoes internas na proxima etapa.{lt}/p{gt}
            {lt}/article{gt}

            {lt}article className="message-bubble outbound"{gt}
              {lt}span{gt}Atendente{lt}/span{gt}
              {lt}p{gt}Ola. Estou verificando seu atendimento e retorno em instantes.{lt}/p{gt}
            {lt}/article{gt}
          {lt}/section{gt}

          {lt}section className="inbox-quick-replies"{gt}
            {{quickReplies.map((reply) => (
              {lt}button key={{reply}} type="button"{gt}
                {{reply}}
              {lt}/button{gt}
            ))}}
          {lt}/section{gt}

          {lt}footer className="inbox-composer"{gt}
            {lt}textarea placeholder="Digite uma mensagem para o cliente" /{gt}
            {lt}button type="button"{gt}Enviar{lt}/button{gt}
          {lt}/footer{gt}
        {lt}/main{gt}

        {lt}aside className="inbox-contact-panel"{gt}
          {lt}div className="inbox-panel-title"{gt}
            {lt}strong{gt}Contato{lt}/strong{gt}
            {lt}span{gt}Historico e operacao{lt}/span{gt}
          {lt}/div{gt}

          {lt}div className="contact-card"{gt}
            {lt}img alt="LH Solucao Chat Bot" src="/assets/lh_chatbot_favicon.png" /{gt}
            {lt}strong{gt}{{selectedConversation.contactName}}{lt}/strong{gt}
            {lt}span{gt}{{selectedConversation.phone}}{lt}/span{gt}
          {lt}/div{gt}

          {lt}div className="contact-details"{gt}
            {lt}span{gt}Departamento: {{selectedConversation.department}}{lt}/span{gt}
            {lt}span{gt}Responsavel: {{selectedConversation.owner}}{lt}/span{gt}
            {lt}span{gt}Prioridade: {{selectedConversation.priority}}{lt}/span{gt}
            {lt}span{gt>Status: {{selectedConversation.status}}{lt}/span{gt}
          {lt}/div{gt}

          {lt}section className="closing-card"{gt}
            {lt}strong{gt}Encerramento com avaliacao{lt}/strong{gt}
            {lt}p{gt}Mensagem padrao pronta para finalizar o atendimento e solicitar nota de 1 a 5.{lt}/p{gt}
            {lt}button type="button"{gt}Preparar encerramento{lt}/button{gt}
          {lt}/section{gt}
        {lt}/aside{gt}
      {lt}/section{gt}
    {lt}/section{gt}
  );
}}
"""

content = content.replace('{lt}span{gt>Status:', '{lt}span{gt}Status:')

Path("apps/frontend/src/pages/inbox/InboxPage.tsx").write_text(content)
PY

echo "Atualizando Sidebar com link Inbox..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/components/layout/Sidebar.tsx")
text = path.read_text()

if 'to="/app/inbox"' not in text:
    text = text.replace(
        '<NavLink to="/app/contacts">Contatos</NavLink>',
        '<NavLink to="/app/inbox">Atendimento</NavLink>\n        <NavLink to="/app/contacts">Contatos</NavLink>'
    )

path.write_text(text)
PY

echo "Atualizando rotas com InboxPage..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/app/routes.tsx")
text = path.read_text()

if "InboxPage" not in text:
    text = text.replace(
        "import { LoginPage } from '../pages/login/LoginPage';",
        "import { InboxPage } from '../pages/inbox/InboxPage';\nimport { LoginPage } from '../pages/login/LoginPage';"
    )

if 'path="inbox"' not in text:
    text = text.replace(
        '<Route path="dashboard" element={<DashboardPage />} />',
        '<Route path="dashboard" element={<DashboardPage />} />\n          <Route path="inbox" element={<InboxPage />} />'
    )

path.write_text(text)
PY

echo "Adicionando CSS da central de atendimento..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 56 - Central de atendimento responsiva */

.inbox-shell {
  display: grid;
  gap: 22px;
}

.inbox-hero {
  align-items: center;
  background:
    linear-gradient(135deg, rgba(7, 87, 200, 0.14), rgba(34, 197, 94, 0.08)),
    #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 28px;
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  display: grid;
  gap: 20px;
  grid-template-columns: minmax(0, 1fr) auto;
  padding: 24px;
}

.inbox-hero span {
  color: var(--lh-orange-700, #f97316);
  display: block;
  font-size: 13px;
  font-weight: 950;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.inbox-hero h1 {
  color: var(--lh-blue-950, #04204f);
  font-size: clamp(28px, 4vw, 44px);
  letter-spacing: -0.05em;
  margin: 8px 0;
}

.inbox-hero p {
  color: var(--lh-muted, #6b7280);
  margin: 0;
  max-width: 860px;
}

.inbox-hero-brand {
  align-items: center;
  background: #ffffff;
  border: 1px solid rgba(7, 87, 200, 0.12);
  border-radius: 22px;
  box-shadow: 0 16px 40px rgba(4, 32, 79, 0.12);
  display: grid;
  justify-items: center;
  min-width: 150px;
  padding: 18px;
}

.inbox-hero-brand img {
  height: 72px;
  object-fit: contain;
  width: 72px;
}

.inbox-hero-brand strong {
  color: var(--lh-blue-950, #04204f);
  margin-top: 8px;
}

.inbox-hero-brand small {
  color: var(--lh-muted, #6b7280);
  font-weight: 800;
}

.inbox-metrics {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.inbox-metrics article {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 22px;
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  padding: 18px;
}

.inbox-metrics span {
  color: var(--lh-muted, #6b7280);
  display: block;
  font-size: 12px;
  font-weight: 950;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.inbox-metrics strong {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-size: 28px;
  margin-top: 6px;
}

.inbox-metrics p {
  color: var(--lh-muted, #6b7280);
  margin: 6px 0 0;
}

.inbox-workspace {
  display: grid;
  gap: 14px;
  grid-template-columns: 190px 320px minmax(0, 1fr) 280px;
  min-height: 680px;
}

.inbox-queues,
.inbox-conversation-list,
.inbox-chat,
.inbox-contact-panel {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 24px;
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  min-width: 0;
}

.inbox-queues,
.inbox-conversation-list,
.inbox-contact-panel {
  padding: 16px;
}

.inbox-panel-title strong {
  color: var(--lh-blue-950, #04204f);
  display: block;
}

.inbox-panel-title span {
  color: var(--lh-muted, #6b7280);
  display: block;
  font-size: 13px;
  margin-top: 3px;
}

.inbox-queue-list,
.inbox-conversation-items {
  display: grid;
  gap: 10px;
  margin-top: 16px;
}

.inbox-queue-list button,
.inbox-conversation-items button {
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  color: #374151;
  cursor: pointer;
  font-weight: 850;
  padding: 12px;
  text-align: left;
}

.inbox-queue-list button.active,
.inbox-conversation-items button.active {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-700, #0a6de8));
  border-color: transparent;
  color: #ffffff;
}

.inbox-search input {
  border: 1px solid #d1d5db;
  border-radius: 16px;
  margin-top: 16px;
  padding: 12px 14px;
  width: 100%;
}

.inbox-conversation-items button {
  display: grid;
  gap: 8px;
  grid-template-columns: minmax(0, 1fr) auto;
  position: relative;
}

.inbox-conversation-items strong,
.inbox-conversation-items span,
.inbox-conversation-items small {
  display: block;
  overflow-wrap: anywhere;
}

.inbox-conversation-items span,
.inbox-conversation-items small {
  color: inherit;
  opacity: 0.78;
}

.inbox-conversation-items em {
  font-style: normal;
  opacity: 0.75;
}

.inbox-conversation-items b {
  align-items: center;
  background: var(--lh-orange-600, #ff7a00);
  border-radius: 999px;
  color: #ffffff;
  display: inline-flex;
  font-size: 12px;
  height: 24px;
  justify-content: center;
  position: absolute;
  right: 10px;
  top: 38px;
  width: 24px;
}

.inbox-chat {
  display: grid;
  grid-template-rows: auto minmax(0, 1fr) auto auto;
  overflow: hidden;
}

.inbox-chat-header {
  align-items: center;
  border-bottom: 1px solid #e5e7eb;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) auto;
  padding: 16px;
}

.inbox-chat-header strong,
.inbox-chat-header span {
  display: block;
}

.inbox-chat-header span {
  color: var(--lh-muted, #6b7280);
  font-size: 13px;
}

.inbox-chat-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: flex-end;
}

.inbox-chat-badges span {
  background: #eff6ff;
  border-radius: 999px;
  color: var(--lh-blue-800, #0757c8);
  font-weight: 900;
  padding: 7px 10px;
}

.inbox-message-area {
  background:
    radial-gradient(circle at top left, rgba(7, 87, 200, 0.08), transparent 32%),
    #f8fafc;
  display: grid;
  gap: 12px;
  overflow: auto;
  padding: 18px;
}

.message-bubble {
  border-radius: 18px;
  max-width: 78%;
  padding: 14px;
}

.message-bubble span {
  display: block;
  font-size: 12px;
  font-weight: 950;
  margin-bottom: 4px;
}

.message-bubble p {
  margin: 0;
}

.message-bubble.inbound {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  justify-self: start;
}

.message-bubble.outbound {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-700, #0a6de8));
  color: #ffffff;
  justify-self: end;
}

.message-bubble.internal {
  background: #fff7ed;
  border: 1px solid #fed7aa;
  color: #9a3412;
  justify-self: center;
}

.inbox-quick-replies {
  border-top: 1px solid #e5e7eb;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 16px;
}

.inbox-quick-replies button {
  background: #eff6ff;
  border: 0;
  border-radius: 999px;
  color: var(--lh-blue-800, #0757c8);
  cursor: pointer;
  flex: 0 0 auto;
  font-weight: 900;
  padding: 10px 12px;
}

.inbox-composer {
  border-top: 1px solid #e5e7eb;
  display: grid;
  gap: 10px;
  grid-template-columns: minmax(0, 1fr) auto;
  padding: 14px;
}

.inbox-composer textarea {
  border: 1px solid #d1d5db;
  border-radius: 18px;
  min-height: 54px;
  padding: 12px 14px;
  resize: vertical;
}

.inbox-composer button,
.closing-card button {
  background: linear-gradient(135deg, var(--lh-orange-700, #f97316), var(--lh-orange-500, #ff9f1c));
  border: 0;
  border-radius: 16px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 12px 18px;
}

.contact-card {
  align-items: center;
  display: grid;
  justify-items: center;
  margin-top: 18px;
  text-align: center;
}

.contact-card img {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 24px;
  height: 78px;
  object-fit: contain;
  padding: 8px;
  width: 78px;
}

.contact-card strong {
  color: var(--lh-blue-950, #04204f);
  margin-top: 10px;
}

.contact-card span {
  color: var(--lh-muted, #6b7280);
  margin-top: 3px;
}

.contact-details,
.closing-card {
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 18px;
  display: grid;
  gap: 8px;
  margin-top: 16px;
  padding: 14px;
}

.contact-details span {
  color: #374151;
  font-weight: 750;
}

.closing-card p {
  color: var(--lh-muted, #6b7280);
  margin: 6px 0;
}

@media (max-width: 1400px) {
  .inbox-workspace {
    grid-template-columns: 180px 300px minmax(0, 1fr);
  }

  .inbox-contact-panel {
    grid-column: 1 / -1;
  }
}

@media (max-width: 1100px) {
  .inbox-hero {
    grid-template-columns: 1fr;
  }

  .inbox-hero-brand {
    justify-self: start;
  }

  .inbox-metrics {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .inbox-workspace {
    grid-template-columns: 1fr;
  }

  .inbox-queues,
  .inbox-conversation-list,
  .inbox-contact-panel {
    min-height: auto;
  }

  .inbox-queue-list {
    display: flex;
    overflow-x: auto;
  }

  .inbox-queue-list button {
    flex: 0 0 auto;
    white-space: nowrap;
  }

  .inbox-chat {
    min-height: 620px;
  }
}

@media (max-width: 680px) {
  .inbox-hero,
  .inbox-metrics article,
  .inbox-queues,
  .inbox-conversation-list,
  .inbox-chat,
  .inbox-contact-panel {
    border-radius: 18px;
  }

  .inbox-metrics {
    grid-template-columns: 1fr;
  }

  .inbox-chat-header {
    grid-template-columns: 1fr;
  }

  .inbox-chat-badges {
    justify-content: flex-start;
  }

  .message-bubble {
    max-width: 94%;
  }

  .inbox-composer {
    grid-template-columns: 1fr;
  }

  .inbox-composer button {
    min-height: 48px;
  }
}
DOC

echo "Validando ausencia de HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML injetado encontrado."
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

echo "Validando credenciais..."

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

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: auditoria nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 56..."

cat > "${DOC_FILE}" <<'DOC'
# Responsive Attendance Center Layout

## Visao geral

Este documento registra a criacao do layout responsivo profissional da central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tela app inbox
- layout responsivo de central de atendimento
- area de filas
- lista de conversas
- area de conversa ativa
- painel lateral do contato
- indicadores de atendimento
- chips de departamento, status e SLA
- respostas rapidas visuais
- nota interna visual
- composicao de mensagem
- card de encerramento com avaliacao
- adaptacao para desktop, tablet e celular

## Observacao

Esta etapa cria a base visual e estrutural da central de atendimento.

A persistencia de departamentos, filas, responsaveis, tags, notas e encerramento com avaliacao sera implementada nas proximas etapas.

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/RESPONSIVE_ATTENDANCE_CENTER_LAYOUT.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- login dominio
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_56_frontend_typecheck.log
- logs/setup_56_frontend_build.log
- logs/setup_56_frontend_docker_build.log
- logs/setup_56_docker_up.log
- logs/setup_56_auth_login_domain.log
- logs/setup_56_domain_inbox_page.log
- logs/setup_56_domain_dashboard.log
- logs/setup_56_domain_audit_page.log
- logs/setup_56.log

## Proxima etapa sugerida

Etapa 57:

    Criar status operacional das conversas
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 56 - Criar layout responsivo profissional da central de atendimento",
    "- [x] Etapa 56 - Criar layout responsivo profissional da central de atendimento\n- [ ] Etapa 57 - Criar status operacional das conversas"
)

text = text.replace(
    "Etapa 56 - Criar layout responsivo profissional da central de atendimento.",
    "Etapa 57 - Criar status operacional das conversas."
)

text = text.replace(
    "Etapa 55 - Aplicar identidade visual com logos e favicon.",
    "Etapa 56 - Criar layout responsivo profissional da central de atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Layout responsivo profissional da central de atendimento criado." not in text:
    text = text.replace(
        "Identidade visual com logos e favicon aplicada.",
        "Identidade visual com logos e favicon aplicada.\n\nLayout responsivo profissional da central de atendimento criado."
    )

if "- docs/RESPONSIVE_ATTENDANCE_CENTER_LAYOUT.md" not in text:
    text = text.replace(
        "- docs/VISUAL_IDENTITY_LOGOS_FAVICON.md",
        "- docs/RESPONSIVE_ATTENDANCE_CENTER_LAYOUT.md\n- docs/VISUAL_IDENTITY_LOGOS_FAVICON.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 55 concluidas",
    "- Etapa 01 ate Etapa 56 concluidas"
)

text = text.replace(
    "- Etapa 56 - Criar layout responsivo profissional da central de atendimento",
    "- Etapa 57 - Criar status operacional das conversas"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 56 - Criar layout responsivo profissional da central de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada a tela app inbox com layout responsivo para filas, conversas, chat ativo, painel do contato, respostas rapidas e base visual para atendimento profissional.
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
Etapa: 56
Acao: Criar layout responsivo profissional da central de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 56 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "${DOMAIN_INBOX_PAGE_URL}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 57 - Criar status operacional das conversas"
