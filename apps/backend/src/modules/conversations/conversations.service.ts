import {
  BadRequestException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  ConversationDetail,
  ConversationItem,
  ConversationListResponse,
  ConversationMessageItem,
  ConversationMessageResponse,
  ConversationResponse,
  CreateConversationMessagePayload,
  CreateConversationPayload
} from './conversations.types';

type ListConversationsQuery = {
  search?: string;
  status?: string;
  limit?: string;
  offset?: string;
};

@Injectable()
export class ConversationsService {
  constructor(private readonly prismaService: PrismaService) {}

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
    const whatsappAccount = await this.ensureDefaultWhatsappAccount(tenantId);

    const conversation = await this.prismaService.conversation.create({
      data: {
        tenantId,
        contactId: contact.id,
        whatsappAccountId: whatsappAccount.id,
        status: 'open',
        channel: 'whatsapp',
        lastMessageAt: payload.initialMessage ? new Date() : null,
        messages: payload.initialMessage
          ? {
              create: {
                tenantId,
                contactId: contact.id,
                whatsappAccountId: whatsappAccount.id,
                direction: 'inbound',
                type: 'text',
                body: payload.initialMessage,
                status: 'received'
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

    const message = await this.prismaService.message.create({
      data: {
        tenantId,
        conversationId: conversation.id,
        contactId: conversation.contact.id,
        whatsappAccountId: conversation.whatsappAccountId,
        direction: 'outbound',
        type: 'text',
        body,
        status: 'pending',
        sentAt: new Date()
      }
    });

    await this.prismaService.conversation.update({
      where: {
        id: conversation.id
      },
      data: {
        lastMessageAt: new Date(),
        status: 'human'
      }
    });

    return {
      success: true,
      data: {
        message: this.toMessageItem(message)
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
        status: 'closed',
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
        phone
      }
    });
  }

  private async ensureDefaultWhatsappAccount(tenantId: string) {
    return this.prismaService.whatsappAccount.upsert({
      where: {
        tenantId_phoneNumberId: {
          tenantId,
          phoneNumberId: 'local_default_phone_number'
        }
      },
      update: {},
      create: {
        tenantId,
        wabaId: 'local_default_waba',
        phoneNumberId: 'local_default_phone_number',
        displayPhoneNumber: 'Nao configurado',
        accessTokenEncrypted: 'not_configured',
        status: 'pending'
      }
    });
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
