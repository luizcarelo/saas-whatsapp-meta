import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  ContactDeleteResponse,
  ContactItem,
  ContactListResponse,
  ContactPayload,
  ContactResponse
} from './contacts.types';

type ListContactsQuery = {
  search?: string;
  limit?: string;
  offset?: string;
};

type PrismaContactShape = {
  id: string;
  tenantId: string;
  name: string | null;
  phone: string;
  waId: string | null;
  email: string | null;
  document: string | null;
  createdAt: Date;
  updatedAt: Date;
};

@Injectable()
export class ContactsService {
  constructor(private readonly prismaService: PrismaService) {}

  async listContacts(tenantId: string, query: ListContactsQuery): Promise<ContactListResponse> {
    const limit = this.parseLimit(query.limit);
    const offset = this.parseOffset(query.offset);
    const search = query.search ? query.search.trim() : '';

    const where = {
      tenantId,
      deletedAt: null,
      ...(search
        ? {
            OR: [
              {
                name: {
                  contains: search,
                  mode: 'insensitive' as const
                }
              },
              {
                phone: {
                  contains: search
                }
              },
              {
                email: {
                  contains: search,
                  mode: 'insensitive' as const
                }
              }
            ]
          }
        : {})
    };

    const contacts = await this.prismaService.contact.findMany({
      where,
      orderBy: {
        createdAt: 'desc'
      },
      take: limit,
      skip: offset
    });

    const total = await this.prismaService.contact.count({
      where
    });

    return {
      success: true,
      data: {
        contacts: contacts.map((contact) => this.toContactItem(contact)),
        total
      },
      meta: {}
    };
  }

  async createContact(tenantId: string, payload: ContactPayload): Promise<ContactResponse> {
    const phone = this.normalizePhone(payload.phone);

    if (!phone) {
      throw new BadRequestException('Telefone obrigatorio');
    }

    const existing = await this.prismaService.contact.findFirst({
      where: {
        tenantId,
        phone,
        deletedAt: null
      }
    });

    if (existing) {
      throw new ConflictException('Contato ja existe para este telefone');
    }

    const contact = await this.prismaService.contact.create({
      data: {
        tenantId,
        name: this.cleanOptional(payload.name),
        phone,
        waId: this.cleanOptional(payload.waId),
        email: this.cleanOptional(payload.email),
        document: this.cleanOptional(payload.document)
      }
    });

    return {
      success: true,
      data: {
        contact: this.toContactItem(contact)
      },
      meta: {}
    };
  }

  async getContact(tenantId: string, contactId: string): Promise<ContactResponse> {
    const contact = await this.findContactOrFail(tenantId, contactId);

    return {
      success: true,
      data: {
        contact: this.toContactItem(contact)
      },
      meta: {}
    };
  }

  async updateContact(
    tenantId: string,
    contactId: string,
    payload: ContactPayload
  ): Promise<ContactResponse> {
    await this.findContactOrFail(tenantId, contactId);

    const phone = payload.phone ? this.normalizePhone(payload.phone) : undefined;

    if (phone) {
      const existing = await this.prismaService.contact.findFirst({
        where: {
          tenantId,
          phone,
          deletedAt: null,
          id: {
            not: contactId
          }
        }
      });

      if (existing) {
        throw new ConflictException('Outro contato ja usa este telefone');
      }
    }

    const contact = await this.prismaService.contact.update({
      where: {
        id: contactId
      },
      data: {
        ...(payload.name !== undefined ? { name: this.cleanOptional(payload.name) } : {}),
        ...(phone !== undefined ? { phone } : {}),
        ...(payload.waId !== undefined ? { waId: this.cleanOptional(payload.waId) } : {}),
        ...(payload.email !== undefined ? { email: this.cleanOptional(payload.email) } : {}),
        ...(payload.document !== undefined ? { document: this.cleanOptional(payload.document) } : {})
      }
    });

    return {
      success: true,
      data: {
        contact: this.toContactItem(contact)
      },
      meta: {}
    };
  }

  async deleteContact(tenantId: string, contactId: string): Promise<ContactDeleteResponse> {
    await this.findContactOrFail(tenantId, contactId);

    await this.prismaService.contact.update({
      where: {
        id: contactId
      },
      data: {
        deletedAt: new Date()
      }
    });

    return {
      success: true,
      data: {
        deleted: true,
        id: contactId
      },
      meta: {}
    };
  }

  private async findContactOrFail(tenantId: string, contactId: string): Promise<PrismaContactShape> {
    const contact = await this.prismaService.contact.findFirst({
      where: {
        id: contactId,
        tenantId,
        deletedAt: null
      }
    });

    if (!contact) {
      throw new NotFoundException('Contato nao encontrado');
    }

    return contact;
  }

  private toContactItem(contact: PrismaContactShape): ContactItem {
    return {
      id: contact.id,
      tenantId: contact.tenantId,
      name: contact.name,
      phone: contact.phone,
      waId: contact.waId,
      email: contact.email,
      document: contact.document,
      createdAt: contact.createdAt.toISOString(),
      updatedAt: contact.updatedAt.toISOString()
    };
  }

  private normalizePhone(value?: string): string {
    if (!value) {
      return '';
    }

    return value.replace(/[^0-9]/g, '');
  }

  private cleanOptional(value?: string): string | null {
    if (value === undefined) {
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

    if (Number.isNaN(parsed)) {
      return 20;
    }

    if (parsed < 1) {
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
