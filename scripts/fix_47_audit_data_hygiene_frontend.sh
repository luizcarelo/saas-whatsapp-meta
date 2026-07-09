#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

FIX_LOG_FILE="${LOGS_DIR}/fix_47_audit_data_hygiene_frontend.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_47_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_47_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_47_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_47_frontend_docker_up.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_47_auth_login_domain.log"
DOMAIN_HYGIENE_PREVIEW_LOG="${LOGS_DIR}/setup_47_hygiene_preview_domain.log"
DOMAIN_HYGIENE_DRYRUN_LOG="${LOGS_DIR}/setup_47_hygiene_dryrun_domain.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_47_domain_audit_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_47_domain_dashboard.log"
LOG_FILE="${LOGS_DIR}/setup_47.log"
DOC_FILE="${DOCS_DIR}/AUDIT_DATA_HYGIENE.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Fix Etapa 47: Frontend da higienizacao de auditoria =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/types"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/pages/audit"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
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

for tool in node npm docker curl; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ] || [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: credenciais admin incompletas."
  exit 1
fi

echo "Regravando types de auditoria..."

cat > "${FRONTEND_DIR}/src/types/operational-audit.types.ts" <<'DOC'
export type AuditSummary = {
  messages: {
    total: number;
    sent: number;
    delivered: number;
    read: number;
    failed: number;
    pending: number;
    received: number;
  };
  webhooks: {
    total: number;
    received: number;
    processed: number;
    failed: number;
  };
  conversations: {
    visible: number;
    deleted: number;
  };
  accounts: {
    active: number;
    deleted: number;
  };
};

export type AuditMessageItem = {
  id: string;
  conversationId: string;
  contactName: string | null;
  contactPhone: string | null;
  direction: string;
  type: string;
  status: string;
  body: string | null;
  providerMessageId: string | null;
  sentAt: string | null;
  createdAt: string;
  errorMessage: string | null;
};

export type AuditWebhookItem = {
  id: string;
  provider: string;
  eventType: string;
  eventId: string | null;
  status: string;
  createdAt: string;
};

export type AuditHygieneResult = {
  dryRun: boolean;
  days: number;
  cutoff: string;
  candidates: {
    oldMessages: number;
    oldFailedMessagesWithMetadata: number;
    oldWebhookEvents: number;
  };
  changed: {
    messagesRedacted: number;
    webhookEventsRedacted: number;
  };
};

export type AuditSummaryData = AuditSummary;

export type AuditMessagesData = {
  messages: AuditMessageItem[];
};

export type AuditWebhooksData = {
  webhooks: AuditWebhookItem[];
};

export type AuditHygieneData = AuditHygieneResult;
DOC

echo "Regravando service de auditoria..."

cat > "${FRONTEND_DIR}/src/services/operational-audit.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AuditHygieneData,
  AuditMessagesData,
  AuditSummaryData,
  AuditWebhooksData
} from '../types/operational-audit.types';

export async function getAuditSummaryRequest(token: string) {
  return apiRequest<AuditSummaryData>('/operational-audit/summary', {
    method: 'GET',
    token
  });
}

export async function listAuditMessagesRequest(
  token: string,
  filters: {
    status?: string;
    direction?: string;
    type?: string;
  }
) {
  const params = new URLSearchParams();

  if (filters.status) {
    params.set('status', filters.status);
  }

  if (filters.direction) {
    params.set('direction', filters.direction);
  }

  if (filters.type) {
    params.set('type', filters.type);
  }

  params.set('limit', '50');

  return apiRequest<AuditMessagesData>('/operational-audit/messages?' + params.toString(), {
    method: 'GET',
    token
  });
}

export async function listAuditWebhooksRequest(
  token: string,
  filters: {
    status?: string;
    type?: string;
  }
) {
  const params = new URLSearchParams();

  if (filters.status) {
    params.set('status', filters.status);
  }

  if (filters.type) {
    params.set('type', filters.type);
  }

  params.set('limit', '50');

  return apiRequest<AuditWebhooksData>('/operational-audit/webhooks?' + params.toString(), {
    method: 'GET',
    token
  });
}

export async function previewAuditHygieneRequest(token: string, days: number) {
  return apiRequest<AuditHygieneData>(
    '/operational-audit/hygiene-preview?days=' + encodeURIComponent(String(days)),
    {
      method: 'GET',
      token
    }
  );
}

export async function runAuditHygieneRequest(
  token: string,
  days: number,
  dryRun: boolean
) {
  return apiRequest<AuditHygieneData>('/operational-audit/hygiene-run', {
    method: 'POST',
    token,
    body: {
      days,
      dryRun
    }
  });
}

export async function downloadAuditExportRequest(
  token: string,
  filters: {
    resource: string;
    format: string;
    status?: string;
    direction?: string;
    type?: string;
  }
) {
  const params = new URLSearchParams();

  params.set('resource', filters.resource);
  params.set('format', filters.format);
  params.set('limit', '500');

  if (filters.status) {
    params.set('status', filters.status);
  }

  if (filters.direction) {
    params.set('direction', filters.direction);
  }

  if (filters.type) {
    params.set('type', filters.type);
  }

  const response = await fetch('/api/v1/operational-audit/export?' + params.toString(), {
    method: 'GET',
    headers: {
      Authorization: 'Bearer ' + token
    }
  });

  if (!response.ok) {
    throw new Error('Nao foi possivel exportar o relatorio');
  }

  const blob = await response.blob();
  const disposition = response.headers.get('Content-Disposition') || '';
  const match = disposition.match(/filename="([^"]+)"/);
  const filename = match ? match[1] : 'operational_export.' + filters.format;

  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');

  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();

  window.URL.revokeObjectURL(url);
}
DOC

echo "Regravando AuditPage.tsx completo e limpo..."

cat > "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" <<'DOC'
import { FormEvent, useEffect, useState } from 'react';
import {
  downloadAuditExportRequest,
  getAuditSummaryRequest,
  listAuditMessagesRequest,
  listAuditWebhooksRequest,
  previewAuditHygieneRequest,
  runAuditHygieneRequest
} from '../../services/operational-audit.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  AuditHygieneResult,
  AuditMessageItem,
  AuditSummary,
  AuditWebhookItem
} from '../../types/operational-audit.types';

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

  const [hygieneDays, setHygieneDays] = useState(90);
  const [hygieneResult, setHygieneResult] = useState<AuditHygieneResult | null>(null);

  function getToken() {
    return accessToken || loadToken();
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

    const response = await previewAuditHygieneRequest(token, hygieneDays);

    if (response.success) {
      setHygieneResult(response.data);
      setNotice('Preview de higienizacao carregado.');
      return;
    }

    setNotice(response.error.message || 'Nao foi possivel carregar preview.');
  }

  async function handleDryRunHygiene() {
    const token = getToken();

    if (!token) {
      return;
    }

    const response = await runAuditHygieneRequest(token, hygieneDays, true);

    if (response.success) {
      setHygieneResult(response.data);
      setNotice('Dry-run de higienizacao executado sem alterar dados.');
      return;
    }

    setNotice(response.error.message || 'Nao foi possivel executar dry-run.');
  }

  return (
    <section>
      <div className="page-heading">
        <span>Auditoria</span>
        <h1>Painel de auditoria operacional</h1>
        <p>Acompanhe mensagens, webhooks, status, exportacoes e higienizacao segura.</p>
      </div>

      {notice ? <div className="form-message">{notice}</div> : null}

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
          <p>Simule a higienizacao de dados antigos antes de qualquer execucao real.</p>
        </div>

        <label>
          Retencao em dias
          <input
            min="1"
            onChange={(event) => setHygieneDays(Number(event.target.value))}
            type="number"
            value={hygieneDays}
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
DOC

echo "Regravando Sidebar e rotas para garantir pagina audit..."

cat > "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" <<'DOC'
import { NavLink } from 'react-router-dom';

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div className="sidebar-logo">LH</div>
        <div>
          <strong>LH Bot</strong>
          <span>WhatsApp Meta</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/app/dashboard">
          Dashboard
        </NavLink>

        <NavLink to="/app/contacts">
          Contatos
        </NavLink>

        <NavLink to="/app/conversations">
          Conversas
        </NavLink>

        <NavLink to="/app/whatsapp-accounts">
          WhatsApp
        </NavLink>

        <NavLink to="/app/meta-settings">
          Meta
        </NavLink>

        <NavLink to="/app/audit">
          Auditoria
        </NavLink>

        <NavLink to="/app/profile">
          Perfil
        </NavLink>
      </nav>
    </aside>
  );
}
DOC

cat > "${FRONTEND_DIR}/src/app/routes.tsx" <<'DOC'
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes
} from 'react-router-dom';
import { AppLayout } from '../components/layout/AppLayout';
import { AuditPage } from '../pages/audit/AuditPage';
import { ContactsPage } from '../pages/contacts/ContactsPage';
import { ConversationsPage } from '../pages/conversations/ConversationsPage';
import { DashboardPage } from '../pages/dashboard/DashboardPage';
import { LoginPage } from '../pages/login/LoginPage';
import { MetaSettingsPage } from '../pages/meta-settings/MetaSettingsPage';
import { ProfilePage } from '../pages/profile/ProfilePage';
import { WhatsappAccountsPage } from '../pages/whatsapp-accounts/WhatsappAccountsPage';
import { ProtectedRoute } from './ProtectedRoute';

export function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/login" element={<LoginPage />} />

        <Route
          path="/app"
          element={
            <ProtectedRoute>
              <AppLayout />
            </ProtectedRoute>
          }
        >
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="contacts" element={<ContactsPage />} />
          <Route path="conversations" element={<ConversationsPage />} />
          <Route path="whatsapp-accounts" element={<WhatsappAccountsPage />} />
          <Route path="meta-settings" element={<MetaSettingsPage />} />
          <Route path="audit" element={<AuditPage />} />
          <Route path="profile" element={<ProfilePage />} />
        </Route>

        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
DOC

echo "Adicionando estilos de higienizacao se necessario..."

if ! grep -q "audit-hygiene-panel" "${FRONTEND_DIR}/src/styles.css"; then
  cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.audit-hygiene-panel {
  align-items: center;
  background: #fff7ed;
  border: 1px solid #fed7aa;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.06);
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) 160px auto auto;
  margin-top: 22px;
  padding: 20px;
}

.audit-hygiene-panel strong {
  color: #9a3412;
  display: block;
}

.audit-hygiene-panel p {
  color: #9a3412;
  margin: 4px 0 0;
}

.audit-hygiene-panel label {
  color: #9a3412;
  display: grid;
  font-size: 13px;
  font-weight: 900;
  gap: 6px;
}

.audit-hygiene-panel input {
  border: 1px solid #fdba74;
  border-radius: 14px;
  padding: 10px 12px;
}

.audit-hygiene-panel button {
  background: #ea580c;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 14px;
}

.audit-hygiene-result {
  color: #9a3412;
  display: grid;
  font-size: 13px;
  font-weight: 800;
  gap: 4px;
  grid-column: 1 / -1;
}

@media (max-width: 900px) {
  .audit-hygiene-panel {
    grid-template-columns: 1fr;
  }
}
DOC
fi

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML indevido encontrado no frontend."
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

echo "Validando dominio e endpoints de higienizacao..."

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

DOMAIN_HYGIENE_PREVIEW_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_PREVIEW_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/hygiene-preview?days=90" || true)"

if [ "${DOMAIN_HYGIENE_PREVIEW_STATUS}" != "200" ]; then
  echo "ERRO: hygiene preview falhou. Status ${DOMAIN_HYGIENE_PREVIEW_STATUS}"
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

if ! grep -q "candidates" "${DOMAIN_HYGIENE_PREVIEW_LOG}"; then
  echo "ERRO: hygiene preview nao retornou candidates."
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_DRYRUN_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_DRYRUN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"days":90,"dryRun":true}' \
  "${DOMAIN_AUDIT_URL}/hygiene-run" || true)"

if [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "200" ] && [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "201" ]; then
  echo "ERRO: hygiene dry-run falhou. Status ${DOMAIN_HYGIENE_DRYRUN_STATUS}"
  cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
  exit 1
fi

if ! grep -q '"dryRun":true' "${DOMAIN_HYGIENE_DRYRUN_LOG}"; then
  echo "ERRO: hygiene dry-run nao retornou dryRun true."
  cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
  exit 1
fi

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina audit nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da correcao da Etapa 47..."

cat > "${DOC_FILE}" <<'DOC'
# Audit Data Hygiene

## Visao geral

Este documento registra a higienizacao de dados antigos de auditoria.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi corrigido o frontend da auditoria para evitar erro de tipagem no AuditPage.

O arquivo AuditPage foi regravado de forma limpa com:

- filtros de mensagens
- filtros de webhooks
- exportacao CSV e JSON
- preview de higienizacao
- dry-run seguro de higienizacao

## Politica implementada

A higienizacao e segura por padrao.

O endpoint de execucao usa dryRun como padrao, a menos que seja enviado dryRun false explicitamente.

A validacao automatica executa somente preview e dry-run seguro.

## Funcionalidades criadas

Funcionalidades:

- preview de dados antigos de auditoria
- dry-run de higienizacao
- endpoint de execucao protegida
- contagem de mensagens antigas
- contagem de mensagens failed antigas com metadata
- contagem de webhooks antigos
- painel visual no app audit
- validacao sem alteracao automatica de dados

## Endpoints criados

Endpoints:

- GET api v1 operational audit hygiene preview
- POST api v1 operational audit hygiene run

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit/AuditPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/AUDIT_DATA_HYGIENE.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- endpoint hygiene preview dominio
- endpoint hygiene dry run dominio
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_47_frontend_typecheck.log
- logs/setup_47_frontend_build.log
- logs/setup_47_frontend_docker_build.log
- logs/setup_47_frontend_docker_up.log
- logs/setup_47_auth_login_domain.log
- logs/setup_47_hygiene_preview_domain.log
- logs/setup_47_hygiene_dryrun_domain.log
- logs/setup_47_domain_audit_page.log
- logs/setup_47_domain_dashboard.log
- logs/setup_47.log
- logs/fix_47_audit_data_hygiene_frontend.log

## Observacoes

A etapa nao apaga dados automaticamente.

A execucao real deve ser feita somente depois de revisar o preview e confirmar a politica de retencao desejada.

## Proxima etapa sugerida

Etapa 48:

    Criar configuracao visual de politica de retencao
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
- [x] Etapa 43 - Painel de configuracao operacional da conta Meta
- [x] Etapa 44 - Limpeza operacional de dados de teste
- [x] Etapa 45 - Painel de auditoria operacional
- [x] Etapa 46 - Relatorio operacional exportavel
- [x] Etapa 47 - Higienizacao de dados de auditoria antigos
- [ ] Etapa 48 - Configuracao visual de politica de retencao

## Ultima etapa executada

Etapa 47 - Higienizacao de dados de auditoria antigos.

## Proxima etapa sugerida

Etapa 48 - Criar configuracao visual de politica de retencao.
DOC

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Higienizacao de dados de auditoria antigos criada." not in text:
    text = text.replace(
        "Relatorio operacional exportavel criado.",
        "Relatorio operacional exportavel criado.\n\nHigienizacao de dados de auditoria antigos criada."
    )

if "- docs/AUDIT_DATA_HYGIENE.md" not in text:
    text = text.replace(
        "- docs/OPERATIONAL_EXPORT_REPORT.md",
        "- docs/OPERATIONAL_EXPORT_REPORT.md\n- docs/AUDIT_DATA_HYGIENE.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 46 concluidas",
    "- Etapa 01 ate Etapa 47 concluidas"
)

text = text.replace(
    "- Etapa 47 - Higienizacao de dados de auditoria antigos",
    "- Etapa 48 - Configuracao visual de politica de retencao"
)

path.write_text(text)
PY

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
Etapa: 47
Acao: Higienizacao de dados de auditoria antigos
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Hygiene preview status: ${DOMAIN_HYGIENE_PREVIEW_STATUS}
Hygiene dry-run status: ${DOMAIN_HYGIENE_DRYRUN_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 47
Acao: Correcao frontend de higienizacao de auditoria
Data: $(date '+%Y-%m-%d %H:%M:%S')
Status: Concluido
DOC

echo ""
echo "== Etapa 47 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Preview:"
cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
echo ""
echo "Dry-run:"
cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 48 - Criar configuracao visual de politica de retencao"
