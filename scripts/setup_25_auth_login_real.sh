#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_25.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_25_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_25_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_25_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_25_backend_docker_up.log"
LOCAL_LOGIN_LOG="${LOGS_DIR}/setup_25_auth_login_local.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_25_auth_login_domain.log"
LOCAL_ME_LOG="${LOGS_DIR}/setup_25_auth_me_local.log"
DOMAIN_ME_LOG="${LOGS_DIR}/setup_25_auth_me_domain.log"
LOCAL_HEALTH_LOG="${LOGS_DIR}/setup_25_health_local.log"
DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_25_health_domain.log"
DOC_FILE="${DOCS_DIR}/AUTH_LOGIN_REAL.md"

LOCAL_HEALTH_URL="http://127.0.0.1:3300/api/v1/health"
DOMAIN_HEALTH_URL="https://bot.lhsolucao.com.br/api/v1/health"
LOCAL_LOGIN_URL="http://127.0.0.1:3300/api/v1/auth/login"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/api/v1/auth/login"
LOCAL_ME_URL="http://127.0.0.1:3300/api/v1/auth/me"
DOMAIN_ME_URL="https://bot.lhsolucao.com.br/api/v1/auth/me"

echo "== Etapa 25: Auth inicial com login real =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/auth"
mkdir -p "${BACKEND_DIR}/src/common/guards"
mkdir -p "${BACKEND_DIR}/src/common/decorators"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/auth/auth.module.ts" \
  "${BACKEND_DIR}/src/modules/auth/auth.controller.ts" \
  "${BACKEND_DIR}/src/modules/auth/auth.service.ts" \
  "${BACKEND_DIR}/src/modules/auth/auth.types.ts" \
  "${BACKEND_DIR}/src/common/guards/jwt-auth.guard.ts" \
  "${BACKEND_DIR}/src/common/decorators/current-user.decorator.ts" \
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

echo "Validando credenciais iniciais..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais do seed nao encontrado."
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

echo "Admin encontrado: ${ADMIN_EMAIL}"

echo "Criando auth.types.ts..."

cat > "${BACKEND_DIR}/src/modules/auth/auth.types.ts" <<'DOC'
export type AuthenticatedUser = {
  id: string;
  tenantId: string;
  name: string;
  email: string;
  roles: string[];
  permissions: string[];
};

export type LoginResponse = {
  success: true;
  data: {
    access_token: string;
    token_type: string;
    user: AuthenticatedUser;
  };
  meta: Record<string, never>;
};

export type MeResponse = {
  success: true;
  data: {
    user: AuthenticatedUser;
  };
  meta: Record<string, never>;
};
DOC

echo "Criando current-user.decorator.ts..."

cat > "${BACKEND_DIR}/src/common/decorators/current-user.decorator.ts" <<'DOC'
import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { AuthenticatedUser } from '../../modules/auth/auth.types';

type RequestWithUser = {
  user?: AuthenticatedUser;
};

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): AuthenticatedUser | undefined => {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    return request.user;
  }
);
DOC

echo "Criando jwt-auth.guard.ts..."

cat > "${BACKEND_DIR}/src/common/guards/jwt-auth.guard.ts" <<'DOC'
import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { AuthenticatedUser } from '../../modules/auth/auth.types';

type RequestWithHeadersAndUser = {
  headers: {
    authorization?: string;
  };
  user?: AuthenticatedUser;
};

type JwtPayload = AuthenticatedUser & {
  iat?: number;
  exp?: number;
};

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<RequestWithHeadersAndUser>();
    const authorization = request.headers.authorization || '';

    if (!authorization.startsWith('Bearer ')) {
      throw new UnauthorizedException('Token ausente');
    }

    const token = authorization.replace('Bearer ', '').trim();

    if (!token) {
      throw new UnauthorizedException('Token invalido');
    }

    try {
      const payload = this.jwtService.verify<JwtPayload>(token, {
        secret: process.env.JWT_SECRET || 'change_me_jwt_secret'
      });

      request.user = {
        id: payload.id,
        tenantId: payload.tenantId,
        name: payload.name,
        email: payload.email,
        roles: payload.roles,
        permissions: payload.permissions
      };

      return true;
    } catch (_error) {
      throw new UnauthorizedException('Token invalido');
    }
  }
}
DOC

echo "Criando auth.service.ts..."

cat > "${BACKEND_DIR}/src/modules/auth/auth.service.ts" <<'DOC'
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import bcrypt from 'bcryptjs';
import { PrismaService } from '../database/prisma.service';
import type { AuthenticatedUser, LoginResponse } from './auth.types';

type LoginInput = {
  email?: string;
  password?: string;
};

@Injectable()
export class AuthService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly jwtService: JwtService
  ) {}

  async login(input: LoginInput): Promise<LoginResponse> {
    const email = input.email ? input.email.trim().toLowerCase() : '';
    const password = input.password || '';

    if (!email || !password) {
      throw new UnauthorizedException('Credenciais invalidas');
    }

    const user = await this.prismaService.user.findFirst({
      where: {
        email,
        status: 'active',
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

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Credenciais invalidas');
    }

    if (user.tenant.status !== 'active') {
      throw new UnauthorizedException('Tenant inativo');
    }

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);

    if (!passwordMatches) {
      throw new UnauthorizedException('Credenciais invalidas');
    }

    const roles = user.userRoles.map((userRole) => userRole.role.name);

    const permissions = Array.from(
      new Set(
        user.userRoles.flatMap((userRole) =>
          userRole.role.rolePermissions.map((rolePermission) => rolePermission.permission.key)
        )
      )
    ).sort();

    const authenticatedUser: AuthenticatedUser = {
      id: user.id,
      tenantId: user.tenantId,
      name: user.name,
      email: user.email,
      roles,
      permissions
    };

    const accessToken = this.jwtService.sign(authenticatedUser, {
      secret: process.env.JWT_SECRET || 'change_me_jwt_secret',
      expiresIn: '8h'
    });

    return {
      success: true,
      data: {
        access_token: accessToken,
        token_type: 'Bearer',
        user: authenticatedUser
      },
      meta: {}
    };
  }
}
DOC

echo "Criando auth.controller.ts..."

cat > "${BACKEND_DIR}/src/modules/auth/auth.controller.ts" <<'DOC'
import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { AuthService } from './auth.service';
import type { AuthenticatedUser, MeResponse } from './auth.types';

type LoginBody = {
  email?: string;
  password?: string;
};

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  login(@Body() body: LoginBody) {
    return this.authService.login(body);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: AuthenticatedUser): MeResponse {
    return {
      success: true,
      data: {
        user
      },
      meta: {}
    };
  }
}
DOC

echo "Criando auth.module.ts..."

cat > "${BACKEND_DIR}/src/modules/auth/auth.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AuthController
  ],
  providers: [
    AuthService
  ],
  exports: [
    AuthService
  ]
})
export class AuthModule {}
DOC

echo "Atualizando app.module.ts..."

cat > "${BACKEND_DIR}/src/app.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { AuthModule } from './modules/auth/auth.module';
import { ConfigurationModule } from './modules/configuration/configuration.module';
import { DatabaseModule } from './modules/database/database.module';
import { HealthModule } from './modules/health/health.module';

@Module({
  imports: [
    ConfigurationModule,
    DatabaseModule,
    HealthModule,
    AuthModule
  ],
  controllers: [],
  providers: []
})
export class AppModule {}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/auth" \
  "${BACKEND_DIR}/src/common/guards/jwt-auth.guard.ts" \
  "${BACKEND_DIR}/src/common/decorators/current-user.decorator.ts" \
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

echo "Testando health local..."

LOCAL_HEALTH_STATUS="$(curl -s -o "${LOCAL_HEALTH_LOG}" -w "%{http_code}" --max-time 20 "${LOCAL_HEALTH_URL}" || true)"

if [ "${LOCAL_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health local nao respondeu 200."
  docker compose logs --tail=160 backend
  exit 1
fi

echo "Testando health dominio..."

DOMAIN_HEALTH_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_HEALTH_URL}" || true)"

if [ "${DOMAIN_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health dominio nao respondeu 200."
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando login local..."

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

LOCAL_LOGIN_STATUS="$(curl -s -o "${LOCAL_LOGIN_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${LOCAL_LOGIN_URL}" || true)"

if [ "${LOCAL_LOGIN_STATUS}" != "201" ] && [ "${LOCAL_LOGIN_STATUS}" != "200" ]; then
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

echo "Testando auth me local..."

LOCAL_ME_STATUS="$(curl -s -o "${LOCAL_ME_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Authorization: Bearer ${LOCAL_ACCESS_TOKEN}" \
  "${LOCAL_ME_URL}" || true)"

if [ "${LOCAL_ME_STATUS}" != "200" ]; then
  echo "ERRO: auth me local falhou. Status ${LOCAL_ME_STATUS}"
  cat "${LOCAL_ME_LOG}"
  exit 1
fi

echo "Testando login dominio..."

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "201" ] && [ "${DOMAIN_LOGIN_STATUS}" != "200" ]; then
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

echo "Testando auth me dominio..."

DOMAIN_ME_STATUS="$(curl -L -s -o "${DOMAIN_ME_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ME_URL}" || true)"

if [ "${DOMAIN_ME_STATUS}" != "200" ]; then
  echo "ERRO: auth me dominio falhou. Status ${DOMAIN_ME_STATUS}"
  cat "${DOMAIN_ME_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 25..."

cat > "${DOC_FILE}" <<'DOC'
# Auth Login Real

## Visao geral

Este documento registra a criacao do modulo inicial de autenticacao com login real.

## Resultado

Status:

    concluido

## Endpoints criados

Endpoints:

- POST api v1 auth login
- GET api v1 auth me

## Arquivos criados

Arquivos:

- apps/backend/src/modules/auth/auth.module.ts
- apps/backend/src/modules/auth/auth.controller.ts
- apps/backend/src/modules/auth/auth.service.ts
- apps/backend/src/modules/auth/auth.types.ts
- apps/backend/src/common/guards/jwt-auth.guard.ts
- apps/backend/src/common/decorators/current-user.decorator.ts

## Arquivo atualizado

Arquivo:

- apps/backend/src/app.module.ts

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- health local
- health dominio
- login local
- auth me local
- login dominio
- auth me dominio

## Usuario validado

Usuario:

- admin@lhsolucao.com.br

## Seguranca

A senha nao foi gravada neste documento.

A senha inicial continua no log local de credenciais da Etapa 24.

## Logs gerados

Logs:

- logs/setup_25_backend_typecheck.log
- logs/setup_25_backend_build.log
- logs/setup_25_backend_docker_build.log
- logs/setup_25_backend_docker_up.log
- logs/setup_25_health_local.log
- logs/setup_25_health_domain.log
- logs/setup_25_auth_login_local.log
- logs/setup_25_auth_login_domain.log
- logs/setup_25_auth_me_local.log
- logs/setup_25_auth_me_domain.log
- logs/setup_25.log

## Proxima etapa sugerida

Etapa 26:

    Criar tela de login no frontend integrada ao backend
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
- [ ] Etapa 26 - Frontend login integrado

## Ultima etapa executada

Etapa 25 - Auth inicial com login real.

## Proxima etapa sugerida

Etapa 26 - Criar tela de login no frontend integrada ao backend.
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

## Etapas concluidas

- Etapa 01 ate Etapa 25 concluidas

## Proxima etapa

- Etapa 26 - Frontend login integrado
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
Etapa: 25
Acao: Auth inicial com login real
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health local status: ${LOCAL_HEALTH_STATUS}
Health dominio status: ${DOMAIN_HEALTH_STATUS}
Login local status: ${LOCAL_LOGIN_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Auth me local status: ${LOCAL_ME_STATUS}
Auth me dominio status: ${DOMAIN_ME_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 25 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Login local:"
cat "${LOCAL_LOGIN_LOG}"
echo ""
echo "Auth me local:"
cat "${LOCAL_ME_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 26 - Criar tela de login no frontend integrada ao backend"
