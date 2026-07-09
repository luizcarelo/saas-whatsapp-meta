#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_34.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_34_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_34_frontend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_34_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_34_frontend_docker_up.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_34_auth_login_domain.log"
DOMAIN_CONVERSATIONS_LIST_API_LOG="${LOGS_DIR}/setup_34_conversations_list_domain.log"
DOMAIN_CONVERSATIONS_CREATE_API_LOG="${LOGS_DIR}/setup_34_conversations_create_domain.log"
DOMAIN_CONVERSATIONS_MESSAGE_API_LOG="${LOGS_DIR}/setup_34_conversations_message_domain.log"
DOMAIN_CONVERSATIONS_PAGE_LOG="${LOGS_DIR}/setup_34_domain_conversations_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_34_domain_dashboard.log"
DOC_FILE="${DOCS_DIR}/FRONTEND_CONVERSATIONS_INTEGRADO.md"

DOMAIN_HOST="bot.lhsolucao.com.br"
DOMAIN_BASE_URL="https://${DOMAIN_HOST}"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_CONVERSATIONS_API_URL="${DOMAIN_BASE_URL}/api/v1/conversations"
DOMAIN_CONVERSATIONS_PAGE_URL="${DOMAIN_BASE_URL}/app/conversations"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Etapa 34: Frontend de conversas integrado ao backend =="

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
  "${FRONTEND_DIR}/src/services/conversations.service.ts" \
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

echo "Validando API de conversas via dominio antes do frontend..."

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

DOMAIN_CONVERSATIONS_LIST_API_STATUS="$(curl -L -s -o "${DOMAIN_CONVERSATIONS_LIST_API_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_CONVERSATIONS_API_URL}" || true)"

if [ "${DOMAIN_CONVERSATIONS_LIST_API_STATUS}" != "200" ]; then
  echo "ERRO: listagem de conversas dominio falhou. Status ${DOMAIN_CONVERSATIONS_LIST_API_STATUS}"
  cat "${DOMAIN_CONVERSATIONS_LIST_API_LOG}"
  exit 1
fi

if ! grep -q "conversations" "${DOMAIN_CONVERSATIONS_LIST_API_LOG}"; then
  echo "ERRO: listagem de conversas nao retornou conversations."
  cat "${DOMAIN_CONVERSATIONS_LIST_API_LOG}"
  exit 1
fi

CONVERSATION_PHONE="5521444${STAMP}"
CONVERSATION_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Conversa Frontend Etapa 34', phone:process.argv[1], initialMessage:'Mensagem frontend da Etapa 34'}))" "${CONVERSATION_PHONE}")"

DOMAIN_CONVERSATIONS_CREATE_API_STATUS="$(curl -L -s -o "${DOMAIN_CONVERSATIONS_CREATE_API_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CONVERSATION_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_API_URL}" || true)"

if [ "${DOMAIN_CONVERSATIONS_CREATE_API_STATUS}" != "200" ] && [ "${DOMAIN_CONVERSATIONS_CREATE_API_STATUS}" != "201" ]; then
  echo "ERRO: criacao de conversa dominio falhou. Status ${DOMAIN_CONVERSATIONS_CREATE_API_STATUS}"
  cat "${DOMAIN_CONVERSATIONS_CREATE_API_LOG}"
  exit 1
fi

if ! grep -q "Conversa Frontend Etapa 34" "${DOMAIN_CONVERSATIONS_CREATE_API_LOG}"; then
  echo "ERRO: criacao de conversa nao retornou nome esperado."
  cat "${DOMAIN_CONVERSATIONS_CREATE_API_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.conversation.id)" "${DOMAIN_CONVERSATIONS_CREATE_API_LOG}")"

MESSAGE_PAYLOAD="$(node -e "console.log(JSON.stringify({body:'Resposta frontend da Etapa 34'}))")"

DOMAIN_CONVERSATIONS_MESSAGE_API_STATUS="$(curl -L -s -o "${DOMAIN_CONVERSATIONS_MESSAGE_API_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${MESSAGE_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_API_URL}/${CONVERSATION_ID}/messages" || true)"

if [ "${DOMAIN_CONVERSATIONS_MESSAGE_API_STATUS}" != "200" ] && [ "${DOMAIN_CONVERSATIONS_MESSAGE_API_STATUS}" != "201" ]; then
  echo "ERRO: criacao de mensagem dominio falhou. Status ${DOMAIN_CONVERSATIONS_MESSAGE_API_STATUS}"
  cat "${DOMAIN_CONVERSATIONS_MESSAGE_API_LOG}"
  exit 1
fi

if ! grep -q "Resposta frontend da Etapa 34" "${DOMAIN_CONVERSATIONS_MESSAGE_API_LOG}"; then
  echo "ERRO: mensagem dominio nao retornou corpo esperado."
  cat "${DOMAIN_CONVERSATIONS_MESSAGE_API_LOG}"
  exit 1
fi

echo "Criando conversations.types.ts..."

cat > "${FRONTEND_DIR}/src/types/conversations.types.ts" <<'DOC'
export type ConversationContact = {
  id: string;
  name: string | null;
  phone: string;
  email: string | null;
};

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
  status: string;
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
DOC

echo "Criando conversations.service.ts..."

cat > "${FRONTEND_DIR}/src/services/conversations.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  ConversationData,
  ConversationFormData,
  ConversationListData,
  ConversationMessageData
} from '../types/conversations.types';

export async function listConversationsRequest(token: string, search = '') {
  const query = search ? `?search=${encodeURIComponent(search)}` : '';

  return apiRequest<ConversationListData>(`/conversations${query}`, {
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
  return apiRequest<ConversationData>(`/conversations/${conversationId}`, {
    method: 'GET',
    token
  });
}

export async function createConversationMessageRequest(
  token: string,
  conversationId: string,
  body: string
) {
  return apiRequest<ConversationMessageData>(`/conversations/${conversationId}/messages`, {
    method: 'POST',
    token,
    body: {
      body
    }
  });
}

export async function closeConversationRequest(token: string, conversationId: string) {
  return apiRequest<ConversationData>(`/conversations/${conversationId}/close`, {
    method: 'PATCH',
    token
  });
}
DOC

echo "Criando ConversationsPage integrada..."

cat > "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" <<'DOC'
import { FormEvent, useEffect, useMemo, useState } from 'react';
import {
  closeConversationRequest,
  createConversationMessageRequest,
  createConversationRequest,
  getConversationRequest,
  listConversationsRequest
} from '../../services/conversations.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  ConversationDetail,
  ConversationFormData,
  ConversationItem
} from '../../types/conversations.types';

const initialForm: ConversationFormData = {
  name: '',
  phone: '',
  initialMessage: ''
};

const statusLabel: Record<string, string> = {
  open: 'Aberta',
  pending: 'Pendente',
  bot: 'Bot',
  human: 'Humano',
  resolved: 'Resolvida',
  closed: 'Fechada'
};

export function ConversationsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [conversations, setConversations] = useState<ConversationItem[]>([]);
  const [selectedConversation, setSelectedConversation] = useState<ConversationDetail | null>(null);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState<ConversationFormData>(initialForm);
  const [reply, setReply] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

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

  useEffect(() => {
    void loadConversations('');
  }, []);

  const metrics = useMemo(() => {
    return {
      open: conversations.filter((conversation) => conversation.status === 'open').length,
      human: conversations.filter((conversation) => conversation.status === 'human').length,
      closed: conversations.filter((conversation) => conversation.status === 'closed').length
    };
  }, [conversations]);

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

  return (
    <section>
      <div className="page-heading">
        <span>Atendimento</span>
        <h1>Conversas</h1>
        <p>Caixa de entrada integrada ao backend real de conversas.</p>
      </div>

      <div className="conversation-metrics">
        <article className="metric-card">
          <span>Abertas</span>
          <strong>{metrics.open}</strong>
          <p>Conversas aguardando atendimento.</p>
        </article>

        <article className="metric-card">
          <span>Em atendimento</span>
          <strong>{metrics.human}</strong>
          <p>Conversas com resposta humana.</p>
        </article>

        <article className="metric-card">
          <span>Fechadas</span>
          <strong>{metrics.closed}</strong>
          <p>Conversas encerradas.</p>
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
                  <em>{statusLabel[conversation.status] || conversation.status}</em>
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
                    {statusLabel[selectedConversation.status] || selectedConversation.status}
                  </span>

                  <button onClick={() => void handleCloseConversation()} type="button">
                    Fechar
                  </button>
                </div>
              </header>

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
                    <span>{item.createdAt}</span>
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

echo "Adicionando estilos complementares..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.conversations-actions-panel {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  margin-top: 24px;
  padding: 20px;
}

.conversation-create-form {
  display: grid;
  gap: 12px;
  grid-template-columns: 1fr 220px 1fr auto;
}

.conversation-create-form input,
.conversation-search-form input {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 12px 14px;
}

.conversation-create-form input:focus,
.conversation-search-form input:focus {
  border-color: #b91c1c;
  box-shadow: 0 0 0 4px rgba(185, 28, 28, 0.12);
  outline: none;
}

.conversation-create-form button,
.conversation-search-form button,
.thread-header-actions button {
  background: #b91c1c;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 800;
  padding: 12px 16px;
}

.conversation-search-form {
  display: grid;
  gap: 10px;
  grid-template-columns: minmax(0, 1fr) auto;
  padding: 0 16px 16px;
}

.conversation-search-form .conversation-search {
  margin: 0;
  width: 100%;
}

.conversation-empty {
  color: #6b7280;
  padding: 18px;
}

.conversation-empty-center {
  margin: auto;
  text-align: center;
}

.thread-header-actions {
  align-items: center;
  display: flex;
  gap: 12px;
}

.thread-composer button {
  background: #b91c1c;
  cursor: pointer;
}

@media (max-width: 1100px) {
  .conversation-create-form {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .conversation-search-form {
    grid-template-columns: 1fr;
  }

  .thread-header-actions {
    align-items: flex-start;
    flex-direction: column;
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/conversations.types.ts" \
  "${FRONTEND_DIR}/src/services/conversations.service.ts" \
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

echo "Gerando documentacao da Etapa 34..."

cat > "${DOC_FILE}" <<'DOC'
# Frontend Conversations Integrado

## Visao geral

Este documento registra a integracao do frontend de conversas ao backend real.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- servico frontend de conversas
- listagem real de conversas
- criacao real de conversa
- busca simples
- selecao de conversa
- carregamento real de mensagens
- envio de mensagem
- fechamento de conversa
- cards de metricas com dados carregados

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/conversations.types.ts
- apps/frontend/src/services/conversations.service.ts
- apps/frontend/src/pages/conversations/ConversationsPage.tsx
- apps/frontend/src/styles.css
- docs/FRONTEND_CONVERSATIONS_INTEGRADO.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- login via dominio
- listagem de conversas via dominio
- criacao de conversa via dominio
- criacao de mensagem via dominio
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

A integracao usa o backend real de conversas criado na Etapa 33.

A integracao com API oficial da Meta ainda sera criada em etapa futura.

## Proxima etapa sugerida

Etapa 35:

    Criar modulo backend de WhatsApp Accounts
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

- [ ] Etapa 35 - Modulo backend de WhatsApp Accounts

## Ultima etapa executada

Etapa 34 - Frontend de conversas integrado ao backend.

## Proxima etapa sugerida

Etapa 35 - Criar modulo backend de WhatsApp Accounts.
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

## Etapas concluidas

- Etapa 01 ate Etapa 34 concluidas

## Proxima etapa

- Etapa 35 - Modulo backend de WhatsApp Accounts
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
Etapa: 34
Acao: Frontend de conversas integrado ao backend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Conversations list api status: ${DOMAIN_CONVERSATIONS_LIST_API_STATUS}
Conversations create api status: ${DOMAIN_CONVERSATIONS_CREATE_API_STATUS}
Conversations message api status: ${DOMAIN_CONVERSATIONS_MESSAGE_API_STATUS}
Conversations page status: ${DOMAIN_CONVERSATIONS_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 34 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/conversations"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 35 - Criar modulo backend de WhatsApp Accounts"
