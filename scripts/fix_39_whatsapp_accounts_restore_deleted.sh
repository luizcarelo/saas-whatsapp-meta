#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

FIX_LOG_FILE="${LOGS_DIR}/fix_39_whatsapp_accounts_restore_deleted.log"
TYPECHECK_LOG="${LOGS_DIR}/fix_39_backend_typecheck_whatsapp_restore.log"
BUILD_LOG="${LOGS_DIR}/fix_39_backend_build_whatsapp_restore.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/fix_39_backend_docker_build_whatsapp_restore.log"
DOCKER_UP_LOG="${LOGS_DIR}/fix_39_backend_docker_up_whatsapp_restore.log"
LOCAL_LOGIN_LOG="${LOGS_DIR}/fix_39_auth_login_local.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/fix_39_auth_login_domain.log"
LOCAL_CREATE_LOG="${LOGS_DIR}/fix_39_whatsapp_account_create_local.log"
LOCAL_DELETE_LOG="${LOGS_DIR}/fix_39_whatsapp_account_delete_local.log"
LOCAL_RESTORE_LOG="${LOGS_DIR}/fix_39_whatsapp_account_restore_local.log"
DOMAIN_CREATE_LOG="${LOGS_DIR}/fix_39_whatsapp_account_create_domain.log"
DOMAIN_DELETE_LOG="${LOGS_DIR}/fix_39_whatsapp_account_delete_domain.log"
DOMAIN_RESTORE_LOG="${LOGS_DIR}/fix_39_whatsapp_account_restore_domain.log"
DOMAIN_LIST_LOG="${LOGS_DIR}/fix_39_whatsapp_accounts_list_domain.log"
DOC_FILE="${DOCS_DIR}/BACKEND_WHATSAPP_ACCOUNTS.md"

LOCAL_LOGIN_URL="http://127.0.0.1:3300/api/v1/auth/login"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/api/v1/auth/login"
LOCAL_ACCOUNTS_URL="http://127.0.0.1:3300/api/v1/whatsapp-accounts"
DOMAIN_ACCOUNTS_URL="https://bot.lhsolucao.com.br/api/v1/whatsapp-accounts"

echo "== Correcao: Restaurar WhatsApp Account removida logicamente =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/whatsapp-accounts"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts" \
  "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts" \
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

echo "Regravando whatsapp-accounts.service.ts com restauracao de removidos..."

cat > "${BACKEND_DIR}/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts" <<'DOC'
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { WhatsappAccountStatus } from '@prisma/client';
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
  status: WhatsappAccountStatus;
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
        phoneNumberId
      }
    });

    if (existing && !existing.deletedAt) {
      throw new ConflictException('Conta WhatsApp ja existe para este phoneNumberId');
    }

    if (existing && existing.deletedAt) {
      const restored = await this.prismaService.whatsappAccount.update({
        where: {
          id: existing.id
        },
        data: {
          deletedAt: null,
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
          account: this.toItem(restored)
        },
        meta: {}
      };
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
        ...(payload.wabaId !== undefined
          ? { wabaId: this.requiredValue(payload.wabaId, 'WABA ID obrigatorio') }
          : {}),
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
        status: WhatsappAccountStatus.inactive
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

  private normalizeStatus(value?: string): WhatsappAccountStatus {
    const status = value ? value.trim() : 'pending';

    if (status === 'active') {
      return WhatsappAccountStatus.active;
    }

    if (status === 'inactive') {
      return WhatsappAccountStatus.inactive;
    }

    if (status === 'disconnected') {
      return WhatsappAccountStatus.disconnected;
    }

    if (status === 'error') {
      return WhatsappAccountStatus.error;
    }

    return WhatsappAccountStatus.pending;
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

echo "Criando conta local para teste de restauracao..."

RESTORE_PHONE_NUMBER_ID="restore_phone_${STAMP}"
LOCAL_CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({wabaId:'restore_waba_1', phoneNumberId:process.argv[1], displayPhoneNumber:'+55 21 97777 3901', verifiedName:'Conta Restore Local Original', accessToken:'token_restore_1', status:'pending'}))" "${RESTORE_PHONE_NUMBER_ID}")"

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

LOCAL_ACCOUNT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.account.id)" "${LOCAL_CREATE_LOG}")"

if [ -z "${LOCAL_ACCOUNT_ID}" ]; then
  echo "ERRO: id da conta local nao encontrado."
  cat "${LOCAL_CREATE_LOG}"
  exit 1
fi

echo "Removendo conta local..."

LOCAL_DELETE_STATUS="$(curl -s -o "${LOCAL_DELETE_LOG}" -w "%{http_code}" --max-time 20 \
  -X DELETE \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_ACCOUNTS_URL}/${LOCAL_ACCOUNT_ID}" || true)"

if [ "${LOCAL_DELETE_STATUS}" != "200" ]; then
  echo "ERRO: remover conta local falhou. Status ${LOCAL_DELETE_STATUS}"
  cat "${LOCAL_DELETE_LOG}"
  exit 1
fi

echo "Recriando mesma conta local com mesmo phoneNumberId..."

LOCAL_RESTORE_PAYLOAD="$(node -e "console.log(JSON.stringify({wabaId:'restore_waba_2', phoneNumberId:process.argv[1], displayPhoneNumber:'+55 21 97777 3902', verifiedName:'Conta Restore Local Reativada', accessToken:'token_restore_2', status:'active'}))" "${RESTORE_PHONE_NUMBER_ID}")"

LOCAL_RESTORE_STATUS="$(curl -s -o "${LOCAL_RESTORE_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${LOCAL_RESTORE_PAYLOAD}" \
  "${LOCAL_ACCOUNTS_URL}" || true)"

if [ "${LOCAL_RESTORE_STATUS}" != "200" ] && [ "${LOCAL_RESTORE_STATUS}" != "201" ]; then
  echo "ERRO: restaurar conta local falhou. Status ${LOCAL_RESTORE_STATUS}"
  cat "${LOCAL_RESTORE_LOG}"
  exit 1
fi

if ! grep -q "Conta Restore Local Reativada" "${LOCAL_RESTORE_LOG}"; then
  echo "ERRO: restauracao local nao retornou nome atualizado."
  cat "${LOCAL_RESTORE_LOG}"
  exit 1
fi

if ! grep -q "active" "${LOCAL_RESTORE_LOG}"; then
  echo "ERRO: restauracao local nao retornou status active."
  cat "${LOCAL_RESTORE_LOG}"
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

echo "Criando conta dominio para teste de restauracao..."

DOMAIN_RESTORE_PHONE_NUMBER_ID="restore_domain_phone_${STAMP}"
DOMAIN_CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({wabaId:'restore_domain_waba_1', phoneNumberId:process.argv[1], displayPhoneNumber:'+55 21 96666 3901', verifiedName:'Conta Restore Dominio Original', accessToken:'token_restore_domain_1', status:'pending'}))" "${DOMAIN_RESTORE_PHONE_NUMBER_ID}")"

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

DOMAIN_ACCOUNT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.account.id)" "${DOMAIN_CREATE_LOG}")"

if [ -z "${DOMAIN_ACCOUNT_ID}" ]; then
  echo "ERRO: id da conta dominio nao encontrado."
  cat "${DOMAIN_CREATE_LOG}"
  exit 1
fi

echo "Removendo conta dominio..."

DOMAIN_DELETE_STATUS="$(curl -L -s -o "${DOMAIN_DELETE_LOG}" -w "%{http_code}" --max-time 30 \
  -X DELETE \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}/${DOMAIN_ACCOUNT_ID}" || true)"

if [ "${DOMAIN_DELETE_STATUS}" != "200" ]; then
  echo "ERRO: remover conta dominio falhou. Status ${DOMAIN_DELETE_STATUS}"
  cat "${DOMAIN_DELETE_LOG}"
  exit 1
fi

echo "Recriando mesma conta dominio com mesmo phoneNumberId..."

DOMAIN_RESTORE_PAYLOAD="$(node -e "console.log(JSON.stringify({wabaId:'restore_domain_waba_2', phoneNumberId:process.argv[1], displayPhoneNumber:'+55 21 96666 3902', verifiedName:'Conta Restore Dominio Reativada', accessToken:'token_restore_domain_2', status:'active'}))" "${DOMAIN_RESTORE_PHONE_NUMBER_ID}")"

DOMAIN_RESTORE_STATUS="$(curl -L -s -o "${DOMAIN_RESTORE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${DOMAIN_RESTORE_PAYLOAD}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_RESTORE_STATUS}" != "200" ] && [ "${DOMAIN_RESTORE_STATUS}" != "201" ]; then
  echo "ERRO: restaurar conta dominio falhou. Status ${DOMAIN_RESTORE_STATUS}"
  cat "${DOMAIN_RESTORE_LOG}"
  exit 1
fi

if ! grep -q "Conta Restore Dominio Reativada" "${DOMAIN_RESTORE_LOG}"; then
  echo "ERRO: restauracao dominio nao retornou nome atualizado."
  cat "${DOMAIN_RESTORE_LOG}"
  exit 1
fi

if ! grep -q "active" "${DOMAIN_RESTORE_LOG}"; then
  echo "ERRO: restauracao dominio nao retornou status active."
  cat "${DOMAIN_RESTORE_LOG}"
  exit 1
fi

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

echo "Atualizando documentacao..."

cat > "${DOC_FILE}" <<'DOC'
# Backend WhatsApp Accounts

## Visao geral

Este documento registra a criacao e ajustes do modulo backend de WhatsApp Accounts.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi adicionada restauracao automatica de contas removidas logicamente.

Quando uma conta com o mesmo tenant e phoneNumberId existe com deletedAt preenchido, o cadastro passa a reativar a conta em vez de falhar por duplicidade.

## Endpoints

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
- restaurar conta removida logicamente pelo mesmo phoneNumberId
- atualizar conta WhatsApp
- remover conta com deletedAt
- validar phoneNumberId duplicado quando a conta ativa ja existe
- filtrar contas por busca simples
- armazenar token em formato codificado local

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts
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
- remover conta local
- recriar mesma conta local com mesmo phoneNumberId
- login dominio
- criar conta dominio
- remover conta dominio
- recriar mesma conta dominio com mesmo phoneNumberId
- listar contas dominio

## Logs gerados

Logs:

- logs/fix_39_backend_typecheck_whatsapp_restore.log
- logs/fix_39_backend_build_whatsapp_restore.log
- logs/fix_39_backend_docker_build_whatsapp_restore.log
- logs/fix_39_backend_docker_up_whatsapp_restore.log
- logs/fix_39_auth_login_local.log
- logs/fix_39_auth_login_domain.log
- logs/fix_39_whatsapp_account_create_local.log
- logs/fix_39_whatsapp_account_delete_local.log
- logs/fix_39_whatsapp_account_restore_local.log
- logs/fix_39_whatsapp_account_create_domain.log
- logs/fix_39_whatsapp_account_delete_domain.log
- logs/fix_39_whatsapp_account_restore_domain.log
- logs/fix_39_whatsapp_accounts_list_domain.log
- logs/fix_39_whatsapp_accounts_restore_deleted.log

## Observacoes

Este ajuste permite corrigir cadastros errados removidos pela tela sem intervenção manual no banco.

## Proxima etapa sugerida

Etapa 40:

    Criar envio real de mensagens pela API oficial da Meta
DOC

echo "Atualizando 00_CONTROLE.md sem alterar etapa atual..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

if "- [x] Etapa 39 - Processamento de status no frontend" not in text:
    text = text.replace(
        "- [ ] Etapa 39 - Processamento de status no frontend",
        "- [x] Etapa 39 - Processamento de status no frontend"
    )

if "- [ ] Etapa 40 - Envio real pela API oficial da Meta" not in text:
    text = text.replace(
        "- [x] Etapa 39 - Processamento de status no frontend",
        "- [x] Etapa 39 - Processamento de status no frontend\n- [ ] Etapa 40 - Envio real pela API oficial da Meta"
    )

text = text.replace(
    "Etapa 39 - Processamento de status de mensagens da Meta no frontend.",
    "Etapa 39 - Processamento de status de mensagens da Meta no frontend."
)

text = text.replace(
    "Etapa 40 - Criar envio real de mensagens pela API oficial da Meta.",
    "Etapa 40 - Criar envio real de mensagens pela API oficial da Meta."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Ajuste de restauracao de WhatsApp Accounts removidas criado." not in text:
    text = text.replace(
        "Processamento de status de mensagens no frontend criado.",
        "Processamento de status de mensagens no frontend criado.\n\nAjuste de restauracao de WhatsApp Accounts removidas criado."
    )

if "- docs/BACKEND_WHATSAPP_ACCOUNTS.md" not in text:
    text = text.replace(
        "- docs/FRONTEND_WHATSAPP_ACCOUNTS.md",
        "- docs/BACKEND_WHATSAPP_ACCOUNTS.md\n- docs/FRONTEND_WHATSAPP_ACCOUNTS.md"
    )

path.write_text(text)
PY

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

cat > "${FIX_LOG_FILE}" <<DOC
Acao: Restaurar WhatsApp Account removida logicamente
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login local status: ${LOCAL_LOGIN_STATUS}
Create local status: ${LOCAL_CREATE_STATUS}
Delete local status: ${LOCAL_DELETE_STATUS}
Restore local status: ${LOCAL_RESTORE_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Create dominio status: ${DOMAIN_CREATE_STATUS}
Delete dominio status: ${DOMAIN_DELETE_STATUS}
Restore dominio status: ${DOMAIN_RESTORE_STATUS}
List dominio status: ${DOMAIN_LIST_STATUS}
Status: Concluido
DOC

echo ""
echo "== Correcao concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Restauracao dominio:"
cat "${DOMAIN_RESTORE_LOG}"
echo ""
echo "Agora voce pode cadastrar novamente a conta Meta removida pela tela."
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 40 - Criar envio real de mensagens pela API oficial da Meta"
