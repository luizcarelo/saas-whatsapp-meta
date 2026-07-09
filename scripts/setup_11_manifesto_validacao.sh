#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_11.log"
VALIDATION_FILE="${DOCS_DIR}/VALIDACAO_FINAL.md"

echo "== Etapa 11: Manifesto final e validacao geral =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${VALIDATION_FILE}" ]; then
  cp "${VALIDATION_FILE}" "${BACKUPS_DIR}/VALIDACAO_FINAL_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Validando estrutura de pastas..."

test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando arquivos principais..."

test -f "${BASE_DIR}/README.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -f "${BASE_DIR}/00_CONTROLE.md"

echo "Validando documentos tecnicos..."

test -f "${DOCS_DIR}/ARQUITETURA.md"
test -f "${DOCS_DIR}/BANCO_DADOS.md"
test -f "${DOCS_DIR}/API.md"
test -f "${DOCS_DIR}/SEGURANCA.md"
test -f "${DOCS_DIR}/WEBHOOKS_META.md"
test -f "${DOCS_DIR}/FRONTEND.md"
test -f "${DOCS_DIR}/BACKEND.md"
test -f "${DOCS_DIR}/DEPLOY.md"

echo "Validando logs das etapas..."

test -f "${LOGS_DIR}/setup_01.log"
test -f "${LOGS_DIR}/setup_02.log"
test -f "${LOGS_DIR}/setup_03.log"
test -f "${LOGS_DIR}/setup_04.log"
test -f "${LOGS_DIR}/setup_05.log"
test -f "${LOGS_DIR}/setup_06.log"
test -f "${LOGS_DIR}/setup_07.log"
test -f "${LOGS_DIR}/setup_08.log"
test -f "${LOGS_DIR}/setup_09.log"
test -f "${LOGS_DIR}/setup_10.log"

echo "Validando conteudo minimo dos documentos..."

for file in \
  "${BASE_DIR}/README.md" \
  "${BASE_DIR}/MANIFESTO.md" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${DOCS_DIR}/ARQUITETURA.md" \
  "${DOCS_DIR}/BANCO_DADOS.md" \
  "${DOCS_DIR}/API.md" \
  "${DOCS_DIR}/SEGURANCA.md" \
  "${DOCS_DIR}/WEBHOOKS_META.md" \
  "${DOCS_DIR}/FRONTEND.md" \
  "${DOCS_DIR}/BACKEND.md" \
  "${DOCS_DIR}/DEPLOY.md"
do
  if [ ! -s "${file}" ]; then
    echo "ERRO: arquivo vazio ou inexistente: ${file}"
    exit 1
  fi
done

echo "Validando ausencia de caractere proibido nos documentos atuais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${BASE_DIR}/README.md" \
  "${BASE_DIR}/MANIFESTO.md" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${DOCS_DIR}/ARQUITETURA.md" \
  "${DOCS_DIR}/BANCO_DADOS.md" \
  "${DOCS_DIR}/API.md" \
  "${DOCS_DIR}/SEGURANCA.md" \
  "${DOCS_DIR}/WEBHOOKS_META.md" \
  "${DOCS_DIR}/FRONTEND.md" \
  "${DOCS_DIR}/BACKEND.md" \
  "${DOCS_DIR}/DEPLOY.md"
then
  echo "ERRO: caractere proibido encontrado nos documentos atuais."
  exit 1
fi

echo "Gerando docs/VALIDACAO_FINAL.md..."

cat > "${VALIDATION_FILE}" <<'DOC'
# Validacao Final da Documentacao

## Visao geral

Este documento registra a validacao final da documentacao inicial do projeto SaaS de Chatbot WhatsApp com API Oficial da Meta.

A documentacao foi criada em etapas pequenas, com backup, validacao, manifesto e controle por etapa.

## Resultado geral

Status:

    concluido

Resultado:

    documentacao inicial preparada

## Arquivos principais validados

Arquivos principais:

- README.md
- MANIFESTO.md
- 00_CONTROLE.md

## Documentos tecnicos validados

Documentos tecnicos:

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md
- docs/VALIDACAO_FINAL.md

## Pastas validadas

Pastas:

- docs
- scripts
- logs
- backups

## Etapas concluidas

Etapas:

- Etapa 01 - Preparacao do ambiente de documentacao
- Etapa 02 - Criacao do README principal
- Etapa 03 - Documentacao de arquitetura
- Etapa 04 - Documentacao do banco de dados
- Etapa 05 - Documentacao da API
- Etapa 06 - Documentacao de seguranca
- Etapa 07 - Documentacao de webhooks da Meta
- Etapa 08 - Documentacao do frontend
- Etapa 09 - Documentacao do backend
- Etapa 10 - Documentacao de deploy
- Etapa 11 - Manifesto final e validacao geral

## Stack oficial documentada

Frontend:

- React
- TypeScript
- Vite
- Tailwind CSS
- shadcn/ui
- React Router
- TanStack Query
- Zustand
- React Hook Form
- Zod
- Socket.IO Client

Backend:

- NestJS
- Fastify
- TypeScript
- PostgreSQL
- Redis
- BullMQ
- Socket.IO
- JWT
- RBAC

Infraestrutura:

- Docker
- Docker Compose
- Nginx ou Traefik
- PostgreSQL
- Redis

Canal principal:

- WhatsApp Business Platform
- Cloud API da Meta

## Decisoes tecnicas consolidadas

Decisoes:

- Arquitetura inicial em modular monolith
- Workers separados para tarefas assincronas
- PostgreSQL como banco principal
- Redis para filas, cache e estado temporario
- BullMQ para processamento assincrono
- Socket.IO para tempo real
- tenant_id como estrategia multi-tenant inicial
- JWT para autenticacao
- RBAC para autorizacao
- Tokens sensiveis criptografados
- Webhooks processados por fila
- Deploy inicial com Docker Compose

## Validacoes executadas

Validacoes:

- Pastas principais existem
- Arquivos principais existem
- Documentos tecnicos existem
- Logs das etapas existem
- Arquivos principais nao estao vazios
- Documentos tecnicos nao estao vazios
- Caractere proibido nao foi encontrado nos documentos atuais

## Observacoes

Esta validacao encerra a fase de documentacao inicial.

A proxima fase recomendada e criar a estrutura real do projeto, ainda em etapas pequenas, com scripts separados para:

- estrutura de pastas do monorepo
- arquivos base do backend
- arquivos base do frontend
- Docker Compose inicial
- env example
- validacao do ambiente
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Etapas

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

## Ultima etapa executada

Etapa 11 - Manifesto final e validacao geral.

## Status da documentacao inicial

Concluida.

## Proxima fase sugerida

Fase 02 - Criar estrutura real do projeto com backend, frontend, workers, Docker Compose e arquivos de ambiente.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto Final da Documentacao

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

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

## Logs esperados

- logs/setup_01.log
- logs/setup_02.log
- logs/setup_03.log
- logs/setup_04.log
- logs/setup_05.log
- logs/setup_06.log
- logs/setup_07.log
- logs/setup_08.log
- logs/setup_09.log
- logs/setup_10.log
- logs/setup_11.log

## Etapas concluidas

- Etapa 01 - Preparacao do ambiente de documentacao
- Etapa 02 - Criacao do README principal
- Etapa 03 - Documentacao de arquitetura
- Etapa 04 - Documentacao do banco de dados
- Etapa 05 - Documentacao da API
- Etapa 06 - Documentacao de seguranca
- Etapa 07 - Documentacao de webhooks da Meta
- Etapa 08 - Documentacao do frontend
- Etapa 09 - Documentacao do backend
- Etapa 10 - Documentacao de deploy
- Etapa 11 - Manifesto final e validacao geral

## Resultado

A documentacao inicial esta pronta para orientar a proxima fase do projeto.

## Proxima fase sugerida

Criar a estrutura real do projeto em etapas menores:

- Etapa 12 - Estrutura de pastas do monorepo
- Etapa 13 - Arquivos base do backend
- Etapa 14 - Arquivos base do frontend
- Etapa 15 - Docker Compose inicial
- Etapa 16 - Arquivo .env.example
- Etapa 17 - Validacao do ambiente inicial
DOC

echo "Validando arquivos finais..."

test -f "${VALIDATION_FILE}"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"

echo "Validando ausencia de caractere proibido nos arquivos finais gerados..."

if grep -n "${BAD_CHAR}" "${VALIDATION_FILE}" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 11
Acao: Manifesto final e validacao geral
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/VALIDACAO_FINAL.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/VALIDACAO_FINAL_${STAMP}.md quando existia
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 11 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo de docs/VALIDACAO_FINAL.md:"
sed -n '1,180p' "${VALIDATION_FILE}"
echo ""
echo "Documentacao inicial concluida."
echo "Proxima fase sugerida: criar a estrutura real do projeto."
