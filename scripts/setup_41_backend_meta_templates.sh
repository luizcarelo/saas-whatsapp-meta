#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_41.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_41_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_41_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_41_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_41_backend_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_41_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_41_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_41_auth_login_domain.log"
DOMAIN_ACCOUNTS_LOG="${LOGS_DIR}/setup_41_whatsapp_accounts_domain.log"
DOMAIN_TEMPLATES_LOG="${LOGS_DIR}/setup_41_templates_list_domain.log"
DOMAIN_CREATE_CONVERSATION_LOG="${LOGS_DIR}/setup_41_conversation_create_domain.log"
DOMAIN_SEND_TEMPLATE_LOG="${LOGS_DIR}/setup_41_template_send_domain.log"
DOMAIN_GET_CONVERSATION_LOG="${LOGS_DIR}/setup_41_conversation_get_domain.log"

DOC_FILE="${DOCS_DIR}/BACKEND_META_TEMPLATES.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ACCOUNTS_URL="${DOMAIN_BASE_URL}/api/v1/whatsapp-accounts"
DOMAIN_CONVERSATIONS_URL="${DOMAIN_BASE_URL}/api/v1/conversations"

echo "== Etapa 41: Suporte a templates oficiais da Meta =="

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
  "${BACKEND_DIR}/src/modules/conversations/conversations.controller.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.service.ts" \
  "${BACKEND_DIR}/src/modules/conversations/conversations.types.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.module.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.types.ts" \
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

echo "Garantindo variaveis no .env..."

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
CURRENT_TEST_RECIPIENT="$(get_env_value "META_TEST_RECIPIENT_PHONE" "${BASE_DIR}/.env")"

if [ -z "${CURRENT_GRAPH_VERSION}" ]; then
  META_GRAPH_API_VERSION="v25.0"
else
  META_GRAPH_API_VERSION="${CURRENT_GRAPH_VERSION}"
fi

if [ -z "${CURRENT_TEST_RECIPIENT}" ]; then
  META_TEST_RECIPIENT_PHONE="5521999940266"
else
  META_TEST_RECIPIENT_PHONE="${CURRENT_TEST_RECIPIENT}"
fi

set_env_value "META_GRAPH_API_VERSION" "v25.0" "${BASE_DIR}/.env.example"
set_env_value "META_TEST_RECIPIENT_PHONE" "5521999940266" "${BASE_DIR}/.env.example"
set_env_value "META_TEMPLATE_TEST_NAME" "hello_world" "${BASE_DIR}/.env.example"
set_env_value "META_TEMPLATE_TEST_LANGUAGE" "en_US" "${BASE_DIR}/.env.example"

set_env_value "META_GRAPH_API_VERSION" "${META_GRAPH_API_VERSION}" "${BASE_DIR}/.env"
set_env_value "META_TEST_RECIPIENT_PHONE" "${META_TEST_RECIPIENT_PHONE}" "${BASE_DIR}/.env"

CURRENT_TEMPLATE_NAME="$(get_env_value "META_TEMPLATE_TEST_NAME" "${BASE_DIR}/.env")"
CURRENT_TEMPLATE_LANGUAGE="$(get_env_value "META_TEMPLATE_TEST_LANGUAGE" "${BASE_DIR}/.env")"

if [ -z "${CURRENT_TEMPLATE_NAME}" ]; then
  CURRENT_TEMPLATE_NAME="hello_world"
fi

if [ -z "${CURRENT_TEMPLATE_LANGUAGE}" ]; then
  CURRENT_TEMPLATE_LANGUAGE="en_US"
fi

set_env_value "META_TEMPLATE_TEST_NAME" "${CURRENT_TEMPLATE_NAME}" "${BASE_DIR}/.env"
set_env_value "META_TEMPLATE_TEST_LANGUAGE" "${CURRENT_TEMPLATE_LANGUAGE}" "${BASE_DIR}/.env"

echo "Atualizando meta-whatsapp.types.ts..."

cat > "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.types.ts" <<'DOC'
export type MetaSendTextMessageInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
  to: string;
  body: string;
};

export type MetaSendTemplateMessageInput = {
  phoneNumberId: string;
  accessTokenEncrypted: string;
  to: string;
  templateName: string;
  languageCode: string;
};

export type MetaSendMessageResult = {
  success: boolean;
  providerMessageId: string | null;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};

export type MetaListTemplatesInput = {
  wabaId: string;
  accessTokenEncrypted: string;
};

export type MetaListTemplatesResult = {
  success: boolean;
  statusCode: number;
  response: unknown;
  errorMessage: string | null;
};
DOC

echo "Atualizando meta-whatsapp.service.ts..."

cat > "${BACKEND_DIR}/src/modules/meta-whatsapp/meta-whatsapp.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import type {
  MetaListTemplatesInput,
  MetaListTemplatesResult,
  MetaSendMessageResult,
  MetaSendTemplateMessageInput,
  MetaSendTextMessageInput
} from './meta-whatsapp.types';

@Injectable()
export class MetaWhatsappService {
  async sendTextMessage(input: MetaSendTextMessageInput): Promise<MetaSendMessageResult> {
    return this.sendMessageRequest({
      phoneNumberId: input.phoneNumberId,
      accessTokenEncrypted: input.accessTokenEncrypted,
      payload: {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: this.normalizePhone(input.to),
        type: 'text',
        text: {
          preview_url: false,
          body: input.body
        }
      }
    });
  }

  async sendTemplateMessage(
    input: MetaSendTemplateMessageInput
  ): Promise<MetaSendMessageResult> {
    return this.sendMessageRequest({
      phoneNumberId: input.phoneNumberId,
      accessTokenEncrypted: input.accessTokenEncrypted,
      payload: {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: this.normalizePhone(input.to),
        type: 'template',
        template: {
          name: input.templateName,
          language: {
            code: input.languageCode
          }
        }
      }
    });
  }

  async listTemplates(input: MetaListTemplatesInput): Promise<MetaListTemplatesResult> {
    const token = this.decodeAccessToken(input.accessTokenEncrypted);

    if (!token) {
      return {
        success: false,
        statusCode: 0,
        response: {
          error: 'access_token_not_configured'
        },
        errorMessage: 'Token da conta WhatsApp nao configurado'
      };
    }

    const graphVersion = process.env.META_GRAPH_API_VERSION || 'v25.0';
    const fields = 'name,language,status,category,id';
    const url = `https://graph.facebook.com/${graphVersion}/${input.wabaId}/message_templates?fields=${encodeURIComponent(fields)}`;

    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      const responseBody = await response.json().catch(() => ({}));

      return {
        success: response.ok,
        statusCode: response.status,
        response: responseBody,
        errorMessage: response.ok ? null : this.extractErrorMessage(responseBody)
      };
    } catch (error) {
      return {
        success: false,
        statusCode: 0,
        response: {
          error: 'network_or_runtime_error'
        },
        errorMessage: error instanceof Error ? error.message : 'Erro desconhecido ao listar templates'
      };
    }
  }

  private async sendMessageRequest(input: {
    phoneNumberId: string;
    accessTokenEncrypted: string;
    payload: Record<string, unknown>;
  }): Promise<MetaSendMessageResult> {
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

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(input.payload)
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

    return body.error?.message || 'Meta retornou erro na chamada';
  }

  private normalizePhone(value: string): string {
    return value.replace(/[^0-9]/g, '');
  }
}
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

export type SendConversationTemplatePayload = {
  templateName?: string;
  languageCode?: string;
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

echo "Atualizando whatsapp-accounts.types.ts..."

cat > "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.types.ts" <<'DOC'
export type WhatsappAccountPayload = {
  wabaId?: string;
  phoneNumberId?: string;
  displayPhoneNumber?: string;
  verifiedName?: string;
  accessToken?: string;
  status?: string;
};

export type WhatsappAccountItem = {
  id: string;
  tenantId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type WhatsappAccountListResponse = {
  success: true;
  data: {
    accounts: WhatsappAccountItem[];
    total: number;
  };
  meta: Record<string, never>;
};

export type WhatsappAccountResponse = {
  success: true;
  data: {
    account: WhatsappAccountItem;
  };
  meta: Record<string, never>;
};

export type WhatsappAccountDeleteResponse = {
  success: true;
  data: {
    deleted: true;
    id: string;
  };
  meta: Record<string, never>;
};

export type WhatsappTemplateListResponse = {
  success: true;
  data: {
    account: WhatsappAccountItem;
    templates: unknown;
  };
  meta: Record<string, never>;
};
DOC

echo "Atualizando whatsapp-accounts.module.ts..."

cat > "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { MetaWhatsappModule } from '../meta-whatsapp/meta-whatsapp.module';
import { WhatsappAccountsController } from './whatsapp-accounts.controller';
import { WhatsappAccountsService } from './whatsapp-accounts.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({}),
    MetaWhatsappModule
  ],
  controllers: [
    WhatsappAccountsController
  ],
  providers: [
    WhatsappAccountsService
  ],
  exports: [
    WhatsappAccountsService
  ]
})
export class WhatsappAccountsModule {}
DOC

echo "Atualizando whatsapp-accounts.controller.ts..."

cat > "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Delete,
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
import { WhatsappAccountsService } from './whatsapp-accounts.service';
import type { WhatsappAccountPayload } from './whatsapp-accounts.types';

type ListAccountsQuery = {
  search?: string;
  limit?: string;
  offset?: string;
};

@Controller('whatsapp-accounts')
@UseGuards(JwtAuthGuard)
export class WhatsappAccountsController {
  constructor(private readonly whatsappAccountsService: WhatsappAccountsService) {}

  @Get()
  listAccounts(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListAccountsQuery
  ) {
    return this.whatsappAccountsService.listAccounts(user.tenantId, query);
  }

  @Post()
  createAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: WhatsappAccountPayload
  ) {
    return this.whatsappAccountsService.createAccount(user.tenantId, body);
  }

  @Get(':id/templates')
  listTemplates(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.listTemplates(user.tenantId, id);
  }

  @Get(':id')
  getAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.getAccount(user.tenantId, id);
  }

  @Patch(':id')
  updateAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: WhatsappAccountPayload
  ) {
    return this.whatsappAccountsService.updateAccount(user.tenantId, id, body);
  }

  @Delete(':id')
  deleteAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.deleteAccount(user.tenantId, id);
  }
}
DOC

echo "Atualizando whatsapp-accounts.service.ts com listagem de templates..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts")
text = path.read_text()

if "MetaWhatsappService" not in text:
    text = text.replace(
        "import { PrismaService } from '../database/prisma.service';",
        "import { PrismaService } from '../database/prisma.service';\nimport { MetaWhatsappService } from '../meta-whatsapp/meta-whatsapp.service';"
    )

text = text.replace(
    "WhatsappAccountResponse\n} from './whatsapp-accounts.types';",
    "WhatsappAccountResponse,\n  WhatsappTemplateListResponse\n} from './whatsapp-accounts.types';"
)

text = text.replace(
    "constructor(private readonly prismaService: PrismaService) {}",
    "constructor(\n    private readonly prismaService: PrismaService,\n    private readonly metaWhatsappService: MetaWhatsappService\n  ) {}"
)

marker = "  async getAccount(tenantId: string, accountId: string): Promise<WhatsappAccountResponse> {"
if "async listTemplates(" not in text:
    insert = """  async listTemplates(
    tenantId: string,
    accountId: string
  ): Promise<WhatsappTemplateListResponse> {
    const account = await this.findAccountOrFail(tenantId, accountId);
    const result = await this.metaWhatsappService.listTemplates({
      wabaId: account.wabaId,
      accessTokenEncrypted: await this.getAccessTokenEncrypted(account.id)
    });

    return {
      success: true,
      data: {
        account: this.toItem(account),
        templates: result.response
      },
      meta: {}
    };
  }

"""
    text = text.replace(marker, insert + marker)

if "private async getAccessTokenEncrypted" not in text:
    marker2 = "  private async findAccountOrFail"
    insert2 = """  private async getAccessTokenEncrypted(accountId: string): Promise<string> {
    const account = await this.prismaService.whatsappAccount.findUnique({
      where: {
        id: accountId
      }
    });

    return account?.accessTokenEncrypted || 'not_configured';
  }

"""
    text = text.replace(marker2, insert2 + marker2)

path.write_text(text)
PY

echo "Atualizando conversations.controller.ts..."

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
  CreateConversationPayload,
  SendConversationTemplatePayload
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

  @Post(':id/templates')
  sendTemplate(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: SendConversationTemplatePayload
  ) {
    return this.conversationsService.sendConversationTemplate(user.tenantId, id, body);
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

echo "Inserindo envio de template em conversations.service.ts..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/conversations/conversations.service.ts")
text = path.read_text()

text = text.replace(
    "CreateConversationPayload\n} from './conversations.types';",
    "CreateConversationPayload,\n  SendConversationTemplatePayload\n} from './conversations.types';"
)

if "async sendConversationTemplate(" not in text:
    marker = "  async closeConversation(tenantId: string, conversationId: string): Promise<ConversationResponse> {"
    method = """  async sendConversationTemplate(
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

"""
    text = text.replace(marker, method + marker)

path.write_text(text)
PY

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/meta-whatsapp" \
  "${BACKEND_DIR}/src/modules/conversations" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts"
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
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

echo "Listando contas WhatsApp..."

DOMAIN_ACCOUNTS_STATUS="$(curl -L -s -o "${DOMAIN_ACCOUNTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_STATUS}" != "200" ]; then
  echo "ERRO: listagem de contas falhou. Status ${DOMAIN_ACCOUNTS_STATUS}"
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

ACCOUNT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const accounts=data.data.accounts||[]; const found=accounts.find((account)=>account.status==='active' && account.phoneNumberId==='1235882016268785') || accounts.find((account)=>account.status==='active' && /^[0-9]+$/.test(account.phoneNumberId)); if(!found){process.exit(2)} console.log(found.id)" "${DOMAIN_ACCOUNTS_LOG}" || true)"

if [ -z "${ACCOUNT_ID}" ]; then
  echo "ERRO: nenhuma conta ativa real encontrada."
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

echo "Listando templates da conta..."

DOMAIN_TEMPLATES_STATUS="$(curl -L -s -o "${DOMAIN_TEMPLATES_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}/${ACCOUNT_ID}/templates" || true)"

if [ "${DOMAIN_TEMPLATES_STATUS}" != "200" ] && [ "${DOMAIN_TEMPLATES_STATUS}" != "201" ]; then
  echo "ERRO: listar templates falhou. Status ${DOMAIN_TEMPLATES_STATUS}"
  cat "${DOMAIN_TEMPLATES_LOG}"
  exit 1
fi

if ! grep -q "templates" "${DOMAIN_TEMPLATES_LOG}"; then
  echo "ERRO: resposta de templates nao contem templates."
  cat "${DOMAIN_TEMPLATES_LOG}"
  exit 1
fi

echo "Criando conversa para envio de template..."

TEST_RECIPIENT_PHONE="$(get_env_value "META_TEST_RECIPIENT_PHONE" "${BASE_DIR}/.env")"
TEST_RECIPIENT_PHONE="$(node -e "console.log(String(process.argv[1] || '').replace(/[^0-9]/g,''))" "${TEST_RECIPIENT_PHONE}")"

if [ -z "${TEST_RECIPIENT_PHONE}" ]; then
  echo "ERRO: META_TEST_RECIPIENT_PHONE nao configurado."
  exit 1
fi

CONVERSATION_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Template Meta Etapa 41', phone:process.argv[1], initialMessage:'Conversa criada para teste de template etapa 41'}))" "${TEST_RECIPIENT_PHONE}")"

DOMAIN_CREATE_CONVERSATION_STATUS="$(curl -L -s -o "${DOMAIN_CREATE_CONVERSATION_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CONVERSATION_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_URL}" || true)"

if [ "${DOMAIN_CREATE_CONVERSATION_STATUS}" != "200" ] && [ "${DOMAIN_CREATE_CONVERSATION_STATUS}" != "201" ]; then
  echo "ERRO: criar conversa falhou. Status ${DOMAIN_CREATE_CONVERSATION_STATUS}"
  cat "${DOMAIN_CREATE_CONVERSATION_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.conversation.id)" "${DOMAIN_CREATE_CONVERSATION_LOG}")"

TEMPLATE_NAME="$(get_env_value "META_TEMPLATE_TEST_NAME" "${BASE_DIR}/.env")"
TEMPLATE_LANGUAGE="$(get_env_value "META_TEMPLATE_TEST_LANGUAGE" "${BASE_DIR}/.env")"

TEMPLATE_PAYLOAD="$(node -e "console.log(JSON.stringify({templateName:process.argv[1], languageCode:process.argv[2]}))" "${TEMPLATE_NAME}" "${TEMPLATE_LANGUAGE}")"

echo "Enviando template pela Meta..."

DOMAIN_SEND_TEMPLATE_STATUS="$(curl -L -s -o "${DOMAIN_SEND_TEMPLATE_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${TEMPLATE_PAYLOAD}" \
  "${DOMAIN_CONVERSATIONS_URL}/${CONVERSATION_ID}/templates" || true)"

if [ "${DOMAIN_SEND_TEMPLATE_STATUS}" != "200" ] && [ "${DOMAIN_SEND_TEMPLATE_STATUS}" != "201" ]; then
  echo "ERRO: endpoint de envio de template falhou. Status ${DOMAIN_SEND_TEMPLATE_STATUS}"
  cat "${DOMAIN_SEND_TEMPLATE_LOG}"
  exit 1
fi

TEMPLATE_MESSAGE_STATUS="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.message.status)" "${DOMAIN_SEND_TEMPLATE_LOG}")"

if [ "${TEMPLATE_MESSAGE_STATUS}" = "sent" ]; then
  echo "Template aceito pela Meta com status sent."
else
  echo "ATENCAO: template retornou status ${TEMPLATE_MESSAGE_STATUS}."
  echo "Veja ${DOMAIN_SEND_TEMPLATE_LOG}"
fi

echo "Buscando conversa apos envio de template..."

DOMAIN_GET_CONVERSATION_STATUS="$(curl -L -s -o "${DOMAIN_GET_CONVERSATION_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_CONVERSATIONS_URL}/${CONVERSATION_ID}" || true)"

if [ "${DOMAIN_GET_CONVERSATION_STATUS}" != "200" ]; then
  echo "ERRO: buscar conversa falhou. Status ${DOMAIN_GET_CONVERSATION_STATUS}"
  cat "${DOMAIN_GET_CONVERSATION_LOG}"
  exit 1
fi

if ! grep -q "providerMessageId" "${DOMAIN_GET_CONVERSATION_LOG}"; then
  echo "ERRO: conversa nao retornou providerMessageId."
  cat "${DOMAIN_GET_CONVERSATION_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 41..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Meta Templates

## Visao geral

Este documento registra o suporte a templates oficiais da Meta.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- listar templates oficiais da WABA
- enviar template oficial para contato de conversa
- suporte ao template hello_world
- suporte a idioma do template
- gravar providerMessageId quando retornado
- marcar status sent quando aceito
- marcar status failed quando rejeitado
- salvar retorno da Meta em metadata sem expor token

## Endpoints criados

Endpoints:

- GET api v1 whatsapp accounts id templates
- POST api v1 conversations id templates

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.types.ts
- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.service.ts
- apps/backend/src/modules/conversations/conversations.controller.ts
- apps/backend/src/modules/conversations/conversations.service.ts
- apps/backend/src/modules/conversations/conversations.types.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.module.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.types.ts
- .env
- .env.example
- docs/BACKEND_META_TEMPLATES.md
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
- listagem de contas dominio
- listagem de templates dominio
- criacao de conversa dominio
- envio de template dominio
- busca da conversa apos envio

## Logs gerados

Logs:

- logs/setup_41_backend_typecheck.log
- logs/setup_41_backend_build.log
- logs/setup_41_backend_docker_build.log
- logs/setup_41_backend_docker_up.log
- logs/setup_41_backend_wait.log
- logs/setup_41_auth_login_domain.log
- logs/setup_41_whatsapp_accounts_domain.log
- logs/setup_41_templates_list_domain.log
- logs/setup_41_conversation_create_domain.log
- logs/setup_41_template_send_domain.log
- logs/setup_41_conversation_get_domain.log
- logs/setup_41.log

## Observacoes

Templates sao importantes para mensagens iniciadas pela empresa e para testes oficiais como hello_world.

## Proxima etapa sugerida

Etapa 42:

    Criar frontend para envio de templates oficiais
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
- [ ] Etapa 42 - Frontend para templates oficiais

## Ultima etapa executada

Etapa 41 - Templates oficiais da Meta.

## Proxima etapa sugerida

Etapa 42 - Criar frontend para envio de templates oficiais.
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

## Etapas concluidas

- Etapa 01 ate Etapa 41 concluidas

## Proxima etapa

- Etapa 42 - Frontend para templates oficiais
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
Etapa: 41
Acao: Suporte a templates oficiais da Meta
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Accounts status: ${DOMAIN_ACCOUNTS_STATUS}
Templates status: ${DOMAIN_TEMPLATES_STATUS}
Create conversation status: ${DOMAIN_CREATE_CONVERSATION_STATUS}
Send template status: ${DOMAIN_SEND_TEMPLATE_STATUS}
Template message final status: ${TEMPLATE_MESSAGE_STATUS}
Get conversation status: ${DOMAIN_GET_CONVERSATION_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 41 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Resultado do envio de template:"
cat "${DOMAIN_SEND_TEMPLATE_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 42 - Criar frontend para envio de templates oficiais"
