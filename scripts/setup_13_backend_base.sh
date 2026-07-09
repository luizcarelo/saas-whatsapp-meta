#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_13.log"
BACKEND_BASE_DOC="${DOCS_DIR}/BACKEND_BASE.md"

echo "== Etapa 13: Arquivos base do backend =="

cd "${BASE_DIR}"

mkdir -p "${BACKEND_DIR}/src"
mkdir -p "${BACKEND_DIR}/src/config"
mkdir -p "${BACKEND_DIR}/src/common"
mkdir -p "${BACKEND_DIR}/src/common/guards"
mkdir -p "${BACKEND_DIR}/src/common/decorators"
mkdir -p "${BACKEND_DIR}/src/common/filters"
mkdir -p "${BACKEND_DIR}/src/common/interceptors"
mkdir -p "${BACKEND_DIR}/src/common/pipes"
mkdir -p "${BACKEND_DIR}/src/modules"
mkdir -p "${BACKEND_DIR}/test"
mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/package.json" \
  "${BACKEND_DIR}/tsconfig.json" \
  "${BACKEND_DIR}/src/main.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/health.controller.ts" \
  "${BACKEND_DIR}/src/config/app.config.ts" \
  "${BACKEND_DIR}/src/config/env.example.ts" \
  "${BACKEND_DIR}/src/common/README.md" \
  "${BACKEND_BASE_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    safe_name="$(echo "${base_name}" | tr '/' '_')"
    cp "${file}" "${BACKUPS_DIR}/${safe_name}_${STAMP}.bak"
  fi
done

echo "Gerando apps/backend/package.json..."

cat > "${BACKEND_DIR}/package.json" <<'DOC'
{
  "name": "saas-whatsapp-meta-backend",
  "version": "0.1.0",
  "private": true,
  "description": "Backend do SaaS de Chatbot WhatsApp com API Oficial da Meta",
  "scripts": {
    "dev": "nest start --watch",
    "build": "nest build",
    "start": "node dist/main.js",
    "start:prod": "node dist/main.js",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "jest"
  },
  "dependencies": {
    "@nestjs/common": "latest",
    "@nestjs/core": "latest",
    "@nestjs/platform-fastify": "latest",
    "@nestjs/config": "latest",
    "@nestjs/jwt": "latest",
    "@nestjs/passport": "latest",
    "fastify": "latest",
    "reflect-metadata": "latest",
    "rxjs": "latest"
  },
  "devDependencies": {
    "@nestjs/cli": "latest",
    "@nestjs/testing": "latest",
    "@types/node": "latest",
    "typescript": "latest",
    "ts-node": "latest",
    "eslint": "latest",
    "jest": "latest",
    "ts-jest": "latest"
  }
}
DOC

echo "Gerando apps/backend/tsconfig.json..."

cat > "${BACKEND_DIR}/tsconfig.json" <<'DOC'
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "strict": true,
    "skipLibCheck": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": [
    "src/**/*.ts"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
DOC

echo "Gerando apps/backend/src/main.ts..."

cat > "${BACKEND_DIR}/src/main.ts" <<'DOC'
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from './app.module';
import { appConfig } from './config/app.config';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter()
  );

  app.enableCors({
    origin: appConfig.frontendUrl,
    credentials: true
  });

  app.setGlobalPrefix('api/v1');

  await app.listen(appConfig.port, '0.0.0.0');
}

void bootstrap();
DOC

echo "Gerando apps/backend/src/app.module.ts..."

cat > "${BACKEND_DIR}/src/app.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

@Module({
  imports: [],
  controllers: [
    HealthController
  ],
  providers: []
})
export class AppModule {}
DOC

echo "Gerando apps/backend/src/health.controller.ts..."

cat > "${BACKEND_DIR}/src/health.controller.ts" <<'DOC'
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  getHealth() {
    return {
      success: true,
      data: {
        status: 'ok',
        service: 'backend',
        timestamp: new Date().toISOString()
      },
      meta: {}
    };
  }
}
DOC

echo "Gerando apps/backend/src/config/app.config.ts..."

cat > "${BACKEND_DIR}/src/config/app.config.ts" <<'DOC'
function readNumber(value: string | undefined, fallback: number): number {
  if (!value) {
    return fallback;
  }

  const parsed = Number(value);

  if (Number.isNaN(parsed)) {
    return fallback;
  }

  return parsed;
}

export const appConfig = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: readNumber(process.env.APP_PORT, 3000),
  appUrl: process.env.APP_URL || 'http://localhost:3000',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:5173'
};
DOC

echo "Gerando apps/backend/src/config/env.example.ts..."

cat > "${BACKEND_DIR}/src/config/env.example.ts" <<'DOC'
export const backendEnvExample = {
  NODE_ENV: 'development',
  APP_PORT: '3000',
  APP_URL: 'http://localhost:3000',
  FRONTEND_URL: 'http://localhost:5173',
  DATABASE_URL: 'postgresql://user:password@postgres:5432/saas_whatsapp',
  REDIS_HOST: 'redis',
  REDIS_PORT: '6379',
  JWT_SECRET: 'change_me',
  JWT_REFRESH_SECRET: 'change_me',
  ENCRYPTION_KEY: 'change_me',
  META_GRAPH_BASE_URL: 'https://graph.facebook.com',
  META_API_VERSION: 'v20.0',
  META_WEBHOOK_VERIFY_TOKEN: 'change_me',
  META_APP_SECRET: 'change_me'
};
DOC

echo "Gerando apps/backend/src/common/README.md..."

cat > "${BACKEND_DIR}/src/common/README.md" <<'DOC'
# Common do Backend

Esta pasta concentrara recursos compartilhados do backend.

## Pastas previstas

- guards
- decorators
- filters
- interceptors
- pipes
- utils
- constants

## Regras

- Guards validam autenticacao, tenant e permissoes
- Decorators reduzem repeticao em controllers
- Filters padronizam erros
- Interceptors padronizam respostas e logs
- Pipes validam e normalizam entradas

## Observacao

Nesta etapa foram criadas apenas pastas base.
DOC

echo "Criando marcadores .gitkeep..."

for dir in \
  "${BACKEND_DIR}/src/common/guards" \
  "${BACKEND_DIR}/src/common/decorators" \
  "${BACKEND_DIR}/src/common/filters" \
  "${BACKEND_DIR}/src/common/interceptors" \
  "${BACKEND_DIR}/src/common/pipes" \
  "${BACKEND_DIR}/src/modules" \
  "${BACKEND_DIR}/test"
do
  touch "${dir}/.gitkeep"
done

echo "Gerando docs/BACKEND_BASE.md..."

cat > "${BACKEND_BASE_DOC}" <<'DOC'
# Backend Base

## Visao geral

Este documento registra a criacao dos arquivos base do backend.

A Etapa 13 preparou uma base inicial para o backend NestJS com Fastify e TypeScript.

## Objetivo

Preparar os arquivos minimos para receber a implementacao real do backend nas proximas etapas.

## Arquivos criados

Arquivos principais:

- apps/backend/package.json
- apps/backend/tsconfig.json
- apps/backend/src/main.ts
- apps/backend/src/app.module.ts
- apps/backend/src/health.controller.ts
- apps/backend/src/config/app.config.ts
- apps/backend/src/config/env.example.ts
- apps/backend/src/common/README.md

## Pastas criadas

Pastas:

- apps/backend/src/config
- apps/backend/src/common
- apps/backend/src/common/guards
- apps/backend/src/common/decorators
- apps/backend/src/common/filters
- apps/backend/src/common/interceptors
- apps/backend/src/common/pipes
- apps/backend/src/modules
- apps/backend/test

## Endpoint inicial

Endpoint previsto:

    GET /api/v1/health

Resposta esperada:

    {
      "success": true,
      "data": {
        "status": "ok",
        "service": "backend",
        "timestamp": "data"
      },
      "meta": {}
    }

## Observacoes

Nesta etapa ainda nao foram instaladas dependencias.

Nesta etapa ainda nao foi executado npm install.

Nesta etapa ainda nao foi criado Dockerfile.

Nesta etapa ainda nao foram criados modulos de negocio.

## Proximas etapas sugeridas

Etapa 14:

    Criar arquivos base do frontend

Etapa 15:

    Criar Docker Compose inicial

Etapa 16:

    Criar arquivo .env.example

Etapa futura do backend:

    Instalar dependencias e validar build do backend

## Decisao final desta etapa

O backend agora possui uma base inicial com NestJS, Fastify, TypeScript, health check e estrutura comum para evoluir os modulos do SaaS.
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
- [ ] Etapa 14 - Arquivos base do frontend
- [ ] Etapa 15 - Docker Compose inicial
- [ ] Etapa 16 - Arquivo env example
- [ ] Etapa 17 - Validacao do ambiente inicial

## Ultima etapa executada

Etapa 13 - Arquivos base do backend.

## Proxima etapa sugerida

Etapa 14 - Criar arquivos base do frontend.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto do Projeto

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

Estrutura real do monorepo iniciada.

Backend base criado.

## Pasta base

saas-whatsapp-meta/

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md

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

## Estrutura real criada

- apps/backend
- apps/frontend
- apps/worker
- packages/shared
- packages/types
- packages/config
- infra/docker
- infra/nginx
- infra/postgres
- infra/redis
- infra/scripts

## Backend base

- apps/backend/package.json
- apps/backend/tsconfig.json
- apps/backend/src/main.ts
- apps/backend/src/app.module.ts
- apps/backend/src/health.controller.ts
- apps/backend/src/config/app.config.ts
- apps/backend/src/config/env.example.ts
- apps/backend/src/common/README.md

## Pastas de apoio

- scripts/
- logs/
- backups/

## Proxima etapa

- Etapa 14 - Arquivos base do frontend

## Arquivos atualizados na Etapa 13

- apps/backend/package.json
- apps/backend/tsconfig.json
- apps/backend/src/main.ts
- apps/backend/src/app.module.ts
- apps/backend/src/health.controller.ts
- apps/backend/src/config/app.config.ts
- apps/backend/src/config/env.example.ts
- apps/backend/src/common/README.md
- docs/BACKEND_BASE.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_13.log
DOC

echo "Validando arquivos criados..."

test -f "${BACKEND_DIR}/package.json"
test -f "${BACKEND_DIR}/tsconfig.json"
test -f "${BACKEND_DIR}/src/main.ts"
test -f "${BACKEND_DIR}/src/app.module.ts"
test -f "${BACKEND_DIR}/src/health.controller.ts"
test -f "${BACKEND_DIR}/src/config/app.config.ts"
test -f "${BACKEND_DIR}/src/config/env.example.ts"
test -f "${BACKEND_DIR}/src/common/README.md"
test -f "${BACKEND_BASE_DOC}"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${BACKEND_DIR}/package.json" \
  "${BACKEND_DIR}/tsconfig.json" \
  "${BACKEND_DIR}/src/main.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/health.controller.ts" \
  "${BACKEND_DIR}/src/config/app.config.ts" \
  "${BACKEND_DIR}/src/config/env.example.ts" \
  "${BACKEND_DIR}/src/common/README.md" \
  "${BACKEND_BASE_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 13
Acao: Arquivos base do backend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos criados ou atualizados:
- apps/backend/package.json
- apps/backend/tsconfig.json
- apps/backend/src/main.ts
- apps/backend/src/app.module.ts
- apps/backend/src/health.controller.ts
- apps/backend/src/config/app.config.ts
- apps/backend/src/config/env.example.ts
- apps/backend/src/common/README.md
- docs/BACKEND_BASE.md
- 00_CONTROLE.md
- MANIFESTO.md
Status: Concluido
DOC

echo ""
echo "== Etapa 13 concluida com sucesso =="
echo ""
echo "Arquivos do backend:"
find "${BACKEND_DIR}" -maxdepth 4 -type f | sort
echo ""
echo "Resumo de docs/BACKEND_BASE.md:"
sed -n '1,180p' "${BACKEND_BASE_DOC}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 14 - Criar arquivos base do frontend"
