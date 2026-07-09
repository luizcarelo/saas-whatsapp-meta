#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
DOCKER_DIR="${BASE_DIR}/infra/docker"
NGINX_DIR="${BASE_DIR}/infra/nginx"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_26.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_26_frontend_spa_nginx.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_26_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_26_frontend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_26_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_26_frontend_docker_up.log"
DOMAIN_HOME_LOG="${LOGS_DIR}/setup_26_domain_home.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_26_domain_login.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_26_domain_dashboard.log"
DOC_FILE="${DOCS_DIR}/FRONTEND_LOGIN_INTEGRADO.md"

DOMAIN_HOME_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/login"
DOMAIN_DASHBOARD_URL="https://bot.lhsolucao.com.br/app/dashboard"

echo "== Correcao Etapa 26: Nginx SPA fallback =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${NGINX_DIR}"

echo "Criando backups..."

for file in \
  "${DOCKER_DIR}/frontend.Dockerfile" \
  "${NGINX_DIR}/frontend.conf" \
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

echo "Criando configuracao Nginx do frontend para SPA..."

cat > "${NGINX_DIR}/frontend.conf" <<'DOC'
server {
  listen 80;
  server_name localhost;

  root /usr/share/nginx/html;
  index index.html;

  location /assets/ {
    try_files $uri =404;
  }

  location / {
    try_files $uri $uri/ /index.html;
  }
}
DOC

echo "Atualizando frontend.Dockerfile para copiar configuracao Nginx..."

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

COPY infra/nginx/frontend.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/apps/frontend/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${NGINX_DIR}/frontend.conf" \
  "${DOCKER_DIR}/frontend.Dockerfile"
then
  echo "ERRO: HTML indevido encontrado."
  exit 1
fi

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_BUILD_LOG}"

echo "Subindo frontend e proxy..."

docker compose up -d frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

sleep 8

echo "Testando dominio raiz..."

DOMAIN_HOME_STATUS="$(curl -L -s -o "${DOMAIN_HOME_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_HOME_URL}" || true)"

if [ "${DOMAIN_HOME_STATUS}" != "200" ]; then
  echo "ERRO: dominio raiz nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando rota login SPA..."

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ]; then
  echo "ERRO: rota login nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "SaaS WhatsApp Meta" "${DOMAIN_LOGIN_LOG}"; then
  echo "ERRO: login nao contem titulo esperado."
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

echo "Testando rota dashboard SPA..."

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: rota dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "SaaS WhatsApp Meta" "${DOMAIN_DASHBOARD_LOG}"; then
  echo "ERRO: dashboard SPA nao retornou index esperado."
  cat "${DOMAIN_DASHBOARD_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 26..."

cat > "${DOC_FILE}" <<'DOC'
# Frontend Login Integrado

## Visao geral

Este documento registra a criacao da tela de login integrada ao backend real.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi adicionada configuracao Nginx especifica para SPA.

O frontend agora usa fallback para index.html quando uma rota do React e acessada diretamente.

## Funcionalidades criadas

Funcionalidades:

- tela de login real
- chamada para auth login
- armazenamento local de access token
- chamada para auth me
- dashboard protegido simples
- logout
- tela placeholder de conversas
- suporte a rotas SPA no Nginx do frontend

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/api.types.ts
- apps/frontend/src/types/auth.types.ts
- apps/frontend/src/services/api.ts
- apps/frontend/src/services/auth.service.ts
- apps/frontend/src/stores/auth.store.ts
- apps/frontend/src/pages/login/LoginPage.tsx
- apps/frontend/src/pages/dashboard/DashboardPage.tsx
- apps/frontend/src/pages/conversations/ConversationsPage.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/App.tsx
- apps/frontend/src/styles.css
- infra/nginx/frontend.conf
- infra/docker/frontend.Dockerfile
- docs/FRONTEND_LOGIN_INTEGRADO.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- teste do dominio raiz
- teste da rota login
- teste da rota dashboard

## Acesso

Dominio:

    bot lhsolucao com br

Rota de login:

    login

## Observacoes

A senha inicial nao foi documentada aqui.

A senha inicial fica no log local da Etapa 24.

## Proxima etapa sugerida

Etapa 27:

    Criar protecao visual de rotas e layout base do painel
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
- [ ] Etapa 27 - Protecao visual de rotas e layout base

## Ultima etapa executada

Etapa 26 - Frontend login integrado.

## Proxima etapa sugerida

Etapa 27 - Criar protecao visual de rotas e layout base do painel.
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

## Etapas concluidas

- Etapa 01 ate Etapa 26 concluidas

## Proxima etapa

- Etapa 27 - Protecao visual de rotas e layout base
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

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 26
Acao: Correcao Nginx SPA fallback
Data: $(date '+%Y-%m-%d %H:%M:%S')
Dominio raiz status: ${DOMAIN_HOME_STATUS}
Dominio login status: ${DOMAIN_LOGIN_STATUS}
Dominio dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

cat > "${LOG_FILE}" <<DOC
Etapa: 26
Acao: Frontend login integrado
Data: $(date '+%Y-%m-%d %H:%M:%S')
Dominio raiz status: ${DOMAIN_HOME_STATUS}
Dominio login status: ${DOMAIN_LOGIN_STATUS}
Dominio dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 26 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/login"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 27 - Criar protecao visual de rotas e layout base do painel"
