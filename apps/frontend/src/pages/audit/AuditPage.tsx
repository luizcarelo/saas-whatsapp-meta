import { FormEvent, useEffect, useState } from 'react';
import {
  downloadAuditExportRequest,
  getAuditRetentionPolicyRequest,
  getAuditSummaryRequest,
  listAuditMessagesRequest,
  listAuditWebhooksRequest,
  previewAuditHygieneRequest,
  runAuditHygieneRequest,
  updateAuditRetentionPolicyRequest
} from '../../services/operational-audit.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  AuditHygieneResult,
  AuditMessageItem,
  AuditRetentionPolicy,
  AuditSummary,
  AuditWebhookItem
} from '../../types/operational-audit.types';

const retentionStorageKey = 'lhbot.audit.retention.days';

const retentionOptions = [
  30,
  60,
  90,
  180,
  365
];

const emptySummary: AuditSummary = {
  messages: {
    total: 0,
    sent: 0,
    delivered: 0,
    read: 0,
    failed: 0,
    pending: 0,
    received: 0
  },
  webhooks: {
    total: 0,
    received: 0,
    processed: 0,
    failed: 0
  },
  conversations: {
    visible: 0,
    deleted: 0
  },
  accounts: {
    active: 0,
    deleted: 0
  }
};

function statusBadgeClass(status: string) {
  if (status === 'sent' || status === 'processed' || status === 'read' || status === 'delivered') {
    return 'audit-status-good';
  }

  if (status === 'failed') {
    return 'audit-status-danger';
  }

  if (status === 'pending' || status === 'received') {
    return 'audit-status-warning';
  }

  return 'audit-status-neutral';
}

function loadFallbackRetentionDays() {
  const saved = window.localStorage.getItem(retentionStorageKey);
  const parsed = Number(saved);

  if (Number.isNaN(parsed) || parsed < 1) {
    return 90;
  }

  return parsed;
}

export function AuditPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [summary, setSummary] = useState<AuditSummary>(emptySummary);
  const [messages, setMessages] = useState<AuditMessageItem[]>([]);
  const [webhooks, setWebhooks] = useState<AuditWebhookItem[]>([]);

  const [messageStatus, setMessageStatus] = useState('');
  const [messageDirection, setMessageDirection] = useState('');
  const [messageType, setMessageType] = useState('');
  const [webhookStatus, setWebhookStatus] = useState('');
  const [webhookType, setWebhookType] = useState('');

  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);
  const [notice, setNotice] = useState('');

  const [retentionDays, setRetentionDays] = useState(loadFallbackRetentionDays);
  const [retentionPolicy, setRetentionPolicy] = useState<AuditRetentionPolicy | null>(null);
  const [hygieneResult, setHygieneResult] = useState<AuditHygieneResult | null>(null);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadRetentionPolicy() {
    const token = getToken();

    if (!token) {
      return;
    }

    const response = await getAuditRetentionPolicyRequest(token);

    if (response.success) {
      setRetentionPolicy(response.data);
      setRetentionDays(response.data.auditRetentionDays);
      window.localStorage.setItem(retentionStorageKey, String(response.data.auditRetentionDays));
      return;
    }

    setNotice('Nao foi possivel carregar politica backend. Usando fallback local.');
  }

  async function saveRetentionPolicy(days: number) {
    const token = getToken();
    const normalized = Number.isNaN(days) || days < 1 ? 90 : days;

    setRetentionDays(normalized);
    window.localStorage.setItem(retentionStorageKey, String(normalized));

    if (!token) {
      setNotice('Politica salva localmente com ' + normalized + ' dias.');
      return;
    }

    const response = await updateAuditRetentionPolicyRequest(token, normalized);

    if (response.success) {
      setRetentionPolicy(response.data);
      setRetentionDays(response.data.auditRetentionDays);
      window.localStorage.setItem(retentionStorageKey, String(response.data.auditRetentionDays));
      setNotice('Politica de retencao salva no backend com ' + response.data.auditRetentionDays + ' dias.');
      return;
    }

    setNotice(response.error.message || 'Nao foi possivel salvar politica no backend.');
  }

  async function loadAudit() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const summaryResponse = await getAuditSummaryRequest(token);
    const messagesResponse = await listAuditMessagesRequest(token, {
      status: messageStatus,
      direction: messageDirection,
      type: messageType
    });
    const webhooksResponse = await listAuditWebhooksRequest(token, {
      status: webhookStatus,
      type: webhookType
    });

    if (summaryResponse.success) {
      setSummary(summaryResponse.data);
    }

    if (messagesResponse.success) {
      setMessages(messagesResponse.data.messages);
    }

    if (webhooksResponse.success) {
      setWebhooks(webhooksResponse.data.webhooks);
    }

    if (!summaryResponse.success || !messagesResponse.success || !webhooksResponse.success) {
      setNotice('Algumas informacoes de auditoria nao puderam ser carregadas.');
    }

    setLoading(false);
  }

  useEffect(() => {
    void loadRetentionPolicy();
    void loadAudit();
  }, []);

  async function handleMessageFilter(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await loadAudit();
  }

  async function handleWebhookFilter(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await loadAudit();
  }

  async function handleExport(resource: string, format: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    setExporting(true);
    setNotice('');

    try {
      await downloadAuditExportRequest(token, {
        resource,
        format,
        status: resource === 'messages' ? messageStatus : webhookStatus,
        direction: resource === 'messages' ? messageDirection : '',
        type: resource === 'messages' ? messageType : webhookType
      });

      setNotice('Relatorio exportado com sucesso.');
    } catch (_error) {
      setNotice('Nao foi possivel exportar o relatorio.');
    } finally {
      setExporting(false);
    }
  }

  async function handlePreviewHygiene() {
    const token = getToken();

    if (!token) {
      return;
    }

    const response = await previewAuditHygieneRequest(token, retentionDays);

    if (response.success) {
      setHygieneResult(response.data);
      setNotice('Preview carregado usando politica backend de ' + response.data.days + ' dias.');
      return;
    }

    setNotice(response.error.message || 'Nao foi possivel carregar preview.');
  }

  async function handleDryRunHygiene() {
    const token = getToken();

    if (!token) {
      return;
    }

    const response = await runAuditHygieneRequest(token, retentionDays, true);

    if (response.success) {
      setHygieneResult(response.data);
      setNotice('Dry-run executado sem alterar dados usando politica de ' + response.data.days + ' dias.');
      return;
    }

    setNotice(response.error.message || 'Nao foi possivel executar dry-run.');
  }

  return (
    <section>
      <div className="page-heading">
        <span>Auditoria</span>
        <h1>Painel de auditoria operacional</h1>
        <p>Acompanhe mensagens, webhooks, exportacoes e politica de retencao persistida.</p>
      </div>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="retention-policy-panel">
        <div>
          <strong>Politica de retencao persistida</strong>
          <p>
            Configure a retencao usada nos previews e dry-runs. Fonte atual:
            {' '}
            {retentionPolicy?.source || 'local'}
          </p>
        </div>

        <label>
          Dias de retencao
          <input
            min="1"
            onChange={(event) => setRetentionDays(Number(event.target.value))}
            type="number"
            value={retentionDays}
          />
        </label>

        <div className="retention-quick-options">
          {retentionOptions.map((days) => (
            <button
              key={days}
              onClick={() => void saveRetentionPolicy(days)}
              type="button"
            >
              {days} dias
            </button>
          ))}
        </div>

        <button onClick={() => void saveRetentionPolicy(retentionDays)} type="button">
          Salvar no backend
        </button>
      </section>

      <div className="audit-export-toolbar">
        <div>
          <strong>Relatorios exportaveis</strong>
          <p>Baixe mensagens ou webhooks em CSV ou JSON usando os filtros atuais.</p>
        </div>

        <button disabled={exporting} onClick={() => void handleExport('messages', 'csv')} type="button">
          Mensagens CSV
        </button>

        <button disabled={exporting} onClick={() => void handleExport('messages', 'json')} type="button">
          Mensagens JSON
        </button>

        <button disabled={exporting} onClick={() => void handleExport('webhooks', 'csv')} type="button">
          Webhooks CSV
        </button>

        <button disabled={exporting} onClick={() => void handleExport('webhooks', 'json')} type="button">
          Webhooks JSON
        </button>
      </div>

      <section className="audit-hygiene-panel">
        <div>
          <strong>Higienizacao de auditoria</strong>
          <p>Use a politica persistida para simular a higienizacao de dados antigos.</p>
        </div>

        <label>
          Politica atual
          <input
            readOnly
            type="number"
            value={retentionDays}
          />
        </label>

        <button onClick={() => void handlePreviewHygiene()} type="button">
          Preview
        </button>

        <button onClick={() => void handleDryRunHygiene()} type="button">
          Dry-run seguro
        </button>

        {hygieneResult ? (
          <div className="audit-hygiene-result">
            <span>Cutoff: {hygieneResult.cutoff}</span>
            <span>Mensagens antigas: {hygieneResult.candidates.oldMessages}</span>
            <span>Falhas com metadata: {hygieneResult.candidates.oldFailedMessagesWithMetadata}</span>
            <span>Webhooks antigos: {hygieneResult.candidates.oldWebhookEvents}</span>
            <span>Dry-run: {hygieneResult.dryRun ? 'sim' : 'nao'}</span>
          </div>
        ) : null}
      </section>

      <div className="audit-summary-grid">
        <article>
          <span>Mensagens</span>
          <strong>{summary.messages.total}</strong>
          <p>Sent: {summary.messages.sent} | Failed: {summary.messages.failed}</p>
        </article>

        <article>
          <span>Webhooks</span>
          <strong>{summary.webhooks.total}</strong>
          <p>Received: {summary.webhooks.received} | Failed: {summary.webhooks.failed}</p>
        </article>

        <article>
          <span>Conversas visiveis</span>
          <strong>{summary.conversations.visible}</strong>
          <p>Removidas: {summary.conversations.deleted}</p>
        </article>

        <article>
          <span>Contas ativas</span>
          <strong>{summary.accounts.active}</strong>
          <p>Removidas: {summary.accounts.deleted}</p>
        </article>
      </div>

      <section className="audit-panel">
        <div className="panel-heading">
          <div>
            <h2>Mensagens recentes</h2>
            <p>Ultimas mensagens com status operacional.</p>
          </div>
        </div>

        <form className="audit-filter-form" onSubmit={handleMessageFilter}>
          <select onChange={(event) => setMessageStatus(event.target.value)} value={messageStatus}>
            <option value="">Todos os status</option>
            <option value="pending">Pendente</option>
            <option value="received">Recebida</option>
            <option value="sent">Enviada</option>
            <option value="delivered">Entregue</option>
            <option value="read">Lida</option>
            <option value="failed">Falhou</option>
          </select>

          <select onChange={(event) => setMessageDirection(event.target.value)} value={messageDirection}>
            <option value="">Todas as direcoes</option>
            <option value="inbound">Inbound</option>
            <option value="outbound">Outbound</option>
          </select>

          <select onChange={(event) => setMessageType(event.target.value)} value={messageType}>
            <option value="">Todos os tipos</option>
            <option value="text">Texto</option>
            <option value="template">Template</option>
            <option value="image">Imagem</option>
            <option value="audio">Audio</option>
            <option value="video">Video</option>
            <option value="document">Documento</option>
          </select>

          <button type="submit">Filtrar mensagens</button>
        </form>

        {loading ? <div className="conversation-empty">Carregando auditoria...</div> : null}

        <div className="audit-table">
          {messages.map((item) => (
            <article key={item.id}>
              <div>
                <strong>{item.contactName || item.contactPhone || 'Contato nao informado'}</strong>
                <span>{item.body || 'Sem corpo'}</span>
                {item.providerMessageId ? <small>{item.providerMessageId}</small> : null}
                {item.errorMessage ? <small className="audit-error">{item.errorMessage}</small> : null}
              </div>

              <em className={statusBadgeClass(item.status)}>{item.status}</em>
              <small>{item.direction} | {item.type}</small>
              <small>{item.createdAt}</small>
            </article>
          ))}
        </div>
      </section>

      <section className="audit-panel">
        <div className="panel-heading">
          <div>
            <h2>Webhooks recentes</h2>
            <p>Eventos recebidos da Meta e processados pelo backend.</p>
          </div>
        </div>

        <form className="audit-filter-form" onSubmit={handleWebhookFilter}>
          <select onChange={(event) => setWebhookStatus(event.target.value)} value={webhookStatus}>
            <option value="">Todos os status</option>
            <option value="received">Received</option>
            <option value="processed">Processed</option>
            <option value="failed">Failed</option>
          </select>

          <input
            onChange={(event) => setWebhookType(event.target.value)}
            placeholder="Tipo do evento"
            value={webhookType}
          />

          <button type="submit">Filtrar webhooks</button>
        </form>

        <div className="audit-table">
          {webhooks.map((item) => (
            <article key={item.id}>
              <div>
                <strong>{item.eventType}</strong>
                <span>{item.provider}</span>
                {item.eventId ? <small>{item.eventId}</small> : null}
              </div>

              <em className={statusBadgeClass(item.status)}>{item.status}</em>
              <small>{item.createdAt}</small>
            </article>
          ))}
        </div>
      </section>
    </section>
  );
}
