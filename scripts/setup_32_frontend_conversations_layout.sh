#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_32.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_32_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_32_frontend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_32_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_32_frontend_docker_up.log"
DOMAIN_CONVERSATIONS_LOG="${LOGS_DIR}/setup_32_domain_conversations.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_32_domain_dashboard.log"
DOMAIN_CONTACTS_LOG="${LOGS_DIR}/setup_32_domain_contacts.log"
DOC_FILE="${DOCS_DIR}/FRONTEND_CONVERSATIONS_LAYOUT.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_CONVERSATIONS_URL="${DOMAIN_BASE_URL}/app/conversations"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_CONTACTS_URL="${DOMAIN_BASE_URL}/app/contacts"

echo "== Etapa 32: Frontend de conversas com layout inicial =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/pages/conversations"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/types/conversations.types.ts" \
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

echo "Criando conversations.types.ts..."

cat > "${FRONTEND_DIR}/src/types/conversations.types.ts" <<'DOC'
export type ConversationStatus = 'open' | 'pending' | 'bot' | 'human' | 'resolved';

export type ConversationPreview = {
  id: string;
  contactName: string;
  phone: string;
  status: ConversationStatus;
  lastMessage: string;
  lastMessageAt: string;
  unreadCount: number;
};

export type ConversationMessage = {
  id: string;
  direction: 'inbound' | 'outbound';
  body: string;
  createdAt: string;
};
DOC

echo "Criando ConversationsPage..."

cat > "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" <<'DOC'
import { useMemo, useState } from 'react';
import type {
  ConversationMessage,
  ConversationPreview
} from '../../types/conversations.types';

const conversations: ConversationPreview[] = [
  {
    id: 'conv-001',
    contactName: 'Cliente Exemplo',
    phone: '5521999999999',
    status: 'open',
    lastMessage: 'Preciso de informacoes sobre atendimento.',
    lastMessageAt: '09:10',
    unreadCount: 2
  },
  {
    id: 'conv-002',
    contactName: 'Lead Comercial',
    phone: '5521888888888',
    status: 'bot',
    lastMessage: 'Gostaria de conhecer os planos.',
    lastMessageAt: '08:42',
    unreadCount: 0
  },
  {
    id: 'conv-003',
    contactName: 'Suporte Interno',
    phone: '5521777777777',
    status: 'pending',
    lastMessage: 'Pode encaminhar para atendimento humano?',
    lastMessageAt: 'Ontem',
    unreadCount: 1
  }
];

const messages: ConversationMessage[] = [
  {
    id: 'msg-001',
    direction: 'inbound',
    body: 'Ola, preciso de informacoes sobre atendimento.',
    createdAt: '09:08'
  },
  {
    id: 'msg-002',
    direction: 'outbound',
    body: 'Ola. Claro, posso ajudar. Qual assunto deseja tratar?',
    createdAt: '09:09'
  },
  {
    id: 'msg-003',
    direction: 'inbound',
    body: 'Quero entender como funcionara o bot integrado ao WhatsApp.',
    createdAt: '09:10'
  }
];

const statusLabel = {
  open: 'Aberta',
  pending: 'Pendente',
  bot: 'Bot',
  human: 'Humano',
  resolved: 'Resolvida'
};

export function ConversationsPage() {
  const [selectedConversationId, setSelectedConversationId] = useState(conversations[0].id);
  const [search, setSearch] = useState('');

  const filteredConversations = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();

    if (!normalizedSearch) {
      return conversations;
    }

    return conversations.filter((conversation) => {
      return (
        conversation.contactName.toLowerCase().includes(normalizedSearch) ||
        conversation.phone.includes(normalizedSearch) ||
        conversation.lastMessage.toLowerCase().includes(normalizedSearch)
      );
    });
  }, [search]);

  const selectedConversation = conversations.find(
    (conversation) => conversation.id === selectedConversationId
  ) || conversations[0];

  return (
    <section>
      <div className="page-heading">
        <span>Atendimento</span>
        <h1>Conversas</h1>
        <p>Layout inicial da caixa de entrada para atendimento via WhatsApp.</p>
      </div>

      <div className="conversation-metrics">
        <article className="metric-card">
          <span>Abertas</span>
          <strong>1</strong>
          <p>Conversas aguardando atendimento.</p>
        </article>

        <article className="metric-card">
          <span>Com bot</span>
          <strong>1</strong>
          <p>Conversas em fluxo automatizado.</p>
        </article>

        <article className="metric-card">
          <span>Pendentes</span>
          <strong>1</strong>
          <p>Conversas que precisam de acao.</p>
        </article>
      </div>

      <div className="conversations-layout">
        <aside className="conversation-list-panel">
          <div className="conversation-list-header">
            <h2>Caixa de entrada</h2>
            <p>{filteredConversations.length} conversas</p>
          </div>

          <input
            className="conversation-search"
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Buscar conversa"
            value={search}
          />

          <div className="conversation-list">
            {filteredConversations.map((conversation) => (
              <button
                className={
                  conversation.id === selectedConversationId
                    ? 'conversation-preview active'
                    : 'conversation-preview'
                }
                key={conversation.id}
                onClick={() => setSelectedConversationId(conversation.id)}
                type="button"
              >
                <div>
                  <strong>{conversation.contactName}</strong>
                  <span>{conversation.phone}</span>
                  <p>{conversation.lastMessage}</p>
                </div>

                <div className="conversation-preview-meta">
                  <small>{conversation.lastMessageAt}</small>
                  <em>{statusLabel[conversation.status]}</em>
                  {conversation.unreadCount > 0 ? (
                    <b>{conversation.unreadCount}</b>
                  ) : null}
                </div>
              </button>
            ))}
          </div>
        </aside>

        <section className="conversation-thread-panel">
          <header className="thread-header">
            <div>
              <h2>{selectedConversation.contactName}</h2>
              <p>{selectedConversation.phone}</p>
            </div>

            <span className="thread-status">
              {statusLabel[selectedConversation.status]}
            </span>
          </header>

          <div className="thread-messages">
            {messages.map((message) => (
              <article
                className={
                  message.direction === 'outbound'
                    ? 'thread-message outbound'
                    : 'thread-message inbound'
                }
                key={message.id}
              >
                <p>{message.body}</p>
                <span>{message.createdAt}</span>
              </article>
            ))}
          </div>

          <footer className="thread-composer">
            <input
              disabled
              placeholder="Resposta sera habilitada quando o backend de mensagens estiver pronto"
            />
            <button disabled type="button">
              Enviar
            </button>
          </footer>
        </section>
      </div>
    </section>
  );
}
DOC

echo "Adicionando estilos de conversas..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.conversation-metrics {
  display: grid;
  gap: 20px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  margin-top: 28px;
}

.conversations-layout {
  display: grid;
  gap: 24px;
  grid-template-columns: 370px minmax(0, 1fr);
  margin-top: 24px;
}

.conversation-list-panel,
.conversation-thread-panel {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  overflow: hidden;
}

.conversation-list-header {
  border-bottom: 1px solid #e5e7eb;
  padding: 20px;
}

.conversation-list-header h2 {
  margin: 0 0 6px;
}

.conversation-list-header p {
  color: #6b7280;
  margin: 0;
}

.conversation-search {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  box-sizing: border-box;
  margin: 16px;
  padding: 12px 14px;
  width: calc(100% - 32px);
}

.conversation-search:focus {
  border-color: #b91c1c;
  box-shadow: 0 0 0 4px rgba(185, 28, 28, 0.12);
  outline: none;
}

.conversation-list {
  display: grid;
  gap: 8px;
  padding: 0 16px 16px;
}

.conversation-preview {
  align-items: flex-start;
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 18px;
  cursor: pointer;
  display: flex;
  gap: 14px;
  justify-content: space-between;
  padding: 16px;
  text-align: left;
}

.conversation-preview.active {
  background: #fef2f2;
  border-color: #fecaca;
}

.conversation-preview strong {
  display: block;
  font-size: 15px;
}

.conversation-preview span {
  color: #6b7280;
  display: block;
  font-size: 13px;
  margin-top: 4px;
}

.conversation-preview p {
  color: #374151;
  line-height: 1.4;
  margin: 10px 0 0;
}

.conversation-preview-meta {
  align-items: flex-end;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 74px;
}

.conversation-preview-meta small {
  color: #6b7280;
}

.conversation-preview-meta em {
  background: #f3f4f6;
  border-radius: 999px;
  color: #374151;
  font-size: 12px;
  font-style: normal;
  padding: 5px 8px;
}

.conversation-preview-meta b {
  align-items: center;
  background: #b91c1c;
  border-radius: 999px;
  color: #ffffff;
  display: flex;
  font-size: 12px;
  height: 22px;
  justify-content: center;
  width: 22px;
}

.conversation-thread-panel {
  display: flex;
  flex-direction: column;
  min-height: 620px;
}

.thread-header {
  align-items: center;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  justify-content: space-between;
  padding: 22px 24px;
}

.thread-header h2 {
  margin: 0 0 6px;
}

.thread-header p {
  color: #6b7280;
  margin: 0;
}

.thread-status {
  background: #dcfce7;
  border-radius: 999px;
  color: #166534;
  font-weight: 800;
  padding: 8px 12px;
}

.thread-messages {
  background: #f9fafb;
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 14px;
  padding: 24px;
}

.thread-message {
  border-radius: 18px;
  max-width: 70%;
  padding: 14px 16px;
}

.thread-message p {
  line-height: 1.5;
  margin: 0;
}

.thread-message span {
  display: block;
  font-size: 12px;
  margin-top: 8px;
  opacity: 0.75;
}

.thread-message.inbound {
  align-self: flex-start;
  background: #ffffff;
  border: 1px solid #e5e7eb;
}

.thread-message.outbound {
  align-self: flex-end;
  background: #b91c1c;
  color: #ffffff;
}

.thread-composer {
  border-top: 1px solid #e5e7eb;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) auto;
  padding: 18px;
}

.thread-composer input {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 12px 14px;
}

.thread-composer button {
  background: #9ca3af;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  font-weight: 800;
  padding: 12px 18px;
}

@media (max-width: 1100px) {
  .conversation-metrics,
  .conversations-layout {
    grid-template-columns: 1fr;
  }

  .conversation-thread-panel {
    min-height: 520px;
  }
}

@media (max-width: 640px) {
  .thread-header {
    align-items: flex-start;
    flex-direction: column;
    gap: 12px;
  }

  .thread-message {
    max-width: 92%;
  }

  .thread-composer {
    grid-template-columns: 1fr;
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/conversations.types.ts" \
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

DOMAIN_CONVERSATIONS_STATUS="$(curl -L -s -o "${DOMAIN_CONVERSATIONS_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_CONVERSATIONS_URL}" || true)"

if [ "${DOMAIN_CONVERSATIONS_STATUS}" != "200" ]; then
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

echo "Testando rota contacts..."

DOMAIN_CONTACTS_STATUS="$(curl -L -s -o "${DOMAIN_CONTACTS_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_CONTACTS_URL}" || true)"

if [ "${DOMAIN_CONTACTS_STATUS}" != "200" ]; then
  echo "ERRO: rota contacts nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 32..."

cat > "${DOC_FILE}" <<'DOC'
# Frontend Conversations Layout

## Visao geral

Este documento registra a criacao do layout inicial da tela de conversas.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- layout de caixa de entrada
- lista visual de conversas
- busca visual de conversas
- painel de conversa selecionada
- mensagens demonstrativas
- composer visual desabilitado
- cards de status
- tipos frontend de conversas

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/conversations.types.ts
- apps/frontend/src/pages/conversations/ConversationsPage.tsx
- apps/frontend/src/styles.css
- docs/FRONTEND_CONVERSATIONS_LAYOUT.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- teste da rota conversations
- teste da rota dashboard
- teste da rota contacts

## Rotas

Rotas:

- app conversations
- app dashboard
- app contacts

## Observacoes

Esta etapa cria apenas o layout inicial.

O backend real de conversas e mensagens sera criado em etapa futura.

## Proxima etapa sugerida

Etapa 33:

    Criar modulo backend de conversas
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
- [ ] Etapa 33 - Modulo backend de conversas

## Ultima etapa executada

Etapa 32 - Frontend de conversas com layout inicial.

## Proxima etapa sugerida

Etapa 33 - Criar modulo backend de conversas.
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

## Etapas concluidas

- Etapa 01 ate Etapa 32 concluidas

## Proxima etapa

- Etapa 33 - Modulo backend de conversas
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
Etapa: 32
Acao: Frontend de conversas com layout inicial
Data: $(date '+%Y-%m-%d %H:%M:%S')
Conversations status: ${DOMAIN_CONVERSATIONS_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Contacts status: ${DOMAIN_CONTACTS_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 32 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/conversations"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 33 - Criar modulo backend de conversas"
