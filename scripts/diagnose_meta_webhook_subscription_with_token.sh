#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
REPORT_FILE="${LOGS_DIR}/diagnose_meta_webhook_subscription_with_token.log"

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
: > "${REPORT_FILE}"

log() {
  echo "$1" | tee -a "${REPORT_FILE}"
}

mask_value() {
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

hash_value() {
  local value="${1:-}"

  if [ -z "${value}" ]; then
    echo "EMPTY"
    return
  fi

  printf "%s" "${value}" | sha256sum | awk '{print $1}'
}

read_env_value() {
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

log "== Diagnostico Meta com access token temporario =="
log "Data: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

ACCESS_TOKEN="${META_DIAG_ACCESS_TOKEN:-}"

if [ -z "${ACCESS_TOKEN}" ]; then
  log "ERRO: defina META_DIAG_ACCESS_TOKEN antes de executar."
  log "Exemplo: export META_DIAG_ACCESS_TOKEN='token_da_meta'"
  exit 1
fi

GRAPH_VERSION="$(read_env_value ".env" "META_GRAPH_API_VERSION")"
GRAPH_VERSION="${GRAPH_VERSION:-v25.0}"

log "Graph version: ${GRAPH_VERSION}"
log "Access token temporario: $(mask_value "${ACCESS_TOKEN}")"
log "Access token hash: $(hash_value "${ACCESS_TOKEN}")"
log ""

IDS_FILE="${LOGS_DIR}/diagnose_meta_webhook_subscription_ids.tsv"

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -A -F $'\t' -v ON_ERROR_STOP=1 <<'SQL' > "${IDS_FILE}"
select
  id::text as local_id,
  coalesce(phone_number_id, '') as phone_number_id,
  coalesce(waba_id, '') as waba_id,
  coalesce(display_phone_number, '') as display_phone_number,
  coalesce(deleted_at::text, '') as deleted_at
from whatsapp_accounts
order by
  case
    when phone_number_id ~ '^[0-9]+$' and waba_id ~ '^[0-9]+$' then 0
    else 1
  end,
  created_at desc
limit 20;
SQL

log "== Contas detectadas no banco =="
cat "${IDS_FILE}" | tee -a "${REPORT_FILE}"

PHONE_NUMBER_ID="${META_DIAG_PHONE_NUMBER_ID:-}"
WABA_ID="${META_DIAG_WABA_ID:-}"

if [ -z "${PHONE_NUMBER_ID}" ]; then
  PHONE_NUMBER_ID="$(awk -F '\t' 'NR>1 && $2 ~ /^[0-9]+$/ {print $2; exit}' "${IDS_FILE}" || true)"
fi

if [ -z "${WABA_ID}" ]; then
  WABA_ID="$(awk -F '\t' 'NR>1 && $3 ~ /^[0-9]+$/ {print $3; exit}' "${IDS_FILE}" || true)"
fi

log ""
log "Phone Number ID usado: ${PHONE_NUMBER_ID:-NAO_ENCONTRADO}"
log "WABA ID usado: ${WABA_ID:-NAO_ENCONTRADO}"

if [ -z "${PHONE_NUMBER_ID}" ]; then
  log "ERRO: Phone Number ID numerico nao encontrado."
  exit 1
fi

if [ -z "${WABA_ID}" ]; then
  log "ERRO: WABA ID numerico nao encontrado."
  exit 1
fi

log ""
log "== 1. Phone number webhook_configuration =="

curl -s \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://graph.facebook.com/${GRAPH_VERSION}/${PHONE_NUMBER_ID}?fields=id,display_phone_number,verified_name,webhook_configuration" \
  | tee "${LOGS_DIR}/diagnose_meta_phone_webhook_configuration.json" \
  | tee -a "${REPORT_FILE}"

log ""
log ""
log "== 2. WABA subscribed_apps =="

curl -s \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://graph.facebook.com/${GRAPH_VERSION}/${WABA_ID}/subscribed_apps" \
  | tee "${LOGS_DIR}/diagnose_meta_waba_subscribed_apps.json" \
  | tee -a "${REPORT_FILE}"

log ""
log ""
log "== 3. WABA phone_numbers =="

curl -s \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://graph.facebook.com/${GRAPH_VERSION}/${WABA_ID}/phone_numbers?fields=id,display_phone_number,verified_name" \
  | tee "${LOGS_DIR}/diagnose_meta_waba_phone_numbers.json" \
  | tee -a "${REPORT_FILE}"

log ""
log "== Interpretacao =="
log "Se webhook_configuration tiver phone_number ou whatsapp_business_account com outra URL, existe override ativo."
log "Se subscribed_apps nao listar o app correto, a WABA pode nao estar inscrita no app."
log "Se retornar erro de permissao, o token temporario nao tem permissao suficiente."
log "Se tudo estiver correto, rode novamente diagnose_live_webhook_receive.sh e envie mensagem real."
log ""
log "Relatorio: ${REPORT_FILE}"
