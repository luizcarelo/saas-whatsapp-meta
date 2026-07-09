#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_28.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_28_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_28_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_28_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_28_backend_docker_up.log"
LOCAL_LOGIN_LOG="${LOGS_DIR}/setup_28_auth_login_local.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_28_auth_login_domain.log"
LOCAL_PROFILE_LOG="${LOGS_DIR}/setup_28_users_me_local.log"
DOMAIN_PROFILE_LOG="${LOGS_DIR}/setup_28_users_me_domain.log"
LOCAL_PERMISSIONS_LOG="${LOGS_DIR}/setup_28_users_permissions_local.log"
DOMAIN_PERMISSIONS_LOG="${LOGS_DIR}/setup_28_users_permissions_domain.log"
DOC_FILE="${DOCS_DIR}/BACKEND_USERS_PROFILE.md"

LOCAL_LOGIN_URL="http://127.0.0.1:3300/api/v1/auth/login"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/api/v1/auth/login"
LOCAL_PROFILE_URL="http://127.0.0.1:3300/api/v1/users/me"
DOMAIN_PROFILE_URL="https://bot.lhsolucao.com.br/api/v1/users/me"
LOCAL_PERMISSIONS_URL="http://127.0.0.1:3300/api/v1/users/me/permissions"
DOMAIN_PERMISSIONS_URL="https://bot.lhsolucao.com.br/api/v1/users/me/permissions"

echo "== Etapa 28: Modulo backend de usuarios e perfil detalhado =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/users"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/users/users.module.ts" \
  "${BACKEND_DIR}/src/modules/users/users.controller.ts" \
  "${BACKEND_DIR}/src/modules/users/users.service.ts" \
  "${BACKEND_DIR}/src/modules/users/users.types.ts" \
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

echo "Criando users.types.ts..."

cat > "${BACKEND_DIR}/src/modules/users/users.types.ts" <<'DOC'
export type UserProfileRole = {
  id: string;
  name: string;
  description: string | null;
};

export type UserProfilePermission = {
  key: string;
  module: string;
  description: string | null;
};

export type UserProfileTenant = {
  id: string;
  name: string;
  status: string;
};

export type UserProfile = {
  id: string;
  tenantId: string;
  name: string;
  email: string;
  status: string;
  tenant: UserProfileTenant;
  roles: UserProfileRole[];
  permissions: UserProfilePermission[];
};

export type UserProfileResponse = {
  success: true;
  data: {
    user: UserProfile;
  };
  meta: Record<string, never>;
};

export type UserPermissionsResponse = {
  success: true;
  data: {
    permissions: UserProfilePermission[];
  };
  meta: Record<string, never>;
};
DOC

echo "Criando users.service.ts..."

cat > "${BACKEND_DIR}/src/modules/users/users.service.ts" <<'DOC'
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  UserPermissionsResponse,
  UserProfile,
  UserProfilePermission,
  UserProfileResponse,
  UserProfileRole
} from './users.types';

@Injectable()
export class UsersService {
  constructor(private readonly prismaService: PrismaService) {}

  async getCurrentUserProfile(userId: string): Promise<UserProfileResponse> {
    const user = await this.prismaService.user.findFirst({
      where: {
        id: userId,
        deletedAt: null
      },
      include: {
        tenant: true,
        userRoles: {
          include: {
            role: {
              include: {
                rolePermissions: {
                  include: {
                    permission: true
                  }
                }
              }
            }
          }
        }
      }
    });

    if (!user) {
      throw new NotFoundException('Usuario nao encontrado');
    }

    const roles: UserProfileRole[] = user.userRoles.map((userRole) => ({
      id: userRole.role.id,
      name: userRole.role.name,
      description: userRole.role.description
    }));

    const permissionMap = new Map<string, UserProfilePermission>();

    for (const userRole of user.userRoles) {
      for (const rolePermission of userRole.role.rolePermissions) {
        permissionMap.set(rolePermission.permission.key, {
          key: rolePermission.permission.key,
          module: rolePermission.permission.module,
          description: rolePermission.permission.description
        });
      }
    }

    const permissions = Array.from(permissionMap.values()).sort((left, right) =>
      left.key.localeCompare(right.key)
    );

    const profile: UserProfile = {
      id: user.id,
      tenantId: user.tenantId,
      name: user.name,
      email: user.email,
      status: user.status,
      tenant: {
        id: user.tenant.id,
        name: user.tenant.name,
        status: user.tenant.status
      },
      roles,
      permissions
    };

    return {
      success: true,
      data: {
        user: profile
      },
      meta: {}
    };
  }

  async getCurrentUserPermissions(userId: string): Promise<UserPermissionsResponse> {
    const profile = await this.getCurrentUserProfile(userId);

    return {
      success: true,
      data: {
        permissions: profile.data.user.permissions
      },
      meta: {}
    };
  }
}
DOC

echo "Criando users.controller.ts..."

cat > "${BACKEND_DIR}/src/modules/users/users.controller.ts" <<'DOC'
import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { UsersService } from './users.service';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  getMe(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.getCurrentUserProfile(user.id);
  }

  @Get('me/permissions')
  getMyPermissions(@CurrentUser() user: AuthenticatedUser) {
    return this.usersService.getCurrentUserPermissions(user.id);
  }
}
DOC

echo "Criando users.module.ts..."

cat > "${BACKEND_DIR}/src/modules/users/users.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    UsersController
  ],
  providers: [
    UsersService
  ],
  exports: [
    UsersService
  ]
})
export class UsersModule {}
DOC

echo "Atualizando app.module.ts..."

cat > "${BACKEND_DIR}/src/app.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { AuthModule } from './modules/auth/auth.module';
import { ConfigurationModule } from './modules/configuration/configuration.module';
import { DatabaseModule } from './modules/database/database.module';
import { HealthModule } from './modules/health/health.module';
import { UsersModule } from './modules/users/users.module';

@Module({
  imports: [
    ConfigurationModule,
    DatabaseModule,
    HealthModule,
    AuthModule,
    UsersModule
  ],
  controllers: [],
  providers: []
})
export class AppModule {}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/users" \
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

echo "Testando users me local..."

LOCAL_PROFILE_STATUS="$(curl -s -o "${LOCAL_PROFILE_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_PROFILE_URL}" || true)"

if [ "${LOCAL_PROFILE_STATUS}" != "200" ]; then
  echo "ERRO: users me local falhou. Status ${LOCAL_PROFILE_STATUS}"
  cat "${LOCAL_PROFILE_LOG}"
  exit 1
fi

if ! grep -q "permissions" "${LOCAL_PROFILE_LOG}"; then
  echo "ERRO: users me local nao retornou permissoes."
  cat "${LOCAL_PROFILE_LOG}"
  exit 1
fi

echo "Testando users me permissions local..."

LOCAL_PERMISSIONS_STATUS="$(curl -s -o "${LOCAL_PERMISSIONS_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_PERMISSIONS_URL}" || true)"

if [ "${LOCAL_PERMISSIONS_STATUS}" != "200" ]; then
  echo "ERRO: users permissions local falhou. Status ${LOCAL_PERMISSIONS_STATUS}"
  cat "${LOCAL_PERMISSIONS_LOG}"
  exit 1
fi

if ! grep -q "permissions" "${LOCAL_PERMISSIONS_LOG}"; then
  echo "ERRO: users permissions local nao retornou permissoes."
  cat "${LOCAL_PERMISSIONS_LOG}"
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

echo "Testando users me dominio..."

DOMAIN_PROFILE_STATUS="$(curl -L -s -o "${DOMAIN_PROFILE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_PROFILE_URL}" || true)"

if [ "${DOMAIN_PROFILE_STATUS}" != "200" ]; then
  echo "ERRO: users me dominio falhou. Status ${DOMAIN_PROFILE_STATUS}"
  cat "${DOMAIN_PROFILE_LOG}"
  exit 1
fi

if ! grep -q "permissions" "${DOMAIN_PROFILE_LOG}"; then
  echo "ERRO: users me dominio nao retornou permissoes."
  cat "${DOMAIN_PROFILE_LOG}"
  exit 1
fi

echo "Testando users me permissions dominio..."

DOMAIN_PERMISSIONS_STATUS="$(curl -L -s -o "${DOMAIN_PERMISSIONS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_PERMISSIONS_URL}" || true)"

if [ "${DOMAIN_PERMISSIONS_STATUS}" != "200" ]; then
  echo "ERRO: users permissions dominio falhou. Status ${DOMAIN_PERMISSIONS_STATUS}"
  cat "${DOMAIN_PERMISSIONS_LOG}"
  exit 1
fi

if ! grep -q "permissions" "${DOMAIN_PERMISSIONS_LOG}"; then
  echo "ERRO: users permissions dominio nao retornou permissoes."
  cat "${DOMAIN_PERMISSIONS_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 28..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Users Profile

## Visao geral

Este documento registra a criacao do modulo backend de usuarios e perfil detalhado.

## Resultado

Status:

    concluido

## Endpoints criados

Endpoints:

- GET api v1 users me
- GET api v1 users me permissions

## Funcionalidades

Funcionalidades:

- perfil detalhado do usuario autenticado
- dados do tenant
- roles do usuario
- permissoes do usuario
- endpoint dedicado para permissoes

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/users/users.module.ts
- apps/backend/src/modules/users/users.controller.ts
- apps/backend/src/modules/users/users.service.ts
- apps/backend/src/modules/users/users.types.ts
- apps/backend/src/app.module.ts
- docs/BACKEND_USERS_PROFILE.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- login local
- users me local
- users me permissions local
- login dominio
- users me dominio
- users me permissions dominio

## Logs gerados

Logs:

- logs/setup_28_backend_typecheck.log
- logs/setup_28_backend_build.log
- logs/setup_28_backend_docker_build.log
- logs/setup_28_backend_docker_up.log
- logs/setup_28_auth_login_local.log
- logs/setup_28_auth_login_domain.log
- logs/setup_28_users_me_local.log
- logs/setup_28_users_me_domain.log
- logs/setup_28_users_permissions_local.log
- logs/setup_28_users_permissions_domain.log
- logs/setup_28.log

## Proxima etapa sugerida

Etapa 29:

    Integrar frontend ao endpoint users me para perfil detalhado
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
- [ ] Etapa 29 - Frontend com perfil detalhado

## Ultima etapa executada

Etapa 28 - Modulo backend de usuarios e endpoint de perfil detalhado.

## Proxima etapa sugerida

Etapa 29 - Integrar frontend ao endpoint users me para perfil detalhado.
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

## Etapas concluidas

- Etapa 01 ate Etapa 28 concluidas

## Proxima etapa

- Etapa 29 - Frontend com perfil detalhado
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
Etapa: 28
Acao: Modulo backend de usuarios e perfil detalhado
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login local status: ${LOCAL_LOGIN_STATUS}
Users me local status: ${LOCAL_PROFILE_STATUS}
Users permissions local status: ${LOCAL_PERMISSIONS_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Users me dominio status: ${DOMAIN_PROFILE_STATUS}
Users permissions dominio status: ${DOMAIN_PERMISSIONS_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 28 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Perfil local:"
cat "${LOCAL_PROFILE_LOG}"
echo ""
echo "Permissoes local:"
cat "${LOCAL_PERMISSIONS_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 29 - Integrar frontend ao endpoint users me para perfil detalhado"
