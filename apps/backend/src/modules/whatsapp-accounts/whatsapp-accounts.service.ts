import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  WhatsappAccountDeleteResponse,
  WhatsappAccountItem,
  WhatsappAccountListResponse,
  WhatsappAccountPayload,
  WhatsappAccountResponse
} from './whatsapp-accounts.types';

type ListAccountsQuery = {
  search?: string;
  limit?: string;
  offset?: string;
};

type AccountShape = {
  id: string;
  tenantId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string | null;
  status: string;
  createdAt: Date;
  updatedAt: Date;
};

@Injectable()
export class WhatsappAccountsService {
  constructor(private readonly prismaService: PrismaService) {}

  async listAccounts(
    tenantId: string,
    query: ListAccountsQuery
  ): Promise<WhatsappAccountListResponse> {
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
                wabaId: {
                  contains: search
                }
              },
              {
                phoneNumberId: {
                  contains: search
                }
              },
              {
                displayPhoneNumber: {
                  contains: search
                }
              },
              {
                verifiedName: {
                  contains: search,
                  mode: 'insensitive' as const
                }
              }
            ]
          }
        : {})
    };

    const accounts = await this.prismaService.whatsappAccount.findMany({
      where,
      orderBy: {
        createdAt: 'desc'
      },
      take: limit,
      skip: offset
    });

    const total = await this.prismaService.whatsappAccount.count({
      where
    });

    return {
      success: true,
      data: {
        accounts: accounts.map((account) => this.toItem(account)),
        total
      },
      meta: {}
    };
  }

  async createAccount(
    tenantId: string,
    payload: WhatsappAccountPayload
  ): Promise<WhatsappAccountResponse> {
    const wabaId = this.requiredValue(payload.wabaId, 'WABA ID obrigatorio');
    const phoneNumberId = this.requiredValue(payload.phoneNumberId, 'Phone Number ID obrigatorio');
    const displayPhoneNumber = this.requiredValue(
      payload.displayPhoneNumber,
      'Telefone de exibicao obrigatorio'
    );

    const existing = await this.prismaService.whatsappAccount.findFirst({
      where: {
        tenantId,
        phoneNumberId,
        deletedAt: null
      }
    });

    if (existing) {
      throw new ConflictException('Conta WhatsApp ja existe para este phoneNumberId');
    }

    const account = await this.prismaService.whatsappAccount.create({
      data: {
        tenantId,
        wabaId,
        phoneNumberId,
        displayPhoneNumber,
        verifiedName: this.cleanOptional(payload.verifiedName),
        accessTokenEncrypted: this.encodeToken(payload.accessToken),
        status: this.normalizeStatus(payload.status)
      }
    });

    return {
      success: true,
      data: {
        account: this.toItem(account)
      },
      meta: {}
    };
  }

  async getAccount(tenantId: string, accountId: string): Promise<WhatsappAccountResponse> {
    const account = await this.findAccountOrFail(tenantId, accountId);

    return {
      success: true,
      data: {
        account: this.toItem(account)
      },
      meta: {}
    };
  }

  async updateAccount(
    tenantId: string,
    accountId: string,
    payload: WhatsappAccountPayload
  ): Promise<WhatsappAccountResponse> {
    await this.findAccountOrFail(tenantId, accountId);

    const phoneNumberId = payload.phoneNumberId ? payload.phoneNumberId.trim() : undefined;

    if (phoneNumberId) {
      const existing = await this.prismaService.whatsappAccount.findFirst({
        where: {
          tenantId,
          phoneNumberId,
          deletedAt: null,
          id: {
            not: accountId
          }
        }
      });

      if (existing) {
        throw new ConflictException('Outra conta ja usa este phoneNumberId');
      }
    }

    const account = await this.prismaService.whatsappAccount.update({
      where: {
        id: accountId
      },
      data: {
        ...(payload.wabaId !== undefined ? { wabaId: this.requiredValue(payload.wabaId, 'WABA ID obrigatorio') } : {}),
        ...(phoneNumberId !== undefined ? { phoneNumberId } : {}),
        ...(payload.displayPhoneNumber !== undefined
          ? {
              displayPhoneNumber: this.requiredValue(
                payload.displayPhoneNumber,
                'Telefone de exibicao obrigatorio'
              )
            }
          : {}),
        ...(payload.verifiedName !== undefined
          ? { verifiedName: this.cleanOptional(payload.verifiedName) }
          : {}),
        ...(payload.accessToken !== undefined
          ? { accessTokenEncrypted: this.encodeToken(payload.accessToken) }
          : {}),
        ...(payload.status !== undefined ? { status: this.normalizeStatus(payload.status) } : {})
      }
    });

    return {
      success: true,
      data: {
        account: this.toItem(account)
      },
      meta: {}
    };
  }

  async deleteAccount(
    tenantId: string,
    accountId: string
  ): Promise<WhatsappAccountDeleteResponse> {
    await this.findAccountOrFail(tenantId, accountId);

    await this.prismaService.whatsappAccount.update({
      where: {
        id: accountId
      },
      data: {
        deletedAt: new Date(),
        status: 'inactive'
      }
    });

    return {
      success: true,
      data: {
        deleted: true,
        id: accountId
      },
      meta: {}
    };
  }

  private async findAccountOrFail(tenantId: string, accountId: string): Promise<AccountShape> {
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

  private toItem(account: AccountShape): WhatsappAccountItem {
    return {
      id: account.id,
      tenantId: account.tenantId,
      wabaId: account.wabaId,
      phoneNumberId: account.phoneNumberId,
      displayPhoneNumber: account.displayPhoneNumber,
      verifiedName: account.verifiedName,
      status: account.status,
      createdAt: account.createdAt.toISOString(),
      updatedAt: account.updatedAt.toISOString()
    };
  }

  private requiredValue(value: string | undefined, message: string): string {
    const cleaned = value ? value.trim() : '';

    if (!cleaned) {
      throw new BadRequestException(message);
    }

    return cleaned;
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

  private encodeToken(value?: string): string {
    const token = value && value.trim() ? value.trim() : 'not_configured';

    return Buffer.from(token, 'utf8').toString('base64');
  }

  private normalizeStatus(value?: string): string {
    const allowed = ['active', 'inactive', 'pending', 'disconnected', 'error'];
    const status = value ? value.trim() : 'pending';

    if (allowed.includes(status)) {
      return status;
    }

    return 'pending';
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
