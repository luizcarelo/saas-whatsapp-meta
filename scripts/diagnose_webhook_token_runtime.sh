#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
REPORT_FILE="${LOGS_DIR}/diagnose_webhook_token_runtime.log"
DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
WEBHOOK_URL="${DOMAIN_BASE_URL}/api/v1/webhooks/meta"

echo "== Diagnostico runtime do token de webhook =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"

: > "${REPORT_FILE}"

log() {
  echo "$1" | tee -a "${REPORT_FILE}"
}

mask_token() {
  local value="${1:-}"

  if [ -z "${value}" ]; then
    echo "VAZIO"
    return
  fi

  local len="${#value}"
  local first="${value:0:4}"
  local last="${value: -4}"

  if [ "${len}" -le 8 ]; then
    echo "len=${len} masked=****"
  else
    echo "len=${len} masked=${first}****${last}"
  fi
}

hash_token() {
  local value="${1:-}"

  if [ -z "${value}" ]; then
    echo "EMPTY"
    return
  fi

  printf "%s" "${value}" | sha256sum | awk '{print $1}'
}

extract_env_var() {
  local file="$1"
  local key="$2"

  if [ ! -f "${file}" ]; then
    echo ""
    return
  fi

  grep -E "^${key}=" "${file}" \
    | tail -n 1 \
    | cut -d '=' -f 2- \
    | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//' || true
}

test_webhook_token() {
  local label="$1"
  local token="$2"
  local output_file="${LOGS_DIR}/diagnose_webhook_token_runtime_${label}.log"

  if [ -z "${token}" ]; then
    log "Teste ${label}: token vazio, ignorado."
    return
  fi

  local status
  status="$(curl -L -s -o "${output_file}" -w "%{http_code}" --max-time 20 \
    "${WEBHOOK_URL}?hub.mode=subscribe&hub.verify_token=${token}&hub.challenge=246813579" || true)"

  local body
  body="$(cat "${output_file}" || true)"

  log "Teste ${label}: status=${status} body=${body}"
}

log "Data: $(date '+%Y-%m-%d %H:%M:%S')"
log "Webhook URL: ${WEBHOOK_URL}"
log ""

log "== 1. Containers =="
docker compose ps | tee -a "${REPORT_FILE}"

log ""
log "== 2. Health backend local =="
curl -s -i --max-time 10 "http://127.0.0.1:3300/api/v1/health" | tee -a "${REPORT_FILE}" || true

log ""
log "== 3. Variaveis em arquivos .env sem segredo =="

FILES_TO_CHECK=(
  ".env"
  "apps/backend/.env"
  "apps/backend/.env.local"
  "apps/backend/.env.production"
)

ENV_META_TOKEN=""
ENV_WHATSAPP_TOKEN=""

for env_file in "${FILES_TO_CHECK[@]}"; do
  if [ -f "${env_file}" ]; then
    log "Arquivo: ${env_file}"

    meta_value="$(extract_env_var "${env_file}" "META_WEBHOOK_VERIFY_TOKEN")"
    whatsapp_value="$(extract_env_var "${env_file}" "WHATSAPP_VERIFY_TOKEN")"

    if [ -n "${meta_value}" ]; then
      log "META_WEBHOOK_VERIFY_TOKEN: $(mask_token "${meta_value}") hash=$(hash_token "${meta_value}")"

      if [ -z "${ENV_META_TOKEN}" ]; then
        ENV_META_TOKEN="${meta_value}"
      fi
    else
      log "META_WEBHOOK_VERIFY_TOKEN: AUSENTE"
    fi

    if [ -n "${whatsapp_value}" ]; then
      log "WHATSAPP_VERIFY_TOKEN: $(mask_token "${whatsapp_value}") hash=$(hash_token "${whatsapp_value}")"

      if [ -z "${ENV_WHATSAPP_TOKEN}" ]; then
        ENV_WHATSAPP_TOKEN="${whatsapp_value}"
      fi
    else
      log "WHATSAPP_VERIFY_TOKEN: AUSENTE"
    fi

    log ""
  fi
done

log ""
log "== 4. Variaveis dentro do container backend sem segredo =="

CONTAINER_ENV_FILE="${LOGS_DIR}/diagnose_webhook_token_runtime_container_env.raw"
docker compose exec -T backend printenv > "${CONTAINER_ENV_FILE}" || true

CONTAINER_META_TOKEN="$(grep '^META_WEBHOOK_VERIFY_TOKEN=' "${CONTAINER_ENV_FILE}" | tail -n 1 | cut -d '=' -f 2- || true)"
CONTAINER_WHATSAPP_TOKEN="$(grep '^WHATSAPP_VERIFY_TOKEN=' "${CONTAINER_ENV_FILE}" | tail -n 1 | cut -d '=' -f 2- || true)"
CONTAINER_META_REQUIRED="$(grep '^META_WEBHOOK_SIGNATURE_REQUIRED=' "${CONTAINER_ENV_FILE}" | tail -n 1 | cut -d '=' -f 2- || true)"
CONTAINER_META_APP_SECRET="$(grep '^META_APP_SECRET=' "${CONTAINER_ENV_FILE}" | tail -n 1 | cut -d '=' -f 2- || true)"

log "Container META_WEBHOOK_VERIFY_TOKEN: $(mask_token "${CONTAINER_META_TOKEN}") hash=$(hash_token "${CONTAINER_META_TOKEN}")"
log "Container WHATSAPP_VERIFY_TOKEN: $(mask_token "${CONTAINER_WHATSAPP_TOKEN}") hash=$(hash_token "${CONTAINER_WHATSAPP_TOKEN}")"
log "Container META_WEBHOOK_SIGNATURE_REQUIRED: ${CONTAINER_META_REQUIRED:-AUSENTE}"
log "Container META_APP_SECRET: $(mask_token "${CONTAINER_META_APP_SECRET}") hash=$(hash_token "${CONTAINER_META_APP_SECRET}")"

log ""
log "== 5. Comparacao arquivo x container =="

if [ -n "${ENV_META_TOKEN}" ] && [ -n "${CONTAINER_META_TOKEN}" ]; then
  if [ "$(hash_token "${ENV_META_TOKEN}")" = "$(hash_token "${CONTAINER_META_TOKEN}")" ]; then
    log "META_WEBHOOK_VERIFY_TOKEN arquivo x container: IGUAL"
  else
    log "META_WEBHOOK_VERIFY_TOKEN arquivo x container: DIFERENTE"
  fi
else
  log "META_WEBHOOK_VERIFY_TOKEN arquivo x container: INCOMPLETO"
fi

if [ -n "${ENV_WHATSAPP_TOKEN}" ] && [ -n "${CONTAINER_WHATSAPP_TOKEN}" ]; then
  if [ "$(hash_token "${ENV_WHATSAPP_TOKEN}")" = "$(hash_token "${CONTAINER_WHATSAPP_TOKEN}")" ]; then
    log "WHATSAPP_VERIFY_TOKEN arquivo x container: IGUAL"
  else
    log "WHATSAPP_VERIFY_TOKEN arquivo x container: DIFERENTE"
  fi
else
  log "WHATSAPP_VERIFY_TOKEN arquivo x container: INCOMPLETO"
fi

log ""
log "== 6. Codigo que usa verify token =="

grep -RIn \
  "META_WEBHOOK_VERIFY_TOKEN\|WHATSAPP_VERIFY_TOKEN\|hub.verify_token\|verify_token\|Webhook verification failed" \
  apps/backend/src/modules/webhooks apps/backend/src \
  | sed -n '1,240p' \
  | tee -a "${REPORT_FILE}" || true

log ""
log "== 7. Trecho do controller de webhook =="

if [ -f "apps/backend/src/modules/webhooks/meta-webhooks.controller.ts" ]; then
  sed -n '1,120p' apps/backend/src/modules/webhooks/meta-webhooks.controller.ts | tee -a "${REPORT_FILE}"
else
  log "Arquivo apps/backend/src/modules/webhooks/meta-webhooks.controller.ts nao encontrado."
fi

log ""
log "== 8. Testes GET com tokens conhecidos =="

test_webhook_token "env_meta" "${ENV_META_TOKEN}"
test_webhook_token "env_whatsapp" "${ENV_WHATSAPP_TOKEN}"
test_webhook_token "container_meta" "${CONTAINER_META_TOKEN}"
test_webhook_token "container_whatsapp" "${CONTAINER_WHATSAPP_TOKEN}"

log ""
log "== 9. Docker compose config relacionado a webhook sem segredo =="

docker compose config 2>/dev/null \
  | grep -Ein "META_WEBHOOK_VERIFY_TOKEN|WHATSAPP_VERIFY_TOKEN|META_APP_SECRET|META_WEBHOOK_SIGNATURE_REQUIRED|WEBHOOK|WHATSAPP|META" \
  | sed -E 's/(: |:).*/: ***REDACTED***/' \
  | sed -n '1,220p' \
  | tee -a "${REPORT_FILE}" || true

log ""
log "== 10. Interpretacao rapida =="
log "Se token do arquivo e token do container forem diferentes, o container esta usando valor antigo ou outra fonte."
log "Se todos os testes GET retornarem 403, o codigo pode estar lendo outra variavel ou usando fallback diferente."
log "Se algum teste GET retornar 200 com body 246813579, esse e o token efetivo para configurar na Meta."
log "Se o GET validar mas mensagens nao chegarem, revise a assinatura do app Meta no campo messages e a callback URL."
log ""
log "== Diagnostico concluido =="
log "Relatorio: ${REPORT_FILE}"
