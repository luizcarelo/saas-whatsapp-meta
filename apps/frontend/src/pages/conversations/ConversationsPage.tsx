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
