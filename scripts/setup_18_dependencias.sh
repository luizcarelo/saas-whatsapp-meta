#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_18.log"
DEPENDENCIAS_DOC="${DOCS_DIR}/DEPENDENCIAS_BASE.md"

echo "== Etapa 18: Instalacao e validacao de dependencias =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/index.html" \
  "${FRONTEND_DIR}/src/vite-env.d.ts" \
  "${BACKEND_DIR}/package-lock.json" \
  "${FRONTEND_DIR}/package-lock.json" \
  "${DEPENDENCIAS_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando Node e npm..."

if ! command -v node >/dev/null 2>&1; then
  echo "ERRO: node nao encontrado."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERRO: npm nao encontrado."
  exit 1
fi

NODE_VERSION="$(node -v)"
NPM_VERSION="$(npm -v)"

echo "Node encontrado: ${NODE_VERSION}"
echo "npm encontrado: ${NPM_VERSION}"

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

echo "Criando apps/frontend/src/vite-env.d.ts..."

cat > "${FRONTEND_DIR}/src/vite-env.d.ts" <<'DOC'
/// <reference types="vite/client" />
DOC

echo "Validando HTML indevido..."

if grep -n "<a href" "${FRONTEND_DIR}/index.html"; then
  echo "ERRO: HTML indevido encontrado no index.html."
  exit 1
fi

echo "Instalando dependencias do backend..."

cd "${BACKEND_DIR}"
npm install 2>&1 | tee "${LOGS_DIR}/setup_18_backend_npm_install.log"

echo "Rodando typecheck do backend..."

npm run typecheck 2>&1 | tee "${LOGS_DIR}/setup_18_backend_typecheck.log"

echo "Instalando dependencias do frontend..."

cd "${FRONTEND_DIR}"
npm install 2>&1 | tee "${LOGS_DIR}/setup_18_frontend_npm_install.log"

echo "Rodando typecheck do frontend..."

npm run typecheck 2>&1 | tee "${LOGS_DIR}/setup_18_frontend_typecheck.log"

echo "Validando arquivos gerados..."

test -f "${BACKEND_DIR}/package-lock.json"
test -f "${FRONTEND_DIR}/package-lock.json"
test -d "${BACKEND_DIR}/node_modules"
test -d "${FRONTEND_DIR}/node_modules"
test -f "${FRONTEND_DIR}/src/vite-env.d.ts"

echo "Gerando docs/DEPENDENCIAS_BASE.md..."

cd "${BASE_DIR}"

cat > "${DEPENDENCIAS_DOC}" < "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
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

## Proxima fase sugerida

Fase 03 - Build e execucao inicial com Docker.

## Ultima etapa executada

Etapa 18 - Instalacao e validacao de dependencias.

## Proxima etapa sugerida

Etapa 19 - Ajustar Dockerfiles e validar build dos containers.
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
- docs/DEPENDENCIAS_BASE.md

## Dependencias

Arquivos gerados:

- apps/backend/package-lock.json
- apps/frontend/package-lock.json

Logs gerados:

- logs/setup_18_backend_npm_install.log
- logs/setup_18_backend_typecheck.log
- logs/setup_18_frontend_npm_install.log
- logs/setup_18_frontend_typecheck.log

## Etapas concluidas

- Etapa 01 ate Etapa 18 concluidas

## Proxima etapa

- Etapa 19 - Ajustar Dockerfiles e validar build dos containers

## Arquivos atualizados na Etapa 18

- apps/frontend/index.html
- apps/frontend/src/vite-env.d.ts
- apps/backend/package-lock.json
- apps/frontend/package-lock.json
- docs/DEPENDENCIAS_BASE.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_18.log
DOC

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DEPENDENCIAS_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 18
Acao: Instalacao e validacao de dependencias
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Node: ${NODE_VERSION}
npm: ${NPM_VERSION}
Arquivos criados ou atualizados:
- apps/frontend/index.html
- apps/frontend/src/vite-env.d.ts
- apps/backend/package-lock.json
- apps/frontend/package-lock.json
- docs/DEPENDENCIAS_BASE.md
- 00_CONTROLE.md
- MANIFESTO.md
Status: Concluido
DOC

echo ""
echo "== Etapa 18 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DEPENDENCIAS_DOC}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 19 - Ajustar Dockerfiles e validar build dos containers"
