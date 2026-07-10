#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
SCRIPT_FILE="${BASE_DIR}/scripts/setup_48_retention_policy_visual_config.sh"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
FIX_LOG="${LOGS_DIR}/fix_48_retention_policy_visual_config_var.log"

echo "== Fix Etapa 48: corrigir variavel DOCKER_BUILD_LOG =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

if [ ! -f "${SCRIPT_FILE}" ]; then
  echo "ERRO: script original da Etapa 48 nao encontrado."
  exit 1
fi

cp "${SCRIPT_FILE}" "${BACKUPS_DIR}/setup_48_retention_policy_visual_config_${STAMP}.bak"

echo "Corrigindo variavel incorreta..."

python3 <<'PY'
from pathlib import Path

path = Path("scripts/setup_48_retention_policy_visual_config.sh")
text = path.read_text()

text = text.replace("${DOCKER_BUILD_LOG}", "${DOCKER_FRONTEND_BUILD_LOG}")
text = text.replace('"${DOCKER_BUILD_LOG}"', '"${DOCKER_FRONTEND_BUILD_LOG}"')

path.write_text(text)
PY

if grep -q "DOCKER_BUILD_LOG" "${SCRIPT_FILE}"; then
  echo "ERRO: ainda existe DOCKER_BUILD_LOG no script."
  grep -n "DOCKER_BUILD_LOG" "${SCRIPT_FILE}"
  exit 1
fi

if ! grep -q "DOCKER_FRONTEND_BUILD_LOG" "${SCRIPT_FILE}"; then
  echo "ERRO: variavel DOCKER_FRONTEND_BUILD_LOG nao encontrada apos correcao."
  exit 1
fi

chmod +x "${SCRIPT_FILE}"

cat > "${FIX_LOG}" <<DOC
Etapa: 48
Acao: Correcao de variavel no script da Etapa 48
Data: $(date '+%Y-%m-%d %H:%M:%S')
Arquivo corrigido: ${SCRIPT_FILE}
Backup: ${BACKUPS_DIR}/setup_48_retention_policy_visual_config_${STAMP}.bak
Status: Corrigido
DOC

echo "Script corrigido. Reexecutando Etapa 48..."
"${SCRIPT_FILE}"
