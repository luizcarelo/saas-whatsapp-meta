#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_30.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_30_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_30_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_30_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_30_backend_docker_up.log"
LOCAL_LOGIN_LOG="${LOGS_DIR}/setup_30_auth_login_local.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_30_auth_login_domain.log"
LOCAL_CREATE_LOG="${LOGS_DIR}/setup_30_contacts_create_local.log"
LOCAL_LIST_LOG="${LOGS_DIR}/setup_30_contacts_list_local.log"
LOCAL_GET_LOG="${LOGS_DIR}/setup_30_contacts_get_local.log"
LOCAL_UPDATE_LOG="${LOGS_DIR}/setup_30_contacts_update_local.log"
LOCAL_DELETE_LOG="${LOGS_DIR}/setup_30_contacts_delete_local.log"
DOMAIN_LIST_LOG="${LOGS_DIR}/setup_30_contacts_list_domain.log"
DOMAIN_CREATE_LOG="${LOGS_DIR}/setup_30_contacts_create_domain.log"
DOC_FILE="${DOCS_DIR}/BACKEND_CONTACTS.md"

LOCAL_LOGIN_URL="http://127.0.0.1:3300/api/v1/auth/login"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/api/v1/auth/login"
LOCAL_CONTACTS_URL="http://127.0.0.1:3300/api/v1/contacts"
DOMAIN_CONTACTS_URL="https://bot.lhsolucao.com.br/api/v1/contacts"

echo "== Etapa 30: Modulo backend de contatos =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/contacts"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/contacts/contacts.module.ts" \
  "${BACKEND_DIR}/src/modules/contacts/contacts.controller.ts" \
  "${BACKEND_DIR}/src/modules/contacts/contacts.service.ts" \
  "${BACKEND_DIR}/src/modules/contacts/contacts.types.ts" \
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

echo "Criando contacts.types.ts..."

cat > "${BACKEND_DIR}/src/modules/contacts/contacts.types.ts" <<'DOC'
export type ContactPayload = {
  name?: string;
  phone?: string;
  waId?: string;
  email?: string;
  document?: string;
};

export type ContactItem = {
  id: string;
  tenantId: string;
  name: string | null;
  phone: string;
  waId: string | null;
  email: string | null;
  document: string | null;
  createdAt: string;
  updatedAt: string;
};

export type ContactListResponse = {
  success: true;
  data: {
    contacts: ContactItem[];
    total: number;
  };
  meta: Record<string, never>;
};

export type ContactResponse = {
  success: true;
  data: {
    contact: ContactItem;
  };
  meta: Record<string, never>;
};

export type ContactDeleteResponse = {
  success: true;
  data: {
    deleted: true;
    id: string;
  };
  meta: Record<string, never>;
};
DOC

echo "Criando contacts.service.ts..."

cat > "${BACKEND_DIR}/src/modules/contacts/contacts.service.ts" <<'DOC'
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
DOC

echo "Criando contacts.controller.ts..."

cat > "${BACKEND_DIR}/src/modules/contacts/contacts.controller.ts" <<'DOC'
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
import { ContactsService } from './contacts.service';
import type { ContactPayload } from './contacts.types';

type ListContactsQuery = {
  search?: string;
  limit?: string;
  offset?: string;
};

@Controller('contacts')
@UseGuards(JwtAuthGuard)
export class ContactsController {
  constructor(private readonly contactsService: ContactsService) {}

  @Get()
  listContacts(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListContactsQuery
  ) {
    return this.contactsService.listContacts(user.tenantId, query);
  }

  @Post()
  createContact(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: ContactPayload
  ) {
    return this.contactsService.createContact(user.tenantId, body);
  }

  @Get(':id')
  getContact(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.contactsService.getContact(user.tenantId, id);
  }

  @Patch(':id')
  updateContact(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: ContactPayload
  ) {
    return this.contactsService.updateContact(user.tenantId, id, body);
  }

  @Delete(':id')
  deleteContact(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.contactsService.deleteContact(user.tenantId, id);
  }
}
DOC

echo "Criando contacts.module.ts..."

cat > "${BACKEND_DIR}/src/modules/contacts/contacts.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { ContactsController } from './contacts.controller';
import { ContactsService } from './contacts.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    ContactsController
  ],
  providers: [
    ContactsService
  ],
  exports: [
    ContactsService
  ]
})
export class ContactsModule {}
DOC

echo "Atualizando app.module.ts..."

cat > "${BACKEND_DIR}/src/app.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { AuthModule } from './modules/auth/auth.module';
import { ConfigurationModule } from './modules/configuration/configuration.module';
import { ContactsModule } from './modules/contacts/contacts.module';
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
    ContactsModule
  ],
  controllers: [],
  providers: []
})
export class AppModule {}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/contacts" \
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

echo "Criando contato local..."

CONTACT_PHONE="5521999${STAMP}"
CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Contato Teste Etapa 30', phone:process.argv[1], email:'contato30@lhsolucao.com.br'}))" "${CONTACT_PHONE}")"

LOCAL_CREATE_STATUS="$(curl -s -o "${LOCAL_CREATE_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CREATE_PAYLOAD}" \
  "${LOCAL_CONTACTS_URL}" || true)"

if [ "${LOCAL_CREATE_STATUS}" != "200" ] && [ "${LOCAL_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: criar contato local falhou. Status ${LOCAL_CREATE_STATUS}"
  cat "${LOCAL_CREATE_LOG}"
  exit 1
fi

CONTACT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.contact.id)" "${LOCAL_CREATE_LOG}")"

if [ -z "${CONTACT_ID}" ]; then
  echo "ERRO: id do contato nao encontrado."
  cat "${LOCAL_CREATE_LOG}"
  exit 1
fi

echo "Listando contatos local..."

LOCAL_LIST_STATUS="$(curl -s -o "${LOCAL_LIST_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_CONTACTS_URL}" || true)"

if [ "${LOCAL_LIST_STATUS}" != "200" ]; then
  echo "ERRO: listar contatos local falhou. Status ${LOCAL_LIST_STATUS}"
  cat "${LOCAL_LIST_LOG}"
  exit 1
fi

if ! grep -q "contacts" "${LOCAL_LIST_LOG}"; then
  echo "ERRO: listagem local nao retornou contacts."
  cat "${LOCAL_LIST_LOG}"
  exit 1
fi

echo "Buscando contato local..."

LOCAL_GET_STATUS="$(curl -s -o "${LOCAL_GET_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_CONTACTS_URL}/${CONTACT_ID}" || true)"

if [ "${LOCAL_GET_STATUS}" != "200" ]; then
  echo "ERRO: buscar contato local falhou. Status ${LOCAL_GET_STATUS}"
  cat "${LOCAL_GET_LOG}"
  exit 1
fi

echo "Atualizando contato local..."

UPDATE_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Contato Teste Etapa 30 Atualizado'}))")"

LOCAL_UPDATE_STATUS="$(curl -s -o "${LOCAL_UPDATE_LOG}" -w "%{http_code}" --max-time 20 \
  -X PATCH \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${UPDATE_PAYLOAD}" \
  "${LOCAL_CONTACTS_URL}/${CONTACT_ID}" || true)"

if [ "${LOCAL_UPDATE_STATUS}" != "200" ]; then
  echo "ERRO: atualizar contato local falhou. Status ${LOCAL_UPDATE_STATUS}"
  cat "${LOCAL_UPDATE_LOG}"
  exit 1
fi

if ! grep -q "Atualizado" "${LOCAL_UPDATE_LOG}"; then
  echo "ERRO: atualizacao local nao retornou nome atualizado."
  cat "${LOCAL_UPDATE_LOG}"
  exit 1
fi

echo "Removendo contato local..."

LOCAL_DELETE_STATUS="$(curl -s -o "${LOCAL_DELETE_LOG}" -w "%{http_code}" --max-time 20 \
  -X DELETE \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_CONTACTS_URL}/${CONTACT_ID}" || true)"

if [ "${LOCAL_DELETE_STATUS}" != "200" ]; then
  echo "ERRO: remover contato local falhou. Status ${LOCAL_DELETE_STATUS}"
  cat "${LOCAL_DELETE_LOG}"
  exit 1
fi

if ! grep -q "deleted" "${LOCAL_DELETE_LOG}"; then
  echo "ERRO: delete local nao retornou deleted."
  cat "${LOCAL_DELETE_LOG}"
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

echo "Listando contatos dominio..."

DOMAIN_LIST_STATUS="$(curl -L -s -o "${DOMAIN_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_CONTACTS_URL}" || true)"

if [ "${DOMAIN_LIST_STATUS}" != "200" ]; then
  echo "ERRO: listar contatos dominio falhou. Status ${DOMAIN_LIST_STATUS}"
  cat "${DOMAIN_LIST_LOG}"
  exit 1
fi

if ! grep -q "contacts" "${DOMAIN_LIST_LOG}"; then
  echo "ERRO: listagem dominio nao retornou contacts."
  cat "${DOMAIN_LIST_LOG}"
  exit 1
fi

echo "Criando contato dominio..."

DOMAIN_CONTACT_PHONE="5521888${STAMP}"
DOMAIN_CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Contato Dominio Etapa 30', phone:process.argv[1], email:'contato30dominio@lhsolucao.com.br'}))" "${DOMAIN_CONTACT_PHONE}")"

DOMAIN_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${DOMAIN_CREATE_PAYLOAD}" \
  "${DOMAIN_CONTACTS_URL}" || true)"

if [ "${DOMAIN_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: criar contato dominio falhou. Status ${DOMAIN_CREATE_STATUS}"
  cat "${DOMAIN_CREATE_LOG}"
  exit 1
fi

if ! grep -q "Contato Dominio Etapa 30" "${DOMAIN_CREATE_LOG}"; then
  echo "ERRO: criacao dominio nao retornou contato esperado."
  cat "${DOMAIN_CREATE_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 30..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Contacts

## Visao geral

Este documento registra a criacao do modulo backend de contatos.

## Resultado

Status:

    concluido

## Endpoints criados

Endpoints:

- GET api v1 contacts
- POST api v1 contacts
- GET api v1 contacts id
- PATCH api v1 contacts id
- DELETE api v1 contacts id

## Funcionalidades

Funcionalidades:

- listar contatos do tenant autenticado
- buscar contato por id
- criar contato
- atualizar contato
- remover contato com deletedAt
- validar telefone duplicado por tenant
- filtrar contatos por busca simples

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/contacts/contacts.module.ts
- apps/backend/src/modules/contacts/contacts.controller.ts
- apps/backend/src/modules/contacts/contacts.service.ts
- apps/backend/src/modules/contacts/contacts.types.ts
- apps/backend/src/app.module.ts
- docs/BACKEND_CONTACTS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- login local
- criar contato local
- listar contatos local
- buscar contato local
- atualizar contato local
- remover contato local
- login dominio
- listar contatos dominio
- criar contato dominio

## Logs gerados

Logs:

- logs/setup_30_backend_typecheck.log
- logs/setup_30_backend_build.log
- logs/setup_30_backend_docker_build.log
- logs/setup_30_backend_docker_up.log
- logs/setup_30_auth_login_local.log
- logs/setup_30_auth_login_domain.log
- logs/setup_30_contacts_create_local.log
- logs/setup_30_contacts_list_local.log
- logs/setup_30_contacts_get_local.log
- logs/setup_30_contacts_update_local.log
- logs/setup_30_contacts_delete_local.log
- logs/setup_30_contacts_list_domain.log
- logs/setup_30_contacts_create_domain.log
- logs/setup_30.log

## Proxima etapa sugerida

Etapa 31:

    Criar frontend de contatos integrado ao backend
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
- [ ] Etapa 31 - Frontend de contatos integrado

## Ultima etapa executada

Etapa 30 - Modulo backend de contatos.

## Proxima etapa sugerida

Etapa 31 - Criar frontend de contatos integrado ao backend.
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

## Etapas concluidas

- Etapa 01 ate Etapa 30 concluidas

## Proxima etapa

- Etapa 31 - Frontend de contatos integrado
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
Etapa: 30
Acao: Modulo backend de contatos
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login local status: ${LOCAL_LOGIN_STATUS}
Create local status: ${LOCAL_CREATE_STATUS}
List local status: ${LOCAL_LIST_STATUS}
Get local status: ${LOCAL_GET_STATUS}
Update local status: ${LOCAL_UPDATE_STATUS}
Delete local status: ${LOCAL_DELETE_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
List dominio status: ${DOMAIN_LIST_STATUS}
Create dominio status: ${DOMAIN_CREATE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 30 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Contato dominio criado:"
cat "${DOMAIN_CREATE_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 31 - Criar frontend de contatos integrado ao backend"
