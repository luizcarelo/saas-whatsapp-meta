#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_37.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_37_webhook_verify_token_container.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_37_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_37_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_37_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_37_backend_docker_up.log"
LOCAL_VERIFY_LOG="${LOGS_DIR}/setup_37_webhook_verify_local.log"
DOMAIN_VERIFY_LOG="${LOGS_DIR}/setup_37_webhook_verify_domain.log"
LOCAL_POST_LOG="${LOGS_DIR}/setup_37_webhook_post_local.log"
DOMAIN_POST_LOG="${LOGS_DIR}/setup_37_webhook_post_domain.log"
LOCAL_EVENTS_LOG="${LOGS_DIR}/setup_37_webhook_events_local.log"
CONTAINER_ENV_LOG="${LOGS_DIR}/setup_37_container_env.log"
DOC_FILE="${DOCS_DIR}/BACKEND_META_WEBHOOKS.md"

LOCAL_WEBHOOK_URL="http://127.0.0.1:3300/api/v1/webhooks/meta"
DOMAIN_WEBHOOK_URL="https://bot.lhsolucao.com.br/api/v1/webhooks/meta"

echo "== Correcao Etapa 37: WHATSAPP_VERIFY_TOKEN no container backend =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${BASE_DIR}/docker-compose.yml" \
  "${BASE_DIR}/.env" \
  "${BASE_DIR}/.env.example" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.controller.ts" \
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

echo "Garantindo WHATSAPP_VERIFY_TOKEN no .env..."

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

set_env_value "WHATSAPP_VERIFY_TOKEN" "change_me_verify_token" "${BASE_DIR}/.env.example"
set_env_value "WHATSAPP_VERIFY_TOKEN" "${VERIFY_TOKEN}" "${BASE_DIR}/.env"

echo "Garantindo env_file .env no servico backend do docker-compose.yml..."

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

    has_env_file = False
    for line in block_lines:
        if line.strip() == "env_file:":
            has_env_file = True
            break

    if has_env_file:
        return block_lines

    result = []
    inserted = False

    for index, line in enumerate(block_lines):
        result.append(line)
        if index == 0 and line.strip().endswith("backend:"):
            indent = line[:len(line) - len(line.lstrip())]
            child = indent + "  "
            result.append(child + "env_file:")
            result.append(child + "  - .env")
            inserted = True

    if not inserted:
        return block_lines

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

new_text = "\n".join(out) + "\n"
path.write_text(new_text)
PY

echo "Validando docker compose config..."

docker compose config > "${LOGS_DIR}/fix_37_docker_compose_config.log"

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

sleep 10

echo "Validando WHATSAPP_VERIFY_TOKEN dentro do container..."

docker compose exec -T backend sh -lc 'if [ -n "$WHATSAPP_VERIFY_TOKEN" ]; then echo "WHATSAPP_VERIFY_TOKEN_PRESENTE"; else echo "WHATSAPP_VERIFY_TOKEN_AUSENTE"; exit 1; fi' 2>&1 | tee "${CONTAINER_ENV_LOG}"

if ! grep -q "WHATSAPP_VERIFY_TOKEN_PRESENTE" "${CONTAINER_ENV_LOG}"; then
  echo "ERRO: WHATSAPP_VERIFY_TOKEN nao esta presente no container backend."
  docker compose config
  exit 1
fi

echo "Testando verificacao local..."

VERIFY_CHALLENGE="challenge_${STAMP}"

LOCAL_VERIFY_STATUS="$(curl -s -o "${LOCAL_VERIFY_LOG}" -w "%{http_code}" --max-time 20 \
  "${LOCAL_WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=${VERIFY_CHALLENGE}" || true)"

if [ "${LOCAL_VERIFY_STATUS}" != "200" ]; then
  echo "ERRO: verificacao local falhou. Status ${LOCAL_VERIFY_STATUS}"
  cat "${LOCAL_VERIFY_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q "${VERIFY_CHALLENGE}" "${LOCAL_VERIFY_LOG}"; then
  echo "ERRO: verificacao local nao retornou challenge."
  cat "${LOCAL_VERIFY_LOG}"
  exit 1
fi

echo "Testando verificacao dominio..."

DOMAIN_VERIFY_STATUS="$(curl -L -s -o "${DOMAIN_VERIFY_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=${VERIFY_CHALLENGE}" || true)"

if [ "${DOMAIN_VERIFY_STATUS}" != "200" ]; then
  echo "ERRO: verificacao dominio falhou. Status ${DOMAIN_VERIFY_STATUS}"
  cat "${DOMAIN_VERIFY_LOG}"
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "${VERIFY_CHALLENGE}" "${DOMAIN_VERIFY_LOG}"; then
  echo "ERRO: verificacao dominio nao retornou challenge."
  cat "${DOMAIN_VERIFY_LOG}"
  exit 1
fi

echo "Criando payload de webhook..."

WEBHOOK_PAYLOAD_FILE="${LOGS_DIR}/setup_37_webhook_payload.json"

cat > "${WEBHOOK_PAYLOAD_FILE}" <<DOC
{
  "object": "whatsapp_business_account",
  "entry": [
    {
      "id": "waba_fix_37",
      "changes": [
        {
          "field": "messages",
          "value": {
            "messaging_product": "whatsapp",
            "metadata": {
              "display_phone_number": "5521999993737",
              "phone_number_id": "phone_webhook_fix_37_${STAMP}"
            },
            "contacts": [
              {
                "wa_id": "552188887777",
                "profile": {
                  "name": "Contato Webhook Fix Etapa 37"
                }
              }
            ],
            "messages": [
              {
                "from": "552188887777",
                "id": "wamid.fix.etapa37.${STAMP}",
                "timestamp": "1760000000",
                "type": "text",
                "text": {
                  "body": "Mensagem recebida via webhook fix etapa 37"
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

echo "Testando POST local..."

LOCAL_POST_STATUS="$(curl -s -o "${LOCAL_POST_LOG}" -w "%{http_code}" --max-time 20 \
  -H "Content-Type: application/json" \
  --data-binary "@${WEBHOOK_PAYLOAD_FILE}" \
  "${LOCAL_WEBHOOK_URL}" || true)"

if [ "${LOCAL_POST_STATUS}" != "200" ] && [ "${LOCAL_POST_STATUS}" != "201" ]; then
  echo "ERRO: POST local falhou. Status ${LOCAL_POST_STATUS}"
  cat "${LOCAL_POST_LOG}"
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q "received" "${LOCAL_POST_LOG}"; then
  echo "ERRO: POST local nao retornou received."
  cat "${LOCAL_POST_LOG}"
  exit 1
fi

echo "Testando POST dominio..."

DOMAIN_POST_STATUS="$(curl -L -s -o "${DOMAIN_POST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  --data-binary "@${WEBHOOK_PAYLOAD_FILE}" \
  "${DOMAIN_WEBHOOK_URL}" || true)"

if [ "${DOMAIN_POST_STATUS}" != "200" ] && [ "${DOMAIN_POST_STATUS}" != "201" ]; then
  echo "ERRO: POST dominio falhou. Status ${DOMAIN_POST_STATUS}"
  cat "${DOMAIN_POST_LOG}"
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "received" "${DOMAIN_POST_LOG}"; then
  echo "ERRO: POST dominio nao retornou received."
  cat "${DOMAIN_POST_LOG}"
  exit 1
fi

echo "Validando eventos gravados..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as webhook_events from webhook_events;" 2>&1 | tee "${LOCAL_EVENTS_LOG}"
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as webhook_messages from messages where provider_message_id like 'wamid.fix.etapa37.%';" 2>&1 | tee -a "${LOCAL_EVENTS_LOG}"

echo "Gerando documentacao da Etapa 37..."

cat > "${DOC_FILE}" <<'DOC'
# Backend Meta Webhooks

## Visao geral

Este documento registra a criacao do modulo backend de webhooks da Meta.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi garantido que WHATSAPP_VERIFY_TOKEN seja carregado dentro do container backend via docker-compose.yml.

## Endpoints criados

Endpoints:

- GET api v1 webhooks meta
- POST api v1 webhooks meta

## Funcionalidades

Funcionalidades:

- verificacao do webhook usando hub mode
- validacao do verify token
- retorno do hub challenge
- recebimento de payload POST
- gravacao de webhook events
- criacao automatica de conta WhatsApp quando necessario
- criacao ou atualizacao de contato por wa id
- criacao de conversa quando necessario
- gravacao de mensagem inbound
- processamento basico de status de mensagem

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/webhooks/webhooks.module.ts
- apps/backend/src/modules/webhooks/meta-webhooks.controller.ts
- apps/backend/src/modules/webhooks/meta-webhooks.service.ts
- apps/backend/src/modules/webhooks/meta-webhooks.types.ts
- apps/backend/src/app.module.ts
- docker-compose.yml
- .env
- .env.example
- docs/BACKEND_META_WEBHOOKS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- docker compose config
- validacao de WHATSAPP_VERIFY_TOKEN dentro do container backend
- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend com recriacao
- verificacao local com hub challenge
- verificacao dominio com hub challenge
- POST local com payload de mensagem
- POST dominio com payload de mensagem
- contagem de webhook events no banco
- contagem de mensagens de teste no banco

## Logs gerados

Logs:

- logs/setup_37_backend_typecheck.log
- logs/setup_37_backend_build.log
- logs/setup_37_backend_docker_build.log
- logs/setup_37_backend_docker_up.log
- logs/setup_37_container_env.log
- logs/setup_37_webhook_verify_local.log
- logs/setup_37_webhook_verify_domain.log
- logs/setup_37_webhook_post_local.log
- logs/setup_37_webhook_post_domain.log
- logs/setup_37_webhook_events_local.log
- logs/fix_37_webhook_verify_token_container.log
- logs/setup_37.log

## Configuracao para Meta

Callback URL:

    https bot lhsolucao com br api v1 webhooks meta

Verify Token:

    definido em WHATSAPP_VERIFY_TOKEN no arquivo .env

## Observacoes

A validacao de assinatura X-Hub-Signature-256 ainda nao foi implementada nesta etapa.

Essa validacao exige acesso ao corpo bruto da requisicao antes do parse JSON.

## Proxima etapa sugerida

Etapa 38:

    Criar validacao de assinatura dos webhooks da Meta
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 37 - Modulo backend de webhooks da Meta",
    "- [x] Etapa 37 - Modulo backend de webhooks da Meta"
)
text = text.replace(
    "Etapa 36 - Frontend de WhatsApp Accounts integrado.",
    "Etapa 37 - Modulo backend de webhooks da Meta."
)
text = text.replace(
    "Etapa 37 - Criar modulo backend de webhooks da Meta.",
    "Etapa 38 - Criar validacao de assinatura dos webhooks da Meta."
)
text = text.replace(
    "- [ ] Etapa 37 - Modulo backend de webhooks da Meta",
    "- [x] Etapa 37 - Modulo backend de webhooks da Meta"
)

if "- [ ] Etapa 38 - Validacao de assinatura dos webhooks da Meta" not in text:
    text = text.replace(
        "- [x] Etapa 37 - Modulo backend de webhooks da Meta",
        "- [x] Etapa 37 - Modulo backend de webhooks da Meta\n- [ ] Etapa 38 - Validacao de assinatura dos webhooks da Meta"
    )

if "## Ultima etapa executada" in text:
    before, marker, after = text.partition("## Ultima etapa executada")
    if "## Proxima etapa sugerida" in after:
        middle, marker2, tail = after.partition("## Proxima etapa sugerida")
        text = before + marker + "\n\nEtapa 37 - Modulo backend de webhooks da Meta.\n\n" + marker2 + "\n\nEtapa 38 - Criar validacao de assinatura dos webhooks da Meta.\n"
    else:
        text = before + marker + "\n\nEtapa 37 - Modulo backend de webhooks da Meta.\n\n## Proxima etapa sugerida\n\nEtapa 38 - Criar validacao de assinatura dos webhooks da Meta.\n"

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Modulo backend de webhooks da Meta criado." not in text:
    text = text.replace(
        "Frontend de WhatsApp Accounts integrado criado.",
        "Frontend de WhatsApp Accounts integrado criado.\n\nModulo backend de webhooks da Meta criado."
    )

if "- docs/BACKEND_META_WEBHOOKS.md" not in text:
    text = text.replace(
        "- docs/FRONTEND_WHATSAPP_ACCOUNTS.md",
        "- docs/FRONTEND_WHATSAPP_ACCOUNTS.md\n- docs/BACKEND_META_WEBHOOKS.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 36 concluidas",
    "- Etapa 01 ate Etapa 37 concluidas"
)

text = text.replace(
    "- Etapa 37 - Modulo backend de webhooks da Meta",
    "- Etapa 38 - Validacao de assinatura dos webhooks da Meta"
)

path.write_text(text)
PY

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
Etapa: 37
Acao: Correcao WHATSAPP_VERIFY_TOKEN no container backend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Verify local status: ${LOCAL_VERIFY_STATUS}
Verify dominio status: ${DOMAIN_VERIFY_STATUS}
Post local status: ${LOCAL_POST_STATUS}
Post dominio status: ${DOMAIN_POST_STATUS}
Status: Concluido
DOC

cat > "${LOG_FILE}" <<DOC
Etapa: 37
Acao: Modulo backend de webhooks da Meta
Data: $(date '+%Y-%m-%d %H:%M:%S')
Verify local status: ${LOCAL_VERIFY_STATUS}
Verify dominio status: ${DOMAIN_VERIFY_STATUS}
Post local status: ${LOCAL_POST_STATUS}
Post dominio status: ${DOMAIN_POST_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 37 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Verify token salvo em .env:"
echo "WHATSAPP_VERIFY_TOKEN=${VERIFY_TOKEN}"
echo ""
echo "Callback URL para Meta:"
echo "https://bot.lhsolucao.com.br/api/v1/webhooks/meta"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 38 - Criar validacao de assinatura dos webhooks da Meta"
