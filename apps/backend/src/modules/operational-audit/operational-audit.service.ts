import { Injectable } from '@nestjs/common';
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
      this.prismaService.message.count({
        where: {
          tenantId
        }
      }),
      this.prismaService.message.count({
        where: {
          tenantId,
          status: 'sent'
        }
      }),
      this.prismaService.message.count({
        where: {
          tenantId,
          status: 'delivered'
        }
      }),
      this.prismaService.message.count({
        where: {
          tenantId,
          status: 'read'
        }
      }),
      this.prismaService.message.count({
        where: {
          tenantId,
          status: 'failed'
        }
      }),
      this.prismaService.message.count({
        where: {
          tenantId,
          status: 'pending'
        }
      }),
      this.prismaService.message.count({
        where: {
          tenantId,
          status: 'received'
        }
      }),
      this.prismaService.webhookEvent.count({
        where: {
          tenantId
        }
      }),
      this.prismaService.webhookEvent.count({
        where: {
          tenantId,
          status: 'received'
        }
      }),
      this.prismaService.webhookEvent.count({
        where: {
          tenantId,
          status: 'processed'
        }
      }),
      this.prismaService.webhookEvent.count({
        where: {
          tenantId,
          status: 'failed'
        }
      }),
      this.prismaService.conversation.count({
        where: {
          tenantId,
          deletedAt: null
        }
      }),
      this.prismaService.conversation.count({
        where: {
          tenantId,
          deletedAt: {
            not: null
          }
        }
      }),
      this.prismaService.whatsappAccount.count({
        where: {
          tenantId,
          deletedAt: null,
          status: 'active'
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
        ...(query.status ? { status: query.status as never } : {}),
        ...(query.direction ? { direction: query.direction as never } : {}),
        ...(query.type ? { type: query.type as never } : {})
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
        ...(query.status ? { status: query.status as never } : {}),
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
