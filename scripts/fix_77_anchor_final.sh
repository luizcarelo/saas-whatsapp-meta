#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/saas-whatsapp-meta"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
TARGET_FILE="${FRONTEND_DIR}/src/pages/attendance-settings/AttendanceSettingsPage.tsx"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
TYPECHECK_LOG="${LOGS_DIR}/fix_77_anchor_final_typecheck.log"
BUILD_LOG="${LOGS_DIR}/fix_77_anchor_final_build.log"
LOG_FILE="${LOGS_DIR}/fix_77_anchor_final.log"

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

if [ ! -f "${TARGET_FILE}" ]; then
  echo "ERRO: arquivo nao encontrado: ${TARGET_FILE}"
  exit 1
fi

cp "${TARGET_FILE}" "${BACKUPS_DIR}/AttendanceSettingsPage.tsx_${STAMP}.bak"

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/attendance-settings/AttendanceSettingsPage.tsx")
text = path.read_text()

lt = chr(60)
gt = chr(62)

correct_line = (
    "        "
    + lt
    + 'a href="/app/inbox"'
    + gt
    + "Voltar para atendimento"
    + lt
    + "/a"
    + gt
)

lines = text.splitlines()
new_lines = []
changed = 0

for line in lines:
    if "Voltar para atendimento" in line:
        new_lines.append(correct_line)
        changed += 1
    else:
        new_lines.append(line)

if changed == 0:
    raise SystemExit("ERRO: linha com Voltar para atendimento nao encontrada.")

path.write_text("\n".join(new_lines) + "\n")
print("Linhas corrigidas:", changed)
PY

echo "Trecho corrigido:"
sed -n '110,122p' "${TARGET_FILE}"

echo "Validando se ainda existe trecho quebrado..."

if grep -n '/app/inboxVoltar para atendimento' "${TARGET_FILE}"; then
  echo "ERRO: trecho quebrado ainda existe."
  exit 1
fi

if ! grep -n '/app/inboxVoltar para atendimento</a>' "${TARGET_FILE}"; then
  echo "ERRO: ancora correta nao encontrada."
  exit 1
fi

if grep -n 'fai-ChatInputEntity' "${TARGET_FILE}"; then
  echo "ERRO: HTML injetado encontrado."
  exit 1
fi

cd "${FRONTEND_DIR}"

npm run typecheck 2>&1 | tee "${TYPECHECK_LOG}"
npm run build 2>&1 | tee "${BUILD_LOG}"

cd "${BASE_DIR}"

cat > "${LOG_FILE}" <<DOC
Fix: ancora final da Etapa 77
Data: $(date '+%Y-%m-%d %H:%M:%S')
Arquivo: apps/frontend/src/pages/attendance-settings/AttendanceSettingsPage.tsx
Correcao: substituida linha quebrada por ancora JSX valida para app inbox.
Typecheck: concluido
Build: concluido
Status: Concluido
DOC

echo "== Fix concluido =="
cat "${LOG_FILE}"
