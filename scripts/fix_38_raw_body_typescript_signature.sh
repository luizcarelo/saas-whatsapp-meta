#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_38.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_38_raw_body_typescript_signature.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_38_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_38_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_38_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_38_backend_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_38_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_38_backend_crash.log"
LOCAL_SIGNED_POST_LOG="${LOGS_DIR}/setup_38_webhook_signed_post_local.log"
DOMAIN_SIGNED_POST_LOG="${LOGS_DIR}/setup_38_webhook_signed_post_domain.log"
LOCAL_BAD_SIGNATURE_LOG="${LOGS_DIR}/setup_38_webhook_bad_signature_local.log"
DOMAIN_BAD_SIGNATURE_LOG="${LOGS_DIR}/setup_38_webhook_bad_signature_domain.log"
LOCAL_VERIFY_LOG="${LOGS_DIR}/setup_38_webhook_verify_local.log"
DOMAIN_VERIFY_LOG="${LOGS_DIR}/setup_38_webhook_verify_domain.log"
CONTAINER_ENV_LOG="${LOGS_DIR}/setup_38_container_env.log"
DOC_FILE="${DOCS_DIR}/BACKEND_META_WEBHOOK_SIGNATURE.md"

LOCAL_WEBHOOK_URL="http://127.0.0.1:3300/api/v1/webhooks/meta"
DOMAIN_WEBHOOK_URL="https://bot.lhsolucao.com.br/api/v1/webhooks/meta"

echo "== Correcao Etapa 38: assinatura TypeScript do raw body =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/common/middleware"
mkdir -p "${BACKEND_DIR}/src/modules/webhooks"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/main.ts" \
  "${BACKEND_DIR}/src/common/middleware/raw-body.middleware.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.controller.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.service.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.types.ts" \
  "${BASE_DIR}/docker-compose.yml" \
  "${BASE_DIR}/.env" \
  "${BASE_DIR}/.env.example" \
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

echo "Garantindo variaveis no .env..."

if [ ! -f "${BASE_DIR}/.env" ]; then
  cp "${BASE_DIR}/.env.example" "${BASE_DIR}/.env"
fi

set_env_value() {
  key="$1"
  value="$2"
  file="$3"
  tmp_file="${file}.tmp.${STAMP}"

  awk -v k="${key}" -v v="${value}" '
    BEGIN { done = 0 }
    index($0, k "=") == 1 {
      print k "=" v
      done = 1
      next
    }
    {
      print
    }
    END {
      if (done == 0) {
        print k "=" v
      }
    }
  ' "${file}" > "${tmp_file}"

  mv "${tmp_file}" "${file}"
}

get_env_value() {
  key="$1"
  file="$2"

  grep "^${key}=" "${file}" | head -n 1 | cut -d '=' -f 2- || true
}

CURRENT_VERIFY_TOKEN="$(get_env_value "WHATSAPP_VERIFY_TOKEN" "${BASE_DIR}/.env")"

if [ -z "${CURRENT_VERIFY_TOKEN}" ] || [ "${CURRENT_VERIFY_TOKEN}" = "change_me_verify_token" ]; then
  VERIFY_TOKEN="$(node -e "console.log('verify_' + require('crypto').randomBytes(16).toString('hex'))")"
else
  VERIFY_TOKEN="${CURRENT_VERIFY_TOKEN}"
fi

CURRENT_APP_SECRET="$(get_env_value "META_APP_SECRET" "${BASE_DIR}/.env")"

if [ -z "${CURRENT_APP_SECRET}" ] || [ "${CURRENT_APP_SECRET}" = "change_me_meta_app_secret" ]; then
  META_APP_SECRET="$(node -e "console.log('meta_secret_' + require('crypto').randomBytes(18).toString('hex'))")"
else
  META_APP_SECRET="${CURRENT_APP_SECRET}"
fi

set_env_value "WHATSAPP_VERIFY_TOKEN" "change_me_verify_token" "${BASE_DIR}/.env.example"
set_env_value "META_APP_SECRET" "change_me_meta_app_secret" "${BASE_DIR}/.env.example"
set_env_value "META_WEBHOOK_SIGNATURE_REQUIRED" "false" "${BASE_DIR}/.env.example"

set_env_value "WHATSAPP_VERIFY_TOKEN" "${VERIFY_TOKEN}" "${BASE_DIR}/.env"
set_env_value "META_APP_SECRET" "${META_APP_SECRET}" "${BASE_DIR}/.env"
set_env_value "META_WEBHOOK_SIGNATURE_REQUIRED" "true" "${BASE_DIR}/.env"

echo "Garantindo env_file .env no backend do docker-compose.yml..."

python3 <<'PY'
from pathlib import Path

path = Path("docker-compose.yml")
text = path.read_text()
lines = text.splitlines()
out = []
inside_backend = False
backend_indent = None
block = []

def flush_backend(block_lines):
    if not block_lines:
        return []

    has_env_file = any(line.strip() == "env_file:" for line in block_lines)

    if has_env_file:
        return block_lines

    result = []

    for index, line in enumerate(block_lines):
        result.append(line)

        if index == 0 and line.strip() == "backend:":
            indent = line[:len(line) - len(line.lstrip())]
            child = indent + "  "
            result.append(child + "env_file:")
            result.append(child + "  - .env")

    return result

for line in lines:
    stripped = line.strip()

    if not inside_backend and stripped == "backend:":
        inside_backend = True
        backend_indent = len(line) - len(line.lstrip())
        block = [line]
        continue

    if inside_backend:
        current_indent = len(line) - len(line.lstrip())

        if stripped and current_indent == backend_indent and stripped.endswith(":"):
            out.extend(flush_backend(block))
            inside_backend = False
            backend_indent = None
            block = []
            out.append(line)
            continue

        block.append(line)
        continue

    out.append(line)

if inside_backend:
    out.extend(flush_backend(block))

path.write_text("\n".join(out) + "\n")
PY

echo "Recriando raw-body.middleware.ts com assinatura compativel com body-parser..."

cat > "${BACKEND_DIR}/src/common/middleware/raw-body.middleware.ts" <<'DOC'
import type { IncomingMessage, ServerResponse } from 'http';

export type RequestWithRawBody = IncomingMessage & {
  rawBody?: Buffer;
};

export function rawBodySaver(
  request: IncomingMessage,
  _response: ServerResponse,
  buffer: Buffer,
  _encoding: string
): void {
  const requestWithRawBody = request as RequestWithRawBody;

  if (buffer && buffer.length > 0) {
    requestWithRawBody.rawBody = Buffer.from(buffer);
  }
}
DOC

echo "Revalidando main.ts com body-parser..."

cat > "${BACKEND_DIR}/src/main.ts" <<'DOC'
import { json, urlencoded } from 'body-parser';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { rawBodySaver } from './common/middleware/raw-body.middleware';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bodyParser: false
  });

  app.use(
    json({
      limit: '10mb',
      verify: rawBodySaver
    })
  );

  app.use(
    urlencoded({
      extended: true,
      limit: '10mb',
      verify: rawBodySaver
    })
  );

  app.setGlobalPrefix('api/v1');

  const port = Number(process.env.APP_PORT || 3000);

  await app.listen(port, '0.0.0.0');
}

void bootstrap();
DOC

echo "Revalidando meta-webhooks.controller.ts..."

cat > "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Post,
  Query,
  Req
} from '@nestjs/common';
import type { RequestWithRawBody } from '../../common/middleware/raw-body.middleware';
import { MetaWebhooksService } from './meta-webhooks.service';
import type {
  MetaWebhookPayload,
  MetaWebhookQuery
} from './meta-webhooks.types';

@Controller('webhooks/meta')
export class MetaWebhooksController {
  constructor(private readonly metaWebhooksService: MetaWebhooksService) {}

  @Get()
  verifyWebhook(@Query() query: MetaWebhookQuery): string {
    const mode = query['hub.mode'];
    const token = query['hub.verify_token'];
    const challenge = query['hub.challenge'];
    const expectedToken = process.env.WHATSAPP_VERIFY_TOKEN || '';

    if (mode === 'subscribe' && token === expectedToken && challenge) {
      return challenge;
    }

    throw new ForbiddenException('Webhook verification failed');
  }

  @Post()
  receiveWebhook(
    @Body() body: MetaWebhookPayload,
    @Req() request: RequestWithRawBody,
    @Headers('x-hub-signature-256') signatureHeader?: string
  ) {
    return this.metaWebhooksService.receivePayload(
      body,
      request.rawBody || Buffer.from(''),
      signatureHeader
    );
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/common/middleware" \
  "${BACKEND_DIR}/src/modules/webhooks" \
  "${BACKEND_DIR}/src/main.ts"
then
  echo "ERRO: HTML indevido encontrado."
  exit 1
fi

echo "Validando docker compose config..."

docker compose config > "${LOGS_DIR}/fix_38_raw_body_typescript_signature_docker_compose_config.log"

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${TYPECHECK_LOG}"

echo "Rodando build do backend..."

npm run build 2>&1 | tee "${BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BUILD_LOG}"

echo "Subindo backend com recriacao forçada..."

docker compose up -d --force-recreate backend 2>&1 | tee "${DOCKER_UP_LOG}"

echo "Aguardando backend estabilizar..."

: > "${BACKEND_WAIT_LOG}"

BACKEND_READY="false"

for i in $(seq 1 30); do
  STATUS="$(docker inspect -f '{{.State.Status}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"
  RESTARTING="$(docker inspect -f '{{.State.Restarting}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"

  echo "tentativa=${i} status=${STATUS} restarting=${RESTARTING}" | tee -a "${BACKEND_WAIT_LOG}"

  if [ "${STATUS}" = "running" ] && [ "${RESTARTING}" = "false" ]; then
    if curl -s --max-time 5 "http://127.0.0.1:3300/api/v1/health" >/dev/null 2>&1; then
      BACKEND_READY="true"
      break
    fi
  fi

  sleep 3
done

if [ "${BACKEND_READY}" != "true" ]; then
  echo "ERRO: backend nao estabilizou."
  docker compose logs --tail=220 backend 2>&1 | tee "${BACKEND_CRASH_LOG}"
  exit 1
fi

echo "Backend estabilizado."

echo "Validando variaveis dentro do container..."

docker compose exec -T backend sh -lc 'if [ -n "$WHATSAPP_VERIFY_TOKEN" ] && [ -n "$META_APP_SECRET" ] && [ "$META_WEBHOOK_SIGNATURE_REQUIRED" = "true" ]; then echo "META_WEBHOOK_ENV_OK"; else echo "META_WEBHOOK_ENV_ERRO"; exit 1; fi' 2>&1 | tee "${CONTAINER_ENV_LOG}"

if ! grep -q "META_WEBHOOK_ENV_OK" "${CONTAINER_ENV_LOG}"; then
  echo "ERRO: variaveis de webhook nao estao corretas no container."
  exit 1
fi

echo "Testando GET verify local..."

VERIFY_CHALLENGE="challenge_38_signature_${STAMP}"

LOCAL_VERIFY_STATUS="$(curl -s -o "${LOCAL_VERIFY_LOG}" -w "%{http_code}" --max-time 20 \
  "${LOCAL_WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=${VERIFY_CHALLENGE}" || true)"

if [ "${LOCAL_VERIFY_STATUS}" != "200" ]; then
  echo "ERRO: verify local falhou. Status ${LOCAL_VERIFY_STATUS}"
  cat "${LOCAL_VERIFY_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q "${VERIFY_CHALLENGE}" "${LOCAL_VERIFY_LOG}"; then
  echo "ERRO: verify local nao retornou challenge."
  cat "${LOCAL_VERIFY_LOG}"
  exit 1
fi

echo "Testando GET verify dominio..."

DOMAIN_VERIFY_STATUS="$(curl -L -s -o "${DOMAIN_VERIFY_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=${VERIFY_CHALLENGE}" || true)"

if [ "${DOMAIN_VERIFY_STATUS}" != "200" ]; then
  echo "ERRO: verify dominio falhou. Status ${DOMAIN_VERIFY_STATUS}"
  cat "${DOMAIN_VERIFY_LOG}"
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "${VERIFY_CHALLENGE}" "${DOMAIN_VERIFY_LOG}"; then
  echo "ERRO: verify dominio nao retornou challenge."
  cat "${DOMAIN_VERIFY_LOG}"
  exit 1
fi

echo "Criando payload assinado..."

WEBHOOK_PAYLOAD_FILE="${LOGS_DIR}/setup_38_webhook_payload.json"

cat > "${WEBHOOK_PAYLOAD_FILE}" <<DOC
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "waba_signature_38_signature",
      "changes": [
        {
          "field": "messages",
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "5521999993838",
              "phone_number_id": "phone_signature_38_signature_${STAMP}"
            },
            "contacts": [
              {
                "wa_id": "552188883838",
                "profile": {
                  "name": "Contato Assinatura Etapa 38"
                }
              }
            ],
            "messages": [
              {
                "from": "552188883838",
                "id": "wamid.signature.typescript.etapa38.${STAMP}",
                "timestamp": "1760000000",
                "type": "text",
                "text": {
                  "body": "Mensagem assinada etapa 38 typescript"
                }
              }
            ]
          }
        }
      ]
    }
  ]
}
DOC

SIGNATURE="$(node -e "const fs=require('fs'); const crypto=require('crypto'); const secret=process.argv[1]; const file=process.argv[2]; const body=fs.readFileSync(file); console.log('sha256=' + crypto.createHmac('sha256', secret).update(body).digest('hex'));" "${META_APP_SECRET}" "${WEBHOOK_PAYLOAD_FILE}")"

echo "Testando POST assinado local..."

LOCAL_SIGNED_POST_STATUS="$(curl -s -o "${LOCAL_SIGNED_POST_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: ${SIGNATURE}" \
  --data-binary "@${WEBHOOK_PAYLOAD_FILE}" \
  "${LOCAL_WEBHOOK_URL}" || true)"

if [ "${LOCAL_SIGNED_POST_STATUS}" != "200" ] && [ "${LOCAL_SIGNED_POST_STATUS}" != "201" ]; then
  echo "ERRO: POST assinado local falhou. Status ${LOCAL_SIGNED_POST_STATUS}"
  cat "${LOCAL_SIGNED_POST_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q '"valid":true' "${LOCAL_SIGNED_POST_LOG}"; then
  echo "ERRO: POST assinado local nao retornou assinatura valida."
  cat "${LOCAL_SIGNED_POST_LOG}"
  exit 1
fi

echo "Testando POST assinado dominio..."

DOMAIN_SIGNED_POST_STATUS="$(curl -L -s -o "${DOMAIN_SIGNED_POST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: ${SIGNATURE}" \
  --data-binary "@${WEBHOOK_PAYLOAD_FILE}" \
  "${DOMAIN_WEBHOOK_URL}" || true)"

if [ "${DOMAIN_SIGNED_POST_STATUS}" != "200" ] && [ "${DOMAIN_SIGNED_POST_STATUS}" != "201" ]; then
  echo "ERRO: POST assinado dominio falhou. Status ${DOMAIN_SIGNED_POST_STATUS}"
  cat "${DOMAIN_SIGNED_POST_LOG}"
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q '"valid":true' "${DOMAIN_SIGNED_POST_LOG}"; then
  echo "ERRO: POST assinado dominio nao retornou assinatura valida."
  cat "${DOMAIN_SIGNED_POST_LOG}"
  exit 1
fi

echo "Testando assinatura invalida local..."

BAD_SIGNATURE="sha256=0000000000000000000000000000000000000000000000000000000000000000"

LOCAL_BAD_SIGNATURE_STATUS="$(curl -s -o "${LOCAL_BAD_SIGNATURE_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: ${BAD_SIGNATURE}" \
  --data-binary "@${WEBHOOK_PAYLOAD_FILE}" \
  "${LOCAL_WEBHOOK_URL}" || true)"

if [ "${LOCAL_BAD_SIGNATURE_STATUS}" != "401" ]; then
  echo "ERRO: assinatura invalida local deveria retornar 401. Status ${LOCAL_BAD_SIGNATURE_STATUS}"
  cat "${LOCAL_BAD_SIGNATURE_LOG}"
  exit 1
fi

echo "Testando assinatura invalida dominio..."

DOMAIN_BAD_SIGNATURE_STATUS="$(curl -L -s -o "${DOMAIN_BAD_SIGNATURE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: ${BAD_SIGNATURE}" \
  --data-binary "@${WEBHOOK_PAYLOAD_FILE}" \
  "${DOMAIN_WEBHOOK_URL}" || true)"

if [ "${DOMAIN_BAD_SIGNATURE_STATUS}" != "401" ]; then
  echo "ERRO: assinatura invalida dominio deveria retornar 401. Status ${DOMAIN_BAD_SIGNATURE_STATUS}"
  cat "${DOMAIN_BAD_SIGNATURE_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 38..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Meta Webhook Signature

## Visao geral

Este documento registra a criacao da validacao de assinatura dos webhooks da Meta.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi corrigida a assinatura TypeScript do rawBodySaver para ser compativel com body-parser.

A captura de raw body usa IncomingMessage e ServerResponse.

## Assinatura validada

Cabecalho:

    X-Hub-Signature-256

Algoritmo:

    HMAC SHA256

Prefixo:

    sha256=

## Funcionalidades

Funcionalidades:

- captura do corpo bruto da requisicao
- validacao HMAC SHA256 com META_APP_SECRET
- comparacao segura da assinatura
- rejeicao de assinatura ausente ou invalida
- suporte a assinatura obrigatoria por META_WEBHOOK_SIGNATURE_REQUIRED
- preservacao da verificacao GET com hub challenge

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/main.ts
- apps/backend/src/common/middleware/raw-body.middleware.ts
- apps/backend/src/modules/webhooks/meta-webhooks.controller.ts
- apps/backend/src/modules/webhooks/meta-webhooks.service.ts
- apps/backend/src/modules/webhooks/meta-webhooks.types.ts
- docker-compose.yml
- .env
- .env.example
- docs/BACKEND_META_WEBHOOK_SIGNATURE.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- docker compose config
- variaveis no container backend
- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend com recriacao
- aguardo ativo do backend
- GET verify local
- GET verify dominio
- POST assinado local
- POST assinado dominio
- POST com assinatura invalida local retornando 401
- POST com assinatura invalida dominio retornando 401

## Logs gerados

Logs:

- logs/setup_38_backend_typecheck.log
- logs/setup_38_backend_build.log
- logs/setup_38_backend_docker_build.log
- logs/setup_38_backend_docker_up.log
- logs/setup_38_backend_wait.log
- logs/setup_38_container_env.log
- logs/setup_38_webhook_verify_local.log
- logs/setup_38_webhook_verify_domain.log
- logs/setup_38_webhook_signed_post_local.log
- logs/setup_38_webhook_signed_post_domain.log
- logs/setup_38_webhook_bad_signature_local.log
- logs/setup_38_webhook_bad_signature_domain.log
- logs/fix_38_raw_body_typescript_signature.log
- logs/setup_38.log

## Configuracao

Variaveis:

- META_APP_SECRET
- META_WEBHOOK_SIGNATURE_REQUIRED

## Proxima etapa sugerida

Etapa 39:

    Criar processamento de status de mensagens da Meta no frontend
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
- [x] Etapa 27 - Protecao visual de rotas e layout base

## Fase 06 - Usuarios e perfil

- [x] Etapa 28 - Modulo backend de usuarios
- [x] Etapa 29 - Frontend com perfil detalhado

## Fase 07 - Contatos

- [x] Etapa 30 - Modulo backend de contatos
- [x] Etapa 31 - Frontend de contatos integrado

## Fase 08 - Conversas

- [x] Etapa 32 - Frontend de conversas com layout inicial
- [x] Etapa 33 - Modulo backend de conversas
- [x] Etapa 34 - Frontend de conversas integrado ao backend

## Fase 09 - WhatsApp

- [x] Etapa 35 - Modulo backend de WhatsApp Accounts
- [x] Etapa 36 - Frontend de WhatsApp Accounts integrado
- [x] Etapa 37 - Modulo backend de webhooks da Meta
- [x] Etapa 38 - Validacao de assinatura dos webhooks da Meta
- [ ] Etapa 39 - Processamento de status no frontend

## Ultima etapa executada

Etapa 38 - Validacao de assinatura dos webhooks da Meta.

## Proxima etapa sugerida

Etapa 39 - Criar processamento de status de mensagens da Meta no frontend.
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

Layout base e protecao visual de rotas criados.

Modulo backend de usuarios criado.

Frontend com perfil detalhado criado.

Modulo backend de contatos criado.

Frontend de contatos integrado criado.

Frontend de conversas com layout inicial criado.

Modulo backend de conversas criado.

Frontend de conversas integrado ao backend criado.

Modulo backend de WhatsApp Accounts criado.

Frontend de WhatsApp Accounts integrado criado.

Modulo backend de webhooks da Meta criado.

Validacao de assinatura dos webhooks da Meta criada.

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
- docs/FRONTEND_LAYOUT_PROTECAO_ROTAS.md
- docs/BACKEND_USERS_PROFILE.md
- docs/FRONTEND_PROFILE_DETALHADO.md
- docs/BACKEND_CONTACTS.md
- docs/FRONTEND_CONTACTS.md
- docs/FRONTEND_CONVERSATIONS_LAYOUT.md
- docs/BACKEND_CONVERSATIONS.md
- docs/FRONTEND_CONVERSATIONS_INTEGRADO.md
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- docs/FRONTEND_WHATSAPP_ACCOUNTS.md
- docs/BACKEND_META_WEBHOOKS.md
- docs/BACKEND_META_WEBHOOK_SIGNATURE.md

## Etapas concluidas

- Etapa 01 ate Etapa 38 concluidas

## Proxima etapa

- Etapa 39 - Processamento de status no frontend
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
Etapa: 38
Acao: Correcao assinatura TypeScript rawBodySaver
Data: $(date '+%Y-%m-%d %H:%M:%S')
Verify local status: ${LOCAL_VERIFY_STATUS}
Verify dominio status: ${DOMAIN_VERIFY_STATUS}
Signed post local status: ${LOCAL_SIGNED_POST_STATUS}
Signed post dominio status: ${DOMAIN_SIGNED_POST_STATUS}
Bad signature local status: ${LOCAL_BAD_SIGNATURE_STATUS}
Bad signature dominio status: ${DOMAIN_BAD_SIGNATURE_STATUS}
Status: Concluido
DOC

cat > "${LOG_FILE}" <<DOC
Etapa: 38
Acao: Validacao de assinatura dos webhooks da Meta
Data: $(date '+%Y-%m-%d %H:%M:%S')
Verify local status: ${LOCAL_VERIFY_STATUS}
Verify dominio status: ${DOMAIN_VERIFY_STATUS}
Signed post local status: ${LOCAL_SIGNED_POST_STATUS}
Signed post dominio status: ${DOMAIN_SIGNED_POST_STATUS}
Bad signature local status: ${LOCAL_BAD_SIGNATURE_STATUS}
Bad signature dominio status: ${DOMAIN_BAD_SIGNATURE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 38 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 39 - Criar processamento de status de mensagens da Meta no frontend"
