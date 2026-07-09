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
