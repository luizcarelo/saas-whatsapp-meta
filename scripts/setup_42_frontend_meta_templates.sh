#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_42.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_42_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_42_frontend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_42_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_42_frontend_docker_up.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_42_auth_login_domain.log"
DOMAIN_ACCOUNTS_LOG="${LOGS_DIR}/setup_42_whatsapp_accounts_domain.log"
DOMAIN_TEMPLATES_LOG="${LOGS_DIR}/setup_42_templates_domain.log"
DOMAIN_CREATE_CONVERSATION_LOG="${LOGS_DIR}/setup_42_conversation_create_domain.log"
DOMAIN_SEND_TEMPLATE_LOG="${LOGS_DIR}/setup_42_template_send_domain.log"
DOMAIN_CONVERSATIONS_PAGE_LOG="${LOGS_DIR}/setup_42_domain_conversations_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_42_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/FRONTEND_META_TEMPLATES.md"

DOMAIN_HOST="bot.lhsolucao.com.br"
DOMAIN_BASE_URL="https://${DOMAIN_HOST}"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ACCOUNTS_URL="${DOMAIN_BASE_URL}/api/v1/whatsapp-accounts"
DOMAIN_CONVERSATIONS_URL="${DOMAIN_BASE_URL}/api/v1/conversations"
DOMAIN_CONVERSATIONS_PAGE_URL="${DOMAIN_BASE_URL}/app/conversations"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Etapa 42: Frontend para envio de templates oficiais da Meta =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/pages/conversations"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/types/conversations.types.ts" \
  "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" \
  "${FRONTEND_DIR}/src/services/conversations.service.ts" \
  "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" \
  "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

if ! command -v node >/dev/null 2>&1; then
  echo "ERRO: node nao encontrado."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERRO: npm nao encontrado."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERRO: curl nao encontrado."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ]; then
  echo "ERRO: email admin nao encontrado."
  exit 1
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: senha admin nao encontrada."
  exit 1
fi

echo "Validando backend de templates via dominio antes do frontend..."

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

if ! grep -q "access_token" "${DOMAIN_LOGIN_LOG}"; then
  echo "ERRO: login dominio nao retornou access_token."
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

DOMAIN_ACCOUNTS_STATUS="$(curl -L -s -o "${DOMAIN_ACCOUNTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_STATUS}" != "200" ]; then
  echo "ERRO: listagem de contas dominio falhou. Status ${DOMAIN_ACCOUNTS_STATUS}"
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

ACCOUNT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const accounts=(data.data&&data.data.accounts)||[]; const found=accounts.find((account)=>account.status==='active' && account.phoneNumberId==='1235882016268785') || accounts.find((account)=>account.status==='active' && /^[0-9]+$/.test(account.phoneNumberId)); if(!found){process.exit(2)} console.log(found.id)" "${DOMAIN_ACCOUNTS_LOG}" || true)"

if [ -z "${ACCOUNT_ID}" ]; then
  echo "ERRO: nenhuma conta WhatsApp ativa real encontrada."
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

DOMAIN_TEMPLATES_STATUS="$(curl -L -s -o "${DOMAIN_TEMPLATES_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}/${ACCOUNT_ID}/templates" || true)"

if [ "${DOMAIN_TEMPLATES_STATUS}" != "200" ] && [ "${DOMAIN_TEMPLATES_STATUS}" != "201" ]; then
  echo "ERRO: listagem de templates dominio falhou. Status ${DOMAIN_TEMPLATES_STATUS}"
  cat "${DOMAIN_TEMPLATES_LOG}"
  exit 1
fi

if ! grep -q "hello_world" "${DOMAIN_TEMPLATES_LOG}"; then
  echo "ERRO: template hello_world nao encontrado na resposta."
  cat "${DOMAIN_TEMPLATES_LOG}"
  exit 1
fi

TEST_RECIPIENT_PHONE="$(grep '^META_TEST_RECIPIENT_PHONE=' "${BASE_DIR}/.env" | head -n 1 | cut -d '=' -f 2- || true)"

if [ -z "${TEST_RECIPIENT_PHONE}" ]; then
  TEST_RECIPIENT_PHONE="5521999940266"
fi

TEST_RECIPIENT_PHONE="$(node -e "console.log(String(process.argv[1] || '').replace(/[^0-9]/g,''))" "${TEST_RECIPIENT_PHONE}")"

CONVERSATION_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Frontend Template Etapa 42', phone:process.argv[1], initialMessage:'Conversa criada para teste frontend template etapa 42'}))" "${TEST_RECIPIENT_PHONE}")"

DOMAIN_CREATE_CONVERSATION_STATUS="$(curl -L -s -o "${DOMAIN_CREATE_CONVERSATION_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CONVERSATION_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_URL}" || true)"

if [ "${DOMAIN_CREATE_CONVERSATION_STATUS}" != "200" ] && [ "${DOMAIN_CREATE_CONVERSATION_STATUS}" != "201" ]; then
  echo "ERRO: criacao de conversa dominio falhou. Status ${DOMAIN_CREATE_CONVERSATION_STATUS}"
  cat "${DOMAIN_CREATE_CONVERSATION_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.conversation.id)" "${DOMAIN_CREATE_CONVERSATION_LOG}")"

TEMPLATE_PAYLOAD="$(node -e "console.log(JSON.stringify({templateName:'hello_world', languageCode:'en_US'}))")"

DOMAIN_SEND_TEMPLATE_STATUS="$(curl -L -s -o "${DOMAIN_SEND_TEMPLATE_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${TEMPLATE_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_URL}/${CONVERSATION_ID}/templates" || true)"

if [ "${DOMAIN_SEND_TEMPLATE_STATUS}" != "200" ] && [ "${DOMAIN_SEND_TEMPLATE_STATUS}" != "201" ]; then
  echo "ERRO: envio de template dominio falhou. Status ${DOMAIN_SEND_TEMPLATE_STATUS}"
  cat "${DOMAIN_SEND_TEMPLATE_LOG}"
  exit 1
fi

if ! grep -q '"status":"sent"' "${DOMAIN_SEND_TEMPLATE_LOG}"; then
  echo "ERRO: envio de template nao retornou status sent."
  cat "${DOMAIN_SEND_TEMPLATE_LOG}"
  exit 1
fi

echo "Atualizando types de conversations..."

cat > "${FRONTEND_DIR}/src/types/conversations.types.ts" <<'DOC'
export type ConversationContact = {
  id: string;
  name: string | null;
  phone: string;
  email: string | null;
};

export type MessageStatus =
  | 'pending'
  | 'received'
  | 'sent'
  | 'delivered'
  | 'read'
  | 'failed';

export type ConversationLastMessage = {
  id: string;
  direction: string;
  body: string | null;
  createdAt: string;
};

export type ConversationMessage = {
  id: string;
  direction: string;
  type: string;
  body: string | null;
  status: MessageStatus | string;
  providerMessageId?: string | null;
  sentAt?: string | null;
  metadata?: unknown;
  createdAt: string;
};

export type ConversationItem = {
  id: string;
  tenantId: string;
  contact: ConversationContact;
  status: string;
  channel: string;
  lastMessageAt: string | null;
  createdAt: string;
  updatedAt: string;
  lastMessage: ConversationLastMessage | null;
};

export type ConversationDetail = ConversationItem & {
  messages: ConversationMessage[];
};

export type ConversationListData = {
  conversations: ConversationItem[];
  total: number;
};

export type ConversationData = {
  conversation: ConversationDetail;
};

export type ConversationMessageData = {
  message: ConversationMessage;
};

export type ConversationFormData = {
  name: string;
  phone: string;
  initialMessage: string;
};

export type MessageStatusSummary = {
  pending: number;
  received: number;
  sent: number;
  delivered: number;
  read: number;
  failed: number;
};

export type SendTemplateFormData = {
  templateName: string;
  languageCode: string;
};
DOC

echo "Atualizando types de whatsapp accounts..."

cat > "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" <<'DOC'
export type WhatsappAccountItem = {
  id: string;
  tenantId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type WhatsappAccountListData = {
  accounts: WhatsappAccountItem[];
  total: number;
};

export type WhatsappAccountData = {
  account: WhatsappAccountItem;
};

export type WhatsappAccountDeleteData = {
  deleted: true;
  id: string;
};

export type WhatsappAccountFormData = {
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string;
  accessToken: string;
  status: string;
};

export type MetaTemplateItem = {
  id: string;
  name: string;
  language: string;
  status: string;
  category: string;
};

export type MetaTemplatesEnvelope = {
  data?: MetaTemplateItem[];
  paging?: unknown;
};

export type WhatsappTemplatesData = {
  account: WhatsappAccountItem;
  templates: MetaTemplatesEnvelope;
};
DOC

echo "Atualizando conversations.service.ts..."

cat > "${FRONTEND_DIR}/src/services/conversations.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  ConversationData,
  ConversationFormData,
  ConversationListData,
  ConversationMessageData,
  SendTemplateFormData
} from '../types/conversations.types';

export async function listConversationsRequest(token: string, search = '') {
  const query = search ? '?search=' + encodeURIComponent(search) : '';

  return apiRequest<ConversationListData>('/conversations' + query, {
    method: 'GET',
    token
  });
}

export async function createConversationRequest(token: string, data: ConversationFormData) {
  return apiRequest<ConversationData>('/conversations', {
    method: 'POST',
    token,
    body: {
      name: data.name,
      phone: data.phone,
      initialMessage: data.initialMessage
    }
  });
}

export async function getConversationRequest(token: string, conversationId: string) {
  return apiRequest<ConversationData>('/conversations/' + conversationId, {
    method: 'GET',
    token
  });
}

export async function createConversationMessageRequest(
  token: string,
  conversationId: string,
  body: string
) {
  return apiRequest<ConversationMessageData>('/conversations/' + conversationId + '/messages', {
    method: 'POST',
    token,
    body: {
      body
    }
  });
}

export async function sendConversationTemplateRequest(
  token: string,
  conversationId: string,
  data: SendTemplateFormData
) {
  return apiRequest<ConversationMessageData>('/conversations/' + conversationId + '/templates', {
    method: 'POST',
    token,
    body: {
      templateName: data.templateName,
      languageCode: data.languageCode
    }
  });
}

export async function closeConversationRequest(token: string, conversationId: string) {
  return apiRequest<ConversationData>('/conversations/' + conversationId + '/close', {
    method: 'PATCH',
    token
  });
}
DOC

echo "Atualizando whatsapp-accounts.service.ts..."

cat > "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  WhatsappAccountData,
  WhatsappAccountDeleteData,
  WhatsappAccountFormData,
  WhatsappAccountListData,
  WhatsappTemplatesData
} from '../types/whatsapp-accounts.types';

export async function listWhatsappAccountsRequest(token: string, search = '') {
  const query = search ? '?search=' + encodeURIComponent(search) : '';

  return apiRequest<WhatsappAccountListData>('/whatsapp-accounts' + query, {
    method: 'GET',
    token
  });
}

export async function listWhatsappTemplatesRequest(token: string, accountId: string) {
  return apiRequest<WhatsappTemplatesData>('/whatsapp-accounts/' + accountId + '/templates', {
    method: 'GET',
    token
  });
}

export async function createWhatsappAccountRequest(
  token: string,
  data: WhatsappAccountFormData
) {
  return apiRequest<WhatsappAccountData>('/whatsapp-accounts', {
    method: 'POST',
    token,
    body: {
      wabaId: data.wabaId,
      phoneNumberId: data.phoneNumberId,
      displayPhoneNumber: data.displayPhoneNumber,
      verifiedName: data.verifiedName,
      accessToken: data.accessToken,
      status: data.status
    }
  });
}

export async function deleteWhatsappAccountRequest(token: string, accountId: string) {
  return apiRequest<WhatsappAccountDeleteData>('/whatsapp-accounts/' + accountId, {
    method: 'DELETE',
    token
  });
}
DOC

echo "Atualizando ConversationsPage.tsx com envio de templates..."

cat > "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" <<'DOC'
import { FormEvent, useEffect, useMemo, useState } from 'react';
import {
  closeConversationRequest,
  createConversationMessageRequest,
  createConversationRequest,
  getConversationRequest,
  listConversationsRequest,
  sendConversationTemplateRequest
} from '../../services/conversations.service';
import {
  listWhatsappAccountsRequest,
  listWhatsappTemplatesRequest
} from '../../services/whatsapp-accounts.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  ConversationDetail,
  ConversationFormData,
  ConversationItem,
  ConversationMessage,
  MessageStatusSummary,
  SendTemplateFormData
} from '../../types/conversations.types';
import type { MetaTemplateItem } from '../../types/whatsapp-accounts.types';

const initialForm: ConversationFormData = {
  name: '',
  phone: '',
  initialMessage: ''
};

const initialTemplateForm: SendTemplateFormData = {
  templateName: 'hello_world',
  languageCode: 'en_US'
};

const conversationStatusLabel: Record<string, string> = {
  open: 'Aberta',
  pending: 'Pendente',
  bot: 'Bot',
  human: 'Humano',
  resolved: 'Resolvida',
  closed: 'Fechada'
};

const messageStatusLabel: Record<string, string> = {
  pending: 'Pendente',
  received: 'Recebida',
  sent: 'Enviada',
  delivered: 'Entregue',
  read: 'Lida',
  failed: 'Falhou'
};

const emptyStatusSummary: MessageStatusSummary = {
  pending: 0,
  received: 0,
  sent: 0,
  delivered: 0,
  read: 0,
  failed: 0
};

function getMessageStatusLabel(status: string) {
  return messageStatusLabel[status] || status;
}

function getMessageStatusClass(status: string) {
  if (status === 'read') {
    return 'status-read';
  }

  if (status === 'delivered') {
    return 'status-delivered';
  }

  if (status === 'sent') {
    return 'status-sent';
  }

  if (status === 'received') {
    return 'status-received';
  }

  if (status === 'failed') {
    return 'status-failed';
  }

  return 'status-pending';
}

function summarizeMessageStatuses(messages: ConversationMessage[]): MessageStatusSummary {
  return messages.reduce<MessageStatusSummary>((summary, message) => {
    if (message.status === 'received') {
      return {
        ...summary,
        received: summary.received + 1
      };
    }

    if (message.status === 'sent') {
      return {
        ...summary,
        sent: summary.sent + 1
      };
    }

    if (message.status === 'delivered') {
      return {
        ...summary,
        delivered: summary.delivered + 1
      };
    }

    if (message.status === 'read') {
      return {
        ...summary,
        read: summary.read + 1
      };
    }

    if (message.status === 'failed') {
      return {
        ...summary,
        failed: summary.failed + 1
      };
    }

    return {
      ...summary,
      pending: summary.pending + 1
    };
  }, emptyStatusSummary);
}

function templateOptionValue(template: MetaTemplateItem) {
  return template.name + '|' + template.language;
}

function templateLabel(template: MetaTemplateItem) {
  return template.name + ' - ' + template.language + ' - ' + template.status;
}

export function ConversationsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [conversations, setConversations] = useState<ConversationItem[]>([]);
  const [selectedConversation, setSelectedConversation] = useState<ConversationDetail | null>(null);
  const [templates, setTemplates] = useState<MetaTemplateItem[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState<ConversationFormData>(initialForm);
  const [templateForm, setTemplateForm] = useState<SendTemplateFormData>(initialTemplateForm);
  const [reply, setReply] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [sendingTemplate, setSendingTemplate] = useState(false);
  const [message, setMessage] = useState('');
  const [templateMessage, setTemplateMessage] = useState('');

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadConversations(currentSearch = search) {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);

    try {
      const response = await listConversationsRequest(token, currentSearch);

      if (response.success) {
        setConversations(response.data.conversations);
        setTotal(response.data.total);

        if (!selectedConversation && response.data.conversations.length > 0) {
          await loadConversation(response.data.conversations[0].id);
        }
      }
    } finally {
      setLoading(false);
    }
  }

  async function loadConversation(conversationId: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    const response = await getConversationRequest(token, conversationId);

    if (response.success) {
      setSelectedConversation(response.data.conversation);
    }
  }

  async function loadTemplates() {
    const token = getToken();

    if (!token) {
      return;
    }

    const accountsResponse = await listWhatsappAccountsRequest(token);

    if (!accountsResponse.success) {
      return;
    }

    const activeAccounts = accountsResponse.data.accounts.filter((account) => account.status === 'active');
    const preferred = activeAccounts.find((account) => account.phoneNumberId === '1235882016268785')
      || activeAccounts.find((account) => /^[0-9]+$/.test(account.phoneNumberId))
      || activeAccounts[0];

    if (!preferred) {
      return;
    }

    const templatesResponse = await listWhatsappTemplatesRequest(token, preferred.id);

    if (!templatesResponse.success) {
      return;
    }

    const items = templatesResponse.data.templates.data || [];
    const approved = items.filter((item) => item.status === 'APPROVED');

    setTemplates(approved);

    const helloWorld = approved.find((item) => item.name === 'hello_world') || approved[0];

    if (helloWorld) {
      setTemplateForm({
        templateName: helloWorld.name,
        languageCode: helloWorld.language
      });
    }
  }

  useEffect(() => {
    void loadConversations('');
    void loadTemplates();
  }, []);

  const conversationMetrics = useMemo(() => {
    return {
      open: conversations.filter((conversation) => conversation.status === 'open').length,
      human: conversations.filter((conversation) => conversation.status === 'human').length,
      closed: conversations.filter((conversation) => conversation.status === 'closed').length
    };
  }, [conversations]);

  const messageStatusSummary = useMemo(() => {
    if (!selectedConversation) {
      return emptyStatusSummary;
    }

    return summarizeMessageStatuses(selectedConversation.messages);
  }, [selectedConversation]);

  async function handleSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await loadConversations(search);
  }

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token) {
      return;
    }

    setSaving(true);
    setMessage('');

    try {
      const response = await createConversationRequest(token, form);

      if (!response.success) {
        setMessage(response.error.message || 'Nao foi possivel criar a conversa');
        return;
      }

      setForm(initialForm);
      setSelectedConversation(response.data.conversation);
      setMessage('Conversa criada com sucesso');
      await loadConversations(search);
    } catch (_error) {
      setMessage('Nao foi possivel conectar ao servidor');
    } finally {
      setSaving(false);
    }
  }

  async function handleReply(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !selectedConversation || !reply.trim()) {
      return;
    }

    const response = await createConversationMessageRequest(
      token,
      selectedConversation.id,
      reply
    );

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel enviar a mensagem');
      return;
    }

    setReply('');
    await loadConversation(selectedConversation.id);
    await loadConversations(search);
  }

  async function handleSendTemplate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !selectedConversation || !templateForm.templateName) {
      return;
    }

    setSendingTemplate(true);
    setTemplateMessage('');

    try {
      const response = await sendConversationTemplateRequest(
        token,
        selectedConversation.id,
        templateForm
      );

      if (!response.success) {
        setTemplateMessage(response.error.message || 'Nao foi possivel enviar o template');
        return;
      }

      setTemplateMessage('Template enviado com status ' + response.data.message.status);
      await loadConversation(selectedConversation.id);
      await loadConversations(search);
    } catch (_error) {
      setTemplateMessage('Nao foi possivel conectar ao servidor');
    } finally {
      setSendingTemplate(false);
    }
  }

  async function handleCloseConversation() {
    const token = getToken();

    if (!token || !selectedConversation) {
      return;
    }

    const response = await closeConversationRequest(token, selectedConversation.id);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel fechar a conversa');
      return;
    }

    setSelectedConversation(response.data.conversation);
    setMessage('Conversa fechada com sucesso');
    await loadConversations(search);
  }

  function handleTemplateChange(value: string) {
    const parts = value.split('|');

    setTemplateForm({
      templateName: parts[0] || 'hello_world',
      languageCode: parts[1] || 'en_US'
    });
  }

  return (
    <section>
      <div className="page-heading">
        <span>Atendimento</span>
        <h1>Conversas</h1>
        <p>Caixa de entrada integrada ao backend real com mensagens e templates da Meta.</p>
      </div>

      <div className="conversation-metrics">
        <article className="metric-card">
          <span>Abertas</span>
          <strong>{conversationMetrics.open}</strong>
          <p>Conversas aguardando atendimento.</p>
        </article>

        <article className="metric-card">
          <span>Em atendimento</span>
          <strong>{conversationMetrics.human}</strong>
          <p>Conversas com resposta humana.</p>
        </article>

        <article className="metric-card">
          <span>Fechadas</span>
          <strong>{conversationMetrics.closed}</strong>
          <p>Conversas encerradas.</p>
        </article>
      </div>

      <div className="message-status-summary">
        <article>
          <span className="message-status-badge status-pending">Pendente</span>
          <strong>{messageStatusSummary.pending}</strong>
        </article>

        <article>
          <span className="message-status-badge status-received">Recebida</span>
          <strong>{messageStatusSummary.received}</strong>
        </article>

        <article>
          <span className="message-status-badge status-sent">Enviada</span>
          <strong>{messageStatusSummary.sent}</strong>
        </article>

        <article>
          <span className="message-status-badge status-delivered">Entregue</span>
          <strong>{messageStatusSummary.delivered}</strong>
        </article>

        <article>
          <span className="message-status-badge status-read">Lida</span>
          <strong>{messageStatusSummary.read}</strong>
        </article>

        <article>
          <span className="message-status-badge status-failed">Falhou</span>
          <strong>{messageStatusSummary.failed}</strong>
        </article>
      </div>

      <div className="conversations-actions-panel">
        <form className="conversation-create-form" onSubmit={handleCreate}>
          <input
            onChange={(event) => setForm({ ...form, name: event.target.value })}
            placeholder="Nome do contato"
            value={form.name}
          />

          <input
            onChange={(event) => setForm({ ...form, phone: event.target.value })}
            placeholder="Telefone com DDI"
            required
            value={form.phone}
          />

          <input
            onChange={(event) => setForm({ ...form, initialMessage: event.target.value })}
            placeholder="Mensagem inicial"
            value={form.initialMessage}
          />

          <button disabled={saving} type="submit">
            {saving ? 'Criando...' : 'Criar conversa'}
          </button>
        </form>

        {message ? <div className="form-message">{message}</div> : null}
      </div>

      <div className="conversations-layout">
        <aside className="conversation-list-panel">
          <div className="conversation-list-header">
            <h2>Caixa de entrada</h2>
            <p>{total} conversas</p>
          </div>

          <form className="conversation-search-form" onSubmit={handleSearch}>
            <input
              className="conversation-search"
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Buscar conversa"
              value={search}
            />

            <button type="submit">
              Buscar
            </button>
          </form>

          {loading ? (
            <div className="conversation-empty">
              Carregando conversas...
            </div>
          ) : null}

          {!loading && conversations.length === 0 ? (
            <div className="conversation-empty">
              Nenhuma conversa encontrada.
            </div>
          ) : null}

          <div className="conversation-list">
            {conversations.map((conversation) => (
              <button
                className={
                  selectedConversation?.id === conversation.id
                    ? 'conversation-preview active'
                    : 'conversation-preview'
                }
                key={conversation.id}
                onClick={() => void loadConversation(conversation.id)}
                type="button"
              >
                <div>
                  <strong>{conversation.contact.name || 'Sem nome'}</strong>
                  <span>{conversation.contact.phone}</span>
                  <p>{conversation.lastMessage?.body || 'Sem mensagens'}</p>
                </div>

                <div className="conversation-preview-meta">
                  <small>{conversation.lastMessageAt || 'Sem data'}</small>
                  <em>{conversationStatusLabel[conversation.status] || conversation.status}</em>
                </div>
              </button>
            ))}
          </div>
        </aside>

        <section className="conversation-thread-panel">
          {selectedConversation ? (
            <>
              <header className="thread-header">
                <div>
                  <h2>{selectedConversation.contact.name || 'Sem nome'}</h2>
                  <p>{selectedConversation.contact.phone}</p>
                </div>

                <div className="thread-header-actions">
                  <span className="thread-status">
                    {conversationStatusLabel[selectedConversation.status] || selectedConversation.status}
                  </span>

                  <button onClick={() => void handleCloseConversation()} type="button">
                    Fechar
                  </button>
                </div>
              </header>

              <div className="thread-status-legend">
                <span className="message-status-badge status-pending">Pendente</span>
                <span className="message-status-badge status-received">Recebida</span>
                <span className="message-status-badge status-sent">Enviada</span>
                <span className="message-status-badge status-delivered">Entregue</span>
                <span className="message-status-badge status-read">Lida</span>
                <span className="message-status-badge status-failed">Falhou</span>
              </div>

              <form className="template-composer" onSubmit={handleSendTemplate}>
                <div>
                  <strong>Template oficial da Meta</strong>
                  <p>Envie templates aprovados como hello_world.</p>
                </div>

                <select
                  onChange={(event) => handleTemplateChange(event.target.value)}
                  value={templateForm.templateName + '|' + templateForm.languageCode}
                >
                  {templates.length === 0 ? (
                    <option value="hello_world|en_US">
                      hello_world - en_US
                    </option>
                  ) : null}

                  {templates.map((template) => (
                    <option key={template.id} value={templateOptionValue(template)}>
                      {templateLabel(template)}
                    </option>
                  ))}
                </select>

                <button disabled={sendingTemplate} type="submit">
                  {sendingTemplate ? 'Enviando...' : 'Enviar template'}
                </button>

                {templateMessage ? <span>{templateMessage}</span> : null}
              </form>

              <div className="thread-messages">
                {selectedConversation.messages.length === 0 ? (
                  <div className="conversation-empty">
                    Nenhuma mensagem nesta conversa.
                  </div>
                ) : null}

                {selectedConversation.messages.map((item) => (
                  <article
                    className={
                      item.direction === 'outbound'
                        ? 'thread-message outbound'
                        : 'thread-message inbound'
                    }
                    key={item.id}
                  >
                    <p>{item.body}</p>

                    <footer className="thread-message-footer">
                      <span>{item.createdAt}</span>
                      <span className={'message-status-badge ' + getMessageStatusClass(item.status)}>
                        {getMessageStatusLabel(item.status)}
                      </span>
                    </footer>
                  </article>
                ))}
              </div>

              <form className="thread-composer" onSubmit={handleReply}>
                <input
                  onChange={(event) => setReply(event.target.value)}
                  placeholder="Digite uma resposta"
                  value={reply}
                />

                <button type="submit">
                  Enviar
                </button>
              </form>
            </>
          ) : (
            <div className="conversation-empty conversation-empty-center">
              Selecione uma conversa para visualizar as mensagens.
            </div>
          )}
        </section>
      </div>
    </section>
  );
}
DOC

echo "Adicionando estilos para templates..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.template-composer {
  align-items: center;
  background: #fff7ed;
  border-bottom: 1px solid #fed7aa;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(180px, 1fr) minmax(220px, 1.4fr) auto;
  padding: 14px 18px;
}

.template-composer strong {
  color: #9a3412;
  display: block;
}

.template-composer p {
  color: #9a3412;
  font-size: 13px;
  margin: 4px 0 0;
}

.template-composer select {
  border: 1px solid #fdba74;
  border-radius: 14px;
  padding: 12px 14px;
}

.template-composer select:focus {
  border-color: #ea580c;
  box-shadow: 0 0 0 4px rgba(234, 88, 12, 0.14);
  outline: none;
}

.template-composer button {
  background: #ea580c;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 16px;
}

.template-composer span {
  color: #9a3412;
  font-size: 13px;
  font-weight: 800;
  grid-column: 1 / -1;
}

@media (max-width: 900px) {
  .template-composer {
    grid-template-columns: 1fr;
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/conversations.types.ts" \
  "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" \
  "${FRONTEND_DIR}/src/services/conversations.service.ts" \
  "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" \
  "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML indevido encontrado."
  exit 1
fi

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_BUILD_LOG}"

echo "Subindo frontend e proxy..."

docker compose up -d frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

sleep 8

echo "Testando rota conversations..."

DOMAIN_CONVERSATIONS_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_CONVERSATIONS_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_CONVERSATIONS_PAGE_URL}" || true)"

if [ "${DOMAIN_CONVERSATIONS_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: rota conversations nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando rota dashboard..."

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: rota dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 42..."

cat > "${DOC_FILE}" <<'DOC'
# Frontend Meta Templates

## Visao geral

Este documento registra o frontend para envio de templates oficiais da Meta.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- carregar templates oficiais da conta WhatsApp ativa
- exibir templates aprovados na tela de conversas
- selecionar template por nome e idioma
- enviar template para a conversa selecionada
- exibir status do envio como sent ou failed
- atualizar a conversa apos envio do template

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/conversations.types.ts
- apps/frontend/src/types/whatsapp-accounts.types.ts
- apps/frontend/src/services/conversations.service.ts
- apps/frontend/src/services/whatsapp-accounts.service.ts
- apps/frontend/src/pages/conversations/ConversationsPage.tsx
- apps/frontend/src/styles.css
- docs/FRONTEND_META_TEMPLATES.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- login via dominio
- listagem de contas WhatsApp via dominio
- listagem de templates via dominio
- criacao de conversa via dominio
- envio de template via dominio
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- teste da rota conversations
- teste da rota dashboard

## Rotas

Rotas:

- app conversations
- app dashboard

## Observacoes

A tela de conversas passa a permitir envio de templates oficiais aprovados pela Meta.

## Proxima etapa sugerida

Etapa 43:

    Criar painel de configuracao operacional da conta Meta
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Fase 01 - Documentacao inicial

- [x] Etapa 01 - Preparacao do ambiente de documentacao
- [x] Etapa 02 - Criacao do README principal
- [x] Etapa 03 - Documentacao de arquitetura
- [x] Etapa 04 - Documentacao do banco de dados
- [x] Etapa 05 - Documentacao da API
- [x] Etapa 06 - Documentacao de seguranca
- [x] Etapa 07 - Documentacao de webhooks da Meta
- [x] Etapa 08 - Documentacao do frontend
- [x] Etapa 09 - Documentacao do backend
- [x] Etapa 10 - Documentacao de deploy
- [x] Etapa 11 - Manifesto final e validacao

## Fase 02 - Estrutura real do projeto

- [x] Etapa 12 - Estrutura de pastas do monorepo
- [x] Etapa 13 - Arquivos base do backend
- [x] Etapa 14 - Arquivos base do frontend
- [x] Etapa 15 - Docker Compose inicial
- [x] Etapa 16 - Arquivo env example
- [x] Etapa 17 - Validacao do ambiente inicial
- [x] Etapa 18 - Instalacao e validacao de dependencias

## Fase 03 - Build e execucao inicial com Docker

- [x] Etapa 19 - Ajustar Dockerfiles e validar build dos containers
- [x] Etapa 20A - Auditoria e backup do Nginx
- [x] Etapa 20B - Configurar Nginx para bot.lhsolucao.com.br
- [x] Etapa 20C - Subir containers e testar dominio

## Fase 04 - Backend real inicial

- [x] Etapa 21 - Health, configuracao e database base
- [x] Etapa 22 - ORM e conexao real com PostgreSQL
- [x] Etapa 23 - Schema inicial do banco com Prisma
- [x] Etapa 24 - Seed inicial de tenant, admin, roles e permissoes
- [x] Etapa 25 - Auth inicial com login real

## Fase 05 - Frontend integrado inicial

- [x] Etapa 26 - Frontend login integrado
- [x] Etapa 27 - Protecao visual de rotas e layout base

## Fase 06 - Usuarios e perfil

- [x] Etapa 28 - Modulo backend de usuarios
- [x] Etapa 29 - Frontend com perfil detalhado

## Fase 07 - Contatos

- [x] Etapa 30 - Modulo backend de contatos
- [x] Etapa 31 - Frontend de contatos integrado

## Fase 08 - Conversas

- [x] Etapa 32 - Frontend de conversas com layout inicial
- [x] Etapa 33 - Modulo backend de conversas
- [x] Etapa 34 - Frontend de conversas integrado ao backend

## Fase 09 - WhatsApp

- [x] Etapa 35 - Modulo backend de WhatsApp Accounts
- [x] Etapa 36 - Frontend de WhatsApp Accounts integrado
- [x] Etapa 37 - Modulo backend de webhooks da Meta
- [x] Etapa 38 - Validacao de assinatura dos webhooks da Meta
- [x] Etapa 39 - Processamento de status no frontend
- [x] Etapa 40 - Envio real pela API oficial da Meta
- [x] Etapa 41 - Templates oficiais da Meta
- [x] Etapa 42 - Frontend para templates oficiais
- [ ] Etapa 43 - Painel de configuracao operacional da conta Meta

## Ultima etapa executada

Etapa 42 - Frontend para envio de templates oficiais.

## Proxima etapa sugerida

Etapa 43 - Criar painel de configuracao operacional da conta Meta.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto do Projeto

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

Estrutura real do monorepo criada.

Backend base criado.

Frontend base criado.

Docker Compose inicial criado.

Env example criado.

Ambiente inicial validado.

Dependencias base instaladas e validadas.

Dockerfiles ajustados e builds validados.

Dominio bot.lhsolucao.com.br configurado e testado.

Backend real inicial iniciado.

Prisma configurado com conexao real ao PostgreSQL.

Schema inicial do banco criado.

Seed inicial criado.

Auth inicial com login real criado.

Frontend login integrado criado.

Layout base e protecao visual de rotas criados.

Modulo backend de usuarios criado.

Frontend com perfil detalhado criado.

Modulo backend de contatos criado.

Frontend de contatos integrado criado.

Frontend de conversas com layout inicial criado.

Modulo backend de conversas criado.

Frontend de conversas integrado ao backend criado.

Modulo backend de WhatsApp Accounts criado.

Frontend de WhatsApp Accounts integrado criado.

Modulo backend de webhooks da Meta criado.

Validacao de assinatura dos webhooks da Meta criada.

Processamento de status de mensagens no frontend criado.

Envio real de mensagens pela API oficial da Meta criado.

Suporte a templates oficiais da Meta criado.

Frontend para envio de templates oficiais criado.

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml
- .env.example
- .env
- .dockerignore

## Documentos tecnicos

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md
- docs/VALIDACAO_FINAL.md
- docs/ESTRUTURA_PROJETO.md
- docs/BACKEND_BASE.md
- docs/FRONTEND_BASE.md
- docs/DOCKER_COMPOSE_BASE.md
- docs/ENV_EXAMPLE.md
- docs/VALIDACAO_AMBIENTE.md
- docs/DEPENDENCIAS_BASE.md
- docs/DOCKER_BUILD.md
- docs/NGINX_BOT_LHSOLUCAO.md
- docs/EXECUCAO_INICIAL_DOMINIO.md
- docs/BACKEND_HEALTH_CONFIG_DATABASE.md
- docs/BACKEND_PRISMA_POSTGRES.md
- docs/PRISMA_SCHEMA_INICIAL.md
- docs/SEED_INICIAL.md
- docs/AUTH_LOGIN_REAL.md
- docs/FRONTEND_LOGIN_INTEGRADO.md
- docs/FRONTEND_LAYOUT_PROTECAO_ROTAS.md
- docs/BACKEND_USERS_PROFILE.md
- docs/FRONTEND_PROFILE_DETALHADO.md
- docs/BACKEND_CONTACTS.md
- docs/FRONTEND_CONTACTS.md
- docs/FRONTEND_CONVERSATIONS_LAYOUT.md
- docs/BACKEND_CONVERSATIONS.md
- docs/FRONTEND_CONVERSATIONS_INTEGRADO.md
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- docs/FRONTEND_WHATSAPP_ACCOUNTS.md
- docs/BACKEND_META_WEBHOOKS.md
- docs/BACKEND_META_WEBHOOK_SIGNATURE.md
- docs/FRONTEND_MESSAGE_STATUS.md
- docs/BACKEND_META_SEND_MESSAGES.md
- docs/BACKEND_META_TEMPLATES.md
- docs/FRONTEND_META_TEMPLATES.md

## Etapas concluidas

- Etapa 01 ate Etapa 42 concluidas

## Proxima etapa

- Etapa 43 - Painel de configuracao operacional da conta Meta
DOC

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
Etapa: 42
Acao: Frontend para envio de templates oficiais da Meta
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Accounts status: ${DOMAIN_ACCOUNTS_STATUS}
Templates status: ${DOMAIN_TEMPLATES_STATUS}
Create conversation status: ${DOMAIN_CREATE_CONVERSATION_STATUS}
Send template status: ${DOMAIN_SEND_TEMPLATE_STATUS}
Conversations page status: ${DOMAIN_CONVERSATIONS_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 42 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/conversations"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 43 - Criar painel de configuracao operacional da conta Meta"
