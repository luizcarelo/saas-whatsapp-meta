#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_33.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_33_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_33_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_33_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_33_backend_docker_up.log"
LOCAL_LOGIN_LOG="${LOGS_DIR}/setup_33_auth_login_local.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_33_auth_login_domain.log"
LOCAL_CREATE_LOG="${LOGS_DIR}/setup_33_conversations_create_local.log"
LOCAL_LIST_LOG="${LOGS_DIR}/setup_33_conversations_list_local.log"
LOCAL_GET_LOG="${LOGS_DIR}/setup_33_conversations_get_local.log"
LOCAL_MESSAGE_LOG="${LOGS_DIR}/setup_33_conversations_message_local.log"
LOCAL_CLOSE_LOG="${LOGS_DIR}/setup_33_conversations_close_local.log"
DOMAIN_LIST_LOG="${LOGS_DIR}/setup_33_conversations_list_domain.log"
DOMAIN_CREATE_LOG="${LOGS_DIR}/setup_33_conversations_create_domain.log"
DOC_FILE="${DOCS_DIR}/BACKEND_CONVERSATIONS.md"

LOCAL_LOGIN_URL="http://127.0.0.1:3300/api/v1/auth/login"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/api/v1/auth/login"
LOCAL_CONVERSATIONS_URL="http://127.0.0.1:3300/api/v1/conversations"
DOMAIN_CONVERSATIONS_URL="https://bot.lhsolucao.com.br/api/v1/conversations"

echo "== Etapa 33: Modulo backend de conversas =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/conversations"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.module.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.controller.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.service.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.types.ts" \
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

echo "Criando conversations.types.ts..."

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

echo "Criando conversations.service.ts..."

cat > "${BACKEND_DIR}/src/modules/conversations/conversations.service.ts" <<'DOC'
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
DOC

echo "Criando conversations.controller.ts..."

cat > "${BACKEND_DIR}/src/modules/conversations/conversations.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { ConversationsService } from './conversations.service';
import type {
  CreateConversationMessagePayload,
  CreateConversationPayload
} from './conversations.types';

type ListConversationsQuery = {
  search?: string;
  status?: string;
  limit?: string;
  offset?: string;
};

@Controller('conversations')
@UseGuards(JwtAuthGuard)
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Get()
  listConversations(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListConversationsQuery
  ) {
    return this.conversationsService.listConversations(user.tenantId, query);
  }

  @Post()
  createConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: CreateConversationPayload
  ) {
    return this.conversationsService.createConversation(user.tenantId, body);
  }

  @Get(':id')
  getConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.conversationsService.getConversation(user.tenantId, id);
  }

  @Post(':id/messages')
  createMessage(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: CreateConversationMessagePayload
  ) {
    return this.conversationsService.createConversationMessage(user.tenantId, id, body);
  }

  @Patch(':id/close')
  closeConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.conversationsService.closeConversation(user.tenantId, id);
  }
}
DOC

echo "Criando conversations.module.ts..."

cat > "${BACKEND_DIR}/src/modules/conversations/conversations.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
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

echo "Atualizando app.module.ts..."

cat > "${BACKEND_DIR}/src/app.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { AuthModule } from './modules/auth/auth.module';
import { ConfigurationModule } from './modules/configuration/configuration.module';
import { ContactsModule } from './modules/contacts/contacts.module';
import { ConversationsModule } from './modules/conversations/conversations.module';
import { DatabaseModule } from './modules/database/database.module';
import { HealthModule } from './modules/health/health.module';
import { UsersModule } from './modules/users/users.module';

@Module({
  imports: [
    ConfigurationModule,
    DatabaseModule,
    HealthModule,
    AuthModule,
    UsersModule,
    ContactsModule,
    ConversationsModule
  ],
  controllers: [],
  providers: []
})
export class AppModule {}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/conversations" \
  "${BACKEND_DIR}/src/app.module.ts"
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

sleep 10

echo "Testando login local..."

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

LOCAL_LOGIN_STATUS="$(curl -s -o "${LOCAL_LOGIN_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${LOCAL_LOGIN_URL}" || true)"

if [ "${LOCAL_LOGIN_STATUS}" != "200" ] && [ "${LOCAL_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login local falhou. Status ${LOCAL_LOGIN_STATUS}"
  cat "${LOCAL_LOGIN_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q "access_token" "${LOCAL_LOGIN_LOG}"; then
  echo "ERRO: login local nao retornou access_token."
  cat "${LOCAL_LOGIN_LOG}"
  exit 1
fi

LOCAL_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${LOCAL_LOGIN_LOG}")"

echo "Criando conversa local..."

CONVERSATION_PHONE="5521666${STAMP}"
CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Contato Conversa Etapa 33', phone:process.argv[1], initialMessage:'Mensagem inicial da Etapa 33'}))" "${CONVERSATION_PHONE}")"

LOCAL_CREATE_STATUS="$(curl -s -o "${LOCAL_CREATE_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CREATE_PAYLOAD}" \
  "${LOCAL_CONVERSATIONS_URL}" || true)"

if [ "${LOCAL_CREATE_STATUS}" != "200" ] && [ "${LOCAL_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: criar conversa local falhou. Status ${LOCAL_CREATE_STATUS}"
  cat "${LOCAL_CREATE_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.conversation.id)" "${LOCAL_CREATE_LOG}")"

if [ -z "${CONVERSATION_ID}" ]; then
  echo "ERRO: id da conversa nao encontrado."
  cat "${LOCAL_CREATE_LOG}"
  exit 1
fi

echo "Listando conversas local..."

LOCAL_LIST_STATUS="$(curl -s -o "${LOCAL_LIST_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_CONVERSATIONS_URL}" || true)"

if [ "${LOCAL_LIST_STATUS}" != "200" ]; then
  echo "ERRO: listar conversas local falhou. Status ${LOCAL_LIST_STATUS}"
  cat "${LOCAL_LIST_LOG}"
  exit 1
fi

if ! grep -q "conversations" "${LOCAL_LIST_LOG}"; then
  echo "ERRO: listagem local nao retornou conversations."
  cat "${LOCAL_LIST_LOG}"
  exit 1
fi

echo "Buscando conversa local..."

LOCAL_GET_STATUS="$(curl -s -o "${LOCAL_GET_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_CONVERSATIONS_URL}/${CONVERSATION_ID}" || true)"

if [ "${LOCAL_GET_STATUS}" != "200" ]; then
  echo "ERRO: buscar conversa local falhou. Status ${LOCAL_GET_STATUS}"
  cat "${LOCAL_GET_LOG}"
  exit 1
fi

echo "Criando mensagem local..."

MESSAGE_PAYLOAD="$(node -e "console.log(JSON.stringify({body:'Resposta local da Etapa 33'}))")"

LOCAL_MESSAGE_STATUS="$(curl -s -o "${LOCAL_MESSAGE_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${MESSAGE_PAYLOAD}" \
  "${LOCAL_CONVERSATIONS_URL}/${CONVERSATION_ID}/messages" || true)"

if [ "${LOCAL_MESSAGE_STATUS}" != "200" ] && [ "${LOCAL_MESSAGE_STATUS}" != "201" ]; then
  echo "ERRO: criar mensagem local falhou. Status ${LOCAL_MESSAGE_STATUS}"
  cat "${LOCAL_MESSAGE_LOG}"
  exit 1
fi

if ! grep -q "Resposta local da Etapa 33" "${LOCAL_MESSAGE_LOG}"; then
  echo "ERRO: mensagem local nao retornou corpo esperado."
  cat "${LOCAL_MESSAGE_LOG}"
  exit 1
fi

echo "Fechando conversa local..."

LOCAL_CLOSE_STATUS="$(curl -s -o "${LOCAL_CLOSE_LOG}" -w "%{http_code}" --max-time 20 \
  -X PATCH \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_CONVERSATIONS_URL}/${CONVERSATION_ID}/close" || true)"

if [ "${LOCAL_CLOSE_STATUS}" != "200" ]; then
  echo "ERRO: fechar conversa local falhou. Status ${LOCAL_CLOSE_STATUS}"
  cat "${LOCAL_CLOSE_LOG}"
  exit 1
fi

if ! grep -q "closed" "${LOCAL_CLOSE_LOG}"; then
  echo "ERRO: fechamento local nao retornou status closed."
  cat "${LOCAL_CLOSE_LOG}"
  exit 1
fi

echo "Testando login dominio..."

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

echo "Listando conversas dominio..."

DOMAIN_LIST_STATUS="$(curl -L -s -o "${DOMAIN_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_CONVERSATIONS_URL}" || true)"

if [ "${DOMAIN_LIST_STATUS}" != "200" ]; then
  echo "ERRO: listar conversas dominio falhou. Status ${DOMAIN_LIST_STATUS}"
  cat "${DOMAIN_LIST_LOG}"
  exit 1
fi

if ! grep -q "conversations" "${DOMAIN_LIST_LOG}"; then
  echo "ERRO: listagem dominio nao retornou conversations."
  cat "${DOMAIN_LIST_LOG}"
  exit 1
fi

echo "Criando conversa dominio..."

DOMAIN_CONVERSATION_PHONE="5521555${STAMP}"
DOMAIN_CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Conversa Dominio Etapa 33', phone:process.argv[1], initialMessage:'Mensagem dominio da Etapa 33'}))" "${DOMAIN_CONVERSATION_PHONE}")"

DOMAIN_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${DOMAIN_CREATE_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_URL}" || true)"

if [ "${DOMAIN_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: criar conversa dominio falhou. Status ${DOMAIN_CREATE_STATUS}"
  cat "${DOMAIN_CREATE_LOG}"
  exit 1
fi

if ! grep -q "Conversa Dominio Etapa 33" "${DOMAIN_CREATE_LOG}"; then
  echo "ERRO: criacao dominio nao retornou conversa esperada."
  cat "${DOMAIN_CREATE_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 33..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Conversations

## Visao geral

Este documento registra a criacao do modulo backend de conversas.

## Resultado

Status:

    concluido

## Endpoints criados

Endpoints:

- GET api v1 conversations
- POST api v1 conversations
- GET api v1 conversations id
- POST api v1 conversations id messages
- PATCH api v1 conversations id close

## Funcionalidades

Funcionalidades:

- listar conversas do tenant autenticado
- buscar conversa por id
- criar conversa com contato existente ou telefone
- criar contato automaticamente quando necessario
- criar conta WhatsApp placeholder quando necessario
- criar mensagem inicial inbound
- criar mensagem outbound
- fechar conversa
- filtrar conversas por busca simples
- filtrar conversas por status

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/conversations/conversations.module.ts
- apps/backend/src/modules/conversations/conversations.controller.ts
- apps/backend/src/modules/conversations/conversations.service.ts
- apps/backend/src/modules/conversations/conversations.types.ts
- apps/backend/src/app.module.ts
- docs/BACKEND_CONVERSATIONS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- login local
- criar conversa local
- listar conversas local
- buscar conversa local
- criar mensagem local
- fechar conversa local
- login dominio
- listar conversas dominio
- criar conversa dominio

## Logs gerados

Logs:

- logs/setup_33_backend_typecheck.log
- logs/setup_33_backend_build.log
- logs/setup_33_backend_docker_build.log
- logs/setup_33_backend_docker_up.log
- logs/setup_33_auth_login_local.log
- logs/setup_33_auth_login_domain.log
- logs/setup_33_conversations_create_local.log
- logs/setup_33_conversations_list_local.log
- logs/setup_33_conversations_get_local.log
- logs/setup_33_conversations_message_local.log
- logs/setup_33_conversations_close_local.log
- logs/setup_33_conversations_list_domain.log
- logs/setup_33_conversations_create_domain.log
- logs/setup_33.log

## Observacoes

A conta WhatsApp criada nesta etapa e um placeholder local.

A integracao real com a API oficial da Meta sera criada em etapa futura.

## Proxima etapa sugerida

Etapa 34:

    Integrar frontend de conversas ao backend
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
- [ ] Etapa 34 - Frontend de conversas integrado ao backend

## Ultima etapa executada

Etapa 33 - Modulo backend de conversas.

## Proxima etapa sugerida

Etapa 34 - Integrar frontend de conversas ao backend.
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

## Etapas concluidas

- Etapa 01 ate Etapa 33 concluidas

## Proxima etapa

- Etapa 34 - Frontend de conversas integrado ao backend
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
Etapa: 33
Acao: Modulo backend de conversas
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login local status: ${LOCAL_LOGIN_STATUS}
Create local status: ${LOCAL_CREATE_STATUS}
List local status: ${LOCAL_LIST_STATUS}
Get local status: ${LOCAL_GET_STATUS}
Message local status: ${LOCAL_MESSAGE_STATUS}
Close local status: ${LOCAL_CLOSE_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
List dominio status: ${DOMAIN_LIST_STATUS}
Create dominio status: ${DOMAIN_CREATE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 33 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Conversa dominio criada:"
cat "${DOMAIN_CREATE_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 34 - Integrar frontend de conversas ao backend"
