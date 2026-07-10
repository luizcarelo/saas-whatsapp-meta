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

LOG_FILE="${LOGS_DIR}/setup_49.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_49_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_49_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_49_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_49_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_49_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_49_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_49_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_49_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_49_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_49_auth_login_domain.log"
DOMAIN_GET_POLICY_LOG="${LOGS_DIR}/setup_49_retention_policy_get_domain.log"
DOMAIN_PATCH_POLICY_LOG="${LOGS_DIR}/setup_49_retention_policy_patch_domain.log"
DOMAIN_GET_POLICY_AFTER_LOG="${LOGS_DIR}/setup_49_retention_policy_get_after_domain.log"
DOMAIN_HYGIENE_PREVIEW_LOG="${LOGS_DIR}/setup_49_hygiene_preview_domain.log"
DOMAIN_HYGIENE_DRYRUN_LOG="${LOGS_DIR}/setup_49_hygiene_dryrun_domain.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_49_domain_audit_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_49_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/RETENTION_POLICY_BACKEND.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Etapa 49: Persistencia backend da politica de retencao por tenant =="

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
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md" \
  "${BASE_DIR}/CONTEXTO_PROJETO.md" \
  "${BASE_DIR}/CHANGELOG.md" \
  "${BASE_DIR}/DECISOES_TECNICAS.md" \
  "${BASE_DIR}/PENDENCIAS.md"
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

echo "Criando tabela de politica de retencao se necessario..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists operational_audit_settings (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null unique,
  audit_retention_days integer not null default 90,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_operational_audit_settings_tenant_id
on operational_audit_settings (tenant_id);
SQL

echo "Atualizando types backend..."

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

export type OperationalAuditRetentionPolicyPayload = {
  auditRetentionDays?: number;
};

export type OperationalAuditRetentionPolicyResponse = {
  success: true;
  data: {
    auditRetentionDays: number;
    source: string;
    updatedAt: string | null;
  };
  meta: Record<string, never>;
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

echo "Atualizando service backend..."

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
  OperationalAuditRetentionPolicyPayload,
  OperationalAuditRetentionPolicyResponse,
  OperationalAuditSummaryResponse,
  OperationalAuditWebhookItem,
  OperationalAuditWebhooksResponse
} from './operational-audit.types';

type RetentionPolicyRow = {
  audit_retention_days: number;
  updated_at: Date | null;
};

@Injectable()
export class OperationalAuditService {
  constructor(private readonly prismaService: PrismaService) {}

  async getRetentionPolicy(tenantId: string): Promise<OperationalAuditRetentionPolicyResponse> {
    const row = await this.findRetentionPolicyRow(tenantId);

    if (!row) {
      return {
        success: true,
        data: {
          auditRetentionDays: 90,
          source: 'default',
          updatedAt: null
        },
        meta: {}
      };
    }

    return {
      success: true,
      data: {
        auditRetentionDays: row.audit_retention_days,
        source: 'backend',
        updatedAt: row.updated_at ? row.updated_at.toISOString() : null
      },
      meta: {}
    };
  }

  async updateRetentionPolicy(
    tenantId: string,
    payload: OperationalAuditRetentionPolicyPayload
  ): Promise<OperationalAuditRetentionPolicyResponse> {
    const days = this.parseRetentionDays(String(payload.auditRetentionDays || '90'));

    await this.prismaService.$executeRawUnsafe(
      'insert into operational_audit_settings (tenant_id, audit_retention_days, created_at, updated_at) values ($1::uuid, $2, now(), now()) on conflict (tenant_id) do update set audit_retention_days = excluded.audit_retention_days, updated_at = now()',
      tenantId,
      days
    );

    const row = await this.findRetentionPolicyRow(tenantId);

    return {
      success: true,
      data: {
        auditRetentionDays: row?.audit_retention_days || days,
        source: 'backend',
        updatedAt: row?.updated_at ? row.updated_at.toISOString() : null
      },
      meta: {}
    };
  }

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
    const policy = await this.getRetentionPolicy(tenantId);
    const fallbackDays = policy.data.auditRetentionDays;
    const days = query.days ? this.parseRetentionDays(query.days) : fallbackDays;

    return this.runHygiene(tenantId, {
      days,
      dryRun: true
    });
  }

  async runHygiene(
    tenantId: string,
    payload: OperationalAuditHygienePayload
  ): Promise<OperationalAuditHygieneResponse> {
    const policy = await this.getRetentionPolicy(tenantId);
    const days = payload.days ? this.parseRetentionDays(String(payload.days)) : policy.data.auditRetentionDays;
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

  private async findRetentionPolicyRow(tenantId: string): Promise<RetentionPolicyRow | null> {
    const rows = await this.prismaService.$queryRawUnsafe<RetentionPolicyRow[]>(
      'select audit_retention_days, updated_at from operational_audit_settings where tenant_id = $1::uuid limit 1',
      tenantId
    );

    return rows[0] || null;
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
cat <<'EOF' >> scripts/setup_49_retention_policy_backend.sh

echo "Atualizando controller backend..."

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Get,
  Patch,
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
  OperationalAuditQuery,
  OperationalAuditRetentionPolicyPayload
} from './operational-audit.types';

@Controller('operational-audit')
@UseGuards(JwtAuthGuard)
export class OperationalAuditController {
  constructor(private readonly operationalAuditService: OperationalAuditService) {}

  @Get('retention-policy')
  getRetentionPolicy(@CurrentUser() user: AuthenticatedUser) {
    return this.operationalAuditService.getRetentionPolicy(user.tenantId);
  }

  @Patch('retention-policy')
  updateRetentionPolicy(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: OperationalAuditRetentionPolicyPayload
  ) {
    return this.operationalAuditService.updateRetentionPolicy(user.tenantId, body);
  }

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

echo "Atualizando types frontend..."

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

export type AuditRetentionPolicy = {
  auditRetentionDays: number;
  source: string;
  updatedAt: string | null;
};

export type AuditSummaryData = AuditSummary;

export type AuditMessagesData = {
  messages: AuditMessageItem[];
};

export type AuditWebhooksData = {
  webhooks: AuditWebhookItem[];
};

export type AuditHygieneData = AuditHygieneResult;

export type AuditRetentionPolicyData = AuditRetentionPolicy;
DOC

echo "Atualizando service frontend..."

cat > "${FRONTEND_DIR}/src/services/operational-audit.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AuditHygieneData,
  AuditMessagesData,
  AuditRetentionPolicyData,
  AuditSummaryData,
  AuditWebhooksData
} from '../types/operational-audit.types';

export async function getAuditRetentionPolicyRequest(token: string) {
  return apiRequest<AuditRetentionPolicyData>('/operational-audit/retention-policy', {
    method: 'GET',
    token
  });
}

export async function updateAuditRetentionPolicyRequest(token: string, auditRetentionDays: number) {
  return apiRequest<AuditRetentionPolicyData>('/operational-audit/retention-policy', {
    method: 'PATCH',
    token,
    body: {
      auditRetentionDays
    }
  });
}

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

export async function previewAuditHygieneRequest(token: string, days?: number) {
  const suffix = days ? '?days=' + encodeURIComponent(String(days)) : '';

  return apiRequest<AuditHygieneData>('/operational-audit/hygiene-preview' + suffix, {
    method: 'GET',
    token
  });
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
cat <<'EOF' >> scripts/setup_49_retention_policy_backend.sh

echo "Atualizando AuditPage.tsx..."

cat > "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" <<'DOC'
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
DOC
cat <<'EOF' >> scripts/setup_49_retention_policy_backend.sh

echo "Garantindo estilos da politica de retencao..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.retention-policy-panel {
  align-items: center;
  background: #eff6ff;
  border: 1px solid #bfdbfe;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.06);
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) 160px minmax(260px, auto) auto;
  margin-top: 22px;
  padding: 20px;
}

.retention-policy-panel strong {
  color: #1d4ed8;
  display: block;
}

.retention-policy-panel p {
  color: #1e40af;
  margin: 4px 0 0;
}

.retention-policy-panel label {
  color: #1e40af;
  display: grid;
  font-size: 13px;
  font-weight: 900;
  gap: 6px;
}

.retention-policy-panel input {
  border: 1px solid #93c5fd;
  border-radius: 14px;
  padding: 10px 12px;
}

.retention-policy-panel button {
  background: #2563eb;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 14px;
}

.retention-quick-options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.retention-quick-options button {
  background: #dbeafe;
  color: #1d4ed8;
}

@media (max-width: 1100px) {
  .retention-policy-panel {
    grid-template-columns: 1fr 160px;
  }

  .retention-quick-options {
    grid-column: 1 / -1;
  }
}

@media (max-width: 700px) {
  .retention-policy-panel {
    grid-template-columns: 1fr;
  }

  .retention-quick-options {
    grid-column: auto;
  }
}
DOC

echo "Validando frontend sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
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

DOMAIN_GET_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_GET_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_GET_POLICY_STATUS}" != "200" ]; then
  echo "ERRO: get retention policy falhou. Status ${DOMAIN_GET_POLICY_STATUS}"
  cat "${DOMAIN_GET_POLICY_LOG}"
  exit 1
fi

PATCH_PAYLOAD="$(node -e "console.log(JSON.stringify({auditRetentionDays:180}))")"

DOMAIN_PATCH_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_PATCH_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -X PATCH \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${PATCH_PAYLOAD}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_PATCH_POLICY_STATUS}" != "200" ] && [ "${DOMAIN_PATCH_POLICY_STATUS}" != "201" ]; then
  echo "ERRO: patch retention policy falhou. Status ${DOMAIN_PATCH_POLICY_STATUS}"
  cat "${DOMAIN_PATCH_POLICY_LOG}"
  exit 1
fi

if ! grep -q '"auditRetentionDays":180' "${DOMAIN_PATCH_POLICY_LOG}"; then
  echo "ERRO: patch nao confirmou auditRetentionDays 180."
  cat "${DOMAIN_PATCH_POLICY_LOG}"
  exit 1
fi

DOMAIN_GET_POLICY_AFTER_STATUS="$(curl -L -s -o "${DOMAIN_GET_POLICY_AFTER_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_GET_POLICY_AFTER_STATUS}" != "200" ]; then
  echo "ERRO: get retention policy after falhou. Status ${DOMAIN_GET_POLICY_AFTER_STATUS}"
  cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
  exit 1
fi

if ! grep -q '"auditRetentionDays":180' "${DOMAIN_GET_POLICY_AFTER_LOG}"; then
  echo "ERRO: get after nao confirmou auditRetentionDays 180."
  cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_PREVIEW_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_PREVIEW_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/hygiene-preview" || true)"

if [ "${DOMAIN_HYGIENE_PREVIEW_STATUS}" != "200" ]; then
  echo "ERRO: hygiene preview sem days falhou. Status ${DOMAIN_HYGIENE_PREVIEW_STATUS}"
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

if ! grep -q '"days":180' "${DOMAIN_HYGIENE_PREVIEW_LOG}"; then
  echo "ERRO: hygiene preview nao usou politica persistida de 180 dias."
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_DRYRUN_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_DRYRUN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"dryRun":true}' \
  "${DOMAIN_AUDIT_URL}/hygiene-run" || true)"

if [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "200" ] && [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "201" ]; then
  echo "ERRO: hygiene dry-run sem days falhou. Status ${DOMAIN_HYGIENE_DRYRUN_STATUS}"
  cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
  exit 1
fi

if ! grep -q '"days":180' "${DOMAIN_HYGIENE_DRYRUN_LOG}"; then
  echo "ERRO: hygiene dry-run nao usou politica persistida de 180 dias."
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

echo "Gerando documentacao da Etapa 49..."

cat > "${DOC_FILE}" <<'DOC'
# Retention Policy Backend

## Visao geral

Este documento registra a persistencia backend da politica de retencao por tenant.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela operational audit settings
- politica de retencao por tenant
- endpoint para consultar politica de retencao
- endpoint para atualizar politica de retencao
- uso da politica persistida no preview de higienizacao
- uso da politica persistida no dry-run de higienizacao
- integracao do painel app audit com backend
- fallback local caso backend nao carregue
- validacao sem executar higienizacao real

## Endpoints criados

Endpoints:

- GET api v1 operational audit retention policy
- PATCH api v1 operational audit retention policy

## Tabela criada

Tabela:

- operational audit settings

Campos:

- id
- tenant id
- audit retention days
- created at
- updated at

## Politica de seguranca

A etapa nao executa higienizacao real.

A validacao executa GET e PATCH da politica e depois usa preview e dry-run seguro.

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
- apps/frontend/src/styles.css
- docs/RETENTION_POLICY_BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela operational audit settings
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- GET retention policy dominio
- PATCH retention policy dominio com 180 dias
- GET retention policy after dominio
- hygiene preview usando politica persistida
- hygiene dry-run usando politica persistida
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_49_backend_typecheck.log
- logs/setup_49_backend_build.log
- logs/setup_49_frontend_typecheck.log
- logs/setup_49_frontend_build.log
- logs/setup_49_backend_docker_build.log
- logs/setup_49_frontend_docker_build.log
- logs/setup_49_docker_up.log
- logs/setup_49_backend_wait.log
- logs/setup_49_auth_login_domain.log
- logs/setup_49_retention_policy_get_domain.log
- logs/setup_49_retention_policy_patch_domain.log
- logs/setup_49_retention_policy_get_after_domain.log
- logs/setup_49_hygiene_preview_domain.log
- logs/setup_49_hygiene_dryrun_domain.log
- logs/setup_49_domain_audit_page.log
- logs/setup_49_domain_dashboard.log
- logs/setup_49.log

## Proxima etapa sugerida

Etapa 50:

    Criar execucao operacional controlada de higienizacao real
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
- [x] Etapa 48 - Configuracao visual de politica de retencao
- [x] Etapa 49 - Persistencia backend da politica de retencao por tenant
- [ ] Etapa 50 - Execucao operacional controlada de higienizacao real

## Ultima etapa executada

Etapa 49 - Persistencia backend da politica de retencao por tenant.

## Proxima etapa sugerida

Etapa 50 - Criar execucao operacional controlada de higienizacao real.
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

Higienizacao de dados de auditoria antigos criada.

Configuracao visual de politica de retencao criada.

Persistencia backend da politica de retencao por tenant criada.

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
- docs/RETENTION_POLICY_VISUAL_CONFIG.md
- docs/RETENTION_POLICY_BACKEND.md

## Etapas concluidas

- Etapa 01 ate Etapa 49 concluidas

## Proxima etapa

- Etapa 50 - Execucao operacional controlada de higienizacao real
DOC

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 49 - Persistencia backend da politica de retencao por tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada tabela operational audit settings e endpoints para consultar e atualizar auditRetentionDays por tenant. O painel de auditoria passou a carregar e salvar a politica no backend.
DOC
  fi
done

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
Etapa: 49
Acao: Persistencia backend da politica de retencao por tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
GET policy status: ${DOMAIN_GET_POLICY_STATUS}
PATCH policy status: ${DOMAIN_PATCH_POLICY_STATUS}
GET policy after status: ${DOMAIN_GET_POLICY_AFTER_STATUS}
Hygiene preview status: ${DOMAIN_HYGIENE_PREVIEW_STATUS}
Hygiene dry-run status: ${DOMAIN_HYGIENE_DRYRUN_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 49 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Politica apos PATCH:"
cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
echo ""
echo "Preview usando politica persistida:"
cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
echo ""
echo "Dry-run usando politica persistida:"
cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 50 - Criar execucao operacional controlada de higienizacao real"

echo "Atualizando controller backend..."

cat > "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Get,
  Patch,
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
  OperationalAuditQuery,
  OperationalAuditRetentionPolicyPayload
} from './operational-audit.types';

@Controller('operational-audit')
@UseGuards(JwtAuthGuard)
export class OperationalAuditController {
  constructor(private readonly operationalAuditService: OperationalAuditService) {}

  @Get('retention-policy')
  getRetentionPolicy(@CurrentUser() user: AuthenticatedUser) {
    return this.operationalAuditService.getRetentionPolicy(user.tenantId);
  }

  @Patch('retention-policy')
  updateRetentionPolicy(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: OperationalAuditRetentionPolicyPayload
  ) {
    return this.operationalAuditService.updateRetentionPolicy(user.tenantId, body);
  }

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

echo "Atualizando types frontend..."

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

export type AuditRetentionPolicy = {
  auditRetentionDays: number;
  source: string;
  updatedAt: string | null;
};

export type AuditSummaryData = AuditSummary;

export type AuditMessagesData = {
  messages: AuditMessageItem[];
};

export type AuditWebhooksData = {
  webhooks: AuditWebhookItem[];
};

export type AuditHygieneData = AuditHygieneResult;

export type AuditRetentionPolicyData = AuditRetentionPolicy;
DOC

echo "Atualizando service frontend..."

cat > "${FRONTEND_DIR}/src/services/operational-audit.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AuditHygieneData,
  AuditMessagesData,
  AuditRetentionPolicyData,
  AuditSummaryData,
  AuditWebhooksData
} from '../types/operational-audit.types';

export async function getAuditRetentionPolicyRequest(token: string) {
  return apiRequest<AuditRetentionPolicyData>('/operational-audit/retention-policy', {
    method: 'GET',
    token
  });
}

export async function updateAuditRetentionPolicyRequest(token: string, auditRetentionDays: number) {
  return apiRequest<AuditRetentionPolicyData>('/operational-audit/retention-policy', {
    method: 'PATCH',
    token,
    body: {
      auditRetentionDays
    }
  });
}

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

export async function previewAuditHygieneRequest(token: string, days?: number) {
  const suffix = days ? '?days=' + encodeURIComponent(String(days)) : '';

  return apiRequest<AuditHygieneData>('/operational-audit/hygiene-preview' + suffix, {
    method: 'GET',
    token
  });
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
cat <<'EOF' >> scripts/setup_49_retention_policy_backend.sh

echo "Atualizando AuditPage.tsx..."

cat > "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" <<'DOC'
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
DOC
cat <<'EOF' >> scripts/setup_49_retention_policy_backend.sh

echo "Garantindo estilos da politica de retencao..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.retention-policy-panel {
  align-items: center;
  background: #eff6ff;
  border: 1px solid #bfdbfe;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.06);
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) 160px minmax(260px, auto) auto;
  margin-top: 22px;
  padding: 20px;
}

.retention-policy-panel strong {
  color: #1d4ed8;
  display: block;
}

.retention-policy-panel p {
  color: #1e40af;
  margin: 4px 0 0;
}

.retention-policy-panel label {
  color: #1e40af;
  display: grid;
  font-size: 13px;
  font-weight: 900;
  gap: 6px;
}

.retention-policy-panel input {
  border: 1px solid #93c5fd;
  border-radius: 14px;
  padding: 10px 12px;
}

.retention-policy-panel button {
  background: #2563eb;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 14px;
}

.retention-quick-options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.retention-quick-options button {
  background: #dbeafe;
  color: #1d4ed8;
}

@media (max-width: 1100px) {
  .retention-policy-panel {
    grid-template-columns: 1fr 160px;
  }

  .retention-quick-options {
    grid-column: 1 / -1;
  }
}

@media (max-width: 700px) {
  .retention-policy-panel {
    grid-template-columns: 1fr;
  }

  .retention-quick-options {
    grid-column: auto;
  }
}
DOC

echo "Validando frontend sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
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

DOMAIN_GET_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_GET_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_GET_POLICY_STATUS}" != "200" ]; then
  echo "ERRO: get retention policy falhou. Status ${DOMAIN_GET_POLICY_STATUS}"
  cat "${DOMAIN_GET_POLICY_LOG}"
  exit 1
fi

PATCH_PAYLOAD="$(node -e "console.log(JSON.stringify({auditRetentionDays:180}))")"

DOMAIN_PATCH_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_PATCH_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -X PATCH \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${PATCH_PAYLOAD}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_PATCH_POLICY_STATUS}" != "200" ] && [ "${DOMAIN_PATCH_POLICY_STATUS}" != "201" ]; then
  echo "ERRO: patch retention policy falhou. Status ${DOMAIN_PATCH_POLICY_STATUS}"
  cat "${DOMAIN_PATCH_POLICY_LOG}"
  exit 1
fi

if ! grep -q '"auditRetentionDays":180' "${DOMAIN_PATCH_POLICY_LOG}"; then
  echo "ERRO: patch nao confirmou auditRetentionDays 180."
  cat "${DOMAIN_PATCH_POLICY_LOG}"
  exit 1
fi

DOMAIN_GET_POLICY_AFTER_STATUS="$(curl -L -s -o "${DOMAIN_GET_POLICY_AFTER_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_GET_POLICY_AFTER_STATUS}" != "200" ]; then
  echo "ERRO: get retention policy after falhou. Status ${DOMAIN_GET_POLICY_AFTER_STATUS}"
  cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
  exit 1
fi

if ! grep -q '"auditRetentionDays":180' "${DOMAIN_GET_POLICY_AFTER_LOG}"; then
  echo "ERRO: get after nao confirmou auditRetentionDays 180."
  cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_PREVIEW_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_PREVIEW_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/hygiene-preview" || true)"

if [ "${DOMAIN_HYGIENE_PREVIEW_STATUS}" != "200" ]; then
  echo "ERRO: hygiene preview sem days falhou. Status ${DOMAIN_HYGIENE_PREVIEW_STATUS}"
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

if ! grep -q '"days":180' "${DOMAIN_HYGIENE_PREVIEW_LOG}"; then
  echo "ERRO: hygiene preview nao usou politica persistida de 180 dias."
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_DRYRUN_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_DRYRUN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"dryRun":true}' \
  "${DOMAIN_AUDIT_URL}/hygiene-run" || true)"

if [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "200" ] && [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "201" ]; then
  echo "ERRO: hygiene dry-run sem days falhou. Status ${DOMAIN_HYGIENE_DRYRUN_STATUS}"
  cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
  exit 1
fi

if ! grep -q '"days":180' "${DOMAIN_HYGIENE_DRYRUN_LOG}"; then
  echo "ERRO: hygiene dry-run nao usou politica persistida de 180 dias."
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

echo "Gerando documentacao da Etapa 49..."

cat > "${DOC_FILE}" <<'DOC'
# Retention Policy Backend

## Visao geral

Este documento registra a persistencia backend da politica de retencao por tenant.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela operational audit settings
- politica de retencao por tenant
- endpoint para consultar politica de retencao
- endpoint para atualizar politica de retencao
- uso da politica persistida no preview de higienizacao
- uso da politica persistida no dry-run de higienizacao
- integracao do painel app audit com backend
- fallback local caso backend nao carregue
- validacao sem executar higienizacao real

## Endpoints criados

Endpoints:

- GET api v1 operational audit retention policy
- PATCH api v1 operational audit retention policy

## Tabela criada

Tabela:

- operational audit settings

Campos:

- id
- tenant id
- audit retention days
- created at
- updated at

## Politica de seguranca

A etapa nao executa higienizacao real.

A validacao executa GET e PATCH da politica e depois usa preview e dry-run seguro.

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
- apps/frontend/src/styles.css
- docs/RETENTION_POLICY_BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela operational audit settings
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- GET retention policy dominio
- PATCH retention policy dominio com 180 dias
- GET retention policy after dominio
- hygiene preview usando politica persistida
- hygiene dry-run usando politica persistida
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_49_backend_typecheck.log
- logs/setup_49_backend_build.log
- logs/setup_49_frontend_typecheck.log
- logs/setup_49_frontend_build.log
- logs/setup_49_backend_docker_build.log
- logs/setup_49_frontend_docker_build.log
- logs/setup_49_docker_up.log
- logs/setup_49_backend_wait.log
- logs/setup_49_auth_login_domain.log
- logs/setup_49_retention_policy_get_domain.log
- logs/setup_49_retention_policy_patch_domain.log
- logs/setup_49_retention_policy_get_after_domain.log
- logs/setup_49_hygiene_preview_domain.log
- logs/setup_49_hygiene_dryrun_domain.log
- logs/setup_49_domain_audit_page.log
- logs/setup_49_domain_dashboard.log
- logs/setup_49.log

## Proxima etapa sugerida

Etapa 50:

    Criar execucao operacional controlada de higienizacao real
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
- [x] Etapa 48 - Configuracao visual de politica de retencao
- [x] Etapa 49 - Persistencia backend da politica de retencao por tenant
- [ ] Etapa 50 - Execucao operacional controlada de higienizacao real

## Ultima etapa executada

Etapa 49 - Persistencia backend da politica de retencao por tenant.

## Proxima etapa sugerida

Etapa 50 - Criar execucao operacional controlada de higienizacao real.
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

Higienizacao de dados de auditoria antigos criada.

Configuracao visual de politica de retencao criada.

Persistencia backend da politica de retencao por tenant criada.

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
- docs/RETENTION_POLICY_VISUAL_CONFIG.md
- docs/RETENTION_POLICY_BACKEND.md

## Etapas concluidas

- Etapa 01 ate Etapa 49 concluidas

## Proxima etapa

- Etapa 50 - Execucao operacional controlada de higienizacao real
DOC

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 49 - Persistencia backend da politica de retencao por tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada tabela operational audit settings e endpoints para consultar e atualizar auditRetentionDays por tenant. O painel de auditoria passou a carregar e salvar a politica no backend.
DOC
  fi
done

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
Etapa: 49
Acao: Persistencia backend da politica de retencao por tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
GET policy status: ${DOMAIN_GET_POLICY_STATUS}
PATCH policy status: ${DOMAIN_PATCH_POLICY_STATUS}
GET policy after status: ${DOMAIN_GET_POLICY_AFTER_STATUS}
Hygiene preview status: ${DOMAIN_HYGIENE_PREVIEW_STATUS}
Hygiene dry-run status: ${DOMAIN_HYGIENE_DRYRUN_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 49 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Politica apos PATCH:"
cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
echo ""
echo "Preview usando politica persistida:"
cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
echo ""
echo "Dry-run usando politica persistida:"
cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 50 - Criar execucao operacional controlada de higienizacao real"

echo "Atualizando AuditPage.tsx..."

cat > "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" <<'DOC'
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
DOC
cat <<'EOF' >> scripts/setup_49_retention_policy_backend.sh

echo "Garantindo estilos da politica de retencao..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.retention-policy-panel {
  align-items: center;
  background: #eff6ff;
  border: 1px solid #bfdbfe;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.06);
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) 160px minmax(260px, auto) auto;
  margin-top: 22px;
  padding: 20px;
}

.retention-policy-panel strong {
  color: #1d4ed8;
  display: block;
}

.retention-policy-panel p {
  color: #1e40af;
  margin: 4px 0 0;
}

.retention-policy-panel label {
  color: #1e40af;
  display: grid;
  font-size: 13px;
  font-weight: 900;
  gap: 6px;
}

.retention-policy-panel input {
  border: 1px solid #93c5fd;
  border-radius: 14px;
  padding: 10px 12px;
}

.retention-policy-panel button {
  background: #2563eb;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 14px;
}

.retention-quick-options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.retention-quick-options button {
  background: #dbeafe;
  color: #1d4ed8;
}

@media (max-width: 1100px) {
  .retention-policy-panel {
    grid-template-columns: 1fr 160px;
  }

  .retention-quick-options {
    grid-column: 1 / -1;
  }
}

@media (max-width: 700px) {
  .retention-policy-panel {
    grid-template-columns: 1fr;
  }

  .retention-quick-options {
    grid-column: auto;
  }
}
DOC

echo "Validando frontend sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
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

DOMAIN_GET_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_GET_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_GET_POLICY_STATUS}" != "200" ]; then
  echo "ERRO: get retention policy falhou. Status ${DOMAIN_GET_POLICY_STATUS}"
  cat "${DOMAIN_GET_POLICY_LOG}"
  exit 1
fi

PATCH_PAYLOAD="$(node -e "console.log(JSON.stringify({auditRetentionDays:180}))")"

DOMAIN_PATCH_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_PATCH_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -X PATCH \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${PATCH_PAYLOAD}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_PATCH_POLICY_STATUS}" != "200" ] && [ "${DOMAIN_PATCH_POLICY_STATUS}" != "201" ]; then
  echo "ERRO: patch retention policy falhou. Status ${DOMAIN_PATCH_POLICY_STATUS}"
  cat "${DOMAIN_PATCH_POLICY_LOG}"
  exit 1
fi

if ! grep -q '"auditRetentionDays":180' "${DOMAIN_PATCH_POLICY_LOG}"; then
  echo "ERRO: patch nao confirmou auditRetentionDays 180."
  cat "${DOMAIN_PATCH_POLICY_LOG}"
  exit 1
fi

DOMAIN_GET_POLICY_AFTER_STATUS="$(curl -L -s -o "${DOMAIN_GET_POLICY_AFTER_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_GET_POLICY_AFTER_STATUS}" != "200" ]; then
  echo "ERRO: get retention policy after falhou. Status ${DOMAIN_GET_POLICY_AFTER_STATUS}"
  cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
  exit 1
fi

if ! grep -q '"auditRetentionDays":180' "${DOMAIN_GET_POLICY_AFTER_LOG}"; then
  echo "ERRO: get after nao confirmou auditRetentionDays 180."
  cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_PREVIEW_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_PREVIEW_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/hygiene-preview" || true)"

if [ "${DOMAIN_HYGIENE_PREVIEW_STATUS}" != "200" ]; then
  echo "ERRO: hygiene preview sem days falhou. Status ${DOMAIN_HYGIENE_PREVIEW_STATUS}"
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

if ! grep -q '"days":180' "${DOMAIN_HYGIENE_PREVIEW_LOG}"; then
  echo "ERRO: hygiene preview nao usou politica persistida de 180 dias."
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_DRYRUN_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_DRYRUN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"dryRun":true}' \
  "${DOMAIN_AUDIT_URL}/hygiene-run" || true)"

if [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "200" ] && [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "201" ]; then
  echo "ERRO: hygiene dry-run sem days falhou. Status ${DOMAIN_HYGIENE_DRYRUN_STATUS}"
  cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
  exit 1
fi

if ! grep -q '"days":180' "${DOMAIN_HYGIENE_DRYRUN_LOG}"; then
  echo "ERRO: hygiene dry-run nao usou politica persistida de 180 dias."
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

echo "Gerando documentacao da Etapa 49..."

cat > "${DOC_FILE}" <<'DOC'
# Retention Policy Backend

## Visao geral

Este documento registra a persistencia backend da politica de retencao por tenant.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela operational audit settings
- politica de retencao por tenant
- endpoint para consultar politica de retencao
- endpoint para atualizar politica de retencao
- uso da politica persistida no preview de higienizacao
- uso da politica persistida no dry-run de higienizacao
- integracao do painel app audit com backend
- fallback local caso backend nao carregue
- validacao sem executar higienizacao real

## Endpoints criados

Endpoints:

- GET api v1 operational audit retention policy
- PATCH api v1 operational audit retention policy

## Tabela criada

Tabela:

- operational audit settings

Campos:

- id
- tenant id
- audit retention days
- created at
- updated at

## Politica de seguranca

A etapa nao executa higienizacao real.

A validacao executa GET e PATCH da politica e depois usa preview e dry-run seguro.

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
- apps/frontend/src/styles.css
- docs/RETENTION_POLICY_BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela operational audit settings
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- GET retention policy dominio
- PATCH retention policy dominio com 180 dias
- GET retention policy after dominio
- hygiene preview usando politica persistida
- hygiene dry-run usando politica persistida
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_49_backend_typecheck.log
- logs/setup_49_backend_build.log
- logs/setup_49_frontend_typecheck.log
- logs/setup_49_frontend_build.log
- logs/setup_49_backend_docker_build.log
- logs/setup_49_frontend_docker_build.log
- logs/setup_49_docker_up.log
- logs/setup_49_backend_wait.log
- logs/setup_49_auth_login_domain.log
- logs/setup_49_retention_policy_get_domain.log
- logs/setup_49_retention_policy_patch_domain.log
- logs/setup_49_retention_policy_get_after_domain.log
- logs/setup_49_hygiene_preview_domain.log
- logs/setup_49_hygiene_dryrun_domain.log
- logs/setup_49_domain_audit_page.log
- logs/setup_49_domain_dashboard.log
- logs/setup_49.log

## Proxima etapa sugerida

Etapa 50:

    Criar execucao operacional controlada de higienizacao real
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
- [x] Etapa 48 - Configuracao visual de politica de retencao
- [x] Etapa 49 - Persistencia backend da politica de retencao por tenant
- [ ] Etapa 50 - Execucao operacional controlada de higienizacao real

## Ultima etapa executada

Etapa 49 - Persistencia backend da politica de retencao por tenant.

## Proxima etapa sugerida

Etapa 50 - Criar execucao operacional controlada de higienizacao real.
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

Higienizacao de dados de auditoria antigos criada.

Configuracao visual de politica de retencao criada.

Persistencia backend da politica de retencao por tenant criada.

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
- docs/RETENTION_POLICY_VISUAL_CONFIG.md
- docs/RETENTION_POLICY_BACKEND.md

## Etapas concluidas

- Etapa 01 ate Etapa 49 concluidas

## Proxima etapa

- Etapa 50 - Execucao operacional controlada de higienizacao real
DOC

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 49 - Persistencia backend da politica de retencao por tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada tabela operational audit settings e endpoints para consultar e atualizar auditRetentionDays por tenant. O painel de auditoria passou a carregar e salvar a politica no backend.
DOC
  fi
done

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
Etapa: 49
Acao: Persistencia backend da politica de retencao por tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
GET policy status: ${DOMAIN_GET_POLICY_STATUS}
PATCH policy status: ${DOMAIN_PATCH_POLICY_STATUS}
GET policy after status: ${DOMAIN_GET_POLICY_AFTER_STATUS}
Hygiene preview status: ${DOMAIN_HYGIENE_PREVIEW_STATUS}
Hygiene dry-run status: ${DOMAIN_HYGIENE_DRYRUN_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 49 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Politica apos PATCH:"
cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
echo ""
echo "Preview usando politica persistida:"
cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
echo ""
echo "Dry-run usando politica persistida:"
cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 50 - Criar execucao operacional controlada de higienizacao real"

echo "Garantindo estilos da politica de retencao..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.retention-policy-panel {
  align-items: center;
  background: #eff6ff;
  border: 1px solid #bfdbfe;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.06);
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) 160px minmax(260px, auto) auto;
  margin-top: 22px;
  padding: 20px;
}

.retention-policy-panel strong {
  color: #1d4ed8;
  display: block;
}

.retention-policy-panel p {
  color: #1e40af;
  margin: 4px 0 0;
}

.retention-policy-panel label {
  color: #1e40af;
  display: grid;
  font-size: 13px;
  font-weight: 900;
  gap: 6px;
}

.retention-policy-panel input {
  border: 1px solid #93c5fd;
  border-radius: 14px;
  padding: 10px 12px;
}

.retention-policy-panel button {
  background: #2563eb;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 14px;
}

.retention-quick-options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.retention-quick-options button {
  background: #dbeafe;
  color: #1d4ed8;
}

@media (max-width: 1100px) {
  .retention-policy-panel {
    grid-template-columns: 1fr 160px;
  }

  .retention-quick-options {
    grid-column: 1 / -1;
  }
}

@media (max-width: 700px) {
  .retention-policy-panel {
    grid-template-columns: 1fr;
  }

  .retention-quick-options {
    grid-column: auto;
  }
}
DOC

echo "Validando frontend sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
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

DOMAIN_GET_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_GET_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_GET_POLICY_STATUS}" != "200" ]; then
  echo "ERRO: get retention policy falhou. Status ${DOMAIN_GET_POLICY_STATUS}"
  cat "${DOMAIN_GET_POLICY_LOG}"
  exit 1
fi

PATCH_PAYLOAD="$(node -e "console.log(JSON.stringify({auditRetentionDays:180}))")"

DOMAIN_PATCH_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_PATCH_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -X PATCH \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${PATCH_PAYLOAD}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_PATCH_POLICY_STATUS}" != "200" ] && [ "${DOMAIN_PATCH_POLICY_STATUS}" != "201" ]; then
  echo "ERRO: patch retention policy falhou. Status ${DOMAIN_PATCH_POLICY_STATUS}"
  cat "${DOMAIN_PATCH_POLICY_LOG}"
  exit 1
fi

if ! grep -q '"auditRetentionDays":180' "${DOMAIN_PATCH_POLICY_LOG}"; then
  echo "ERRO: patch nao confirmou auditRetentionDays 180."
  cat "${DOMAIN_PATCH_POLICY_LOG}"
  exit 1
fi

DOMAIN_GET_POLICY_AFTER_STATUS="$(curl -L -s -o "${DOMAIN_GET_POLICY_AFTER_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_GET_POLICY_AFTER_STATUS}" != "200" ]; then
  echo "ERRO: get retention policy after falhou. Status ${DOMAIN_GET_POLICY_AFTER_STATUS}"
  cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
  exit 1
fi

if ! grep -q '"auditRetentionDays":180' "${DOMAIN_GET_POLICY_AFTER_LOG}"; then
  echo "ERRO: get after nao confirmou auditRetentionDays 180."
  cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_PREVIEW_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_PREVIEW_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/hygiene-preview" || true)"

if [ "${DOMAIN_HYGIENE_PREVIEW_STATUS}" != "200" ]; then
  echo "ERRO: hygiene preview sem days falhou. Status ${DOMAIN_HYGIENE_PREVIEW_STATUS}"
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

if ! grep -q '"days":180' "${DOMAIN_HYGIENE_PREVIEW_LOG}"; then
  echo "ERRO: hygiene preview nao usou politica persistida de 180 dias."
  cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_DRYRUN_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_DRYRUN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"dryRun":true}' \
  "${DOMAIN_AUDIT_URL}/hygiene-run" || true)"

if [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "200" ] && [ "${DOMAIN_HYGIENE_DRYRUN_STATUS}" != "201" ]; then
  echo "ERRO: hygiene dry-run sem days falhou. Status ${DOMAIN_HYGIENE_DRYRUN_STATUS}"
  cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
  exit 1
fi

if ! grep -q '"days":180' "${DOMAIN_HYGIENE_DRYRUN_LOG}"; then
  echo "ERRO: hygiene dry-run nao usou politica persistida de 180 dias."
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

echo "Gerando documentacao da Etapa 49..."

cat > "${DOC_FILE}" <<'DOC'
# Retention Policy Backend

## Visao geral

Este documento registra a persistencia backend da politica de retencao por tenant.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela operational audit settings
- politica de retencao por tenant
- endpoint para consultar politica de retencao
- endpoint para atualizar politica de retencao
- uso da politica persistida no preview de higienizacao
- uso da politica persistida no dry-run de higienizacao
- integracao do painel app audit com backend
- fallback local caso backend nao carregue
- validacao sem executar higienizacao real

## Endpoints criados

Endpoints:

- GET api v1 operational audit retention policy
- PATCH api v1 operational audit retention policy

## Tabela criada

Tabela:

- operational audit settings

Campos:

- id
- tenant id
- audit retention days
- created at
- updated at

## Politica de seguranca

A etapa nao executa higienizacao real.

A validacao executa GET e PATCH da politica e depois usa preview e dry-run seguro.

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
- apps/frontend/src/styles.css
- docs/RETENTION_POLICY_BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela operational audit settings
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- GET retention policy dominio
- PATCH retention policy dominio com 180 dias
- GET retention policy after dominio
- hygiene preview usando politica persistida
- hygiene dry-run usando politica persistida
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_49_backend_typecheck.log
- logs/setup_49_backend_build.log
- logs/setup_49_frontend_typecheck.log
- logs/setup_49_frontend_build.log
- logs/setup_49_backend_docker_build.log
- logs/setup_49_frontend_docker_build.log
- logs/setup_49_docker_up.log
- logs/setup_49_backend_wait.log
- logs/setup_49_auth_login_domain.log
- logs/setup_49_retention_policy_get_domain.log
- logs/setup_49_retention_policy_patch_domain.log
- logs/setup_49_retention_policy_get_after_domain.log
- logs/setup_49_hygiene_preview_domain.log
- logs/setup_49_hygiene_dryrun_domain.log
- logs/setup_49_domain_audit_page.log
- logs/setup_49_domain_dashboard.log
- logs/setup_49.log

## Proxima etapa sugerida

Etapa 50:

    Criar execucao operacional controlada de higienizacao real
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
- [x] Etapa 48 - Configuracao visual de politica de retencao
- [x] Etapa 49 - Persistencia backend da politica de retencao por tenant
- [ ] Etapa 50 - Execucao operacional controlada de higienizacao real

## Ultima etapa executada

Etapa 49 - Persistencia backend da politica de retencao por tenant.

## Proxima etapa sugerida

Etapa 50 - Criar execucao operacional controlada de higienizacao real.
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

Higienizacao de dados de auditoria antigos criada.

Configuracao visual de politica de retencao criada.

Persistencia backend da politica de retencao por tenant criada.

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
- docs/RETENTION_POLICY_VISUAL_CONFIG.md
- docs/RETENTION_POLICY_BACKEND.md

## Etapas concluidas

- Etapa 01 ate Etapa 49 concluidas

## Proxima etapa

- Etapa 50 - Execucao operacional controlada de higienizacao real
DOC

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 49 - Persistencia backend da politica de retencao por tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada tabela operational audit settings e endpoints para consultar e atualizar auditRetentionDays por tenant. O painel de auditoria passou a carregar e salvar a politica no backend.
DOC
  fi
done

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
Etapa: 49
Acao: Persistencia backend da politica de retencao por tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
GET policy status: ${DOMAIN_GET_POLICY_STATUS}
PATCH policy status: ${DOMAIN_PATCH_POLICY_STATUS}
GET policy after status: ${DOMAIN_GET_POLICY_AFTER_STATUS}
Hygiene preview status: ${DOMAIN_HYGIENE_PREVIEW_STATUS}
Hygiene dry-run status: ${DOMAIN_HYGIENE_DRYRUN_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 49 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Politica apos PATCH:"
cat "${DOMAIN_GET_POLICY_AFTER_LOG}"
echo ""
echo "Preview usando politica persistida:"
cat "${DOMAIN_HYGIENE_PREVIEW_LOG}"
echo ""
echo "Dry-run usando politica persistida:"
cat "${DOMAIN_HYGIENE_DRYRUN_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 50 - Criar execucao operacional controlada de higienizacao real"
