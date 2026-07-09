#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_16.log"
ENV_FILE="${BASE_DIR}/.env.example"
ENV_DOC="${DOCS_DIR}/ENV_EXAMPLE.md"

echo "== Etapa 16: Arquivo env example =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${ENV_FILE}" \
  "${ENV_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Gerando .env.example..."

cat > "${ENV_FILE}" <<'DOC'
# Ambiente
NODE_ENV=development

# Aplicacao backend
APP_PORT=3000
APP_URL=http://localhost:3000
FRONTEND_URL=http://localhost:5173

# Aplicacao frontend
FRONTEND_PORT=5173
VITE_API_URL=http://localhost:3000/api/v1
VITE_SOCKET_URL=http://localhost:3000/realtime
VITE_APP_NAME=SaaS WhatsApp Meta

# Proxy
PROXY_HTTP_PORT=8080

# PostgreSQL
POSTGRES_DB=saas_whatsapp
POSTGRES_USER=saas_user
POSTGRES_PASSWORD=saas_password
POSTGRES_PORT=5432
DATABASE_URL=postgresql://saas_user:saas_password@postgres:5432/saas_whatsapp

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# Autenticacao
JWT_SECRET=change_me_jwt_secret
JWT_REFRESH_SECRET=change_me_jwt_refresh_secret

# Criptografia
ENCRYPTION_KEY=change_me_encryption_key

# Meta WhatsApp
META_GRAPH_BASE_URL=https://graph.facebook.com
META_API_VERSION=v20.0
META_WEBHOOK_VERIFY_TOKEN=change_me_webhook_verify_token
META_APP_SECRET=change_me_meta_app_secret
DOC

echo "Gerando docs/ENV_EXAMPLE.md..."

cat > "${ENV_DOC}" <<'DOC'
# Env Example

## Visao geral

Este documento registra a criacao do arquivo .env.example do projeto.

A Etapa 16 criou um modelo de variaveis de ambiente para desenvolvimento local e futuras configuracoes de deploy.

## Objetivo

O arquivo .env.example serve como referencia para criar o arquivo .env real.

O arquivo .env real nao deve ser versionado.

## Arquivo criado

Arquivo principal:

- .env.example

## Grupos de variaveis

Grupos definidos:

- Ambiente
- Aplicacao backend
- Aplicacao frontend
- Proxy
- PostgreSQL
- Redis
- Autenticacao
- Criptografia
- Meta WhatsApp

## Variaveis de ambiente

Ambiente:

- NODE_ENV

Backend:

- APP_PORT
- APP_URL
- FRONTEND_URL

Frontend:

- FRONTEND_PORT
- VITE_API_URL
- VITE_SOCKET_URL
- VITE_APP_NAME

Proxy:

- PROXY_HTTP_PORT

PostgreSQL:

- POSTGRES_DB
- POSTGRES_USER
- POSTGRES_PASSWORD
- POSTGRES_PORT
- DATABASE_URL

Redis:

- REDIS_HOST
- REDIS_PORT

Autenticacao:

- JWT_SECRET
- JWT_REFRESH_SECRET

Criptografia:

- ENCRYPTION_KEY

Meta WhatsApp:

- META_GRAPH_BASE_URL
- META_API_VERSION
- META_WEBHOOK_VERIFY_TOKEN
- META_APP_SECRET

## Regras de seguranca

Regras obrigatorias:

- Nao versionar .env real
- Nao usar valores change_me em producao
- Usar secrets fortes em producao
- Separar secrets por ambiente
- Rotacionar secrets quando houver suspeita de vazamento
- Nao colocar token real da Meta no frontend
- Nao expor JWT_SECRET no frontend
- Nao expor ENCRYPTION_KEY no frontend

## Como usar futuramente

Quando for iniciar o ambiente real, copiar o modelo:

    cp .env.example .env

Depois editar o arquivo .env com valores reais.

## Observacoes

Nesta etapa apenas o arquivo .env.example foi criado.

Nenhum secret real foi inserido.

A validacao do ambiente sera feita na Etapa 17.

## Decisao final desta etapa

O projeto agora possui um arquivo .env.example inicial, alinhado com Docker Compose, backend, frontend, PostgreSQL, Redis e integracao futura com Meta WhatsApp.
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
- [ ] Etapa 17 - Validacao do ambiente inicial

## Ultima etapa executada

Etapa 16 - Arquivo env example.

## Proxima etapa sugerida

Etapa 17 - Validacao do ambiente inicial.
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

Env example criado.

## Pasta base

saas-whatsapp-meta/

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml
- .env.example

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

## Env base

- .env.example

## Pastas de apoio

- scripts/
- logs/
- backups/

## Proxima etapa

- Etapa 17 - Validacao do ambiente inicial

## Arquivos atualizados na Etapa 16

- .env.example
- docs/ENV_EXAMPLE.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_16.log
DOC

echo "Validando arquivos criados..."

test -f "${ENV_FILE}"
test -f "${ENV_DOC}"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -f "${BASE_DIR}/docker-compose.yml"

echo "Validando variaveis obrigatorias..."

for key in \
  NODE_ENV \
  APP_PORT \
  APP_URL \
  FRONTEND_URL \
  FRONTEND_PORT \
  VITE_API_URL \
  VITE_SOCKET_URL \
  VITE_APP_NAME \
  PROXY_HTTP_PORT \
  POSTGRES_DB \
  POSTGRES_USER \
  POSTGRES_PASSWORD \
  POSTGRES_PORT \
  DATABASE_URL \
  REDIS_HOST \
  REDIS_PORT \
  JWT_SECRET \
  JWT_REFRESH_SECRET \
  ENCRYPTION_KEY \
  META_GRAPH_BASE_URL \
  META_API_VERSION \
  META_WEBHOOK_VERIFY_TOKEN \
  META_APP_SECRET
do
  if ! grep -q "^${key}=" "${ENV_FILE}"; then
    echo "ERRO: variavel ausente no .env.example: ${key}"
    exit 1
  fi
done

echo "Validando ausencia de HTML indevido..."

if grep -n "<a href" "${BASE_DIR}/docker-compose.yml" "${ENV_FILE}" "${ENV_DOC}"; then
  echo "ERRO: HTML indevido encontrado."
  exit 1
fi

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${ENV_FILE}" \
  "${ENV_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 16
Acao: Arquivo env example
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos criados ou atualizados:
- .env.example
- docs/ENV_EXAMPLE.md
- 00_CONTROLE.md
- MANIFESTO.md
Status: Concluido
DOC

echo ""
echo "== Etapa 16 concluida com sucesso =="
echo ""
echo "Arquivo .env.example:"
sed -n '1,220p' "${ENV_FILE}"
echo ""
echo "Resumo de docs/ENV_EXAMPLE.md:"
sed -n '1,180p' "${ENV_DOC}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 17 - Validacao do ambiente inicial"
