#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_45.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_45_operational_audit_panel.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_45_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_45_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_45_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_45_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_45_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_45_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_45_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_45_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_45_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_45_auth_login_domain.log"
DOMAIN_SUMMARY_LOG="${LOGS_DIR}/setup_45_audit_summary_domain.log"
DOMAIN_MESSAGES_LOG="${LOGS_DIR}/setup_45_audit_messages_domain.log"
DOMAIN_WEBHOOKS_LOG="${LOGS_DIR}/setup_45_audit_webhooks_domain.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_45_domain_audit_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_45_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/OPERATIONAL_AUDIT_PANEL.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Fix Etapa 45: Painel de auditoria operacional =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/operational-audit"
mkdir -p "${FRONTEND_DIR}/src/pages/audit"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.module.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.types.ts" \
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

echo "Criando backend de auditoria..."

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.types.ts" <<'DOC'
export type OperationalAuditQuery = {
  status?: string;
  direction?: string;
  type?: string;
  limit?: string;
};

export type OperationalAuditSummaryResponse = {
  success: true;
  data: {
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
  meta: Record<string, never>;
};

export type OperationalAuditMessageItem = {
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

export type OperationalAuditWebhookItem = {
  id: string;
  provider: string;
  eventType: string;
  eventId: string | null;
  status: string;
  createdAt: string;
};

export type OperationalAuditMessagesResponse = {
  success: true;
  data: {
    messages: OperationalAuditMessageItem[];
  };
  meta: Record<string, never>;
};

export type OperationalAuditWebhooksResponse = {
  success: true;
  data: {
    webhooks: OperationalAuditWebhookItem[];
  };
  meta: Record<string, never>;
};
DOC

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import {
  MessageDirection,
  MessageStatus,
  MessageType,
  WebhookEventStatus,
  WhatsappAccountStatus
} from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import type {
  OperationalAuditMessagesResponse,
  OperationalAuditQuery,
  OperationalAuditSummaryResponse,
  OperationalAuditWebhooksResponse
} from './operational-audit.types';

@Injectable()
export class OperationalAuditService {
  constructor(private readonly prismaService: PrismaService) {}

  async getSummary(tenantId: string): Promise<OperationalAuditSummaryResponse> {
    const [
      messagesTotal,
      messagesSent,
      messagesDelivered,
      messagesRead,
      messagesFailed,
      messagesPending,
      messagesReceived,
      webhooksTotal,
      webhooksReceived,
      webhooksProcessed,
      webhooksFailed,
      conversationsVisible,
      conversationsDeleted,
      accountsActive,
      accountsDeleted
    ] = await Promise.all([
      this.prismaService.message.count({ where: { tenantId } }),
      this.prismaService.message.count({ where: { tenantId, status: MessageStatus.sent } }),
      this.prismaService.message.count({ where: { tenantId, status: MessageStatus.delivered } }),
      this.prismaService.message.count({ where: { tenantId, status: MessageStatus.read } }),
      this.prismaService.message.count({ where: { tenantId, status: MessageStatus.failed } }),
      this.prismaService.message.count({ where: { tenantId, status: MessageStatus.pending } }),
      this.prismaService.message.count({ where: { tenantId, status: MessageStatus.received } }),
      this.prismaService.webhookEvent.count({ where: { tenantId } }),
      this.prismaService.webhookEvent.count({ where: { tenantId, status: WebhookEventStatus.received } }),
      this.prismaService.webhookEvent.count({ where: { tenantId, status: WebhookEventStatus.processed } }),
      this.prismaService.webhookEvent.count({ where: { tenantId, status: WebhookEventStatus.failed } }),
      this.prismaService.conversation.count({ where: { tenantId, deletedAt: null } }),
      this.prismaService.conversation.count({ where: { tenantId, deletedAt: { not: null } } }),
      this.prismaService.whatsappAccount.count({
        where: {
          tenantId,
          deletedAt: null,
          status: WhatsappAccountStatus.active
        }
      }),
      this.prismaService.whatsappAccount.count({
        where: {
          tenantId,
          deletedAt: {
            not: null
          }
        }
      })
    ]);

    return {
      success: true,
      data: {
        messages: {
          total: messagesTotal,
          sent: messagesSent,
          delivered: messagesDelivered,
          read: messagesRead,
          failed: messagesFailed,
          pending: messagesPending,
          received: messagesReceived
        },
        webhooks: {
          total: webhooksTotal,
          received: webhooksReceived,
          processed: webhooksProcessed,
          failed: webhooksFailed
        },
        conversations: {
          visible: conversationsVisible,
          deleted: conversationsDeleted
        },
        accounts: {
          active: accountsActive,
          deleted: accountsDeleted
        }
      },
      meta: {}
    };
  }

  async listMessages(
    tenantId: string,
    query: OperationalAuditQuery
  ): Promise<OperationalAuditMessagesResponse> {
    const limit = this.parseLimit(query.limit);

    const messages = await this.prismaService.message.findMany({
      where: {
        tenantId,
        ...(query.status ? { status: query.status as MessageStatus } : {}),
        ...(query.direction ? { direction: query.direction as MessageDirection } : {}),
        ...(query.type ? { type: query.type as MessageType } : {})
      },
      include: {
        contact: true
      },
      orderBy: {
        createdAt: 'desc'
      },
      take: limit
    });

    return {
      success: true,
      data: {
        messages: messages.map((message) => ({
          id: message.id,
          conversationId: message.conversationId,
          contactName: message.contact?.name || null,
          contactPhone: message.contact?.phone || null,
          direction: message.direction,
          type: message.type,
          status: message.status,
          body: message.body,
          providerMessageId: message.providerMessageId || null,
          sentAt: message.sentAt ? message.sentAt.toISOString() : null,
          createdAt: message.createdAt.toISOString(),
          errorMessage: this.extractErrorMessage(message.metadata)
        }))
      },
      meta: {}
    };
  }

  async listWebhooks(
    tenantId: string,
    query: OperationalAuditQuery
  ): Promise<OperationalAuditWebhooksResponse> {
    const limit = this.parseLimit(query.limit);

    const webhooks = await this.prismaService.webhookEvent.findMany({
      where: {
        tenantId,
        ...(query.status ? { status: query.status as WebhookEventStatus } : {}),
        ...(query.type ? { eventType: query.type } : {})
      },
      orderBy: {
        createdAt: 'desc'
      },
      take: limit
    });

    return {
      success: true,
      data: {
        webhooks: webhooks.map((event) => ({
          id: event.id,
          provider: event.provider,
          eventType: event.eventType,
          eventId: event.eventId || null,
          status: event.status,
          createdAt: event.createdAt.toISOString()
        }))
      },
      meta: {}
    };
  }

  private parseLimit(value?: string): number {
    if (!value) {
      return 30;
    }

    const parsed = Number(value);

    if (Number.isNaN(parsed) || parsed < 1) {
      return 30;
    }

    if (parsed > 100) {
      return 100;
    }

    return parsed;
  }

  private extractErrorMessage(metadata: unknown): string | null {
    const payload = metadata as {
      metaSend?: {
        errorMessage?: string | null;
      };
    } | null;

    return payload?.metaSend?.errorMessage || null;
  }
}
DOC

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" <<'DOC'
import {
  Controller,
  Get,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { OperationalAuditService } from './operational-audit.service';
import type { OperationalAuditQuery } from './operational-audit.types';

@Controller('operational-audit')
@UseGuards(JwtAuthGuard)
export class OperationalAuditController {
  constructor(private readonly operationalAuditService: OperationalAuditService) {}

  @Get('summary')
  getSummary(@CurrentUser() user: AuthenticatedUser) {
    return this.operationalAuditService.getSummary(user.tenantId);
  }

  @Get('messages')
  listMessages(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: OperationalAuditQuery
  ) {
    return this.operationalAuditService.listMessages(user.tenantId, query);
  }

  @Get('webhooks')
  listWebhooks(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: OperationalAuditQuery
  ) {
    return this.operationalAuditService.listWebhooks(user.tenantId, query);
  }
}
DOC

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { OperationalAuditController } from './operational-audit.controller';
import { OperationalAuditService } from './operational-audit.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    OperationalAuditController
  ],
  providers: [
    OperationalAuditService
  ]
})
export class OperationalAuditModule {}
DOC

echo "Corrigindo app.module.ts com insercao segura..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()

lines = text.splitlines()

cleaned = []
for line in lines:
    if "operational-audit" in line:
        continue
    if "OperationalAuditModule" in line:
        continue
    cleaned.append(line)

last_import_index = -1
for index, line in enumerate(cleaned):
    if line.startswith("import "):
        last_import_index = index

if last_import_index < 0:
    raise SystemExit("Nenhum import encontrado em app.module.ts")

cleaned.insert(
    last_import_index + 1,
    "import { OperationalAuditModule } from './modules/operational-audit/operational-audit.module';"
)

text = "\n".join(cleaned) + "\n"

if "imports: [" not in text:
    raise SystemExit("Bloco imports nao encontrado em app.module.ts")

text = text.replace(
    "imports: [",
    "imports: [\n    OperationalAuditModule,",
    1
)

path.write_text(text)
PY

echo "Validando backend sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/operational-audit" \
  "${BACKEND_DIR}/src/app.module.ts"
then
  echo "ERRO: HTML indevido encontrado no backend."
  exit 1
fi

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${BACKEND_TYPECHECK_LOG}"

echo "Rodando build do backend..."

npm run build 2>&1 | tee "${BACKEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Criando frontend de auditoria..."

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

export type AuditSummaryData = AuditSummary;

export type AuditMessagesData = {
  messages: AuditMessageItem[];
};

export type AuditWebhooksData = {
  webhooks: AuditWebhookItem[];
};
DOC

cat > "${FRONTEND_DIR}/src/services/operational-audit.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
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
DOC

cat > "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" <<'DOC'
import { FormEvent, useEffect, useState } from 'react';
import {
  getAuditSummaryRequest,
  listAuditMessagesRequest,
  listAuditWebhooksRequest
} from '../../services/operational-audit.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
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
  const [notice, setNotice] = useState('');

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

    const [summaryResponse, messagesResponse, webhooksResponse] = await Promise.all([
      getAuditSummaryRequest(token),
      listAuditMessagesRequest(token, {
        status: messageStatus,
        direction: messageDirection,
        type: messageType
      }),
      listAuditWebhooksRequest(token, {
        status: webhookStatus,
        type: webhookType
      })
    ]);

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

  return (
    <section>
      <div className="page-heading">
        <span>Auditoria</span>
        <h1>Painel de auditoria operacional</h1>
        <p>Acompanhe mensagens, webhooks, status e erros operacionais sem expor tokens.</p>
      </div>

      {notice ? <div className="form-message">{notice}</div> : null}

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

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.audit-summary-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  margin-top: 26px;
}

.audit-summary-grid article {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  padding: 20px;
}

.audit-summary-grid span {
  color: #6b7280;
  display: block;
  font-size: 13px;
  font-weight: 900;
  margin-bottom: 8px;
  text-transform: uppercase;
}

.audit-summary-grid strong {
  color: #111827;
  display: block;
  font-size: 30px;
}

.audit-summary-grid p {
  color: #6b7280;
  margin: 8px 0 0;
}

.audit-panel {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  margin-top: 22px;
  padding: 22px;
}

.audit-filter-form {
  display: grid;
  gap: 12px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  margin-bottom: 18px;
}

.audit-filter-form input,
.audit-filter-form select {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 12px 14px;
}

.audit-filter-form button {
  background: #b91c1c;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 16px;
}

.audit-table {
  display: grid;
  gap: 10px;
}

.audit-table article {
  align-items: center;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) auto auto auto;
  padding: 14px;
}

.audit-table strong {
  display: block;
  overflow-wrap: anywhere;
}

.audit-table span,
.audit-table small {
  color: #6b7280;
  display: block;
  overflow-wrap: anywhere;
}

.audit-table em {
  border-radius: 999px;
  font-style: normal;
  font-weight: 900;
  padding: 7px 10px;
}

.audit-status-good {
  background: #dcfce7;
  color: #166534;
}

.audit-status-warning {
  background: #fef3c7;
  color: #92400e;
}

.audit-status-danger {
  background: #fee2e2;
  color: #991b1b;
}

.audit-status-neutral {
  background: #f3f4f6;
  color: #374151;
}

.audit-error {
  color: #991b1b !important;
  font-weight: 800;
}

@media (max-width: 1100px) {
  .audit-summary-grid,
  .audit-filter-form {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .audit-table article {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .audit-summary-grid,
  .audit-filter-form {
    grid-template-columns: 1fr;
  }
}
DOC

echo "Validando frontend sem HTML indevido..."

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

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BACKEND_BUILD_LOG}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_FRONTEND_BUILD_LOG}"

echo "Subindo backend, frontend e proxy..."

docker compose up -d backend frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

echo "Aguardando backend estabilizar..."

: > "${BACKEND_WAIT_LOG}"

BACKEND_READY="false"

for i in $(seq 1 30); do
  STATUS="$(docker inspect -f '{{.State.Status}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"
  RESTARTING="$(docker inspect -f '{{.State.Restarting}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"

  echo "tentativa=${i} status=${STATUS} restarting=${RESTARTING}" | tee -a "${BACKEND_WAIT_LOG}"

  if [ "${STATUS}" = "running" ] && [ "${RESTARTING}" = "false" ]; then
    if curl -s --max-time 5 "http://127.0.0.1:3300/api/v1/health" >/dev/null 2>&1; then
      BACKEND_READY="true"
      break
    fi
  fi

  sleep 3
done

if [ "${BACKEND_READY}" != "true" ]; then
  echo "ERRO: backend nao estabilizou."
  docker compose logs --tail=220 backend 2>&1 | tee "${BACKEND_CRASH_LOG}"
  exit 1
fi

sleep 8

echo "Validando dominio..."

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

DOMAIN_SUMMARY_STATUS="$(curl -L -s -o "${DOMAIN_SUMMARY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/summary" || true)"

if [ "${DOMAIN_SUMMARY_STATUS}" != "200" ]; then
  echo "ERRO: summary dominio falhou. Status ${DOMAIN_SUMMARY_STATUS}"
  cat "${DOMAIN_SUMMARY_LOG}"
  exit 1
fi

if ! grep -q "messages" "${DOMAIN_SUMMARY_LOG}"; then
  echo "ERRO: summary nao retornou messages."
  cat "${DOMAIN_SUMMARY_LOG}"
  exit 1
fi

DOMAIN_MESSAGES_STATUS="$(curl -L -s -o "${DOMAIN_MESSAGES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/messages?limit=20" || true)"

if [ "${DOMAIN_MESSAGES_STATUS}" != "200" ]; then
  echo "ERRO: messages dominio falhou. Status ${DOMAIN_MESSAGES_STATUS}"
  cat "${DOMAIN_MESSAGES_LOG}"
  exit 1
fi

DOMAIN_WEBHOOKS_STATUS="$(curl -L -s -o "${DOMAIN_WEBHOOKS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/webhooks?limit=20" || true)"

if [ "${DOMAIN_WEBHOOKS_STATUS}" != "200" ]; then
  echo "ERRO: webhooks dominio falhou. Status ${DOMAIN_WEBHOOKS_STATUS}"
  cat "${DOMAIN_WEBHOOKS_LOG}"
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

echo "Gerando documentacao da Etapa 45..."

cat > "${DOC_FILE}" <<'DOC'
# Operational Audit Panel

## Visao geral

Este documento registra a criacao do painel de auditoria operacional.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- endpoint de resumo operacional
- endpoint de mensagens recentes
- endpoint de webhooks recentes
- tela frontend em app audit
- cards com totais de mensagens
- cards com totais de webhooks
- filtro por status, direcao e tipo de mensagem
- filtro por status e tipo de webhook
- exibicao de providerMessageId
- exibicao de erro Meta sem expor token
- link Auditoria na sidebar

## Endpoints criados

Endpoints:

- GET api v1 operational audit summary
- GET api v1 operational audit messages
- GET api v1 operational audit webhooks

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/operational-audit/operational-audit.module.ts
- apps/backend/src/modules/operational-audit/operational-audit.controller.ts
- apps/backend/src/modules/operational-audit/operational-audit.service.ts
- apps/backend/src/modules/operational-audit/operational-audit.types.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit/AuditPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/OPERATIONAL_AUDIT_PANEL.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- aguardo ativo do backend
- login dominio
- endpoint summary dominio
- endpoint messages dominio
- endpoint webhooks dominio
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_45_backend_typecheck.log
- logs/setup_45_backend_build.log
- logs/setup_45_frontend_typecheck.log
- logs/setup_45_frontend_build.log
- logs/setup_45_backend_docker_build.log
- logs/setup_45_frontend_docker_build.log
- logs/setup_45_docker_up.log
- logs/setup_45_backend_wait.log
- logs/setup_45_auth_login_domain.log
- logs/setup_45_audit_summary_domain.log
- logs/setup_45_audit_messages_domain.log
- logs/setup_45_audit_webhooks_domain.log
- logs/setup_45_domain_audit_page.log
- logs/setup_45_domain_dashboard.log
- logs/setup_45.log
- logs/fix_45_operational_audit_panel.log

## Proxima etapa sugerida

Etapa 46:

    Criar relatorio operacional exportavel
DOC

echo "Atualizando 00_CONTROLE.md e MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

control = Path("00_CONTROLE.md")
text = control.read_text()

if "- [x] Etapa 45 - Painel de auditoria operacional" not in text:
    text = text.replace(
        "- [ ] Etapa 45 - Painel de auditoria operacional",
        "- [x] Etapa 45 - Painel de auditoria operacional"
    )

if "- [ ] Etapa 46 - Relatorio operacional exportavel" not in text:
    text = text.replace(
        "- [x] Etapa 45 - Painel de auditoria operacional",
        "- [x] Etapa 45 - Painel de auditoria operacional\n- [ ] Etapa 46 - Relatorio operacional exportavel"
    )

if "## Ultima etapa executada" in text:
    before, marker, after = text.partition("## Ultima etapa executada")
    text = before + marker + "\n\nEtapa 45 - Painel de auditoria operacional.\n\n## Proxima etapa sugerida\n\nEtapa 46 - Criar relatorio operacional exportavel.\n"

control.write_text(text)

manifest = Path("MANIFESTO.md")
mtext = manifest.read_text()

if "Painel de auditoria operacional criado." not in mtext:
    mtext = mtext.replace(
        "Limpeza operacional de dados de teste criada.",
        "Limpeza operacional de dados de teste criada.\n\nPainel de auditoria operacional criado."
    )

if "- docs/OPERATIONAL_AUDIT_PANEL.md" not in mtext:
    mtext = mtext.replace(
        "- docs/OPERATIONAL_CLEANUP.md",
        "- docs/OPERATIONAL_CLEANUP.md\n- docs/OPERATIONAL_AUDIT_PANEL.md"
    )

mtext = mtext.replace(
    "- Etapa 01 ate Etapa 44 concluidas",
    "- Etapa 01 ate Etapa 45 concluidas"
)

mtext = mtext.replace(
    "- Etapa 45 - Painel de auditoria operacional",
    "- Etapa 46 - Relatorio operacional exportavel"
)

manifest.write_text(mtext)
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
Etapa: 45
Acao: Painel de auditoria operacional
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Summary status: ${DOMAIN_SUMMARY_STATUS}
Messages status: ${DOMAIN_MESSAGES_STATUS}
Webhooks status: ${DOMAIN_WEBHOOKS_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 45
Acao: Fix painel de auditoria operacional
Data: $(date '+%Y-%m-%d %H:%M:%S')
Status: Concluido
DOC

echo ""
echo "== Etapa 45 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/audit"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 46 - Criar relatorio operacional exportavel"
