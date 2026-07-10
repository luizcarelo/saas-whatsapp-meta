#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
CONTROL_FILE="${BASE_DIR}/00_CONTROLE.md"
LOG_FILE="${LOGS_DIR}/fix_61_controle_ultima_etapa.log"

echo "== Fix controle Etapa 61 =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

if [ ! -f "${CONTROL_FILE}" ]; then
  echo "ERRO: 00_CONTROLE.md nao encontrado."
  exit 1
fi

cp "${CONTROL_FILE}" "${BACKUPS_DIR}/00_CONTROLE.md_${STAMP}.bak"

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "## Ultima etapa executada\n\nEtapa 62 - Criar encerramento com avaliacao do atendimento.",
    "## Ultima etapa executada\n\nEtapa 61 - Criar notas internas e tags."
)

text = text.replace(
    "## Proxima etapa sugerida\n\nEtapa 62 - Criar encerramento com avaliacao do atendimento.",
    "## Proxima etapa sugerida\n\nEtapa 62 - Criar encerramento com avaliacao do atendimento."
)

path.write_text(text)
PY

if ! grep -q "Etapa 61 - Criar notas internas e tags." "${CONTROL_FILE}"; then
  echo "ERRO: correcao da ultima etapa nao foi aplicada."
  exit 1
fi

if ! grep -q "Etapa 62 - Criar encerramento com avaliacao do atendimento." "${CONTROL_FILE}"; then
  echo "ERRO: proxima etapa nao encontrada."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Fix: controle Etapa 61
Data: $(date '+%Y-%m-%d %H:%M:%S')
Arquivo: 00_CONTROLE.md
Correcao: Ultima etapa executada ajustada para Etapa 61 - Criar notas internas e tags.
Status: Concluido
DOC

echo ""
echo "== Controle corrigido com sucesso =="
echo ""
cat "${LOG_FILE}"
