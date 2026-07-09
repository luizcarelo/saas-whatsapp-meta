#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_21.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_21_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_21_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_21_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_21_backend_docker_up.log"
LOCAL_HEALTH_LOG="${LOGS_DIR}/setup_21_health_local.log"
DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_21_health_domain.log"
DOC_FILE="${DOCS_DIR}/BACKEND_HEALTH_CONFIG_DATABASE.md"

LOCAL_HEALTH_URL="http://127.0.0.1:3300/api/v1/health"
DOMAIN_HEALTH_URL="https://bot.lhsolucao.com.br/api/v1/health"

echo "== Etapa 21: Backend health, configuration e database base =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

mkdir -p "${BACKEND_DIR}/src/modules/health"
mkdir -p "${BACKEND_DIR}/src/modules/configuration"
mkdir -p "${BACKEND_DIR}/src/modules/database"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/health/health.module.ts" \
  "${BACKEND_DIR}/src/modules/health/health.controller.ts" \
  "${BACKEND_DIR}/src/modules/health/health.service.ts" \
  "${BACKEND_DIR}/src/modules/configuration/configuration.module.ts" \
  "${BACKEND_DIR}/src/modules/configuration/configuration.service.ts" \
  "${BACKEND_DIR}/src/modules/database/database.module.ts" \
  "${BACKEND_DIR}/src/modules/database/database.service.ts" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Criando ConfigurationService..."

cat > "${BACKEND_DIR}/src/modules/configuration/configuration.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';

type PublicConfig = {
  nodeEnv: string;
  appPort: number;
  appUrl: string;
  frontendUrl: string;
  databaseConfigured: boolean;
  redisConfigured: boolean;
  metaConfigured: boolean;
};

@Injectable()
export class ConfigurationService {
  getString(key: string, fallback = ''): string {
    return process.env[key] || fallback;
  }

  getNumber(key: string, fallback: number): number {
    const value = process.env[key];

    if (!value) {
      return fallback;
    }

    const parsed = Number(value);

    if (Number.isNaN(parsed)) {
      return fallback;
    }

    return parsed;
  }

  getPublicConfig(): PublicConfig {
    return {
      nodeEnv: this.getString('NODE_ENV', 'development'),
      appPort: this.getNumber('APP_PORT', 3000),
      appUrl: this.getString('APP_URL', 'http://localhost:3300'),
      frontendUrl: this.getString('FRONTEND_URL', 'http://localhost:5573'),
      databaseConfigured: this.hasDatabaseUrl(),
      redisConfigured: this.hasRedisConfig(),
      metaConfigured: this.hasMetaConfig()
    };
  }

  hasDatabaseUrl(): boolean {
    return this.getString('DATABASE_URL').length > 0;
  }

  hasRedisConfig(): boolean {
    return this.getString('REDIS_HOST').length > 0 && this.getString('REDIS_PORT').length > 0;
  }

  hasMetaConfig(): boolean {
    return this.getString('META_GRAPH_BASE_URL').length > 0 && this.getString('META_API_VERSION').length > 0;
  }
}
DOC

echo "Criando ConfigurationModule..."

cat > "${BACKEND_DIR}/src/modules/configuration/configuration.module.ts" <<'DOC'
import { Global, Module } from '@nestjs/common';
import { ConfigurationService } from './configuration.service';

@Global()
@Module({
  providers: [
    ConfigurationService
  ],
  exports: [
    ConfigurationService
  ]
})
export class ConfigurationModule {}
DOC

echo "Criando DatabaseService..."

cat > "${BACKEND_DIR}/src/modules/database/database.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import { ConfigurationService } from '../configuration/configuration.service';

type DatabaseStatus = {
  configured: boolean;
  provider: string;
  connectionName: string;
};

@Injectable()
export class DatabaseService {
  constructor(private readonly configurationService: ConfigurationService) {}

  getStatus(): DatabaseStatus {
    const configured = this.configurationService.hasDatabaseUrl();

    return {
      configured,
      provider: 'postgresql',
      connectionName: configured ? 'primary' : 'not_configured'
    };
  }
}
DOC

echo "Criando DatabaseModule..."

cat > "${BACKEND_DIR}/src/modules/database/database.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { DatabaseService } from './database.service';

@Module({
  providers: [
    DatabaseService
  ],
  exports: [
    DatabaseService
  ]
})
export class DatabaseModule {}
DOC

echo "Criando HealthService..."

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

  getHealth(): HealthResponse {
    const config = this.configurationService.getPublicConfig();
    const database = this.databaseService.getStatus();

    return {
      success: true,
      data: {
        status: 'ok',
        service: 'backend',
        timestamp: new Date().toISOString(),
        environment: config.nodeEnv,
        checks: {
          api: 'ok',
          database: database.configured ? 'configured' : 'not_configured',
          redis: config.redisConfigured ? 'configured' : 'not_configured',
          meta: config.metaConfigured ? 'configured' : 'not_configured'
        }
      },
      meta: {}
    };
  }
}
DOC

echo "Criando HealthController..."

cat > "${BACKEND_DIR}/src/modules/health/health.controller.ts" <<'DOC'
import { Controller, Get } from '@nestjs/common';
import { HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  getHealth() {
    return this.healthService.getHealth();
  }
}
DOC

echo "Criando HealthModule..."

cat > "${BACKEND_DIR}/src/modules/health/health.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';

@Module({
  imports: [
    DatabaseModule
  ],
  controllers: [
    HealthController
  ],
  providers: [
    HealthService
  ]
})
export class HealthModule {}
DOC

echo "Atualizando AppModule..."

cat > "${BACKEND_DIR}/src/app.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { ConfigurationModule } from './modules/configuration/configuration.module';
import { DatabaseModule } from './modules/database/database.module';
import { HealthModule } from './modules/health/health.module';

@Module({
  imports: [
    ConfigurationModule,
    DatabaseModule,
    HealthModule
  ],
  controllers: [],
  providers: []
})
export class AppModule {}
DOC

echo "Validando arquivos criados..."

test -f "${BACKEND_DIR}/src/app.module.ts"
test -f "${BACKEND_DIR}/src/modules/health/health.module.ts"
test -f "${BACKEND_DIR}/src/modules/health/health.controller.ts"
test -f "${BACKEND_DIR}/src/modules/health/health.service.ts"
test -f "${BACKEND_DIR}/src/modules/configuration/configuration.module.ts"
test -f "${BACKEND_DIR}/src/modules/configuration/configuration.service.ts"
test -f "${BACKEND_DIR}/src/modules/database/database.module.ts"
test -f "${BACKEND_DIR}/src/modules/database/database.service.ts"

echo "Validando HTML indevido..."

if grep -R "<a href" "${BACKEND_DIR}/src/modules" "${BACKEND_DIR}/src/app.module.ts"; then
  echo "ERRO: HTML indevido encontrado nos arquivos do backend."
  exit 1
fi

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${TYPECHECK_LOG}"

echo "Rodando build local do backend..."

npm run build 2>&1 | tee "${BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando container backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BUILD_LOG}"

echo "Subindo backend atualizado..."

docker compose up -d backend 2>&1 | tee "${DOCKER_UP_LOG}"

echo "Aguardando backend iniciar..."

sleep 8

echo "Testando health local..."

LOCAL_STATUS="$(curl -s -o "${LOCAL_HEALTH_LOG}" -w "%{http_code}" --max-time 20 "${LOCAL_HEALTH_URL}" || true)"

echo "Health local status: ${LOCAL_STATUS}"

if [ "${LOCAL_STATUS}" != "200" ]; then
  echo "ERRO: health local nao respondeu 200."
  docker compose logs --tail=120 backend
  exit 1
fi

echo "Testando health pelo dominio..."

DOMAIN_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_HEALTH_URL}" || true)"

echo "Health dominio status: ${DOMAIN_STATUS}"

if [ "${DOMAIN_STATUS}" != "200" ]; then
  echo "ERRO: health pelo dominio nao respondeu 200."
  docker compose logs --tail=120 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 21..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Health Configuration Database

## Visao geral

Este documento registra a criacao dos modulos iniciais reais do backend.

## Resultado

Status:

    concluido

## Modulos criados

Modulos:

- HealthModule
- ConfigurationModule
- DatabaseModule

## Arquivos criados

Arquivos:

- apps/backend/src/modules/health/health.module.ts
- apps/backend/src/modules/health/health.controller.ts
- apps/backend/src/modules/health/health.service.ts
- apps/backend/src/modules/configuration/configuration.module.ts
- apps/backend/src/modules/configuration/configuration.service.ts
- apps/backend/src/modules/database/database.module.ts
- apps/backend/src/modules/database/database.service.ts

## Arquivo atualizado

Arquivo:

- apps/backend/src/app.module.ts

## Endpoint validado

Endpoint:

- api v1 health

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- health local
- health pelo dominio

## Logs gerados

Logs:

- logs/setup_21_backend_typecheck.log
- logs/setup_21_backend_build.log
- logs/setup_21_backend_docker_build.log
- logs/setup_21_backend_docker_up.log
- logs/setup_21_health_local.log
- logs/setup_21_health_domain.log
- logs/setup_21.log

## Observacoes

O DatabaseModule criado nesta etapa ainda nao abre conexao real com o banco.

Ele prepara a base para a proxima etapa, onde sera definido o ORM e a conexao real com PostgreSQL.

## Proxima etapa sugerida

Etapa 22:

    Definir ORM e criar conexao real com PostgreSQL
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
- [ ] Etapa 22 - ORM e conexao real com PostgreSQL

## Ultima etapa executada

Etapa 21 - Health, configuracao e database base.

## Proxima etapa sugerida

Etapa 22 - Definir ORM e criar conexao real com PostgreSQL.
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

Backend real inicial iniciado com health, configuracao e database base.

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

## Etapas concluidas

- Etapa 01 ate Etapa 21 concluidas

## Proxima etapa

- Etapa 22 - ORM e conexao real com PostgreSQL
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

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 21
Acao: Health, configuracao e database base
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health local status: ${LOCAL_STATUS}
Health dominio status: ${DOMAIN_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 21 concluida com sucesso =="
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
echo "Etapa 22 - Definir ORM e criar conexao real com PostgreSQL"
