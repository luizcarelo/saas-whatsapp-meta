import { Injectable, UnauthorizedException } from '@nestjs/common';
import {
  ConversationStatus,
  MessageDirection,
  MessageStatus,
  MessageType,
  WebhookEventStatus,
  WhatsappAccountStatus
} from '@prisma/client';
import { createHmac, timingSafeEqual } from 'crypto';
import { PrismaService } from '../database/prisma.service';
import type {
  MetaWebhookPayload,
  MetaWebhookPostResponse,
  MetaWebhookSignatureResult,
  MetaWebhookValue
} from './meta-webhooks.types';

@Injectable()
export class MetaWebhooksService {
  constructor(private readonly prismaService: PrismaService) {}

  validateSignature(rawBody: Buffer, signatureHeader?: string): MetaWebhookSignatureResult {
    const required = process.env.META_WEBHOOK_SIGNATURE_REQUIRED === 'true';
    const appSecret = process.env.META_APP_SECRET || '';

    if (!required) {
      return {
        valid: true,
        required,
        reason: 'signature_not_required'
      };
    }

    if (!appSecret || appSecret === 'change_me_meta_app_secret') {
      return {
        valid: false,
        required,
        reason: 'missing_app_secret'
      };
    }

    if (!signatureHeader || !signatureHeader.startsWith('sha256=')) {
      return {
        valid: false,
        required,
        reason: 'missing_signature'
      };
    }

    const receivedHex = signatureHeader.replace('sha256=', '').trim();

    if (!receivedHex || receivedHex.length !== 64) {
      return {
        valid: false,
        required,
        reason: 'invalid_signature_format'
      };
    }

    const expectedHex = createHmac('sha256', appSecret)
      .update(rawBody)
      .digest('hex');

    const received = Buffer.from(receivedHex, 'hex');
    const expected = Buffer.from(expectedHex, 'hex');

    if (received.length !== expected.length) {
      return {
        valid: false,
        required,
        reason: 'signature_length_mismatch'
      };
    }

    const valid = timingSafeEqual(received, expected);

    return {
      valid,
      required,
      reason: valid ? 'valid' : 'signature_mismatch'
    };
  }

  async receivePayload(
    payload: MetaWebhookPayload,
    rawBody: Buffer,
    signatureHeader?: string
  ): Promise<MetaWebhookPostResponse> {
    const signature = this.validateSignature(rawBody, signatureHeader);

    if (!signature.valid) {
      throw new UnauthorizedException('Webhook signature invalid');
    }

    let events = 0;
    let messages = 0;
    let statuses = 0;

    const entries = payload.entry || [];

    for (const entry of entries) {
      const changes = entry.changes || [];

      for (const change of changes) {
        events += 1;

        const value = change.value || {};
        const account = await this.resolveWhatsappAccount(value);

        await this.prismaService.webhookEvent.create({
          data: {
            tenantId: account?.tenantId || null,
            whatsappAccountId: account?.id || null,
            provider: 'meta_whatsapp',
            eventType: change.field || 'unknown',
            eventId: entry.id || null,
            payload: payload as never,
            status: WebhookEventStatus.received
          }
        });

        const messageCount = await this.processMessages(value, account);
        const statusCount = await this.processStatuses(value, account);

        messages += messageCount;
        statuses += statusCount;
      }
    }

    return {
      success: true,
      data: {
        received: true,
        events,
        messages,
        statuses,
        signature: {
          required: signature.required,
          valid: signature.valid
        }
      },
      meta: {}
    };
  }

  private async resolveWhatsappAccount(value: MetaWebhookValue) {
    const phoneNumberId = value.metadata?.phone_number_id;

    if (!phoneNumberId) {
      return null;
    }

    const account = await this.prismaService.whatsappAccount.findFirst({
      where: {
        phoneNumberId,
        deletedAt: null
      }
    });

    if (account) {
      return account;
    }

    const tenant = await this.prismaService.tenant.findFirst({
      where: {
        deletedAt: null
      },
      orderBy: {
        createdAt: 'asc'
      }
    });

    if (!tenant) {
      return null;
    }

    return this.prismaService.whatsappAccount.create({
      data: {
        tenantId: tenant.id,
        wabaId: 'webhook_auto_waba',
        phoneNumberId,
        displayPhoneNumber: value.metadata?.display_phone_number || 'Nao informado',
        verifiedName: 'Conta detectada por webhook',
        accessTokenEncrypted: 'not_configured',
        status: WhatsappAccountStatus.pending
      }
    });
  }

  private async processMessages(value: MetaWebhookValue, account: any): Promise<number> {
    const incomingMessages = value.messages || [];

    if (!account || incomingMessages.length === 0) {
      return 0;
    }

    let count = 0;

    for (const item of incomingMessages) {
      const phone = this.normalizePhone(item.from);
      const body = this.extractMessageBody(item);
      const contactName = this.findContactName(value, phone);

      if (!phone) {
        continue;
      }

      const contact = await this.prismaService.contact.upsert({
        where: {
          tenantId_phone: {
            tenantId: account.tenantId,
            phone
          }
        },
        update: {
          name: contactName || undefined,
          waId: phone
        },
        create: {
          tenantId: account.tenantId,
          name: contactName,
          phone,
          waId: phone
        }
      });

      let conversation = await this.prismaService.conversation.findFirst({
        where: {
          tenantId: account.tenantId,
          contactId: contact.id,
          whatsappAccountId: account.id,
          deletedAt: null,
          status: {
            in: [
              ConversationStatus.open,
              ConversationStatus.pending,
              ConversationStatus.bot,
              ConversationStatus.human
            ]
          }
        },
        orderBy: {
          updatedAt: 'desc'
        }
      });

      if (!conversation) {
        conversation = await this.prismaService.conversation.create({
          data: {
            tenantId: account.tenantId,
            contactId: contact.id,
            whatsappAccountId: account.id,
            status: ConversationStatus.open,
            channel: 'whatsapp',
            lastMessageAt: new Date()
          }
        });
      }

      const existingMessage = item.id
        ? await this.prismaService.message.findFirst({
            where: {
              providerMessageId: item.id
            }
          })
        : null;

      if (existingMessage) {
        continue;
      }

      await this.prismaService.message.create({
        data: {
          tenantId: account.tenantId,
          conversationId: conversation.id,
          contactId: contact.id,
          whatsappAccountId: account.id,
          providerMessageId: item.id || null,
          direction: MessageDirection.inbound,
          type: this.normalizeMessageType(item.type),
          body,
          status: MessageStatus.received,
          metadata: item as never
        }
      });

      await this.prismaService.conversation.update({
        where: {
          id: conversation.id
        },
        data: {
          lastMessageAt: new Date(),
          status: ConversationStatus.open
        }
      });

      count += 1;
    }

    return count;
  }

  private async processStatuses(value: MetaWebhookValue, account: any): Promise<number> {
    const incomingStatuses = value.statuses || [];

    if (!account || incomingStatuses.length === 0) {
      return 0;
    }

    let count = 0;

    for (const item of incomingStatuses) {
      const providerMessageId = item.id;

      if (!providerMessageId) {
        continue;
      }

      const message = await this.prismaService.message.findFirst({
        where: {
          providerMessageId,
          tenantId: account.tenantId
        }
      });

      if (!message) {
        continue;
      }

      const status = this.normalizeMessageStatus(item.status);

      await this.prismaService.messageStatusHistory.create({
        data: {
          tenantId: account.tenantId,
          messageId: message.id,
          providerMessageId,
          status,
          payload: item as never
        }
      });

      await this.prismaService.message.update({
        where: {
          id: message.id
        },
        data: {
          status
        }
      });

      count += 1;
    }

    return count;
  }

  private findContactName(value: MetaWebhookValue, phone: string): string | null {
    const contacts = value.contacts || [];
    const match = contacts.find((contact) => this.normalizePhone(contact.wa_id) === phone);

    return match?.profile?.name || null;
  }

  private extractMessageBody(item: { type?: string; text?: { body?: string } }): string | null {
    if (item.type === 'text') {
      return item.text?.body || null;
    }

    return item.type ? `[${item.type}]` : null;
  }

  private normalizePhone(value?: string): string {
    if (!value) {
      return '';
    }

    return value.replace(/[^0-9]/g, '');
  }

  private normalizeMessageType(value?: string): MessageType {
    if (value === 'image') {
      return MessageType.image;
    }

    if (value === 'audio') {
      return MessageType.audio;
    }

    if (value === 'video') {
      return MessageType.video;
    }

    if (value === 'document') {
      return MessageType.document;
    }

    if (value === 'location') {
      return MessageType.location;
    }

    if (value === 'contact') {
      return MessageType.contact;
    }

    if (value === 'interactive') {
      return MessageType.interactive;
    }

    if (value === 'template') {
      return MessageType.template;
    }

    if (value === 'text') {
      return MessageType.text;
    }

    return MessageType.unknown;
  }

  private normalizeMessageStatus(value?: string): MessageStatus {
    if (value === 'sent') {
      return MessageStatus.sent;
    }

    if (value === 'delivered') {
      return MessageStatus.delivered;
    }

    if (value === 'read') {
      return MessageStatus.read;
    }

    if (value === 'failed') {
      return MessageStatus.failed;
    }

    return MessageStatus.pending;
  }
}
