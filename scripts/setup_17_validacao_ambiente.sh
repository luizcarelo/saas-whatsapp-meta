#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_17.log"
VALIDATION_DOC="${DOCS_DIR}/VALIDACAO_AMBIENTE.md"

echo "== Etapa 17: Validacao do ambiente inicial =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${BASE_DIR}/docker-compose.yml" \
  "${FRONTEND_DIR}/index.html" \
  "${VALIDATION_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Corrigindo apps/frontend/index.html..."

cat > "${FRONTEND_DIR}/index.html" <<'DOC'
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>SaaS WhatsApp Meta</title>
  </head>
  <body>
    <div id="root"></div>
    /src/main.tsxscript>
  </body>
</html>
DOC

echo "Regravando docker-compose.yml com portas internas e externas separadas..."

cat > "${BASE_DIR}/docker-compose.yml" <<'DOC'
services:
  postgres:
    image: postgres:16-alpine
    container_name: saas_whatsapp_postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-saas_whatsapp}
      POSTGRES_USER: ${POSTGRES_USER:-saas_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-saas_password}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./infra/postgres/init:/docker-entrypoint-initdb.d
    ports:
      - "${POSTGRES_PORT:-55432}:5432"
    networks:
      - saas_network
    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -U saas_user -d saas_whatsapp
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: saas_whatsapp_redis
    command:
      - redis-server
      - /usr/local/etc/redis/redis.conf
    volumes:
      - redis_data:/data
      - ./infra/redis/redis.conf:/usr/local/etc/redis/redis.conf
    ports:
      - "${REDIS_PORT:-56379}:6379"
    networks:
      - saas_network
    healthcheck:
      test:
        - CMD
        - redis-cli
        - ping
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  backend:
    build:
      context: .
      dockerfile: infra/docker/backend.Dockerfile
    container_name: saas_whatsapp_backend
    environment:
      NODE_ENV: ${NODE_ENV:-development}
      APP_PORT: ${APP_PORT:-3300}
      APP_URL: ${APP_URL:-http://localhost:3300}
      FRONTEND_URL: ${FRONTEND_URL:-http://localhost:5573}
      DATABASE_URL: ${DATABASE_URL:-postgresql://saas_user:saas_password@postgres:5432/saas_whatsapp}
      REDIS_HOST: ${REDIS_HOST:-redis}
      REDIS_PORT: ${REDIS_CONTAINER_PORT:-6379}
      JWT_SECRET: ${JWT_SECRET:-change_me}
      JWT_REFRESH_SECRET: ${JWT_REFRESH_SECRET:-change_me}
      ENCRYPTION_KEY: ${ENCRYPTION_KEY:-change_me}
      META_GRAPH_BASE_URL: ${META_GRAPH_BASE_URL:-https://graph.facebook.com}
      META_API_VERSION: ${META_API_VERSION:-v20.0}
      META_WEBHOOK_VERIFY_TOKEN: ${META_WEBHOOK_VERIFY_TOKEN:-change_me}
      META_APP_SECRET: ${META_APP_SECRET:-change_me}
    ports:
      - "${APP_PORT:-3300}:3000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - saas_network
    restart: unless-stopped

  frontend:
    build:
      context: .
      dockerfile: infra/docker/frontend.Dockerfile
    container_name: saas_whatsapp_frontend
    environment:
      VITE_API_URL: ${VITE_API_URL:-http://localhost:3300/api/v1}
      VITE_SOCKET_URL: ${VITE_SOCKET_URL:-http://localhost:3300/realtime}
      VITE_APP_NAME: ${VITE_APP_NAME:-SaaS WhatsApp Meta}
    ports:
      - "${FRONTEND_PORT:-5573}:80"
    depends_on:
      - backend
    networks:
      - saas_network
    restart: unless-stopped

  worker:
    build:
      context: .
      dockerfile: infra/docker/worker.Dockerfile
    container_name: saas_whatsapp_worker
    environment:
      NODE_ENV: ${NODE_ENV:-development}
      DATABASE_URL: ${DATABASE_URL:-postgresql://saas_user:saas_password@postgres:5432/saas_whatsapp}
      REDIS_HOST: ${REDIS_HOST:-redis}
      REDIS_PORT: ${REDIS_CONTAINER_PORT:-6379}
      ENCRYPTION_KEY: ${ENCRYPTION_KEY:-change_me}
      META_GRAPH_BASE_URL: ${META_GRAPH_BASE_URL:-https://graph.facebook.com}
      META_API_VERSION: ${META_API_VERSION:-v20.0}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - saas_network
    restart: unless-stopped

  proxy:
    image: nginx:1.27-alpine
    container_name: saas_whatsapp_proxy
    volumes:
      - ./infra/nginx/nginx.conf:/etc/nginx/conf.d/default.conf
    ports:
      - "${PROXY_HTTP_PORT:-8180}:80"
    depends_on:
      - frontend
      - backend
    networks:
      - saas_network
    restart: unless-stopped

networks:
  saas_network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
DOC

echo "Criando .env a partir de .env.example se necessario..."

if [ ! -f "${BASE_DIR}/.env" ]; then
  cp "${BASE_DIR}/.env.example" "${BASE_DIR}/.env"
fi

echo "Validando estrutura principal..."

test -f "${BASE_DIR}/README.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/docker-compose.yml"
test -f "${BASE_DIR}/.env.example"
test -f "${BASE_DIR}/.env"

test -d "${BASE_DIR}/apps/backend"
test -d "${BASE_DIR}/apps/frontend"
test -d "${BASE_DIR}/apps/worker"
test -d "${BASE_DIR}/packages/shared"
test -d "${BASE_DIR}/packages/types"
test -d "${BASE_DIR}/packages/config"
test -d "${BASE_DIR}/infra/docker"
test -d "${BASE_DIR}/infra/nginx"
test -d "${BASE_DIR}/infra/postgres/init"
test -d "${BASE_DIR}/infra/redis"

echo "Validando arquivos base do backend..."

test -f "${BASE_DIR}/apps/backend/package.json"
test -f "${BASE_DIR}/apps/backend/tsconfig.json"
test -f "${BASE_DIR}/apps/backend/src/main.ts"
test -f "${BASE_DIR}/apps/backend/src/app.module.ts"
test -f "${BASE_DIR}/apps/backend/src/health.controller.ts"

echo "Validando arquivos base do frontend..."

test -f "${FRONTEND_DIR}/package.json"
test -f "${FRONTEND_DIR}/tsconfig.json"
test -f "${FRONTEND_DIR}/index.html"
test -f "${FRONTEND_DIR}/vite.config.ts"
test -f "${FRONTEND_DIR}/src/main.tsx"
test -f "${FRONTEND_DIR}/src/App.tsx"

echo "Validando arquivos de infraestrutura..."

test -f "${BASE_DIR}/infra/docker/backend.Dockerfile"
test -f "${BASE_DIR}/infra/docker/frontend.Dockerfile"
test -f "${BASE_DIR}/infra/docker/worker.Dockerfile"
test -f "${BASE_DIR}/infra/nginx/nginx.conf"
test -f "${BASE_DIR}/infra/postgres/init/001_init.sql"
test -f "${BASE_DIR}/infra/redis/redis.conf"

echo "Validando ausencia de HTML indevido..."

if grep -n "/src/main.tsxFRONTEND_PORT_VALUE="$(grep '^FRONTEND_PORT=' .env | cut -d '=' -f 2)"
PROXY_HTTP_PORT_VALUE="$(grep '^PROXY_HTTP_PORT=' .env | cut -d '=' -f 2)"
POSTGRES_PORT_VALUE="$(grep '^POSTGRES_PORT=' .env | cut -d '=' -f 2)"
REDIS_PORT_VALUE="$(grep '^REDIS_PORT=' .env | cut -d '=' -f 2)"

echo "Validando portas ocupadas no host..."

PORT_CONFLICTS=""

for port in \
  "${APP_PORT_VALUE}" \
  "${FRONTEND_PORT_VALUE}" \
  "${PROXY_HTTP_PORT_VALUE}" \
  "${POSTGRES_PORT_VALUE}" \
  "${REDIS_PORT_VALUE}"
do
  if ss -tln | grep -q ":${port} "; then
    PORT_CONFLICTS="${PORT_CONFLICTS} ${port}"
  fi
done

if [ -n "${PORT_CONFLICTS}" ]; then
  echo "ERRO: portas ocupadas no host:${PORT_CONFLICTS}"
  echo "Ajuste o .env antes de subir os containers."
  exit 1
fi

echo "Validando configuracao do Docker Compose..."

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    docker compose config >/tmp/saas_whatsapp_compose_config_${STAMP}.txt
  else
    echo "ERRO: docker compose nao esta disponivel."
    exit 1
  fi
else
  echo "ERRO: docker nao esta instalado ou nao esta no PATH."
  exit 1
fi

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${VALIDATION_DOC}" 2>/dev/null
then
  echo "ERRO: caractere proibido encontrado em validacao anterior."
  exit 1
fi

echo "Gerando docs/VALIDACAO_AMBIENTE.md..."

cat > "${VALIDATION_DOC}" < "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
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

## Ultima etapa executada

Etapa 17 - Validacao do ambiente inicial.

## Proxima etapa sugerida

Etapa 18 - Preparar instalacao e validacao de dependencias.
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

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml
- .env.example
- .env

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

## Etapas concluidas

- Etapa 01 ate Etapa 17 concluidas

## Proxima etapa

- Etapa 18 - Preparar instalacao e validacao de dependencias

## Arquivos atualizados na Etapa 17

- docker-compose.yml
- apps/frontend/index.html
- docs/VALIDACAO_AMBIENTE.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_17.log
DOC

echo "Validando ausencia de caractere proibido nos arquivos finais..."

if grep -n "${BAD_CHAR}" \
  "${VALIDATION_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 17
Acao: Validacao do ambiente inicial
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos criados ou atualizados:
- docker-compose.yml
- apps/frontend/index.html
- docs/VALIDACAO_AMBIENTE.md
- 00_CONTROLE.md
- MANIFESTO.md
Status: Concluido
DOC

echo ""
echo "== Etapa 17 concluida com sucesso =="
echo ""
echo "Resumo da validacao:"
sed -n '1,220p' "${VALIDATION_DOC}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 18 - Preparar instalacao e validacao de dependencias"
