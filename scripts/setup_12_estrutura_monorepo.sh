#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_12.log"
STRUCTURE_DOC="${DOCS_DIR}/ESTRUTURA_PROJETO.md"

echo "== Etapa 12: Estrutura real do monorepo =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${STRUCTURE_DOC}" ]; then
  cp "${STRUCTURE_DOC}" "${BACKUPS_DIR}/ESTRUTURA_PROJETO_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Criando estrutura de pastas..."

mkdir -p "${BASE_DIR}/apps/backend/src"
mkdir -p "${BASE_DIR}/apps/backend/test"
mkdir -p "${BASE_DIR}/apps/frontend/src"
mkdir -p "${BASE_DIR}/apps/frontend/public"
mkdir -p "${BASE_DIR}/apps/worker/src"
mkdir -p "${BASE_DIR}/apps/worker/test"

mkdir -p "${BASE_DIR}/packages/shared/src"
mkdir -p "${BASE_DIR}/packages/types/src"
mkdir -p "${BASE_DIR}/packages/config/src"

mkdir -p "${BASE_DIR}/infra/docker"
mkdir -p "${BASE_DIR}/infra/nginx"
mkdir -p "${BASE_DIR}/infra/postgres/init"
mkdir -p "${BASE_DIR}/infra/redis"
mkdir -p "${BASE_DIR}/infra/scripts"

echo "Criando marcadores .gitkeep..."

for dir in \
  "${BASE_DIR}/apps/backend/src" \
  "${BASE_DIR}/apps/backend/test" \
  "${BASE_DIR}/apps/frontend/src" \
  "${BASE_DIR}/apps/frontend/public" \
  "${BASE_DIR}/apps/worker/src" \
  "${BASE_DIR}/apps/worker/test" \
  "${BASE_DIR}/packages/shared/src" \
  "${BASE_DIR}/packages/types/src" \
  "${BASE_DIR}/packages/config/src" \
  "${BASE_DIR}/infra/docker" \
  "${BASE_DIR}/infra/nginx" \
  "${BASE_DIR}/infra/postgres/init" \
  "${BASE_DIR}/infra/redis" \
  "${BASE_DIR}/infra/scripts"
do
  touch "${dir}/.gitkeep"
done

echo "Gerando docs/ESTRUTURA_PROJETO.md..."

cat > "${STRUCTURE_DOC}" <<'DOC'
# Estrutura Real do Projeto

## Visao geral

Este documento registra a estrutura inicial real do monorepo do SaaS de Chatbot WhatsApp com API Oficial da Meta.

A estrutura foi criada para separar frontend, backend, worker, pacotes compartilhados e infraestrutura.

## Objetivo

A Etapa 12 prepara o projeto para receber codigo real nas proximas etapas.

Nesta etapa nao foi implementada regra de negocio.

Foram criadas apenas pastas, marcadores e documentacao da estrutura.

## Estrutura criada

Estrutura principal:

    apps
    packages
    infra
    docs
    scripts
    logs
    backups

## Apps

A pasta apps concentra as aplicacoes principais.

## apps/backend

Responsavel pela API principal.

Conteudo inicial:

    apps/backend/src
    apps/backend/test

Responsabilidades futuras:

- API REST
- Autenticacao
- Tenants
- Usuarios
- Permissoes
- Webhooks
- WhatsApp
- Contatos
- Conversas
- Mensagens
- Socket.IO
- Filas

## apps/frontend

Responsavel pelo painel web.

Conteudo inicial:

    apps/frontend/src
    apps/frontend/public

Responsabilidades futuras:

- React
- TypeScript
- Vite
- Login
- Dashboard
- Chat
- Contatos
- Usuarios
- Configuracoes
- Relatorios

## apps/worker

Responsavel por processos assincronos.

Conteudo inicial:

    apps/worker/src
    apps/worker/test

Responsabilidades futuras:

- Processar webhooks
- Enviar mensagens
- Atualizar status
- Executar chatbot
- Processar notificacoes
- Reprocessar falhas

## Packages

A pasta packages concentra codigo compartilhado.

## packages/shared

Responsavel por utilitarios compartilhados.

Uso futuro:

- constantes
- helpers
- validacoes comuns
- funcoes compartilhadas

## packages/types

Responsavel por tipos compartilhados.

Uso futuro:

- tipos de API
- tipos de mensagens
- tipos de tenant
- tipos de usuario
- contratos comuns

## packages/config

Responsavel por configuracoes compartilhadas.

Uso futuro:

- nomes de filas
- constantes de ambiente
- mapas de status
- configuracoes comuns

## Infra

A pasta infra concentra arquivos de infraestrutura.

## infra/docker

Uso futuro:

- Dockerfile do backend
- Dockerfile do frontend
- Dockerfile do worker

## infra/nginx

Uso futuro:

- configuracao do proxy reverso
- configuracao de rotas
- headers basicos
- SSL em producao quando aplicavel

## infra/postgres

Uso futuro:

- scripts de inicializacao
- configuracoes auxiliares
- scripts de banco quando necessario

## infra/redis

Uso futuro:

- configuracoes auxiliares do Redis

## infra/scripts

Uso futuro:

- backup do PostgreSQL
- restore do PostgreSQL
- validacoes de deploy
- scripts auxiliares

## Marcadores

Foram criados arquivos .gitkeep nas pastas vazias.

O objetivo e permitir que a estrutura seja preservada quando o projeto for versionado.

## Proximas etapas sugeridas

Etapa 13:

    Criar arquivos base do backend

Etapa 14:

    Criar arquivos base do frontend

Etapa 15:

    Criar Docker Compose inicial

Etapa 16:

    Criar arquivo .env.example

Etapa 17:

    Validar ambiente inicial

## Decisao final desta etapa

A estrutura real inicial do projeto foi criada como monorepo, separando:

- apps
- packages
- infra
- docs
- scripts
- logs
- backups
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
- [ ] Etapa 13 - Arquivos base do backend
- [ ] Etapa 14 - Arquivos base do frontend
- [ ] Etapa 15 - Docker Compose inicial
- [ ] Etapa 16 - Arquivo env example
- [ ] Etapa 17 - Validacao do ambiente inicial

## Ultima etapa executada

Etapa 12 - Estrutura de pastas do monorepo.

## Proxima etapa sugerida

Etapa 13 - Criar arquivos base do backend.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto do Projeto

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

Estrutura real do monorepo iniciada.

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

## Pastas de apoio

- scripts/
- logs/
- backups/

## Scripts executados

- scripts/setup_01_prepare_docs_env.sh
- scripts/setup_02_readme.sh
- scripts/setup_03_arquitetura.sh
- scripts/setup_04_banco_dados.sh
- scripts/setup_05_api.sh
- scripts/setup_06_seguranca.sh
- scripts/setup_07_webhooks_meta.sh
- scripts/setup_08_frontend.sh
- scripts/setup_09_backend.sh
- scripts/setup_10_deploy.sh
- scripts/setup_11_manifesto_validacao.sh
- scripts/setup_12_estrutura_monorepo.sh

## Proxima etapa

- Etapa 13 - Arquivos base do backend

## Arquivos atualizados na Etapa 12

- docs/ESTRUTURA_PROJETO.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_12.log
DOC

echo "Validando estrutura criada..."

test -d "${BASE_DIR}/apps/backend/src"
test -d "${BASE_DIR}/apps/backend/test"
test -d "${BASE_DIR}/apps/frontend/src"
test -d "${BASE_DIR}/apps/frontend/public"
test -d "${BASE_DIR}/apps/worker/src"
test -d "${BASE_DIR}/apps/worker/test"

test -d "${BASE_DIR}/packages/shared/src"
test -d "${BASE_DIR}/packages/types/src"
test -d "${BASE_DIR}/packages/config/src"

test -d "${BASE_DIR}/infra/docker"
test -d "${BASE_DIR}/infra/nginx"
test -d "${BASE_DIR}/infra/postgres/init"
test -d "${BASE_DIR}/infra/redis"
test -d "${BASE_DIR}/infra/scripts"

echo "Validando arquivos gerados..."

test -f "${STRUCTURE_DOC}"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${STRUCTURE_DOC}" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 12
Acao: Estrutura de pastas do monorepo
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/ESTRUTURA_PROJETO.md
- 00_CONTROLE.md
- MANIFESTO.md
Pastas criadas:
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
Backups:
- backups/ESTRUTURA_PROJETO_${STAMP}.md quando existia
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 12 concluida com sucesso =="
echo ""
echo "Estrutura criada:"
find "${BASE_DIR}" -maxdepth 3 -type d | sort
echo ""
echo "Resumo de docs/ESTRUTURA_PROJETO.md:"
sed -n '1,180p' "${STRUCTURE_DOC}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 13 - Criar arquivos base do backend"
