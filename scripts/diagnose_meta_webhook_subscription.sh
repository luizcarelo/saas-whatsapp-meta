#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
REPORT_FILE="${LOGS_DIR}/diagnose_meta_webhook_subscription.log"

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

log "== Diagnostico de inscricao webhook Meta =="
log "Data: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

GRAPH_VERSION="$(read_env_value ".env" "META_GRAPH_API_VERSION")"
GRAPH_VERSION="${GRAPH_VERSION:-v20.0}"

ACCESS_TOKEN=""
ACCESS_TOKEN_SOURCE=""

TOKEN_KEYS=(
  "WHATSAPP_ACCESS_TOKEN"
  "META_ACCESS_TOKEN"
  "WHATSAPP_CLOUD_ACCESS_TOKEN"
  "META_SYSTEM_USER_ACCESS_TOKEN"
  "META_PERMANENT_ACCESS_TOKEN"
)

for env_file in ".env" "apps/backend/.env" "apps/backend/.env.local" "apps/backend/.env.production"; do
  if [ -f "${env_file}" ]; then
    for key in "${TOKEN_KEYS[@]}"; do
      value="$(read_env_value "${env_file}" "${key}")"

      if [ -n "${value}" ] && [ -z "${ACCESS_TOKEN}" ]; then
        ACCESS_TOKEN="${value}"
        ACCESS_TOKEN_SOURCE="${env_file}:${key}"
      fi
    done
  fi
done

log "Graph version: ${GRAPH_VERSION}"

log ""
log "== 1. Estrutura da tabela whatsapp_accounts =="

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${LOGS_DIR}/diagnose_meta_webhook_subscription_columns.log" | tee -a "${REPORT_FILE}"
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'whatsapp_accounts'
order by ordinal_position;
SQL

log ""
log "== 2. Descobrindo IDs e access token no banco =="

python3 <<'PY' > "${LOGS_DIR}/diagnose_meta_webhook_subscription_build_sql.py"
from pathlib import Path

columns_text = Path("logs/diagnose_meta_webhook_subscription_columns.log").read_text()
columns = []

for line in columns_text.splitlines():
    if "|" not in line:
        continue
    left = line.split("|", 1)[0].strip()
    if left and left not in ("column_name",) and not left.startswith("-"):
        columns.append(left)

def pick(candidates):
    for candidate in candidates:
        if candidate in columns:
            return candidate
    return None

def expr(col, alias):
    if col:
        return f'coalesce("{col}"::text, \'\') as {alias}'
    return f"'' as {alias}"

id_col = pick(["id"])
phone_col = pick(["phone_number_id", "phoneNumberId", "phone_number_id_meta"])
waba_col = pick(["waba_id", "wabaId", "whatsapp_business_account_id", "business_account_id", "businessAccountId"])
display_col = pick(["display_phone_number", "displayPhoneNumber", "phone_number", "phoneNumber"])
access_col = pick(["access_token", "accessToken", "token", "permanent_access_token", "permanentAccessToken"])
created_col = pick(["created_at", "createdAt"])

selects = [
    expr(id_col, "local_id"),
    expr(phone_col, "phone_number_id"),
    expr(waba_col, "waba_id"),
    expr(display_col, "display_phone_number"),
    expr(access_col, "access_token"),
]

order = f'order by "{created_col}" desc' if created_col else ""

sql = "select " + ", ".join(selects) + f" from whatsapp_accounts {order} limit 20;"
Path("logs/diagnose_meta_webhook_subscription_select.sql").write_text(sql + "\n")
PY

python3 "${LOGS_DIR}/diagnose_meta_webhook_subscription_build_sql.py"

IDS_FILE="${LOGS_DIR}/diagnose_meta_webhook_subscription_ids.tsv"

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -A -F $'\t' -v ON_ERROR_STOP=1 < "${LOGS_DIR}/diagnose_meta_webhook_subscription_select.sql" > "${IDS_FILE}"

awk -F '\t' '
NR==1 {
  print $1 "\t" $2 "\t" $3 "\t" $4 "\taccess_token_redacted"
  next
}
{
  token_len=length($5)
  token_status=(token_len > 0 ? "PRESENTE_len_" token_len : "VAZIO")
  print $1 "\t" $2 "\t" $3 "\t" $4 "\t" token_status
}
' "${IDS_FILE}" | tee -a "${REPORT_FILE}"

if [ -z "${ACCESS_TOKEN}" ]; then
  DB_TOKEN="$(awk -F '\t' 'NR>1 && $5 != "" {print $5; exit}' "${IDS_FILE}" || true)"

  if [ -n "${DB_TOKEN}" ]; then
    ACCESS_TOKEN="${DB_TOKEN}"
    ACCESS_TOKEN_SOURCE="whatsapp_accounts"
  fi
fi

PHONE_NUMBER_ID="$(awk -F '\t' 'NR>1 && $2 != "" {print $2; exit}' "${IDS_FILE}" || true)"
WABA_ID="$(awk -F '\t' 'NR>1 && $3 != "" {print $3; exit}' "${IDS_FILE}" || true)"

log ""
log "Access token encontrado: $([ -n "${ACCESS_TOKEN}" ] && echo SIM || echo NAO)"
log "Access token origem: ${ACCESS_TOKEN_SOURCE:-NAO_ENCONTRADO}"
log "Access token mascara: $(mask_value "${ACCESS_TOKEN}")"
log "Access token hash: $(hash_value "${ACCESS_TOKEN}")"
log "Phone Number ID detectado: ${PHONE_NUMBER_ID:-NAO_ENCONTRADO}"
log "WABA ID detectado: ${WABA_ID:-NAO_ENCONTRADO}"

if [ -z "${ACCESS_TOKEN}" ]; then
  log ""
  log "ERRO: access token da Meta nao encontrado no .env nem em whatsapp_accounts."
  log "Observacao: WHATSAPP_VERIFY_TOKEN nao serve para Graph API; ele serve apenas para validar o webhook."
  exit 1
fi

log ""
log "== 3. Consulta Graph: phone number webhook_configuration =="

if [ -n "${PHONE_NUMBER_ID}" ]; then
  curl -s \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://graph.facebook.com/${GRAPH_VERSION}/${PHONE_NUMBER_ID}?fields=id,display_phone_number,verified_name,webhook_configuration" \
    | tee "${LOGS_DIR}/diagnose_meta_phone_webhook_configuration.json" \
    | tee -a "${REPORT_FILE}"
else
  log "SKIP: PHONE_NUMBER_ID nao encontrado."
fi

log ""
log ""
log "== 4. Consulta Graph: WABA subscribed_apps =="

if [ -n "${WABA_ID}" ]; then
  curl -s \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://graph.facebook.com/${GRAPH_VERSION}/${WABA_ID}/subscribed_apps" \
    | tee "${LOGS_DIR}/diagnose_meta_waba_subscribed_apps.json" \
    | tee -a "${REPORT_FILE}"
else
  log "SKIP: WABA_ID nao encontrado no banco."
fi

log ""
log ""
log "== 5. Consulta alternativa: phone_numbers pela WABA =="

if [ -n "${WABA_ID}" ]; then
  curl -s \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://graph.facebook.com/${GRAPH_VERSION}/${WABA_ID}/phone_numbers?fields=id,display_phone_number,verified_name" \
    | tee "${LOGS_DIR}/diagnose_meta_waba_phone_numbers.json" \
    | tee -a "${REPORT_FILE}"
else
  log "SKIP: WABA_ID nao encontrado no banco."
fi

log ""
log "== Interpretacao =="
log "Se webhook_configuration mostrar phone_number ou whatsapp_business_account apontando para outra URL, existe override."
log "Se subscribed_apps nao retornar seu app, a WABA pode nao estar inscrita no app."
log "Se a consulta retornar erro de permissao, o access token pode nao ter permissao suficiente."
log "Relatorio: ${REPORT_FILE}"
