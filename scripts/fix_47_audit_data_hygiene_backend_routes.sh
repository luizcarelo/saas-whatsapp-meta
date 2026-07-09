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

LOG_FILE="${LOGS_DIR}/setup_47.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_47_audit_data_hygiene_backend_routes.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_47_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_47_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_47_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_47_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_47_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_47_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_47_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_47_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_47_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_47_auth_login_domain.log"
DOMAIN_SUMMARY_LOG="${LOGS_DIR}/setup_47_audit_summary_domain.log"
DOMAIN_HYGIENE_PREVIEW_LOG="${LOGS_DIR}/setup_47_hygiene_preview_domain.log"
DOMAIN_HYGIENE_DRYRUN_LOG="${LOGS_DIR}/setup_47_hygiene_dryrun_domain.log"
DOMAIN_EXPORT_JSON_LOG="${LOGS_DIR}/setup_47_export_messages_json_domain.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_47_domain_audit_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_47_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/AUDIT_DATA_HYGIENE.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Fix Etapa 47: rotas backend de higienizacao de auditoria =="

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
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.types.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
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

echo "Regravando types backend de auditoria..."

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

export type OperationalAuditHygieneQuery = {
  days?: string;
};

export type OperationalAuditHygienePayload = {
  days?: number;
  dryRun?: boolean;
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

export type OperationalAuditHygieneResponse = {
  success: true;
  data: {
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
  meta: Record<string, never>;
};
DOC

echo "Regravando service backend de auditoria com hygiene-preview e hygiene-run..."

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
  OperationalAuditHygienePayload,
  OperationalAuditHygieneQuery,
  OperationalAuditHygieneResponse,
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

  async previewHygiene(
    tenantId: string,
    query: OperationalAuditHygieneQuery
  ): Promise<OperationalAuditHygieneResponse> {
    const days = this.parseRetentionDays(query.days);

    return this.runHygiene(tenantId, {
      days,
      dryRun: true
    });
  }

  async runHygiene(
    tenantId: string,
    payload: OperationalAuditHygienePayload
  ): Promise<OperationalAuditHygieneResponse> {
    const days = this.parseRetentionDays(String(payload.days || '90'));
    const dryRun = payload.dryRun !== false;
    const cutoff = this.cutoffDate(days);

    const oldMessages = await this.prismaService.message.count({
      where: {
        tenantId,
        createdAt: {
          lt: cutoff
        }
      }
    });

    const oldFailedMessagesWithMetadata = await this.prismaService.message.count({
      where: {
        tenantId,
        status: MessageStatus.failed,
        createdAt: {
          lt: cutoff
        }
      }
    });

    const oldWebhookEvents = await this.prismaService.webhookEvent.count({
      where: {
        tenantId,
        createdAt: {
          lt: cutoff
        }
      }
    });

    let messagesRedacted = 0;
    let webhookEventsRedacted = 0;

    if (!dryRun) {
      const messageUpdate = await this.prismaService.message.updateMany({
        where: {
          tenantId,
          status: MessageStatus.failed,
          createdAt: {
            lt: cutoff
          }
        },
        data: {
          metadata: {
            hygiene: {
              redacted: true,
              reason: 'old_audit_data',
              redactedAt: new Date().toISOString()
            }
          } as never
        }
      });

      const webhookUpdate = await this.prismaService.webhookEvent.updateMany({
        where: {
          tenantId,
          createdAt: {
            lt: cutoff
          }
        },
        data: {
          payload: {
            hygiene: {
              redacted: true,
              reason: 'old_audit_data',
              redactedAt: new Date().toISOString()
            }
          } as never
        }
      });

      messagesRedacted = messageUpdate.count;
      webhookEventsRedacted = webhookUpdate.count;
    }

    return {
      success: true,
      data: {
        dryRun,
        days,
        cutoff: cutoff.toISOString(),
        candidates: {
          oldMessages,
          oldFailedMessagesWithMetadata,
          oldWebhookEvents
        },
        changed: {
          messagesRedacted,
          webhookEventsRedacted
        }
      },
      meta: {}
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

  private parseRetentionDays(value?: string): number {
    if (!value) {
      return 90;
    }

    const parsed = Number(value);

    if (Number.isNaN(parsed) || parsed < 1) {
      return 90;
    }

    if (parsed > 3650) {
      return 3650;
    }

    return parsed;
  }

  private cutoffDate(days: number): Date {
    const date = new Date();

    date.setDate(date.getDate() - days);

    return date;
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

echo "Regravando controller backend com rotas hygiene..."

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Get,
  Post,
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
  OperationalAuditHygienePayload,
  OperationalAuditHygieneQuery,
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

  @Get('hygiene-preview')
  previewHygiene(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: OperationalAuditHygieneQuery
  ) {
    return this.operationalAuditService.previewHygiene(user.tenantId, query);
  }

  @Post('hygiene-run')
  runHygiene(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: OperationalAuditHygienePayload
  ) {
    return this.operationalAuditService.runHygiene(user.tenantId, body);
  }
}
DOC

echo "Garantindo modulo backend e app.module..."

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

echo "Validando dominio e endpoints hygiene..."

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

DOMAIN_EXPORT_JSON_STATUS="$(curl -L -s -o "${DOMAIN_EXPORT_JSON_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=messages&format=json&limit=50" || true)"

if [ "${DOMAIN_EXPORT_JSON_STATUS}" != "200" ]; then
  echo "ERRO: export json falhou. Status ${DOMAIN_EXPORT_JSON_STATUS}"
  cat "${DOMAIN_EXPORT_JSON_LOG}"
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

echo "Gerando documentacao da Etapa 47..."

cat > "${DOC_FILE}" <<'DOC'
# Audit Data Hygiene

## Visao geral

Este documento registra a higienizacao de dados antigos de auditoria.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi corrigida a publicacao das rotas backend de higienizacao:

- GET api v1 operational audit hygiene preview
- POST api v1 operational audit hygiene run

O backend foi rebuildado e redeployado para evitar retorno 404.

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
- redacao de metadata antiga quando execucao real for solicitada
- redacao de payload antigo de webhook quando execucao real for solicitada
- painel visual no app audit
- validacao sem alteracao automatica de dados

## Endpoints criados

Endpoints:

- GET api v1 operational audit hygiene preview
- POST api v1 operational audit hygiene run

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
- docs/AUDIT_DATA_HYGIENE.md
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
- endpoint hygiene preview dominio
- endpoint hygiene dry run dominio
- export messages json dominio
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_47_backend_typecheck.log
- logs/setup_47_backend_build.log
- logs/setup_47_frontend_typecheck.log
- logs/setup_47_frontend_build.log
- logs/setup_47_backend_docker_build.log
- logs/setup_47_frontend_docker_build.log
- logs/setup_47_docker_up.log
- logs/setup_47_backend_wait.log
- logs/setup_47_auth_login_domain.log
- logs/setup_47_audit_summary_domain.log
- logs/setup_47_hygiene_preview_domain.log
- logs/setup_47_hygiene_dryrun_domain.log
- logs/setup_47_export_messages_json_domain.log
- logs/setup_47_domain_audit_page.log
- logs/setup_47_domain_dashboard.log
- logs/setup_47.log
- logs/fix_47_audit_data_hygiene_backend_routes.log

## Observacoes

A etapa nao apaga dados automaticamente.

A execucao real deve ser feita somente depois de revisar o preview e confirmar a politica de retencao desejada.

## Proxima etapa sugerida

Etapa 48:

    Criar configuracao visual de politica de retencao
DOC

echo "Atualizando controle e manifesto..."

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

Higienizacao de dados de auditoria antigos criada.

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
- docs/AUDIT_DATA_HYGIENE.md

## Etapas concluidas

- Etapa 01 ate Etapa 47 concluidas

## Proxima etapa

- Etapa 48 - Configuracao visual de politica de retencao
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
Etapa: 47
Acao: Higienizacao de dados de auditoria antigos
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Summary status: ${DOMAIN_SUMMARY_STATUS}
Hygiene preview status: ${DOMAIN_HYGIENE_PREVIEW_STATUS}
Hygiene dry-run status: ${DOMAIN_HYGIENE_DRYRUN_STATUS}
Export JSON status: ${DOMAIN_EXPORT_JSON_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 47
Acao: Correcao rotas backend de higienizacao de auditoria
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
