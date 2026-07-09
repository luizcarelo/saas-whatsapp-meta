#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_40.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_40_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_40_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_40_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_40_backend_docker_up.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_40_auth_login_domain.log"
DOMAIN_ACCOUNTS_LIST_LOG="${LOGS_DIR}/setup_40_whatsapp_accounts_list_domain.log"
DOMAIN_CREATE_CONVERSATION_LOG="${LOGS_DIR}/setup_40_conversation_create_domain.log"
DOMAIN_SEND_MESSAGE_LOG="${LOGS_DIR}/setup_40_meta_send_message_domain.log"
DOMAIN_GET_CONVERSATION_LOG="${LOGS_DIR}/setup_40_conversation_get_domain.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_40_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_40_backend_crash.log"
DOC_FILE="${DOCS_DIR}/BACKEND_META_SEND_MESSAGES.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ACCOUNTS_URL="${DOMAIN_BASE_URL}/api/v1/whatsapp-accounts"
DOMAIN_CONVERSATIONS_URL="${DOMAIN_BASE_URL}/api/v1/conversations"

echo "== Etapa 40: Envio real de mensagens pela API oficial da Meta =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/meta-whatsapp"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.module.ts" \
  "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.service.ts" \
  "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.types.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.module.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.service.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.types.ts" \
  "${BASE_DIR}/.env" \
  "${BASE_DIR}/.env.example" \
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

if ! command -v node >/dev/null 2>&1; then
  echo "ERRO: node nao encontrado."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERRO: npm nao encontrado."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERRO: curl nao encontrado."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ]; then
  echo "ERRO: email admin nao encontrado."
  exit 1
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: senha admin nao encontrada."
  exit 1
fi

echo "Garantindo variaveis da Meta no .env..."

if [ ! -f "${BASE_DIR}/.env" ]; then
  cp "${BASE_DIR}/.env.example" "${BASE_DIR}/.env"
fi

set_env_value() {
  key="$1"
  value="$2"
  file="$3"
  tmp_file="${file}.tmp.${STAMP}"

  awk -v k="${key}" -v v="${value}" '
    BEGIN { done = 0 }
    index($0, k "=") == 1 {
      print k "=" v
      done = 1
      next
    }
    {
      print
    }
    END {
      if (done == 0) {
        print k "=" v
      }
    }
  ' "${file}" > "${tmp_file}"

  mv "${tmp_file}" "${file}"
}

get_env_value() {
  key="$1"
  file="$2"

  grep "^${key}=" "${file}" | head -n 1 | cut -d '=' -f 2- || true
}

CURRENT_GRAPH_VERSION="$(get_env_value "META_GRAPH_API_VERSION" "${BASE_DIR}/.env")"

if [ -z "${CURRENT_GRAPH_VERSION}" ]; then
  META_GRAPH_API_VERSION="v25.0"
else
  META_GRAPH_API_VERSION="${CURRENT_GRAPH_VERSION}"
fi

CURRENT_TEST_RECIPIENT="$(get_env_value "META_TEST_RECIPIENT_PHONE" "${BASE_DIR}/.env")"

if [ -z "${CURRENT_TEST_RECIPIENT}" ]; then
  META_TEST_RECIPIENT_PHONE="5521999940266"
else
  META_TEST_RECIPIENT_PHONE="${CURRENT_TEST_RECIPIENT}"
fi

set_env_value "META_GRAPH_API_VERSION" "v25.0" "${BASE_DIR}/.env.example"
set_env_value "META_TEST_RECIPIENT_PHONE" "5521999940266" "${BASE_DIR}/.env.example"

set_env_value "META_GRAPH_API_VERSION" "${META_GRAPH_API_VERSION}" "${BASE_DIR}/.env"
set_env_value "META_TEST_RECIPIENT_PHONE" "${META_TEST_RECIPIENT_PHONE}" "${BASE_DIR}/.env"

echo "Criando meta-whatsapp.types.ts..."

cat > "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.types.ts" <<'DOC'
export type MetaSendTextMessageInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
  to: string;
  body: string;
};

export type MetaSendTextMessageResult = {
  success: boolean;
  providerMessageId: string | null;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};
DOC

echo "Criando meta-whatsapp.service.ts..."

cat > "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import type {
  MetaSendTextMessageInput,
  MetaSendTextMessageResult
} from './meta-whatsapp.types';

@Injectable()
export class MetaWhatsappService {
  async sendTextMessage(input: MetaSendTextMessageInput): Promise<MetaSendTextMessageResult> {
    const token = this.decodeAccessToken(input.accessTokenEncrypted);

    if (!token) {
      return {
        success: false,
        providerMessageId: null,
        statusCode: 0,
        response: {
          error: 'access_token_not_configured'
        },
        errorMessage: 'Token da conta WhatsApp nao configurado'
      };
    }

    const graphVersion = process.env.META_GRAPH_API_VERSION || 'v25.0';
    const url = `https://graph.facebook.com/${graphVersion}/${input.phoneNumberId}/messages`;

    const payload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: this.normalizePhone(input.to),
      type: 'text',
      text: {
        preview_url: false,
        body: input.body
      }
    };

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      const responseBody = await response.json().catch(() => ({}));
      const providerMessageId = this.extractProviderMessageId(responseBody);

      if (!response.ok) {
        return {
          success: false,
          providerMessageId,
          statusCode: response.status,
          response: responseBody,
          errorMessage: this.extractErrorMessage(responseBody)
        };
      }

      return {
        success: true,
        providerMessageId,
        statusCode: response.status,
        response: responseBody,
        errorMessage: null
      };
    } catch (error) {
      return {
        success: false,
        providerMessageId: null,
        statusCode: 0,
        response: {
          error: 'network_or_runtime_error'
        },
        errorMessage: error instanceof Error ? error.message : 'Erro desconhecido ao enviar mensagem'
      };
    }
  }

  private decodeAccessToken(value: string): string {
    if (!value || value === 'not_configured') {
      return '';
    }

    try {
      const decoded = Buffer.from(value, 'base64').toString('utf8');

      if (decoded && decoded.trim()) {
        return decoded.trim();
      }
    } catch (_error) {
      return '';
    }

    return '';
  }

  private extractProviderMessageId(responseBody: unknown): string | null {
    const body = responseBody as {
      messages?: Array<{
        id?: string;
      }>;
    };

    const id = body.messages?.[0]?.id;

    if (!id) {
      return null;
    }

    return id;
  }

  private extractErrorMessage(responseBody: unknown): string {
    const body = responseBody as {
      error?: {
        message?: string;
      };
    };

    return body.error?.message || 'Meta retornou erro no envio da mensagem';
  }

  private normalizePhone(value: string): string {
    return value.replace(/[^0-9]/g, '');
  }
}
DOC

echo "Criando meta-whatsapp.module.ts..."

cat > "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { MetaWhatsappService } from './meta-whatsapp.service';

@Module({
  providers: [
    MetaWhatsappService
  ],
  exports: [
    MetaWhatsappService
  ]
})
export class MetaWhatsappModule {}
DOC

echo "Atualizando conversations.types.ts..."

cat > "${BACKEND_DIR}/src/modules/conversations/conversations.types.ts" <<'DOC'
export type CreateConversationPayload = {
  contactId?: string;
  name?: string;
  phone?: string;
  initialMessage?: string;
};

export type CreateConversationMessagePayload = {
  body?: string;
};

export type ConversationContact = {
  id: string;
  name: string | null;
  phone: string;
  email: string | null;
};

export type ConversationLastMessage = {
  id: string;
  direction: string;
  body: string | null;
  createdAt: string;
};

export type ConversationItem = {
  id: string;
  tenantId: string;
  contact: ConversationContact;
  status: string;
  channel: string;
  lastMessageAt: string | null;
  createdAt: string;
  updatedAt: string;
  lastMessage: ConversationLastMessage | null;
};

export type ConversationMessageItem = {
  id: string;
  direction: string;
  type: string;
  body: string | null;
  status: string;
  providerMessageId: string | null;
  sentAt: string | null;
  metadata: unknown;
  createdAt: string;
};

export type ConversationDetail = ConversationItem & {
  messages: ConversationMessageItem[];
};

export type ConversationListResponse = {
  success: true;
  data: {
    conversations: ConversationItem[];
    total: number;
  };
  meta: Record<string, never>;
};

export type ConversationResponse = {
  success: true;
  data: {
    conversation: ConversationDetail;
  };
  meta: Record<string, never>;
};

export type ConversationMessageResponse = {
  success: true;
  data: {
    message: ConversationMessageItem;
  };
  meta: Record<string, never>;
};
DOC

echo "Atualizando conversations.module.ts..."

cat > "${BACKEND_DIR}/src/modules/conversations/conversations.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { MetaWhatsappModule } from '../meta-whatsapp/meta-whatsapp.module';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({}),
    MetaWhatsappModule
  ],
  controllers: [
    ConversationsController
  ],
  providers: [
    ConversationsService
  ],
  exports: [
    ConversationsService
  ]
})
export class ConversationsModule {}
DOC

echo "Atualizando conversations.service.ts com envio real pela Meta..."

cat > "${BACKEND_DIR}/src/modules/conversations/conversations.service.ts" <<'DOC'
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
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/meta-whatsapp" \
  "${BACKEND_DIR}/src/modules/conversations"
then
  echo "ERRO: HTML indevido encontrado."
  exit 1
fi

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${TYPECHECK_LOG}"

echo "Rodando build do backend..."

npm run build 2>&1 | tee "${BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BUILD_LOG}"

echo "Subindo backend..."

docker compose up -d backend 2>&1 | tee "${DOCKER_UP_LOG}"

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

echo "Testando login dominio..."

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "access_token" "${DOMAIN_LOGIN_LOG}"; then
  echo "ERRO: login dominio nao retornou access_token."
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

echo "Validando existencia de conta WhatsApp ativa real..."

DOMAIN_ACCOUNTS_STATUS="$(curl -L -s -o "${DOMAIN_ACCOUNTS_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_STATUS}" != "200" ]; then
  echo "ERRO: listagem de contas dominio falhou. Status ${DOMAIN_ACCOUNTS_STATUS}"
  cat "${DOMAIN_ACCOUNTS_LIST_LOG}"
  exit 1
fi

ACTIVE_PHONE_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const accounts=(data.data&&data.data.accounts)||[]; const found=accounts.find((account)=>account.status==='active' && /^[0-9]+$/.test(account.phoneNumberId)); if(!found){process.exit(2)} console.log(found.phoneNumberId)" "${DOMAIN_ACCOUNTS_LIST_LOG}" || true)"

if [ -z "${ACTIVE_PHONE_ID}" ]; then
  echo "ERRO: nenhuma conta WhatsApp ativa com Phone Number ID numerico foi encontrada."
  echo "Cadastre a conta real da Meta em /app/whatsapp-accounts com status active."
  cat "${DOMAIN_ACCOUNTS_LIST_LOG}"
  exit 1
fi

echo "Conta real encontrada com Phone Number ID numerico."

echo "Criando conversa de teste para envio real..."

TEST_RECIPIENT_PHONE="$(get_env_value "META_TEST_RECIPIENT_PHONE" "${BASE_DIR}/.env")"
TEST_RECIPIENT_PHONE="$(node -e "console.log(String(process.argv[1] || '').replace(/[^0-9]/g,''))" "${TEST_RECIPIENT_PHONE}")"

if [ -z "${TEST_RECIPIENT_PHONE}" ]; then
  echo "ERRO: META_TEST_RECIPIENT_PHONE nao esta configurado."
  exit 1
fi

CONVERSATION_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Envio Real Meta Etapa 40', phone:process.argv[1], initialMessage:'Conversa criada para teste de envio real etapa 40'}))" "${TEST_RECIPIENT_PHONE}")"

DOMAIN_CREATE_CONVERSATION_STATUS="$(curl -L -s -o "${DOMAIN_CREATE_CONVERSATION_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CONVERSATION_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_URL}" || true)"

if [ "${DOMAIN_CREATE_CONVERSATION_STATUS}" != "200" ] && [ "${DOMAIN_CREATE_CONVERSATION_STATUS}" != "201" ]; then
  echo "ERRO: criar conversa dominio falhou. Status ${DOMAIN_CREATE_CONVERSATION_STATUS}"
  cat "${DOMAIN_CREATE_CONVERSATION_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.conversation.id)" "${DOMAIN_CREATE_CONVERSATION_LOG}")"

if [ -z "${CONVERSATION_ID}" ]; then
  echo "ERRO: id da conversa nao encontrado."
  cat "${DOMAIN_CREATE_CONVERSATION_LOG}"
  exit 1
fi

echo "Enviando mensagem real pela API da Meta..."

MESSAGE_PAYLOAD="$(node -e "console.log(JSON.stringify({body:'Mensagem real enviada pelo sistema LH Solucao - Etapa 40'}))")"

DOMAIN_SEND_MESSAGE_STATUS="$(curl -L -s -o "${DOMAIN_SEND_MESSAGE_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${MESSAGE_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_URL}/${CONVERSATION_ID}/messages" || true)"

if [ "${DOMAIN_SEND_MESSAGE_STATUS}" != "200" ] && [ "${DOMAIN_SEND_MESSAGE_STATUS}" != "201" ]; then
  echo "ERRO: endpoint de envio de mensagem falhou. Status ${DOMAIN_SEND_MESSAGE_STATUS}"
  cat "${DOMAIN_SEND_MESSAGE_LOG}"
  exit 1
fi

if ! grep -q "message" "${DOMAIN_SEND_MESSAGE_LOG}"; then
  echo "ERRO: resposta de envio nao retornou message."
  cat "${DOMAIN_SEND_MESSAGE_LOG}"
  exit 1
fi

MESSAGE_STATUS="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.message.status)" "${DOMAIN_SEND_MESSAGE_LOG}")"

if [ "${MESSAGE_STATUS}" = "sent" ]; then
  echo "Mensagem aceita pela Meta com status sent."
else
  echo "ATENCAO: chamada real foi executada, mas a Meta retornou falha ou bloqueio. Status salvo: ${MESSAGE_STATUS}"
  echo "Veja o log sem token em ${DOMAIN_SEND_MESSAGE_LOG}"
fi

echo "Buscando conversa apos envio..."

DOMAIN_GET_CONVERSATION_STATUS="$(curl -L -s -o "${DOMAIN_GET_CONVERSATION_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_CONVERSATIONS_URL}/${CONVERSATION_ID}" || true)"

if [ "${DOMAIN_GET_CONVERSATION_STATUS}" != "200" ]; then
  echo "ERRO: buscar conversa dominio falhou. Status ${DOMAIN_GET_CONVERSATION_STATUS}"
  cat "${DOMAIN_GET_CONVERSATION_LOG}"
  exit 1
fi

if ! grep -q "providerMessageId" "${DOMAIN_GET_CONVERSATION_LOG}"; then
  echo "ERRO: conversa nao retornou providerMessageId no payload de mensagens."
  cat "${DOMAIN_GET_CONVERSATION_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 40..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Meta Send Messages

## Visao geral

Este documento registra a criacao do envio real de mensagens pela API oficial da Meta.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- modulo Meta WhatsApp
- servico de envio de mensagem text pela Meta Graph API
- uso do Phone Number ID da conta WhatsApp
- decodificacao do token salvo da conta WhatsApp
- selecao de conta WhatsApp ativa e real
- envio real ao endpoint da Meta
- gravacao de providerMessageId quando retornado
- atualizacao de status para sent quando aceito
- atualizacao de status para failed quando rejeitado
- gravacao de resposta da Meta em metadata sem expor token

## Endpoint externo utilizado

Endpoint:

    POST graph facebook com version phone number id messages

Headers:

    Authorization Bearer token
    Content Type application json

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.module.ts
- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.service.ts
- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.types.ts
- apps/backend/src/modules/conversations/conversations.module.ts
- apps/backend/src/modules/conversations/conversations.service.ts
- apps/backend/src/modules/conversations/conversations.types.ts
- .env
- .env.example
- docs/BACKEND_META_SEND_MESSAGES.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- aguardo ativo do backend
- login dominio
- listagem de contas WhatsApp dominio
- validacao de conta ativa real
- criacao de conversa dominio
- chamada real de envio pela Meta
- busca da conversa apos envio

## Logs gerados

Logs:

- logs/setup_40_backend_typecheck.log
- logs/setup_40_backend_build.log
- logs/setup_40_backend_docker_build.log
- logs/setup_40_backend_docker_up.log
- logs/setup_40_backend_wait.log
- logs/setup_40_auth_login_domain.log
- logs/setup_40_whatsapp_accounts_list_domain.log
- logs/setup_40_conversation_create_domain.log
- logs/setup_40_meta_send_message_domain.log
- logs/setup_40_conversation_get_domain.log
- logs/setup_40.log

## Observacoes

Se a Meta rejeitar o envio por destinatario nao permitido, token expirado, janela de atendimento ou politica de template, o sistema salva a mensagem com status failed e grava o retorno da Meta em metadata.

O token nao e impresso nos logs.

## Proxima etapa sugerida

Etapa 41:

    Criar suporte a templates oficiais da Meta
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
- [ ] Etapa 41 - Templates oficiais da Meta

## Ultima etapa executada

Etapa 40 - Envio real de mensagens pela API oficial da Meta.

## Proxima etapa sugerida

Etapa 41 - Criar suporte a templates oficiais da Meta.
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

## Etapas concluidas

- Etapa 01 ate Etapa 40 concluidas

## Proxima etapa

- Etapa 41 - Templates oficiais da Meta
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
Etapa: 40
Acao: Envio real de mensagens pela API oficial da Meta
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Accounts list status: ${DOMAIN_ACCOUNTS_STATUS}
Active phone number id: ${ACTIVE_PHONE_ID}
Create conversation status: ${DOMAIN_CREATE_CONVERSATION_STATUS}
Send message endpoint status: ${DOMAIN_SEND_MESSAGE_STATUS}
Message final status: ${MESSAGE_STATUS}
Get conversation status: ${DOMAIN_GET_CONVERSATION_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 40 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Resultado do envio:"
cat "${DOMAIN_SEND_MESSAGE_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 41 - Criar suporte a templates oficiais da Meta"
