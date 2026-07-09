#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
DOCKER_DIR="${BASE_DIR}/infra/docker"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_19.log"
CONFIG_LOG="${LOGS_DIR}/setup_19_docker_config.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_19_backend_build.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_19_frontend_build.log"
WORKER_BUILD_LOG="${LOGS_DIR}/setup_19_worker_build.log"
DOCKER_BUILD_DOC="${DOCS_DIR}/DOCKER_BUILD.md"

echo "== Etapa 19: Ajustar Dockerfiles e validar build dos containers =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${DOCKER_DIR}"

echo "Criando backups..."

for file in \
  "${BASE_DIR}/.dockerignore" \
  "${DOCKER_DIR}/backend.Dockerfile" \
  "${DOCKER_DIR}/frontend.Dockerfile" \
  "${DOCKER_DIR}/worker.Dockerfile" \
  "${DOCKER_BUILD_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando Docker..."

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

DOCKER_VERSION="$(docker --version)"
COMPOSE_VERSION="$(docker compose version)"

echo "Docker encontrado: ${DOCKER_VERSION}"
echo "Docker Compose encontrado: ${COMPOSE_VERSION}"

echo "Criando .dockerignore..."

cat > "${BASE_DIR}/.dockerignore" <<'DOC'
node_modules
dist
.git
backups
logs
.env
npm-debug.log
Dockerfile
docker-compose.override.yml
DOC

echo "Ajustando backend.Dockerfile..."

cat > "${DOCKER_DIR}/backend.Dockerfile" <<'DOC'
FROM node:20-alpine AS deps

WORKDIR /app/apps/backend

COPY apps/backend/package.json apps/backend/package-lock.json ./

RUN npm ci

FROM node:20-alpine AS build

WORKDIR /app/apps/backend

COPY --from=deps /app/apps/backend/node_modules ./node_modules
COPY apps/backend ./

RUN npm run build

FROM node:20-alpine AS runtime

WORKDIR /app/apps/backend

ENV NODE_ENV=production

COPY apps/backend/package.json ./
COPY --from=deps /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/dist ./dist

EXPOSE 3000

CMD ["node", "dist/main.js"]
DOC

echo "Ajustando frontend.Dockerfile..."

cat > "${DOCKER_DIR}/frontend.Dockerfile" <<'DOC'
FROM node:20-alpine AS deps

WORKDIR /app/apps/frontend

COPY apps/frontend/package.json apps/frontend/package-lock.json ./

RUN npm ci

FROM node:20-alpine AS build

WORKDIR /app/apps/frontend

COPY --from=deps /app/apps/frontend/node_modules ./node_modules
COPY apps/frontend ./

RUN npm run build

FROM nginx:1.27-alpine AS runtime

COPY --from=build /app/apps/frontend/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
DOC

echo "Ajustando worker.Dockerfile..."

cat > "${DOCKER_DIR}/worker.Dockerfile" <<'DOC'
FROM node:20-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production

CMD ["node", "-e", "setInterval(() => console.log('worker placeholder'), 60000)"]
DOC

echo "Validando arquivos obrigatorios..."

test -f "${BASE_DIR}/docker-compose.yml"
test -f "${BASE_DIR}/.env"
test -f "${BASE_DIR}/.env.example"
test -f "${BASE_DIR}/.dockerignore"
test -f "${DOCKER_DIR}/backend.Dockerfile"
test -f "${DOCKER_DIR}/frontend.Dockerfile"
test -f "${DOCKER_DIR}/worker.Dockerfile"
test -f "${BASE_DIR}/apps/backend/package.json"
test -f "${BASE_DIR}/apps/backend/package-lock.json"
test -f "${BASE_DIR}/apps/frontend/package.json"
test -f "${BASE_DIR}/apps/frontend/package-lock.json"

echo "Validando ausencia de HTML indevido..."

if grep -n "<a href" \
  "${BASE_DIR}/docker-compose.yml" \
  "${BASE_DIR}/.dockerignore" \
  "${DOCKER_DIR}/backend.Dockerfile" \
  "${DOCKER_DIR}/frontend.Dockerfile" \
  "${DOCKER_DIR}/worker.Dockerfile"
then
  echo "ERRO: HTML indevido encontrado."
  exit 1
fi

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${BASE_DIR}/.dockerignore" \
  "${DOCKER_DIR}/backend.Dockerfile" \
  "${DOCKER_DIR}/frontend.Dockerfile" \
  "${DOCKER_DIR}/worker.Dockerfile"
then
  echo "ERRO: caractere proibido encontrado nos arquivos Docker gerados."
  exit 1
fi

echo "Validando docker compose config..."

docker compose config 2>&1 | tee "${CONFIG_LOG}"

echo "Construindo container backend..."

docker compose build backend 2>&1 | tee "${BACKEND_BUILD_LOG}"

echo "Construindo container frontend..."

docker compose build frontend 2>&1 | tee "${FRONTEND_BUILD_LOG}"

echo "Construindo container worker..."

docker compose build worker 2>&1 | tee "${WORKER_BUILD_LOG}"

echo "Gerando docs/DOCKER_BUILD.md..."

cat > "${DOCKER_BUILD_DOC}" <<'DOC'
# Docker Build

## Visao geral

Este documento registra o ajuste dos Dockerfiles e a validacao de build dos containers.

## Resultado

Status:

    concluido

## Arquivos ajustados

Arquivos:

- .dockerignore
- infra/docker/backend.Dockerfile
- infra/docker/frontend.Dockerfile
- infra/docker/worker.Dockerfile

## Validacoes executadas

Validacoes:

- docker compose config
- docker compose build backend
- docker compose build frontend
- docker compose build worker

## Backend

Container:

    backend

Ajustes:

- Uso de npm ci
- Build em etapa separada
- Runtime separado
- Porta interna 3000

## Frontend

Container:

    frontend

Ajustes:

- Uso de npm ci
- Build com Vite
- Runtime com Nginx
- Porta interna 80

## Worker

Container:

    worker

Ajustes:

- Worker placeholder mantido
- Container preparado para implementacao futura
- Sem porta publica

## Logs gerados

Logs:

- logs/setup_19_docker_config.log
- logs/setup_19_backend_build.log
- logs/setup_19_frontend_build.log
- logs/setup_19_worker_build.log
- logs/setup_19.log

## Observacoes

Nesta etapa os containers foram construidos.

Os containers ainda nao foram iniciados em modo completo.

A proxima etapa deve subir os servicos de infraestrutura e validar health checks.

## Proxima etapa sugerida

Etapa 20:

    Subir containers e validar execucao inicial
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
- [ ] Etapa 20 - Subir containers e validar execucao inicial

## Ultima etapa executada

Etapa 19 - Ajustar Dockerfiles e validar build dos containers.

## Proxima etapa sugerida

Etapa 20 - Subir containers e validar execucao inicial.
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

## Docker

Arquivos:

- infra/docker/backend.Dockerfile
- infra/docker/frontend.Dockerfile
- infra/docker/worker.Dockerfile

Logs:

- logs/setup_19_docker_config.log
- logs/setup_19_backend_build.log
- logs/setup_19_frontend_build.log
- logs/setup_19_worker_build.log
- logs/setup_19.log

## Etapas concluidas

- Etapa 01 ate Etapa 19 concluidas

## Proxima etapa

- Etapa 20 - Subir containers e validar execucao inicial
DOC

echo "Validando ausencia de caractere proibido nos arquivos finais..."

if grep -n "${BAD_CHAR}" \
  "${DOCKER_BUILD_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 19
Acao: Ajustar Dockerfiles e validar build dos containers
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Docker: ${DOCKER_VERSION}
Docker Compose: ${COMPOSE_VERSION}
Arquivos criados ou atualizados:
- .dockerignore
- infra/docker/backend.Dockerfile
- infra/docker/frontend.Dockerfile
- infra/docker/worker.Dockerfile
- docs/DOCKER_BUILD.md
- 00_CONTROLE.md
- MANIFESTO.md
Status: Concluido
DOC

echo ""
echo "== Etapa 19 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOCKER_BUILD_DOC}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 20 - Subir containers e validar execucao inicial"
