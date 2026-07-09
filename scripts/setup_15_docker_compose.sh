#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
INFRA_DIR="${BASE_DIR}/infra"
DOCKER_DIR="${INFRA_DIR}/docker"
NGINX_DIR="${INFRA_DIR}/nginx"
POSTGRES_INIT_DIR="${INFRA_DIR}/postgres/init"
REDIS_DIR="${INFRA_DIR}/redis"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_15.log"
DOCKER_DOC="${DOCS_DIR}/DOCKER_COMPOSE_BASE.md"

echo "== Etapa 15: Docker Compose inicial =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${DOCKER_DIR}"
mkdir -p "${NGINX_DIR}"
mkdir -p "${POSTGRES_INIT_DIR}"
mkdir -p "${REDIS_DIR}"

echo "Criando backups..."

for file in \
  "${BASE_DIR}/docker-compose.yml" \
  "${DOCKER_DIR}/backend.Dockerfile" \
  "${DOCKER_DIR}/frontend.Dockerfile" \
  "${DOCKER_DIR}/worker.Dockerfile" \
  "${NGINX_DIR}/nginx.conf" \
  "${POSTGRES_INIT_DIR}/001_init.sql" \
  "${REDIS_DIR}/redis.conf" \
  "${DOCKER_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Gerando docker-compose.yml..."

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
      - "${POSTGRES_PORT:-5432}:5432"
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
      - "${REDIS_PORT:-6379}:6379"
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
      APP_PORT: ${APP_PORT:-3000}
      APP_URL: ${APP_URL:-http://localhost:3000}
      FRONTEND_URL: ${FRONTEND_URL:-http://localhost:5173}
      DATABASE_URL: ${DATABASE_URL:-postgresql://saas_user:saas_password@postgres:5432/saas_whatsapp}
      REDIS_HOST: ${REDIS_HOST:-redis}
      REDIS_PORT: ${REDIS_PORT:-6379}
      JWT_SECRET: ${JWT_SECRET:-change_me}
      JWT_REFRESH_SECRET: ${JWT_REFRESH_SECRET:-change_me}
      ENCRYPTION_KEY: ${ENCRYPTION_KEY:-change_me}
      META_GRAPH_BASE_URL: ${META_GRAPH_BASE_URL:-https://graph.facebook.com}
      META_API_VERSION: ${META_API_VERSION:-v20.0}
      META_WEBHOOK_VERIFY_TOKEN: ${META_WEBHOOK_VERIFY_TOKEN:-change_me}
      META_APP_SECRET: ${META_APP_SECRET:-change_me}
    ports:
      - "${APP_PORT:-3000}:3000"
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
      VITE_API_URL: ${VITE_API_URL:-http://localhost:3000/api/v1}
      VITE_SOCKET_URL: ${VITE_SOCKET_URL:-http://localhost:3000/realtime}
      VITE_APP_NAME: ${VITE_APP_NAME:-SaaS WhatsApp Meta}
    ports:
      - "${FRONTEND_PORT:-5173}:80"
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
      REDIS_PORT: ${REDIS_PORT:-6379}
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
      - "${PROXY_HTTP_PORT:-8080}:80"
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

echo "Gerando infra/docker/backend.Dockerfile..."

cat > "${DOCKER_DIR}/backend.Dockerfile" <<'DOC'
FROM node:20-alpine AS build

WORKDIR /app/apps/backend

COPY apps/backend/package.json ./
RUN npm install

COPY apps/backend ./
RUN npm run build

FROM node:20-alpine AS runtime

WORKDIR /app/apps/backend

ENV NODE_ENV=production

COPY --from=build /app/apps/backend/package.json ./
COPY --from=build /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/dist ./dist

EXPOSE 3000

CMD ["node", "dist/main.js"]
DOC

echo "Gerando infra/docker/frontend.Dockerfile..."

cat > "${DOCKER_DIR}/frontend.Dockerfile" <<'DOC'
FROM node:20-alpine AS build

WORKDIR /app/apps/frontend

COPY apps/frontend/package.json ./
RUN npm install

COPY apps/frontend ./
RUN npm run build

FROM nginx:1.27-alpine AS runtime

COPY --from=build /app/apps/frontend/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
DOC

echo "Gerando infra/docker/worker.Dockerfile..."

cat > "${DOCKER_DIR}/worker.Dockerfile" <<'DOC'
FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production

CMD ["node", "-e", "setInterval(() => console.log('worker placeholder'), 60000)"]
DOC

echo "Gerando infra/nginx/nginx.conf..."

cat > "${NGINX_DIR}/nginx.conf" <<'DOC'
server {
  listen 80;
  server_name _;

  client_max_body_size 20m;

  location /api/ {
    proxy_pass http://backend:3000/api/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location /realtime/ {
    proxy_pass http://backend:3000/realtime/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location / {
    proxy_pass http://frontend:80/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
DOC

echo "Gerando infra/postgres/init/001_init.sql..."

cat > "${POSTGRES_INIT_DIR}/001_init.sql" <<'DOC'
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DOC

echo "Gerando infra/redis/redis.conf..."

cat > "${REDIS_DIR}/redis.conf" <<'DOC'
appendonly yes
save 60 1000
loglevel notice
dir /data
DOC

echo "Gerando docs/DOCKER_COMPOSE_BASE.md..."

cat > "${DOCKER_DOC}" <<'DOC'
# Docker Compose Base

## Visao geral

Este documento registra a criacao do Docker Compose inicial do projeto.

A Etapa 15 criou os arquivos base para subir a infraestrutura inicial com containers.

## Objetivo

Preparar uma base de infraestrutura para desenvolvimento e validacao futura.

## Arquivos criados

Arquivos principais:

- docker-compose.yml
- infra/docker/backend.Dockerfile
- infra/docker/frontend.Dockerfile
- infra/docker/worker.Dockerfile
- infra/nginx/nginx.conf
- infra/postgres/init/001_init.sql
- infra/redis/redis.conf

## Servicos definidos

Servicos:

- postgres
- redis
- backend
- frontend
- worker
- proxy

## postgres

Responsavel pelo banco principal.

Uso:

- dados permanentes do SaaS
- tenants
- usuarios
- contatos
- conversas
- mensagens
- auditoria

## redis

Responsavel por cache, filas e estado temporario.

Uso:

- BullMQ futuro
- cache temporario
- rate limit futuro
- coordenacao futura de workers

## backend

Responsavel pela API principal.

Uso:

- API REST
- webhooks
- autenticacao
- regras de negocio
- Socket.IO futuro

## frontend

Responsavel pelo painel web.

Uso:

- React
- TypeScript
- Vite
- interface administrativa
- painel de atendimento

## worker

Responsavel por processamento assincrono.

Observacao:

Nesta etapa o worker ainda e um placeholder.

O worker real sera implementado em etapa futura.

## proxy

Responsavel por centralizar acesso HTTP.

Uso:

- encaminhar chamadas para frontend
- encaminhar chamadas para backend
- preparar caminho para HTTPS em producao futura

## Portas padrao

Portas em desenvolvimento:

- postgres 5432
- redis 6379
- backend 3000
- frontend 5173
- proxy 8080

## Volumes

Volumes criados:

- postgres_data
- redis_data

## Rede

Rede criada:

- saas_network

## Observacoes

Nesta etapa ainda nao foi criado arquivo env example.

Nesta etapa ainda nao foi feito build dos containers.

Nesta etapa ainda nao foi instalado node_modules local.

Nesta etapa ainda nao foi validado docker compose up.

## Proximas etapas sugeridas

Etapa 16:

    Criar arquivo env example

Etapa 17:

    Validar ambiente inicial

Etapa futura:

    Ajustar worker real
    Ajustar Dockerfiles apos instalacao das dependencias
    Configurar HTTPS real
    Configurar deploy de producao

## Decisao final desta etapa

O projeto agora possui Docker Compose inicial com postgres, redis, backend, frontend, worker placeholder e proxy Nginx.
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
- [ ] Etapa 16 - Arquivo env example
- [ ] Etapa 17 - Validacao do ambiente inicial

## Ultima etapa executada

Etapa 15 - Docker Compose inicial.

## Proxima etapa sugerida

Etapa 16 - Criar arquivo env example.
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

Frontend base criado.

Docker Compose inicial criado.

## Pasta base

saas-whatsapp-meta/

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml

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

## Docker base

- docker-compose.yml
- infra/docker/backend.Dockerfile
- infra/docker/frontend.Dockerfile
- infra/docker/worker.Dockerfile
- infra/nginx/nginx.conf
- infra/postgres/init/001_init.sql
- infra/redis/redis.conf

## Pastas de apoio

- scripts/
- logs/
- backups/

## Proxima etapa

- Etapa 16 - Arquivo env example

## Arquivos atualizados na Etapa 15

- docker-compose.yml
- infra/docker/backend.Dockerfile
- infra/docker/frontend.Dockerfile
- infra/docker/worker.Dockerfile
- infra/nginx/nginx.conf
- infra/postgres/init/001_init.sql
- infra/redis/redis.conf
- docs/DOCKER_COMPOSE_BASE.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_15.log
DOC

echo "Validando arquivos criados..."

test -f "${BASE_DIR}/docker-compose.yml"
test -f "${DOCKER_DIR}/backend.Dockerfile"
test -f "${DOCKER_DIR}/frontend.Dockerfile"
test -f "${DOCKER_DIR}/worker.Dockerfile"
test -f "${NGINX_DIR}/nginx.conf"
test -f "${POSTGRES_INIT_DIR}/001_init.sql"
test -f "${REDIS_DIR}/redis.conf"
test -f "${DOCKER_DOC}"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${BASE_DIR}/docker-compose.yml" \
  "${DOCKER_DIR}/backend.Dockerfile" \
  "${DOCKER_DIR}/frontend.Dockerfile" \
  "${DOCKER_DIR}/worker.Dockerfile" \
  "${NGINX_DIR}/nginx.conf" \
  "${POSTGRES_INIT_DIR}/001_init.sql" \
  "${REDIS_DIR}/redis.conf" \
  "${DOCKER_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 15
Acao: Docker Compose inicial
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos criados ou atualizados:
- docker-compose.yml
- infra/docker/backend.Dockerfile
- infra/docker/frontend.Dockerfile
- infra/docker/worker.Dockerfile
- infra/nginx/nginx.conf
- infra/postgres/init/001_init.sql
- infra/redis/redis.conf
- docs/DOCKER_COMPOSE_BASE.md
- 00_CONTROLE.md
- MANIFESTO.md
Status: Concluido
DOC

echo ""
echo "== Etapa 15 concluida com sucesso =="
echo ""
echo "Arquivos Docker:"
find "${BASE_DIR}/infra" -maxdepth 4 -type f | sort
echo ""
echo "Docker Compose:"
sed -n '1,220p' "${BASE_DIR}/docker-compose.yml"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 16 - Criar arquivo env example"
