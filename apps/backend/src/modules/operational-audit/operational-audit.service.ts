import { BadRequestException, Injectable } from '@nestjs/common';
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
  OperationalAuditHygieneRunsResponse,
  OperationalAuditMessageItem,
  OperationalAuditMessagesResponse,
  OperationalAuditQuery,
  OperationalAuditRealHygienePayload,
  OperationalAuditRetentionPolicyPayload,
  OperationalAuditRetentionPolicyResponse,
  OperationalAuditSummaryResponse,
  OperationalAuditWebhookItem,
  OperationalAuditWebhooksResponse
} from './operational-audit.types';

type HygieneRunRow = {
  id: string;
  tenant_id: string;
  retention_days: number;
  dry_run: boolean;
  old_messages: number;
  old_failed_messages_with_metadata: number;
  old_webhook_events: number;
  messages_redacted: number;
  webhook_events_redacted: number;
  created_at: Date;
};

type RetentionPolicyRow = {
  audit_retention_days: number;
  updated_at: Date | null;
};

@Injectable()
export class OperationalAuditService {
  constructor(private readonly prismaService: PrismaService) {}

  async exportRealHygieneRunsCsv(tenantId: string): Promise<OperationalAuditExportResult> {
    const history = await this.listRealHygieneRuns(tenantId);
    const timestamp = this.timestampForFilename();

    return {
      filename: 'real_hygiene_history_' + timestamp + '.csv',
      contentType: 'text/csv; charset=utf-8',
      content: this.toCsv(
        [
          'id',
          'tenantId',
          'retentionDays',
          'dryRun',
          'oldMessages',
          'oldFailedMessagesWithMetadata',
          'oldWebhookEvents',
          'messagesRedacted',
          'webhookEventsRedacted',
          'createdAt'
        ],
        history.data.runs.map((run) => [
          run.id,
          run.tenantId,
          run.retentionDays,
          String(run.dryRun),
          run.oldMessages,
          run.oldFailedMessagesWithMetadata,
          run.oldWebhookEvents,
          run.messagesRedacted,
          run.webhookEventsRedacted,
          run.createdAt
        ])
      )
    };
  }

  async listRealHygieneRuns(tenantId: string): Promise<OperationalAuditHygieneRunsResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<HygieneRunRow[]>(
      'select id, tenant_id, retention_days, dry_run, old_messages, old_failed_messages_with_metadata, old_webhook_events, messages_redacted, webhook_events_redacted, created_at from operational_audit_hygiene_runs where tenant_id = $1::uuid order by created_at desc limit 100',
      tenantId
    );

    return {
      success: true,
      data: {
        runs: rows.map((row) => ({
          id: row.id,
          tenantId: row.tenant_id,
          retentionDays: row.retention_days,
          dryRun: row.dry_run,
          oldMessages: row.old_messages,
          oldFailedMessagesWithMetadata: row.old_failed_messages_with_metadata,
          oldWebhookEvents: row.old_webhook_events,
          messagesRedacted: row.messages_redacted,
          webhookEventsRedacted: row.webhook_events_redacted,
          createdAt: row.created_at.toISOString()
        })),
        total: rows.length
      },
      meta: {}
    };
  }

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

  async runRealHygiene(
    tenantId: string,
    payload: OperationalAuditRealHygienePayload
  ): Promise<OperationalAuditHygieneResponse> {
    const expectedPhrase = 'EXECUTAR_HIGIENIZACAO_REAL';

    if (payload.confirmationPhrase !== expectedPhrase) {
      throw new BadRequestException('Frase de confirmacao invalida para higienizacao real');
    }

    const result = await this.runHygiene(tenantId, {
      days: payload.days,
      dryRun: false
    });

    await this.prismaService.$executeRawUnsafe(
      'insert into operational_audit_hygiene_runs (tenant_id, retention_days, dry_run, confirmation_phrase, old_messages, old_failed_messages_with_metadata, old_webhook_events, messages_redacted, webhook_events_redacted, created_at) values ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, now())',
      tenantId,
      result.data.days,
      result.data.dryRun,
      expectedPhrase,
      result.data.candidates.oldMessages,
      result.data.candidates.oldFailedMessagesWithMetadata,
      result.data.candidates.oldWebhookEvents,
      result.data.changed.messagesRedacted,
      result.data.changed.webhookEventsRedacted
    );

    return result;
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
