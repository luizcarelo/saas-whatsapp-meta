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

LOG_FILE="${LOGS_DIR}/setup_46.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_46_operational_export_report_full.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_46_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_46_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_46_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_46_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_46_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_46_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_46_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_46_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_46_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_46_auth_login_domain.log"
DOMAIN_SUMMARY_LOG="${LOGS_DIR}/setup_46_audit_summary_domain.log"
DOMAIN_MESSAGES_EXPORT_CSV_LOG="${LOGS_DIR}/setup_46_export_messages_csv_domain.log"
DOMAIN_MESSAGES_EXPORT_JSON_LOG="${LOGS_DIR}/setup_46_export_messages_json_domain.log"
DOMAIN_WEBHOOKS_EXPORT_CSV_LOG="${LOGS_DIR}/setup_46_export_webhooks_csv_domain.log"
DOMAIN_WEBHOOKS_EXPORT_JSON_LOG="${LOGS_DIR}/setup_46_export_webhooks_json_domain.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_46_domain_audit_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_46_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/OPERATIONAL_EXPORT_REPORT.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Fix full Etapa 46: Relatorio operacional exportavel =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/operational-audit"
mkdir -p "${FRONTEND_DIR}/src/types"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/pages/audit"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.types.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.module.ts" \
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

echo "Recriando backend completo de auditoria/exportacao..."

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.types.ts" <<'DOC'
export type OperationalAuditQuery = {
  status?: string;
  direction?: string;
  type?: string;
  limit?: string;
};

export type OperationalAuditExportQuery = OperationalAuditQuery & {
  resource?: string;
  format?: string;
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

export type OperationalAuditExportResult = {
  filename: string;
  contentType: string;
  content: string;
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
  OperationalAuditExportQuery,
  OperationalAuditExportResult,
  OperationalAuditMessageItem,
  OperationalAuditMessagesResponse,
  OperationalAuditQuery,
  OperationalAuditSummaryResponse,
  OperationalAuditWebhookItem,
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
    const messages = await this.collectMessages(tenantId, query);

    return {
      success: true,
      data: {
        messages
      },
      meta: {}
    };
  }

  async listWebhooks(
    tenantId: string,
    query: OperationalAuditQuery
  ): Promise<OperationalAuditWebhooksResponse> {
    const webhooks = await this.collectWebhooks(tenantId, query);

    return {
      success: true,
      data: {
        webhooks
      },
      meta: {}
    };
  }

  async exportReport(
    tenantId: string,
    query: OperationalAuditExportQuery
  ): Promise<OperationalAuditExportResult> {
    const resource = query.resource === 'webhooks' ? 'webhooks' : 'messages';
    const format = query.format === 'json' ? 'json' : 'csv';
    const timestamp = this.timestampForFilename();

    if (resource === 'webhooks') {
      const webhooks = await this.collectWebhooks(tenantId, query);

      if (format === 'json') {
        return {
          filename: 'operational_webhooks_' + timestamp + '.json',
          contentType: 'application/json; charset=utf-8',
          content: JSON.stringify({
            exportedAt: new Date().toISOString(),
            resource,
            webhooks
          }, null, 2)
        };
      }

      return {
        filename: 'operational_webhooks_' + timestamp + '.csv',
        contentType: 'text/csv; charset=utf-8',
        content: this.toCsv(
          ['id', 'provider', 'eventType', 'eventId', 'status', 'createdAt'],
          webhooks.map((item) => [
            item.id,
            item.provider,
            item.eventType,
            item.eventId || '',
            item.status,
            item.createdAt
          ])
        )
      };
    }

    const messages = await this.collectMessages(tenantId, query);

    if (format === 'json') {
      return {
        filename: 'operational_messages_' + timestamp + '.json',
        contentType: 'application/json; charset=utf-8',
        content: JSON.stringify({
          exportedAt: new Date().toISOString(),
          resource,
          messages
        }, null, 2)
      };
    }

    return {
      filename: 'operational_messages_' + timestamp + '.csv',
      contentType: 'text/csv; charset=utf-8',
      content: this.toCsv(
        [
          'id',
          'conversationId',
          'contactName',
          'contactPhone',
          'direction',
          'type',
          'status',
          'body',
          'providerMessageId',
          'sentAt',
          'createdAt',
          'errorMessage'
        ],
        messages.map((item) => [
          item.id,
          item.conversationId,
          item.contactName || '',
          item.contactPhone || '',
          item.direction,
          item.type,
          item.status,
          item.body || '',
          item.providerMessageId || '',
          item.sentAt || '',
          item.createdAt,
          item.errorMessage || ''
        ])
      )
    };
  }

  private async collectMessages(
    tenantId: string,
    query: OperationalAuditQuery
  ): Promise<OperationalAuditMessageItem[]> {
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

    return messages.map((message) => ({
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
    }));
  }

  private async collectWebhooks(
    tenantId: string,
    query: OperationalAuditQuery
  ): Promise<OperationalAuditWebhookItem[]> {
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

    return webhooks.map((event) => ({
      id: event.id,
      provider: event.provider,
      eventType: event.eventType || 'unknown',
      eventId: event.eventId || null,
      status: event.status,
      createdAt: event.createdAt.toISOString()
    }));
  }

  private parseLimit(value?: string): number {
    if (!value) {
      return 100;
    }

    const parsed = Number(value);

    if (Number.isNaN(parsed) || parsed < 1) {
      return 100;
    }

    if (parsed > 500) {
      return 500;
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

  private toCsv(headers: string[], rows: Array<Array<string | number>>): string {
    const headerLine = headers.map((item) => this.csvEscape(item)).join(',');
    const rowLines = rows.map((row) => row.map((item) => this.csvEscape(String(item))).join(','));

    return [headerLine, ...rowLines].join('\n') + '\n';
  }

  private csvEscape(value: string): string {
    const cleanValue = value.replace(/\r/g, ' ').replace(/\n/g, ' ');

    if (
      cleanValue.includes(',') ||
      cleanValue.includes('"') ||
      cleanValue.includes(';')
    ) {
      return '"' + cleanValue.replace(/"/g, '""') + '"';
    }

    return cleanValue;
  }

  private timestampForFilename(): string {
    return new Date()
      .toISOString()
      .replace(/[^0-9]/g, '')
      .slice(0, 14);
  }
}
DOC

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" <<'DOC'
import {
  Controller,
  Get,
  Query,
  Res,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { OperationalAuditService } from './operational-audit.service';
import type {
  OperationalAuditExportQuery,
  OperationalAuditQuery
} from './operational-audit.types';

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

  @Get('export')
  async exportReport(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: OperationalAuditExportQuery,
    @Res() response: any
  ) {
    const file = await this.operationalAuditService.exportReport(user.tenantId, query);

    response.setHeader('Content-Type', file.contentType);
    response.setHeader('Content-Disposition', 'attachment; filename="' + file.filename + '"');

    return response.send(file.content);
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

echo "Corrigindo app.module.ts sem blocos quebrados..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()

import_line = "import { OperationalAuditModule } from './modules/operational-audit/operational-audit.module';"

safe_lines = []
for line in text.splitlines():
    if "text.split(\"imports: [\", 1)" in line:
        continue
    safe_lines.append(line)

text = "\n".join(safe_lines) + "\n"

if import_line not in text:
    lines = text.splitlines()
    last_import = -1

    for index, line in enumerate(lines):
        if line.startswith("import "):
            last_import = index

    if last_import < 0:
        raise SystemExit("Nao foi possivel localizar imports em app.module.ts")

    lines.insert(last_import + 1, import_line)
    text = "\n".join(lines) + "\n"

match = re.search(r"imports:\s*\[([\s\S]*?)\]", text)

if not match:
    raise SystemExit("Nao foi possivel localizar bloco imports em app.module.ts")

imports_block = match.group(1)

if "OperationalAuditModule" not in imports_block:
    text = re.sub(
        r"imports:\s*\[",
        "imports: [\n    OperationalAuditModule,",
        text,
        count=1
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

echo "Recriando frontend de auditoria/exportacao..."

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

cat > "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" <<'DOC'
import { FormEvent, useEffect, useState } from 'react';
import {
  downloadAuditExportRequest,
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
  const [exporting, setExporting] = useState(false);
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

  return (
    <section>
      <div className="page-heading">
        <span>Auditoria</span>
        <h1>Painel de auditoria operacional</h1>
        <p>Acompanhe mensagens, webhooks, status e erros operacionais sem expor tokens.</p>
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

echo "Garantindo Sidebar e routes com /app/audit..."

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

echo "Garantindo estilos de auditoria/exportacao..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.audit-summary-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  margin-top: 26px;
}

.audit-summary-grid article,
.audit-panel,
.audit-export-toolbar {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
}

.audit-summary-grid article {
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

.audit-filter-form button,
.audit-export-toolbar button {
  background: #111827;
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

.audit-export-toolbar {
  align-items: center;
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) repeat(4, auto);
  margin-top: 26px;
  padding: 20px;
}

.audit-export-toolbar strong {
  display: block;
}

.audit-export-toolbar p {
  color: #6b7280;
  margin: 4px 0 0;
}

.audit-export-toolbar button:disabled {
  cursor: not-allowed;
  opacity: 0.65;
}

@media (max-width: 1100px) {
  .audit-summary-grid,
  .audit-filter-form {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .audit-table article {
    grid-template-columns: 1fr;
  }

  .audit-export-toolbar {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .audit-export-toolbar div {
    grid-column: 1 / -1;
  }
}

@media (max-width: 640px) {
  .audit-summary-grid,
  .audit-filter-form,
  .audit-export-toolbar {
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

DOMAIN_MESSAGES_EXPORT_CSV_STATUS="$(curl -L -s -o "${DOMAIN_MESSAGES_EXPORT_CSV_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=messages&format=csv&limit=50" || true)"

if [ "${DOMAIN_MESSAGES_EXPORT_CSV_STATUS}" != "200" ]; then
  echo "ERRO: export messages csv falhou. Status ${DOMAIN_MESSAGES_EXPORT_CSV_STATUS}"
  cat "${DOMAIN_MESSAGES_EXPORT_CSV_LOG}"
  exit 1
fi

if ! head -n 1 "${DOMAIN_MESSAGES_EXPORT_CSV_LOG}" | grep -q "providerMessageId"; then
  echo "ERRO: export messages csv nao tem cabecalho esperado."
  head -n 5 "${DOMAIN_MESSAGES_EXPORT_CSV_LOG}"
  exit 1
fi

DOMAIN_MESSAGES_EXPORT_JSON_STATUS="$(curl -L -s -o "${DOMAIN_MESSAGES_EXPORT_JSON_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=messages&format=json&limit=50" || true)"

if [ "${DOMAIN_MESSAGES_EXPORT_JSON_STATUS}" != "200" ]; then
  echo "ERRO: export messages json falhou. Status ${DOMAIN_MESSAGES_EXPORT_JSON_STATUS}"
  cat "${DOMAIN_MESSAGES_EXPORT_JSON_LOG}"
  exit 1
fi

if ! grep -q '"messages"' "${DOMAIN_MESSAGES_EXPORT_JSON_LOG}"; then
  echo "ERRO: export messages json nao contem messages."
  cat "${DOMAIN_MESSAGES_EXPORT_JSON_LOG}"
  exit 1
fi

DOMAIN_WEBHOOKS_EXPORT_CSV_STATUS="$(curl -L -s -o "${DOMAIN_WEBHOOKS_EXPORT_CSV_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=webhooks&format=csv&limit=50" || true)"

if [ "${DOMAIN_WEBHOOKS_EXPORT_CSV_STATUS}" != "200" ]; then
  echo "ERRO: export webhooks csv falhou. Status ${DOMAIN_WEBHOOKS_EXPORT_CSV_STATUS}"
  cat "${DOMAIN_WEBHOOKS_EXPORT_CSV_LOG}"
  exit 1
fi

if ! head -n 1 "${DOMAIN_WEBHOOKS_EXPORT_CSV_LOG}" | grep -q "eventType"; then
  echo "ERRO: export webhooks csv nao tem cabecalho esperado."
  head -n 5 "${DOMAIN_WEBHOOKS_EXPORT_CSV_LOG}"
  exit 1
fi

DOMAIN_WEBHOOKS_EXPORT_JSON_STATUS="$(curl -L -s -o "${DOMAIN_WEBHOOKS_EXPORT_JSON_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=webhooks&format=json&limit=50" || true)"

if [ "${DOMAIN_WEBHOOKS_EXPORT_JSON_STATUS}" != "200" ]; then
  echo "ERRO: export webhooks json falhou. Status ${DOMAIN_WEBHOOKS_EXPORT_JSON_STATUS}"
  cat "${DOMAIN_WEBHOOKS_EXPORT_JSON_LOG}"
  exit 1
fi

if ! grep -q '"webhooks"' "${DOMAIN_WEBHOOKS_EXPORT_JSON_LOG}"; then
  echo "ERRO: export webhooks json nao contem webhooks."
  cat "${DOMAIN_WEBHOOKS_EXPORT_JSON_LOG}"
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

echo "Gerando documentacao da Etapa 46..."

cat > "${DOC_FILE}" <<'DOC'
# Operational Export Report

## Visao geral

Este documento registra a criacao dos relatorios operacionais exportaveis.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi criada uma correcao full para recriar os arquivos frontend ausentes da auditoria e garantir o backend completo de exportacao.

## Funcionalidades criadas

Funcionalidades:

- exportar mensagens operacionais em CSV
- exportar mensagens operacionais em JSON
- exportar webhooks operacionais em CSV
- exportar webhooks operacionais em JSON
- aplicar filtros atuais da auditoria na exportacao
- download no frontend sem expor token
- nomes de arquivos com timestamp
- cabecalhos CSV padronizados
- endpoint protegido por autenticacao
- tela app audit com botoes de download

## Endpoints criados

Endpoints:

- GET api v1 operational audit export

Parametros:

- resource messages ou webhooks
- format csv ou json
- status opcional
- direction opcional para mensagens
- type opcional
- limit opcional

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/operational-audit/operational-audit.types.ts
- apps/backend/src/modules/operational-audit/operational-audit.service.ts
- apps/backend/src/modules/operational-audit/operational-audit.controller.ts
- apps/backend/src/modules/operational-audit/operational-audit.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit/AuditPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/OPERATIONAL_EXPORT_REPORT.md
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
- endpoint summary dominio
- export messages csv dominio
- export messages json dominio
- export webhooks csv dominio
- export webhooks json dominio
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_46_backend_typecheck.log
- logs/setup_46_backend_build.log
- logs/setup_46_frontend_typecheck.log
- logs/setup_46_frontend_build.log
- logs/setup_46_backend_docker_build.log
- logs/setup_46_frontend_docker_build.log
- logs/setup_46_docker_up.log
- logs/setup_46_backend_wait.log
- logs/setup_46_auth_login_domain.log
- logs/setup_46_audit_summary_domain.log
- logs/setup_46_export_messages_csv_domain.log
- logs/setup_46_export_messages_json_domain.log
- logs/setup_46_export_webhooks_csv_domain.log
- logs/setup_46_export_webhooks_json_domain.log
- logs/setup_46_domain_audit_page.log
- logs/setup_46_domain_dashboard.log
- logs/setup_46.log
- logs/fix_46_operational_export_report_full.log

## Proxima etapa sugerida

Etapa 47:

    Criar higienizacao de dados de auditoria antigos
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
- [ ] Etapa 47 - Higienizacao de dados de auditoria antigos

## Ultima etapa executada

Etapa 46 - Relatorio operacional exportavel.

## Proxima etapa sugerida

Etapa 47 - Criar higienizacao de dados de auditoria antigos.
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

Painel de configuracao operacional da conta Meta criado.

Limpeza operacional de dados de teste criada.

Painel de auditoria operacional criado.

Relatorio operacional exportavel criado.

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
- docs/META_OPERATIONAL_PANEL.md
- docs/OPERATIONAL_CLEANUP.md
- docs/OPERATIONAL_AUDIT_PANEL.md
- docs/OPERATIONAL_EXPORT_REPORT.md

## Etapas concluidas

- Etapa 01 ate Etapa 46 concluidas

## Proxima etapa

- Etapa 47 - Higienizacao de dados de auditoria antigos
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
Etapa: 46
Acao: Relatorio operacional exportavel
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Summary status: ${DOMAIN_SUMMARY_STATUS}
Messages CSV export status: ${DOMAIN_MESSAGES_EXPORT_CSV_STATUS}
Messages JSON export status: ${DOMAIN_MESSAGES_EXPORT_JSON_STATUS}
Webhooks CSV export status: ${DOMAIN_WEBHOOKS_EXPORT_CSV_STATUS}
Webhooks JSON export status: ${DOMAIN_WEBHOOKS_EXPORT_JSON_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 46
Acao: Fix full relatorio operacional exportavel
Data: $(date '+%Y-%m-%d %H:%M:%S')
Status: Concluido
DOC

echo ""
echo "== Etapa 46 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/audit"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 47 - Criar higienizacao de dados de auditoria antigos"
