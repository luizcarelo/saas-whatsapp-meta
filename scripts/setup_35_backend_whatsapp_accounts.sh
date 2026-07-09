#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_35.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_35_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_35_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_35_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_35_backend_docker_up.log"
LOCAL_LOGIN_LOG="${LOGS_DIR}/setup_35_auth_login_local.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_35_auth_login_domain.log"
LOCAL_CREATE_LOG="${LOGS_DIR}/setup_35_whatsapp_accounts_create_local.log"
LOCAL_LIST_LOG="${LOGS_DIR}/setup_35_whatsapp_accounts_list_local.log"
LOCAL_GET_LOG="${LOGS_DIR}/setup_35_whatsapp_accounts_get_local.log"
LOCAL_UPDATE_LOG="${LOGS_DIR}/setup_35_whatsapp_accounts_update_local.log"
LOCAL_DELETE_LOG="${LOGS_DIR}/setup_35_whatsapp_accounts_delete_local.log"
DOMAIN_LIST_LOG="${LOGS_DIR}/setup_35_whatsapp_accounts_list_domain.log"
DOMAIN_CREATE_LOG="${LOGS_DIR}/setup_35_whatsapp_accounts_create_domain.log"
DOC_FILE="${DOCS_DIR}/BACKEND_WHATSAPP_ACCOUNTS.md"

LOCAL_LOGIN_URL="http://127.0.0.1:3300/api/v1/auth/login"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/api/v1/auth/login"
LOCAL_ACCOUNTS_URL="http://127.0.0.1:3300/api/v1/whatsapp-accounts"
DOMAIN_ACCOUNTS_URL="https://bot.lhsolucao.com.br/api/v1/whatsapp-accounts"

echo "== Etapa 35: Modulo backend de WhatsApp Accounts =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/whatsapp-accounts"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.module.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts" \
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

echo "Criando whatsapp-accounts.types.ts..."

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
DOC

echo "Criando whatsapp-accounts.service.ts..."

cat > "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts" <<'DOC'
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
DOC

echo "Criando whatsapp-accounts.controller.ts..."

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

echo "Criando whatsapp-accounts.module.ts..."

cat > "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { WhatsappAccountsController } from './whatsapp-accounts.controller';
import { WhatsappAccountsService } from './whatsapp-accounts.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
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
    WhatsappAccountsModule
  ],
  controllers: [],
  providers: []
})
export class AppModule {}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts" \
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

echo "Criando conta local..."

LOCAL_PHONE_NUMBER_ID="local_phone_${STAMP}"
LOCAL_CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({wabaId:'local_waba_35', phoneNumberId:process.argv[1], displayPhoneNumber:'+55 21 99999 3535', verifiedName:'Conta Local Etapa 35', accessToken:'token_local_35', status:'pending'}))" "${LOCAL_PHONE_NUMBER_ID}")"

LOCAL_CREATE_STATUS="$(curl -s -o "${LOCAL_CREATE_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${LOCAL_CREATE_PAYLOAD}" \
  "${LOCAL_ACCOUNTS_URL}" || true)"

if [ "${LOCAL_CREATE_STATUS}" != "200" ] && [ "${LOCAL_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: criar conta local falhou. Status ${LOCAL_CREATE_STATUS}"
  cat "${LOCAL_CREATE_LOG}"
  exit 1
fi

ACCOUNT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.account.id)" "${LOCAL_CREATE_LOG}")"

if [ -z "${ACCOUNT_ID}" ]; then
  echo "ERRO: id da conta nao encontrado."
  cat "${LOCAL_CREATE_LOG}"
  exit 1
fi

echo "Listando contas local..."

LOCAL_LIST_STATUS="$(curl -s -o "${LOCAL_LIST_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_ACCOUNTS_URL}" || true)"

if [ "${LOCAL_LIST_STATUS}" != "200" ]; then
  echo "ERRO: listar contas local falhou. Status ${LOCAL_LIST_STATUS}"
  cat "${LOCAL_LIST_LOG}"
  exit 1
fi

if ! grep -q "accounts" "${LOCAL_LIST_LOG}"; then
  echo "ERRO: listagem local nao retornou accounts."
  cat "${LOCAL_LIST_LOG}"
  exit 1
fi

echo "Buscando conta local..."

LOCAL_GET_STATUS="$(curl -s -o "${LOCAL_GET_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_ACCOUNTS_URL}/${ACCOUNT_ID}" || true)"

if [ "${LOCAL_GET_STATUS}" != "200" ]; then
  echo "ERRO: buscar conta local falhou. Status ${LOCAL_GET_STATUS}"
  cat "${LOCAL_GET_LOG}"
  exit 1
fi

echo "Atualizando conta local..."

LOCAL_UPDATE_PAYLOAD="$(node -e "console.log(JSON.stringify({verifiedName:'Conta Local Etapa 35 Atualizada', status:'active'}))")"

LOCAL_UPDATE_STATUS="$(curl -s -o "${LOCAL_UPDATE_LOG}" -w "%{http_code}" --max-time 20 \
  -X PATCH \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${LOCAL_UPDATE_PAYLOAD}" \
  "${LOCAL_ACCOUNTS_URL}/${ACCOUNT_ID}" || true)"

if [ "${LOCAL_UPDATE_STATUS}" != "200" ]; then
  echo "ERRO: atualizar conta local falhou. Status ${LOCAL_UPDATE_STATUS}"
  cat "${LOCAL_UPDATE_LOG}"
  exit 1
fi

if ! grep -q "Atualizada" "${LOCAL_UPDATE_LOG}"; then
  echo "ERRO: atualizacao local nao retornou nome atualizado."
  cat "${LOCAL_UPDATE_LOG}"
  exit 1
fi

echo "Removendo conta local..."

LOCAL_DELETE_STATUS="$(curl -s -o "${LOCAL_DELETE_LOG}" -w "%{http_code}" --max-time 20 \
  -X DELETE \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_ACCOUNTS_URL}/${ACCOUNT_ID}" || true)"

if [ "${LOCAL_DELETE_STATUS}" != "200" ]; then
  echo "ERRO: remover conta local falhou. Status ${LOCAL_DELETE_STATUS}"
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

echo "Listando contas dominio..."

DOMAIN_LIST_STATUS="$(curl -L -s -o "${DOMAIN_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_LIST_STATUS}" != "200" ]; then
  echo "ERRO: listar contas dominio falhou. Status ${DOMAIN_LIST_STATUS}"
  cat "${DOMAIN_LIST_LOG}"
  exit 1
fi

if ! grep -q "accounts" "${DOMAIN_LIST_LOG}"; then
  echo "ERRO: listagem dominio nao retornou accounts."
  cat "${DOMAIN_LIST_LOG}"
  exit 1
fi

echo "Criando conta dominio..."

DOMAIN_PHONE_NUMBER_ID="domain_phone_${STAMP}"
DOMAIN_CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({wabaId:'domain_waba_35', phoneNumberId:process.argv[1], displayPhoneNumber:'+55 21 98888 3535', verifiedName:'Conta Dominio Etapa 35', accessToken:'token_domain_35', status:'pending'}))" "${DOMAIN_PHONE_NUMBER_ID}")"

DOMAIN_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${DOMAIN_CREATE_PAYLOAD}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: criar conta dominio falhou. Status ${DOMAIN_CREATE_STATUS}"
  cat "${DOMAIN_CREATE_LOG}"
  exit 1
fi

if ! grep -q "Conta Dominio Etapa 35" "${DOMAIN_CREATE_LOG}"; then
  echo "ERRO: criacao dominio nao retornou conta esperada."
  cat "${DOMAIN_CREATE_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 35..."

cat > "${DOC_FILE}" <<'DOC'
# Backend WhatsApp Accounts

## Visao geral

Este documento registra a criacao do modulo backend de WhatsApp Accounts.

## Resultado

Status:

    concluido

## Endpoints criados

Endpoints:

- GET api v1 whatsapp accounts
- POST api v1 whatsapp accounts
- GET api v1 whatsapp accounts id
- PATCH api v1 whatsapp accounts id
- DELETE api v1 whatsapp accounts id

## Funcionalidades

Funcionalidades:

- listar contas WhatsApp do tenant autenticado
- buscar conta por id
- criar conta WhatsApp
- atualizar conta WhatsApp
- remover conta com deletedAt
- validar phoneNumberId duplicado por tenant
- filtrar contas por busca simples
- armazenar token em formato codificado local

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.module.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.types.ts
- apps/backend/src/app.module.ts
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- login local
- criar conta local
- listar contas local
- buscar conta local
- atualizar conta local
- remover conta local
- login dominio
- listar contas dominio
- criar conta dominio

## Logs gerados

Logs:

- logs/setup_35_backend_typecheck.log
- logs/setup_35_backend_build.log
- logs/setup_35_backend_docker_build.log
- logs/setup_35_backend_docker_up.log
- logs/setup_35_auth_login_local.log
- logs/setup_35_auth_login_domain.log
- logs/setup_35_whatsapp_accounts_create_local.log
- logs/setup_35_whatsapp_accounts_list_local.log
- logs/setup_35_whatsapp_accounts_get_local.log
- logs/setup_35_whatsapp_accounts_update_local.log
- logs/setup_35_whatsapp_accounts_delete_local.log
- logs/setup_35_whatsapp_accounts_list_domain.log
- logs/setup_35_whatsapp_accounts_create_domain.log
- logs/setup_35.log

## Observacoes

Esta etapa ainda nao integra com a API oficial da Meta.

A integracao real sera criada em etapa futura.

## Proxima etapa sugerida

Etapa 36:

    Criar frontend de WhatsApp Accounts integrado ao backend
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
- [ ] Etapa 36 - Frontend de WhatsApp Accounts integrado

## Ultima etapa executada

Etapa 35 - Modulo backend de WhatsApp Accounts.

## Proxima etapa sugerida

Etapa 36 - Criar frontend de WhatsApp Accounts integrado ao backend.
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

## Etapas concluidas

- Etapa 01 ate Etapa 35 concluidas

## Proxima etapa

- Etapa 36 - Frontend de WhatsApp Accounts integrado
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
Etapa: 35
Acao: Modulo backend de WhatsApp Accounts
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
echo "== Etapa 35 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Conta dominio criada:"
cat "${DOMAIN_CREATE_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 36 - Criar frontend de WhatsApp Accounts integrado ao backend"
