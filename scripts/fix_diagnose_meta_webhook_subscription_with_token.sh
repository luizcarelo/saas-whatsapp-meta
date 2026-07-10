#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
SCRIPT_FILE="${BASE_DIR}/scripts/diagnose_meta_webhook_subscription_with_token.sh"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/fix_diagnose_meta_webhook_subscription_with_token.log"

echo "== Fix diagnose_meta_webhook_subscription_with_token =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

if [ ! -f "${SCRIPT_FILE}" ]; then
  echo "ERRO: script nao encontrado: ${SCRIPT_FILE}"
  exit 1
fi

cp "${SCRIPT_FILE}" "${BACKUPS_DIR}/diagnose_meta_webhook_subscription_with_token.sh_${STAMP}.bak"

python3 <<'PY'
from pathlib import Path

path = Path("scripts/diagnose_meta_webhook_subscription_with_token.sh")
text = path.read_text()

old = """select
  id::text as local_id,
  coalesce(phone_number_id, '') as phone_number_id,
  coalesce(waba_id, '') as waba_id,
  coalesce(display_phone_number, '') as display_phone_number
from whatsapp_accounts
where deleted_at is null
order by created_at desc
limit 20;
"""

new = """select
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
"""

if old not in text:
    raise SystemExit("Bloco SQL esperado nao encontrado no script.")

text = text.replace(old, new)

path.write_text(text)
PY

cat > "${LOG_FILE}" <<DOC
Fix: diagnose_meta_webhook_subscription_with_token
Data: $(date '+%Y-%m-%d %H:%M:%S')
Arquivo: scripts/diagnose_meta_webhook_subscription_with_token.sh
Correcao: removido filtro deleted_at is null e priorizados IDs numericos reais.
Status: Concluido
DOC

echo ""
echo "== Fix concluido =="
cat "${LOG_FILE}"
