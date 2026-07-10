#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
BACKEND_DIR="${BASE_DIR}/apps/backend"
LOGS_DIR="${BASE_DIR}/logs"
REPORT_FILE="${LOGS_DIR}/review_78_preflight_attendance_files.log"

echo "== Revisao pre-Etapa 78: arquivos do modulo Atendimento =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
: > "${REPORT_FILE}"

log() {
  echo "$1" | tee -a "${REPORT_FILE}"
}

section() {
  log ""
  log "== $1 =="
}

section "1. Data e objetivo"
log "Data: $(date '+%Y-%m-%d %H:%M:%S')"
log "Objetivo: revisar arquivos antes da Etapa 78 sem alterar codigo."
log "Modo: somente leitura"

section "2. Validando arquivos principais"

FILES_TO_CHECK=(
  "apps/frontend/src/pages/inbox/InboxPage.tsx"
  "apps/frontend/src/pages/attendance-settings/AttendanceSettingsPage.tsx"
  "apps/frontend/src/pages/send-failures/SendFailuresPage.tsx"
  "apps/frontend/src/services/attendance-send.service.ts"
  "apps/frontend/src/services/attendance-settings.service.ts"
  "apps/frontend/src/services/attendance-send-failures.service.ts"
  "apps/frontend/src/services/attendance-status.service.ts"
  "apps/frontend/src/app/routes.tsx"
  "apps/frontend/src/components/layout/Sidebar.tsx"
  "apps/frontend/src/styles.css"
)

for file in "${FILES_TO_CHECK[@]}"; do
  if [ -f "${file}" ]; then
    log "OK: ${file}"
  else
    log "AUSENTE: ${file}"
  fi
done

section "3. Busca por HTML injetado ou corrompido"

grep -RIn \
  "fai-ChatInputEntity\|&lt;\|&gt;\|/app/inboxVoltar\|/a&gt;\|href=&quot;" \
  apps/frontend/src/pages \
  apps/frontend/src/services \
  apps/frontend/src/app \
  apps/frontend/src/components \
  apps/frontend/src/styles.css \
  | tee -a "${REPORT_FILE}" || log "Nenhum padrao obvio de HTML corrompido encontrado."

section "4. Trecho atual da AttendanceSettingsPage"

if [ -f "apps/frontend/src/pages/attendance-settings/AttendanceSettingsPage.tsx" ]; then
  sed -n '1,260p' apps/frontend/src/pages/attendance-settings/AttendanceSettingsPage.tsx | tee -a "${REPORT_FILE}"
else
  log "Arquivo AttendanceSettingsPage.tsx nao encontrado."
fi

section "5. Trechos relevantes do InboxPage"

if [ -f "apps/frontend/src/pages/inbox/InboxPage.tsx" ]; then
  log "-- Linhas com envio, composer, quick reply, closing, rating, send history, dryRun --"
  grep -nEi "send|enviar|composer|quick|reply|resposta|closure|encerr|rating|avali|history|historico|dryRun|failure|falha|retry|retent" \
    apps/frontend/src/pages/inbox/InboxPage.tsx \
    | tee -a "${REPORT_FILE}" || log "Nenhum trecho encontrado pelos termos buscados."

  log ""
  log "-- Primeiras 260 linhas do InboxPage --"
  sed -n '1,260p' apps/frontend/src/pages/inbox/InboxPage.tsx | tee -a "${REPORT_FILE}"

  log ""
  log "-- Linhas 261 a 560 do InboxPage --"
  sed -n '261,560p' apps/frontend/src/pages/inbox/InboxPage.tsx | tee -a "${REPORT_FILE}"

  log ""
  log "-- Linhas 561 a 920 do InboxPage --"
  sed -n '561,920p' apps/frontend/src/pages/inbox/InboxPage.tsx | tee -a "${REPORT_FILE}"
else
  log "Arquivo InboxPage.tsx nao encontrado."
fi

section "6. Services de atendimento relacionados"

for file in \
  "apps/frontend/src/services/attendance-send.service.ts" \
  "apps/frontend/src/services/attendance-settings.service.ts" \
  "apps/frontend/src/services/attendance-send-failures.service.ts" \
  "apps/frontend/src/services/attendance-status.service.ts"
do
  if [ -f "${file}" ]; then
    log ""
    log "-- ${file} --"
    sed -n '1,240p' "${file}" | tee -a "${REPORT_FILE}"
  fi
done

section "7. Rotas e menu"

for file in \
  "apps/frontend/src/app/routes.tsx" \
  "apps/frontend/src/components/layout/Sidebar.tsx"
do
  if [ -f "${file}" ]; then
    log ""
    log "-- ${file} --"
    sed -n '1,220p' "${file}" | tee -a "${REPORT_FILE}"
  fi
done

section "8. CSS relacionado ao atendimento"

grep -nEi \
  "inbox|attendance|composer|quick|closure|rating|send-history|settings|failure|status" \
  apps/frontend/src/styles.css \
  | tee -a "${REPORT_FILE}" || log "Nenhum CSS relacionado encontrado."

section "9. Backend relacionado a envio, encerramento e historico"

find apps/backend/src/modules \
  -type f \
  \( \
    -path '*attendance*' \
    -o -path '*conversation*' \
  \) \
  | sort \
  | tee -a "${REPORT_FILE}"

section "10. Endpoints backend relacionados"

grep -RIn \
  "attendance-send\|attendance-send-failures\|attendance-status\|attendance-automations\|quick-replies\|closures\|rating\|messages" \
  apps/backend/src/modules \
  | sed -n '1,260p' \
  | tee -a "${REPORT_FILE}" || log "Nenhum endpoint relacionado encontrado."

section "11. Validacao frontend somente leitura"

cd "${FRONTEND_DIR}"

npm run typecheck 2>&1 | tee "${LOGS_DIR}/review_78_frontend_typecheck.log"

cd "${BASE_DIR}"

section "12. Resumo"
log "Relatorio completo: ${REPORT_FILE}"
log "Typecheck frontend: logs/review_78_frontend_typecheck.log"
log "Status: Revisao pre-Etapa 78 concluida"
