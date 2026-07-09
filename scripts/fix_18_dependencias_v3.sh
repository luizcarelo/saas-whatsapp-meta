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
FIX_LOG_FILE="${LOGS_DIR}/fix_18_v3.log"
DEPENDENCIAS_DOC="${DOCS_DIR}/DEPENDENCIAS_BASE.md"

echo "== Correcao Etapa 18 v3: corrigir moduleResolution do frontend =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/tsconfig.json" \
  "${FRONTEND_DIR}/tsconfig.node.json" \
  "${FRONTEND_DIR}/index.html" \
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

echo "Regravando apps/frontend/tsconfig.json..."

cat > "${FRONTEND_DIR}/tsconfig.json" <<'DOC'
{
  "compilerOptions": {
    "target": "ES2021",
    "useDefineForClassFields": true,
    "lib": [
      "ES2021",
      "DOM",
      "DOM.Iterable"
    ],
    "allowJs": false,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": [
    "src"
  ],
  "references": [
    {
      "path": "./tsconfig.node.json"
    }
  ]
}
DOC

echo "Regravando apps/frontend/tsconfig.node.json..."

cat > "${FRONTEND_DIR}/tsconfig.node.json" <<'DOC'
{
  "compilerOptions": {
    "composite": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": [
    "vite.config.ts"
  ]
}
DOC

echo "Corrigindo index.html do frontend..."

{
  printf '%s\n' '<!doctype html>'
  printf '%s\n' '<html lang="pt-BR">'
  printf '%s\n' '  <head>'
  printf '%s\n' '    <meta charset="UTF-8" />'
  printf '%s\n' '    <meta name="viewport" content="width=device-width, initial-scale=1.0" />'
  printf '%s\n' '    <title>SaaS WhatsApp Meta</title>'
  printf '%s\n' '  </head>'
  printf '%s\n' '  <body>'
  printf '%s\n' '    <div id="root"></div>'
  printf '    <%s type="module" src="/src/main.tsx"></%s>\n' "script" "script"
  printf '%s\n' '  </body>'
  printf '%s\n' '</html>'
} > "${FRONTEND_DIR}/index.html"

echo "Validando index.html..."

if grep -n "href=" "${FRONTEND_DIR}/index.html"; then
  echo "ERRO: HTML indevido encontrado no index.html."
  exit 1
fi

if ! grep -q 'src="/src/main.tsx"' "${FRONTEND_DIR}/index.html"; then
  echo "ERRO: script do Vite nao encontrado no index.html."
  exit 1
fi

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${LOGS_DIR}/setup_18_backend_typecheck.log"

echo "Sincronizando dependencias do frontend..."

cd "${FRONTEND_DIR}"
npm install 2>&1 | tee "${LOGS_DIR}/setup_18_frontend_npm_install.log"

echo "Rodando typecheck do frontend..."

npm run typecheck 2>&1 | tee "${LOGS_DIR}/setup_18_frontend_typecheck.log"

echo "Validando arquivos de dependencias..."

test -f "${BACKEND_DIR}/package-lock.json"
test -f "${FRONTEND_DIR}/package-lock.json"
test -d "${BACKEND_DIR}/node_modules"
test -d "${FRONTEND_DIR}/node_modules"
test -f "${FRONTEND_DIR}/src/vite-env.d.ts"

echo "Gerando docs/DEPENDENCIAS_BASE.md..."

cd "${BASE_DIR}"

cat > "${DEPENDENCIAS_DOC}" <<'DOC'
# Dependencias Base

## Visao geral

Este documento registra a instalacao e validacao das dependencias base do backend e do frontend.

## Resultado

Status:

    concluido

## Backend

Diretorio:

    apps/backend

Acoes executadas:

- npm install
- npm run typecheck

Arquivos gerados:

- apps/backend/package-lock.json
- apps/backend/node_modules

## Frontend

Diretorio:

    apps/frontend

Acoes executadas:

- npm install
- npm run typecheck

Arquivos gerados:

- apps/frontend/package-lock.json
- apps/frontend/node_modules
- apps/frontend/src/vite-env.d.ts

## Correcoes aplicadas

Correcoes:

- Removido baseUrl do tsconfig do backend
- Corrigido index.html do frontend
- Adicionado @types/node ao frontend
- Criado vite-env.d.ts
- Corrigido moduleResolution do frontend para Bundler

## Logs gerados

Logs:

- logs/setup_18_backend_npm_install.log
- logs/setup_18_backend_typecheck.log
- logs/setup_18_frontend_npm_install.log
- logs/setup_18_frontend_typecheck.log
- logs/fix_18_v2.log
- logs/fix_18_v3.log

## Observacoes

As dependencias foram instaladas localmente.

Os containers ainda nao foram construidos nesta etapa.

## Proxima etapa sugerida

Etapa 19:

    Ajustar Dockerfiles e validar build dos containers
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
- logs/fix_18_v2.log
- logs/fix_18_v3.log

## Etapas concluidas

- Etapa 01 ate Etapa 18 concluidas

## Proxima etapa

- Etapa 19 - Ajustar Dockerfiles e validar build dos containers
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

echo "Gravando logs..."

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 18
Acao: Correcao v3 moduleResolution frontend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Node: ${NODE_VERSION}
npm: ${NPM_VERSION}
Status: Concluido
DOC

cat > "${LOG_FILE}" <<DOC
Etapa: 18
Acao: Instalacao e validacao de dependencias
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Node: ${NODE_VERSION}
npm: ${NPM_VERSION}
Arquivos criados ou atualizados:
- apps/frontend/tsconfig.json
- apps/frontend/tsconfig.node.json
- apps/frontend/index.html
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
