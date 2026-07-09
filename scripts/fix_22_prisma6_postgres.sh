#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
DOCKER_DIR="${BASE_DIR}/infra/docker"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_22.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_22_prisma6_postgres.log"
NPM_LOG="${LOGS_DIR}/setup_22_backend_npm.log"
PRISMA_LOG="${LOGS_DIR}/setup_22_prisma_generate.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_22_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_22_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_22_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_22_backend_docker_up.log"
LOCAL_HEALTH_LOG="${LOGS_DIR}/setup_22_health_local.log"
DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_22_health_domain.log"
DOC_FILE="${DOCS_DIR}/BACKEND_PRISMA_POSTGRES.md"

LOCAL_HEALTH_URL="http://127.0.0.1:3300/api/v1/health"
DOMAIN_HEALTH_URL="https://bot.lhsolucao.com.br/api/v1/health"

echo "== Correcao Etapa 22: Prisma 6 e PostgreSQL real =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/prisma"
mkdir -p "${BACKEND_DIR}/src/modules/database"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/package.json" \
  "${BACKEND_DIR}/package-lock.json" \
  "${BACKEND_DIR}/prisma/schema.prisma" \
  "${BACKEND_DIR}/prisma.config.ts" \
  "${BACKEND_DIR}/src/modules/database/prisma.service.ts" \
  "${BACKEND_DIR}/src/modules/database/database.service.ts" \
  "${BACKEND_DIR}/src/modules/database/database.module.ts" \
  "${BACKEND_DIR}/src/modules/health/health.service.ts" \
  "${DOCKER_DIR}/backend.Dockerfile" \
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

NODE_VERSION="$(node -v)"
NPM_VERSION="$(npm -v)"
DOCKER_VERSION="$(docker --version)"
COMPOSE_VERSION="$(docker compose version)"

echo "Node: ${NODE_VERSION}"
echo "npm: ${NPM_VERSION}"
echo "Docker: ${DOCKER_VERSION}"
echo "Docker Compose: ${COMPOSE_VERSION}"

echo "Fixando Prisma 6.19.0 no backend..."

cd "${BACKEND_DIR}"

npm install @prisma/client@6.19.0 2>&1 | tee "${NPM_LOG}"
npm install --save-dev prisma@6.19.0 2>&1 | tee -a "${NPM_LOG}"

cd "${BASE_DIR}"

echo "Removendo prisma.config.ts se existir..."

if [ -f "${BACKEND_DIR}/prisma.config.ts" ]; then
  rm "${BACKEND_DIR}/prisma.config.ts"
fi

echo "Criando schema.prisma compativel com Prisma 6..."

cat > "${BACKEND_DIR}/prisma/schema.prisma" <<'DOC'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
DOC

echo "Criando PrismaService..."

cat > "${BACKEND_DIR}/src/modules/database/prisma.service.ts" <<'DOC'
import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit(): Promise<void> {
    await this.$connect();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
DOC

echo "Atualizando DatabaseService..."

cat > "${BACKEND_DIR}/src/modules/database/database.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma.service';

type DatabaseStatus = {
  configured: boolean;
  connected: boolean;
  provider: string;
  connectionName: string;
  error: string | null;
};

@Injectable()
export class DatabaseService {
  constructor(private readonly prismaService: PrismaService) {}

  async getStatus(): Promise<DatabaseStatus> {
    try {
      await this.prismaService.$queryRawUnsafe('SELECT 1');

      return {
        configured: true,
        connected: true,
        provider: 'postgresql',
        connectionName: 'primary',
        error: null
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'database_error';

      return {
        configured: true,
        connected: false,
        provider: 'postgresql',
        connectionName: 'primary',
        error: message
      };
    }
  }
}
DOC

echo "Atualizando DatabaseModule..."

cat > "${BACKEND_DIR}/src/modules/database/database.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { PrismaService } from './prisma.service';

@Module({
  providers: [
    PrismaService,
    DatabaseService
  ],
  exports: [
    PrismaService,
    DatabaseService
  ]
})
export class DatabaseModule {}
DOC

echo "Atualizando HealthService..."

cat > "${BACKEND_DIR}/src/modules/health/health.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import { ConfigurationService } from '../configuration/configuration.service';
import { DatabaseService } from '../database/database.service';

type HealthResponse = {
  success: true;
  data: {
    status: string;
    service: string;
    timestamp: string;
    environment: string;
    checks: {
      api: string;
      database: string;
      redis: string;
      meta: string;
    };
  };
  meta: Record<string, never>;
};

@Injectable()
export class HealthService {
  constructor(
    private readonly configurationService: ConfigurationService,
    private readonly databaseService: DatabaseService
  ) {}

  async getHealth(): Promise<HealthResponse> {
    const config = this.configurationService.getPublicConfig();
    const database = await this.databaseService.getStatus();

    return {
      success: true,
      data: {
        status: database.connected ? 'ok' : 'degraded',
        service: 'backend',
        timestamp: new Date().toISOString(),
        environment: config.nodeEnv,
        checks: {
          api: 'ok',
          database: database.connected ? 'ok' : 'error',
          redis: config.redisConfigured ? 'configured' : 'not_configured',
          meta: config.metaConfigured ? 'configured' : 'not_configured'
        }
      },
      meta: {}
    };
  }
}
DOC

echo "Ajustando backend.Dockerfile para Prisma 6..."

cat > "${DOCKER_DIR}/backend.Dockerfile" <<'DOC'
FROM node:20-alpine AS deps

WORKDIR /app/apps/backend

COPY apps/backend/package.json apps/backend/package-lock.json ./

RUN npm ci

FROM node:20-alpine AS build

WORKDIR /app/apps/backend

COPY --from=deps /app/apps/backend/node_modules ./node_modules
COPY apps/backend ./

RUN npx prisma generate
RUN npm run build

FROM node:20-alpine AS runtime

WORKDIR /app/apps/backend

ENV NODE_ENV=production

COPY apps/backend/package.json ./
COPY --from=build /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/dist ./dist
COPY --from=build /app/apps/backend/prisma ./prisma

EXPOSE 3000

CMD ["node", "dist/main.js"]
DOC

echo "Validando HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/prisma" \
  "${BACKEND_DIR}/src/modules/database" \
  "${BACKEND_DIR}/src/modules/health" \
  "${DOCKER_DIR}/backend.Dockerfile"
then
  echo "ERRO: HTML indevido encontrado."
  exit 1
fi

echo "Gerando Prisma Client local..."

cd "${BACKEND_DIR}"

DATABASE_URL="postgresql://saas_user:saas_password@localhost:55432/saas_whatsapp" npx prisma generate 2>&1 | tee "${PRISMA_LOG}"

echo "Rodando typecheck do backend..."

npm run typecheck 2>&1 | tee "${TYPECHECK_LOG}"

echo "Rodando build local do backend..."

npm run build 2>&1 | tee "${BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando container backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BUILD_LOG}"

echo "Subindo backend atualizado..."

docker compose up -d backend 2>&1 | tee "${DOCKER_UP_LOG}"

echo "Aguardando backend iniciar..."

sleep 10

echo "Testando health local com banco real..."

LOCAL_STATUS="$(curl -s -o "${LOCAL_HEALTH_LOG}" -w "%{http_code}" --max-time 20 "${LOCAL_HEALTH_URL}" || true)"

echo "Health local status: ${LOCAL_STATUS}"

if [ "${LOCAL_STATUS}" != "200" ]; then
  echo "ERRO: health local nao respondeu 200."
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q '"database":"ok"' "${LOCAL_HEALTH_LOG}"; then
  echo "ERRO: health local nao indicou database ok."
  cat "${LOCAL_HEALTH_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

echo "Testando health pelo dominio com banco real..."

DOMAIN_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_HEALTH_URL}" || true)"

echo "Health dominio status: ${DOMAIN_STATUS}"

if [ "${DOMAIN_STATUS}" != "200" ]; then
  echo "ERRO: health pelo dominio nao respondeu 200."
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q '"database":"ok"' "${DOMAIN_HEALTH_LOG}"; then
  echo "ERRO: health dominio nao indicou database ok."
  cat "${DOMAIN_HEALTH_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

echo "Gerando documentacao da Etapa 22..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Prisma PostgreSQL

## Visao geral

Este documento registra a criacao da conexao real com PostgreSQL usando Prisma.

## Resultado

Status:

    concluido

## ORM definido

ORM:

- Prisma

## Versao fixada

Versao:

- Prisma 6.19.0
- Prisma Client 6.19.0

## Motivo da correcao

A primeira tentativa instalou Prisma 7, que mudou a configuracao do datasource.

Para manter estabilidade nesta fase, o projeto fixou Prisma 6.19.0 e manteve o formato classico do schema.prisma.

## Banco definido

Banco:

- PostgreSQL

## Arquivos criados ou alterados

Arquivos:

- apps/backend/prisma/schema.prisma
- apps/backend/src/modules/database/prisma.service.ts
- apps/backend/src/modules/database/database.service.ts
- apps/backend/src/modules/database/database.module.ts
- apps/backend/src/modules/health/health.service.ts
- infra/docker/backend.Dockerfile
- apps/backend/package.json
- apps/backend/package-lock.json

## Validacoes executadas

Validacoes:

- npm install @prisma/client 6.19.0
- npm install prisma 6.19.0 como dev dependency
- npx prisma generate
- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- health local com database ok
- health pelo dominio com database ok

## Resultado esperado do health

Resultado esperado:

    database ok

## Logs gerados

Logs:

- logs/setup_22_backend_npm.log
- logs/setup_22_prisma_generate.log
- logs/setup_22_backend_typecheck.log
- logs/setup_22_backend_build.log
- logs/setup_22_backend_docker_build.log
- logs/setup_22_backend_docker_up.log
- logs/setup_22_health_local.log
- logs/setup_22_health_domain.log
- logs/fix_22_prisma6_postgres.log
- logs/setup_22.log

## Observacoes

Nesta etapa ainda nao foram criadas tabelas de negocio.

A conexao com PostgreSQL foi validada por consulta simples.

A proxima etapa deve criar o schema inicial com tenants, users, roles, contacts, conversations e messages.

## Proxima etapa sugerida

Etapa 23:

    Criar schema inicial do banco com Prisma
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
- [ ] Etapa 23 - Schema inicial do banco com Prisma

## Ultima etapa executada

Etapa 22 - ORM e conexao real com PostgreSQL.

## Proxima etapa sugerida

Etapa 23 - Criar schema inicial do banco com Prisma.
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

## Etapas concluidas

- Etapa 01 ate Etapa 22 concluidas

## Proxima etapa

- Etapa 23 - Schema inicial do banco com Prisma
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

echo "Gravando logs..."

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 22
Acao: Correcao Prisma 6 e conexao real com PostgreSQL
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health local status: ${LOCAL_STATUS}
Health dominio status: ${DOMAIN_STATUS}
Status: Concluido
DOC

cat > "${LOG_FILE}" <<DOC
Etapa: 22
Acao: Prisma ORM e conexao real com PostgreSQL
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health local status: ${LOCAL_STATUS}
Health dominio status: ${DOMAIN_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 22 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Health local:"
cat "${LOCAL_HEALTH_LOG}"
echo ""
echo "Health dominio:"
cat "${DOMAIN_HEALTH_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 23 - Criar schema inicial do banco com Prisma"
