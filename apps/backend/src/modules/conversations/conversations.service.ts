import {
  BadRequestException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import {
  ConversationStatus,
  MessageDirection,
  MessageStatus,
  MessageType,
  WhatsappAccountStatus
} from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { MetaWhatsappService } from '../meta-whatsapp/meta-whatsapp.service';
import type {
  ConversationDetail,
  ConversationItem,
  ConversationListResponse,
  ConversationMessageItem,
  ConversationMessageResponse,
  ConversationResponse,
  CreateConversationMessagePayload,
  CreateConversationPayload,
  SendConversationTemplatePayload
} from './conversations.types';

type ListConversationsQuery = {
  search?: string;
  status?: string;
  limit?: string;
  offset?: string;
};

@Injectable()
export class ConversationsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly metaWhatsappService: MetaWhatsappService
  ) {}

  async listConversations(
    tenantId: string,
    query: ListConversationsQuery
  ): Promise<ConversationListResponse> {
    const limit = this.parseLimit(query.limit);
    const offset = this.parseOffset(query.offset);
    const search = query.search ? query.search.trim() : '';
    const status = query.status ? query.status.trim() : '';

    const where = {
      tenantId,
      deletedAt: null,
      ...(status ? { status: status as never } : {}),
      ...(search
        ? {
            OR: [
              {
                contact: {
                  name: {
                    contains: search,
                    mode: 'insensitive' as const
                  }
                }
              },
              {
                contact: {
                  phone: {
                    contains: search
                  }
                }
              }
            ]
          }
        : {})
    };

    const conversations = await this.prismaService.conversation.findMany({
      where,
      include: {
        contact: true,
        messages: {
          orderBy: {
            createdAt: 'desc'
          },
          take: 1
        }
      },
      orderBy: {
        updatedAt: 'desc'
      },
      take: limit,
      skip: offset
    });

    const total = await this.prismaService.conversation.count({
      where
    });

    return {
      success: true,
      data: {
        conversations: conversations.map((conversation) => this.toConversationItem(conversation)),
        total
      },
      meta: {}
    };
  }

  async createConversation(
    tenantId: string,
    payload: CreateConversationPayload
  ): Promise<ConversationResponse> {
    const contact = await this.resolveContact(tenantId, payload);
    const whatsappAccount = await this.resolveWhatsappAccountForConversation(tenantId);

    const conversation = await this.prismaService.conversation.create({
      data: {
        tenantId,
        contactId: contact.id,
        whatsappAccountId: whatsappAccount.id,
        status: ConversationStatus.open,
        channel: 'whatsapp',
        lastMessageAt: payload.initialMessage ? new Date() : null,
        messages: payload.initialMessage
          ? {
              create: {
                tenantId,
                contactId: contact.id,
                whatsappAccountId: whatsappAccount.id,
                direction: MessageDirection.inbound,
                type: MessageType.text,
                body: payload.initialMessage,
                status: MessageStatus.received
              }
            }
          : undefined
      },
      include: {
        contact: true,
        messages: {
          orderBy: {
            createdAt: 'asc'
          }
        }
      }
    });

    return {
      success: true,
      data: {
        conversation: this.toConversationDetail(conversation)
      },
      meta: {}
    };
  }

  async getConversation(tenantId: string, conversationId: string): Promise<ConversationResponse> {
    const conversation = await this.findConversationOrFail(tenantId, conversationId);

    return {
      success: true,
      data: {
        conversation: this.toConversationDetail(conversation)
      },
      meta: {}
    };
  }

  async createConversationMessage(
    tenantId: string,
    conversationId: string,
    payload: CreateConversationMessagePayload
  ): Promise<ConversationMessageResponse> {
    const body = payload.body ? payload.body.trim() : '';

    if (!body) {
      throw new BadRequestException('Mensagem obrigatoria');
    }

    const conversation = await this.findConversationOrFail(tenantId, conversationId);
    const whatsappAccount = await this.resolveWhatsappAccountById(
      tenantId,
      conversation.whatsappAccountId
    );

    const message = await this.prismaService.message.create({
      data: {
        tenantId,
        conversationId: conversation.id,
        contactId: conversation.contact.id,
        whatsappAccountId: whatsappAccount.id,
        direction: MessageDirection.outbound,
        type: MessageType.text,
        body,
        status: MessageStatus.pending,
        sentAt: new Date()
      }
    });

    const sendResult = await this.metaWhatsappService.sendTextMessage({
      phoneNumberId: whatsappAccount.phoneNumberId,
      accessTokenEncrypted: whatsappAccount.accessTokenEncrypted,
      to: conversation.contact.waId || conversation.contact.phone,
      body
    });

    const updatedMessage = await this.prismaService.message.update({
      where: {
        id: message.id
      },
      data: {
        providerMessageId: sendResult.providerMessageId,
        status: sendResult.success ? MessageStatus.sent : MessageStatus.failed,
        metadata: {
          metaSend: {
            success: sendResult.success,
            statusCode: sendResult.statusCode,
            providerMessageId: sendResult.providerMessageId,
            response: sendResult.response,
            errorMessage: sendResult.errorMessage
          }
        } as never
      }
    });

    await this.prismaService.conversation.update({
      where: {
        id: conversation.id
      },
      data: {
        lastMessageAt: new Date(),
        status: ConversationStatus.human
      }
    });

    return {
      success: true,
      data: {
        message: this.toMessageItem(updatedMessage)
      },
      meta: {}
    };
  }

  async sendConversationTemplate(
    tenantId: string,
    conversationId: string,
    payload: SendConversationTemplatePayload
  ): Promise<ConversationMessageResponse> {
    const templateName = payload.templateName?.trim() || process.env.META_TEMPLATE_TEST_NAME || 'hello_world';
    const languageCode = payload.languageCode?.trim() || process.env.META_TEMPLATE_TEST_LANGUAGE || 'en_US';

    const conversation = await this.findConversationOrFail(tenantId, conversationId);
    const whatsappAccount = await this.resolveWhatsappAccountById(
      tenantId,
      conversation.whatsappAccountId
    );

    const body = `Template ${templateName} ${languageCode}`;

    const message = await this.prismaService.message.create({
      data: {
        tenantId,
        conversationId: conversation.id,
        contactId: conversation.contact.id,
        whatsappAccountId: whatsappAccount.id,
        direction: MessageDirection.outbound,
        type: MessageType.template,
        body,
        status: MessageStatus.pending,
        sentAt: new Date(),
        metadata: {
          template: {
            name: templateName,
            languageCode
          }
        } as never
      }
    });

    const sendResult = await this.metaWhatsappService.sendTemplateMessage({
      phoneNumberId: whatsappAccount.phoneNumberId,
      accessTokenEncrypted: whatsappAccount.accessTokenEncrypted,
      to: conversation.contact.waId || conversation.contact.phone,
      templateName,
      languageCode
    });

    const updatedMessage = await this.prismaService.message.update({
      where: {
        id: message.id
      },
      data: {
        providerMessageId: sendResult.providerMessageId,
        status: sendResult.success ? MessageStatus.sent : MessageStatus.failed,
        metadata: {
          template: {
            name: templateName,
            languageCode
          },
          metaSend: {
            success: sendResult.success,
            statusCode: sendResult.statusCode,
            providerMessageId: sendResult.providerMessageId,
            response: sendResult.response,
            errorMessage: sendResult.errorMessage
          }
        } as never
      }
    });

    await this.prismaService.conversation.update({
      where: {
        id: conversation.id
      },
      data: {
        lastMessageAt: new Date(),
        status: ConversationStatus.human
      }
    });

    return {
      success: true,
      data: {
        message: this.toMessageItem(updatedMessage)
      },
      meta: {}
    };
  }

  async closeConversation(tenantId: string, conversationId: string): Promise<ConversationResponse> {
    await this.findConversationOrFail(tenantId, conversationId);

    const conversation = await this.prismaService.conversation.update({
      where: {
        id: conversationId
      },
      data: {
        status: ConversationStatus.closed,
        closedAt: new Date()
      },
      include: {
        contact: true,
        messages: {
          orderBy: {
            createdAt: 'asc'
          }
        }
      }
    });

    return {
      success: true,
      data: {
        conversation: this.toConversationDetail(conversation)
      },
      meta: {}
    };
  }

  private async resolveContact(tenantId: string, payload: CreateConversationPayload) {
    if (payload.contactId) {
      const contact = await this.prismaService.contact.findFirst({
        where: {
          id: payload.contactId,
          tenantId,
          deletedAt: null
        }
      });

      if (!contact) {
        throw new NotFoundException('Contato nao encontrado');
      }

      return contact;
    }

    const phone = this.normalizePhone(payload.phone);

    if (!phone) {
      throw new BadRequestException('Telefone ou contactId obrigatorio');
    }

    const existing = await this.prismaService.contact.findFirst({
      where: {
        tenantId,
        phone,
        deletedAt: null
      }
    });

    if (existing) {
      return existing;
    }

    return this.prismaService.contact.create({
      data: {
        tenantId,
        name: this.cleanOptional(payload.name),
        phone,
        waId: phone
      }
    });
  }

  private async resolveWhatsappAccountForConversation(tenantId: string) {
    const preferredPhoneNumberId = process.env.META_DEFAULT_PHONE_NUMBER_ID || '';

    if (preferredPhoneNumberId) {
      const preferred = await this.prismaService.whatsappAccount.findFirst({
        where: {
          tenantId,
          phoneNumberId: preferredPhoneNumberId,
          deletedAt: null,
          status: WhatsappAccountStatus.active
        }
      });

      if (preferred) {
        return preferred;
      }
    }

    const activeAccounts = await this.prismaService.whatsappAccount.findMany({
      where: {
        tenantId,
        deletedAt: null,
        status: WhatsappAccountStatus.active
      },
      orderBy: {
        updatedAt: 'desc'
      }
    });

    const numericActiveAccount = activeAccounts.find((account) =>
      /^[0-9]+$/.test(account.phoneNumberId)
    );

    if (numericActiveAccount) {
      return numericActiveAccount;
    }

    if (activeAccounts.length > 0) {
      return activeAccounts[0];
    }

    const pendingAccount = await this.prismaService.whatsappAccount.findFirst({
      where: {
        tenantId,
        deletedAt: null
      },
      orderBy: {
        updatedAt: 'desc'
      }
    });

    if (pendingAccount) {
      return pendingAccount;
    }

    return this.prismaService.whatsappAccount.create({
      data: {
        tenantId,
        wabaId: 'local_default_waba',
        phoneNumberId: 'local_default_phone_number',
        displayPhoneNumber: 'Nao configurado',
        accessTokenEncrypted: 'not_configured',
        status: WhatsappAccountStatus.pending
      }
    });
  }

  private async resolveWhatsappAccountById(tenantId: string, accountId: string) {
    const account = await this.prismaService.whatsappAccount.findFirst({
      where: {
        id: accountId,
        tenantId,
        deletedAt: null
      }
    });

    if (!account) {
      throw new NotFoundException('Conta WhatsApp nao encontrada');
    }

    return account;
  }

  private async findConversationOrFail(tenantId: string, conversationId: string) {
    const conversation = await this.prismaService.conversation.findFirst({
      where: {
        id: conversationId,
        tenantId,
        deletedAt: null
      },
      include: {
        contact: true,
        messages: {
          orderBy: {
            createdAt: 'asc'
          }
        }
      }
    });

    if (!conversation) {
      throw new NotFoundException('Conversa nao encontrada');
    }

    return conversation;
  }

  private toConversationItem(conversation: any): ConversationItem {
    const lastMessage = conversation.messages && conversation.messages.length > 0
      ? conversation.messages[0]
      : null;

    return {
      id: conversation.id,
      tenantId: conversation.tenantId,
      contact: {
        id: conversation.contact.id,
        name: conversation.contact.name,
        phone: conversation.contact.phone,
        email: conversation.contact.email
      },
      status: conversation.status,
      channel: conversation.channel,
      lastMessageAt: conversation.lastMessageAt ? conversation.lastMessageAt.toISOString() : null,
      createdAt: conversation.createdAt.toISOString(),
      updatedAt: conversation.updatedAt.toISOString(),
      lastMessage: lastMessage ? this.toLastMessageItem(lastMessage) : null
    };
  }

  private toConversationDetail(conversation: any): ConversationDetail {
    return {
      ...this.toConversationItem(conversation),
      messages: conversation.messages.map((message: any) => this.toMessageItem(message))
    };
  }

  private toLastMessageItem(message: any) {
    return {
      id: message.id,
      direction: message.direction,
      body: message.body,
      createdAt: message.createdAt.toISOString()
    };
  }

  private toMessageItem(message: any): ConversationMessageItem {
    return {
      id: message.id,
      direction: message.direction,
      type: message.type,
      body: message.body,
      status: message.status,
      providerMessageId: message.providerMessageId || null,
      sentAt: message.sentAt ? message.sentAt.toISOString() : null,
      metadata: message.metadata || null,
      createdAt: message.createdAt.toISOString()
    };
  }

  private normalizePhone(value?: string): string {
    if (!value) {
      return '';
    }

    return value.replace(/[^0-9]/g, '');
  }

  private cleanOptional(value?: string): string | null {
    if (!value) {
      return null;
    }

    const cleaned = value.trim();

    if (!cleaned) {
      return null;
    }

    return cleaned;
  }

  private parseLimit(value?: string): number {
    if (!value) {
      return 20;
    }

    const parsed = Number(value);

    if (Number.isNaN(parsed) || parsed < 1) {
      return 20;
    }

    if (parsed > 100) {
      return 100;
    }

    return parsed;
  }

  private parseOffset(value?: string): number {
    if (!value) {
      return 0;
    }

    const parsed = Number(value);

    if (Number.isNaN(parsed) || parsed < 0) {
      return 0;
    }

    return parsed;
  }
}
