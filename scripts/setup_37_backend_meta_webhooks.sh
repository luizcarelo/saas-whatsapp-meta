#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_37.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_37_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_37_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_37_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_37_backend_docker_up.log"
LOCAL_VERIFY_LOG="${LOGS_DIR}/setup_37_webhook_verify_local.log"
DOMAIN_VERIFY_LOG="${LOGS_DIR}/setup_37_webhook_verify_domain.log"
LOCAL_POST_LOG="${LOGS_DIR}/setup_37_webhook_post_local.log"
DOMAIN_POST_LOG="${LOGS_DIR}/setup_37_webhook_post_domain.log"
LOCAL_EVENTS_LOG="${LOGS_DIR}/setup_37_webhook_events_local.log"
DOC_FILE="${DOCS_DIR}/BACKEND_META_WEBHOOKS.md"

LOCAL_WEBHOOK_URL="http://127.0.0.1:3300/api/v1/webhooks/meta"
DOMAIN_WEBHOOK_URL="https://bot.lhsolucao.com.br/api/v1/webhooks/meta"

echo "== Etapa 37: Modulo backend de webhooks da Meta =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/webhooks"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/webhooks.module.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.controller.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.service.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.types.ts" \
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

echo "Garantindo variavel WHATSAPP_VERIFY_TOKEN..."

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

CURRENT_VERIFY_TOKEN="$(get_env_value "WHATSAPP_VERIFY_TOKEN" "${BASE_DIR}/.env")"

if [ -z "${CURRENT_VERIFY_TOKEN}" ]; then
  VERIFY_TOKEN="$(node -e "console.log('verify_' + require('crypto').randomBytes(16).toString('hex'))")"
else
  VERIFY_TOKEN="${CURRENT_VERIFY_TOKEN}"
fi

set_env_value "WHATSAPP_VERIFY_TOKEN" "change_me_verify_token" "${BASE_DIR}/.env.example"
set_env_value "WHATSAPP_VERIFY_TOKEN" "${VERIFY_TOKEN}" "${BASE_DIR}/.env"

echo "Criando meta-webhooks.types.ts..."

cat > "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.types.ts" <<'DOC'
export type MetaWebhookQuery = {
  'hub.mode'?: string;
  'hub.verify_token'?: string;
  'hub.challenge'?: string;
};

export type MetaWebhookValue = {
  messaging_product?: string;
  metadata?: {
    display_phone_number?: string;
    phone_number_id?: string;
  };
  contacts?: Array<{
    wa_id?: string;
    profile?: {
      name?: string;
    };
  }>;
  messages?: Array<{
    from?: string;
    id?: string;
    timestamp?: string;
    type?: string;
    text?: {
      body?: string;
    };
  }>;
  statuses?: Array<{
    id?: string;
    status?: string;
    timestamp?: string;
    recipient_id?: string;
  }>;
};

export type MetaWebhookPayload = {
  object?: string;
  entry?: Array<{
    id?: string;
    changes?: Array<{
      field?: string;
      value?: MetaWebhookValue;
    }>;
  }>;
};

export type MetaWebhookPostResponse = {
  success: true;
  data: {
    received: true;
    events: number;
    messages: number;
    statuses: number;
  };
  meta: Record<string, never>;
};
DOC

echo "Criando meta-webhooks.service.ts..."

cat > "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import {
  ConversationStatus,
  MessageDirection,
  MessageStatus,
  MessageType,
  WebhookEventStatus,
  WhatsappAccountStatus
} from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import type {
  MetaWebhookPayload,
  MetaWebhookPostResponse,
  MetaWebhookValue
} from './meta-webhooks.types';

@Injectable()
export class MetaWebhooksService {
  constructor(private readonly prismaService: PrismaService) {}

  async receivePayload(payload: MetaWebhookPayload): Promise<MetaWebhookPostResponse> {
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
        statuses
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
DOC

echo "Criando meta-webhooks.controller.ts..."

cat > "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Post,
  Query
} from '@nestjs/common';
import { MetaWebhooksService } from './meta-webhooks.service';
import type {
  MetaWebhookPayload,
  MetaWebhookQuery
} from './meta-webhooks.types';

@Controller('webhooks/meta')
export class MetaWebhooksController {
  constructor(private readonly metaWebhooksService: MetaWebhooksService) {}

  @Get()
  verifyWebhook(@Query() query: MetaWebhookQuery): string {
    const mode = query['hub.mode'];
    const token = query['hub.verify_token'];
    const challenge = query['hub.challenge'];
    const expectedToken = process.env.WHATSAPP_VERIFY_TOKEN || '';

    if (mode === 'subscribe' && token === expectedToken && challenge) {
      return challenge;
    }

    throw new ForbiddenException('Webhook verification failed');
  }

  @Post()
  receiveWebhook(@Body() body: MetaWebhookPayload) {
    return this.metaWebhooksService.receivePayload(body);
  }
}
DOC

echo "Criando webhooks.module.ts..."

cat > "${BACKEND_DIR}/src/modules/webhooks/webhooks.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { MetaWebhooksController } from './meta-webhooks.controller';
import { MetaWebhooksService } from './meta-webhooks.service';

@Module({
  imports: [
    DatabaseModule
  ],
  controllers: [
    MetaWebhooksController
  ],
  providers: [
    MetaWebhooksService
  ],
  exports: [
    MetaWebhooksService
  ]
})
export class WebhooksModule {}
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
import { WebhooksModule } from './modules/webhooks/webhooks.module';
import { WhatsappAccountsModule } from './modules/whatsapp-accounts/whatsapp-accounts.module';

@Module({
  imports: [
    ConfigurationModule,
    DatabaseModule,
    HealthModule,
    AuthModule,
    UsersModule,
    ContactsModule,
    ConversationsModule,
    WhatsappAccountsModule,
    WebhooksModule
  ],
  controllers: [],
  providers: []
})
export class AppModule {}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/webhooks" \
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

echo "Testando verificacao local..."

VERIFY_CHALLENGE="challenge_${STAMP}"

LOCAL_VERIFY_STATUS="$(curl -s -o "${LOCAL_VERIFY_LOG}" -w "%{http_code}" --max-time 20 \
  "${LOCAL_WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=${VERIFY_CHALLENGE}" || true)"

if [ "${LOCAL_VERIFY_STATUS}" != "200" ]; then
  echo "ERRO: verificacao local falhou. Status ${LOCAL_VERIFY_STATUS}"
  cat "${LOCAL_VERIFY_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q "${VERIFY_CHALLENGE}" "${LOCAL_VERIFY_LOG}"; then
  echo "ERRO: verificacao local nao retornou challenge."
  cat "${LOCAL_VERIFY_LOG}"
  exit 1
fi

echo "Testando verificacao dominio..."

DOMAIN_VERIFY_STATUS="$(curl -L -s -o "${DOMAIN_VERIFY_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=${VERIFY_CHALLENGE}" || true)"

if [ "${DOMAIN_VERIFY_STATUS}" != "200" ]; then
  echo "ERRO: verificacao dominio falhou. Status ${DOMAIN_VERIFY_STATUS}"
  cat "${DOMAIN_VERIFY_LOG}"
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "${VERIFY_CHALLENGE}" "${DOMAIN_VERIFY_LOG}"; then
  echo "ERRO: verificacao dominio nao retornou challenge."
  cat "${DOMAIN_VERIFY_LOG}"
  exit 1
fi

echo "Criando payload de webhook..."

WEBHOOK_PAYLOAD_FILE="${LOGS_DIR}/setup_37_webhook_payload.json"

cat > "${WEBHOOK_PAYLOAD_FILE}" <<DOC
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "waba_test_37",
      "changes": [
        {
          "field": "messages",
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "5521999993737",
              "phone_number_id": "phone_webhook_37_${STAMP}"
            },
            "contacts": [
              {
                "wa_id": "552188887777",
                "profile": {
                  "name": "Contato Webhook Etapa 37"
                }
              }
            ],
            "messages": [
              {
                "from": "552188887777",
                "id": "wamid.etapa37.${STAMP}",
                "timestamp": "1760000000",
                "type": "text",
                "text": {
                  "body": "Mensagem recebida via webhook etapa 37"
                }
              }
            ]
          }
        }
      ]
    }
  ]
}
DOC

echo "Testando POST local..."

LOCAL_POST_STATUS="$(curl -s -o "${LOCAL_POST_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Content-Type: application/json" \
  --data-binary "@${WEBHOOK_PAYLOAD_FILE}" \
  "${LOCAL_WEBHOOK_URL}" || true)"

if [ "${LOCAL_POST_STATUS}" != "200" ] && [ "${LOCAL_POST_STATUS}" != "201" ]; then
  echo "ERRO: POST local falhou. Status ${LOCAL_POST_STATUS}"
  cat "${LOCAL_POST_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q "received" "${LOCAL_POST_LOG}"; then
  echo "ERRO: POST local nao retornou received."
  cat "${LOCAL_POST_LOG}"
  exit 1
fi

echo "Testando POST dominio..."

DOMAIN_POST_STATUS="$(curl -L -s -o "${DOMAIN_POST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  --data-binary "@${WEBHOOK_PAYLOAD_FILE}" \
  "${DOMAIN_WEBHOOK_URL}" || true)"

if [ "${DOMAIN_POST_STATUS}" != "200" ] && [ "${DOMAIN_POST_STATUS}" != "201" ]; then
  echo "ERRO: POST dominio falhou. Status ${DOMAIN_POST_STATUS}"
  cat "${DOMAIN_POST_LOG}"
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "received" "${DOMAIN_POST_LOG}"; then
  echo "ERRO: POST dominio nao retornou received."
  cat "${DOMAIN_POST_LOG}"
  exit 1
fi

echo "Validando eventos gravados..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as webhook_events from webhook_events;" 2>&1 | tee "${LOCAL_EVENTS_LOG}"
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as webhook_messages from messages where provider_message_id like 'wamid.etapa37.%';" 2>&1 | tee -a "${LOCAL_EVENTS_LOG}"

echo "Gerando documentacao da Etapa 37..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Meta Webhooks

## Visao geral

Este documento registra a criacao do modulo backend de webhooks da Meta.

## Resultado

Status:

    concluido

## Endpoints criados

Endpoints:

- GET api v1 webhooks meta
- POST api v1 webhooks meta

## Funcionalidades

Funcionalidades:

- verificacao do webhook usando hub mode
- validacao do verify token
- retorno do hub challenge
- recebimento de payload POST
- gravacao de webhook events
- criacao automatica de conta WhatsApp quando necessario
- criacao ou atualizacao de contato por wa id
- criacao de conversa quando necessario
- gravacao de mensagem inbound
- processamento basico de status de mensagem

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/webhooks/webhooks.module.ts
- apps/backend/src/modules/webhooks/meta-webhooks.controller.ts
- apps/backend/src/modules/webhooks/meta-webhooks.service.ts
- apps/backend/src/modules/webhooks/meta-webhooks.types.ts
- apps/backend/src/app.module.ts
- .env
- .env.example
- docs/BACKEND_META_WEBHOOKS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- verificacao local com hub challenge
- verificacao dominio com hub challenge
- POST local com payload de mensagem
- POST dominio com payload de mensagem
- contagem de webhook events no banco
- contagem de mensagens de teste no banco

## Logs gerados

Logs:

- logs/setup_37_backend_typecheck.log
- logs/setup_37_backend_build.log
- logs/setup_37_backend_docker_build.log
- logs/setup_37_backend_docker_up.log
- logs/setup_37_webhook_verify_local.log
- logs/setup_37_webhook_verify_domain.log
- logs/setup_37_webhook_post_local.log
- logs/setup_37_webhook_post_domain.log
- logs/setup_37_webhook_events_local.log
- logs/setup_37.log

## Configuracao para Meta

Callback URL:

    https bot lhsolucao com br api v1 webhooks meta

Verify Token:

    definido em WHATSAPP_VERIFY_TOKEN no arquivo .env

## Observacoes

A validacao de assinatura X-Hub-Signature-256 ainda nao foi implementada nesta etapa.

Essa validacao exige acesso ao corpo bruto da requisicao antes do parse JSON.

## Proxima etapa sugerida

Etapa 38:

    Criar validacao de assinatura dos webhooks da Meta
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
- [ ] Etapa 38 - Validacao de assinatura dos webhooks da Meta

## Ultima etapa executada

Etapa 37 - Modulo backend de webhooks da Meta.

## Proxima etapa sugerida

Etapa 38 - Criar validacao de assinatura dos webhooks da Meta.
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

## Etapas concluidas

- Etapa 01 ate Etapa 37 concluidas

## Proxima etapa

- Etapa 38 - Validacao de assinatura dos webhooks da Meta
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
Etapa: 37
Acao: Modulo backend de webhooks da Meta
Data: $(date '+%Y-%m-%d %H:%M:%S')
Verify local status: ${LOCAL_VERIFY_STATUS}
Verify dominio status: ${DOMAIN_VERIFY_STATUS}
Post local status: ${LOCAL_POST_STATUS}
Post dominio status: ${DOMAIN_POST_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 37 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Verify token salvo em .env:"
echo "WHATSAPP_VERIFY_TOKEN=${VERIFY_TOKEN}"
echo ""
echo "Callback URL para Meta:"
echo "https://bot.lhsolucao.com.br/api/v1/webhooks/meta"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 38 - Criar validacao de assinatura dos webhooks da Meta"
