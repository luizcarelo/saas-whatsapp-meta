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
