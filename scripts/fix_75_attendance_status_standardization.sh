#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_75.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_75_attendance_status_standardization.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_STATUS_STANDARDIZATION.md"
DOC_COMPAT="${DOCS_DIR}/ATTENDANCE_STATUS_COMPATIBILITY_MAP.md"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_75_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_75_auth_login_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_75_status_model_domain.log"
DOMAIN_STATUS_OPTIONS_LOG="${LOGS_DIR}/setup_75_status_options_domain.log"
DOMAIN_STATUS_MAP_LOG="${LOGS_DIR}/setup_75_status_compatibility_map_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_75_attendance_conversations_domain.log"
DOMAIN_DB_COUNTS_LOG="${LOGS_DIR}/setup_75_status_database_counts.log"
DOMAIN_PAGES_LOG="${LOGS_DIR}/setup_75_pages_status.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"

echo "== Fix Etapa 75: Padronizacao dos status de atendimento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${DOC_FILE}" \
  "${DOC_COMPAT}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md" \
  "${BASE_DIR}/CONTEXTO_PROJETO.md" \
  "${BASE_DIR}/CHANGELOG.md" \
  "${BASE_DIR}/DECISOES_TECNICAS.md" \
  "${BASE_DIR}/PENDENCIAS.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

for tool in node docker curl python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando conclusao da Etapa 74..."

if [ ! -f "${LOGS_DIR}/setup_74.log" ]; then
  echo "ERRO: setup_74.log nao encontrado."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_74.log"; then
  echo "ERRO: Etapa 74 nao esta concluida."
  cat "${LOGS_DIR}/setup_74.log"
  exit 1
fi

echo "Validando backend local..."

BACKEND_READY="false"

for i in $(seq 1 20); do
  if curl -s --max-time 5 "http://127.0.0.1:3300/api/v1/health" >/dev/null 2>&1; then
    BACKEND_READY="true"
    break
  fi

  sleep 2
done

if [ "${BACKEND_READY}" != "true" ]; then
  echo "ERRO: backend local nao respondeu health."
  docker compose logs --tail=160 backend || true
  exit 1
fi

echo "Validando health dominio..."

DOMAIN_HEALTH_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_BASE_URL}/api/v1/health" || true)"

if [ "${DOMAIN_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health dominio falhou. Status ${DOMAIN_HEALTH_STATUS}"
  cat "${DOMAIN_HEALTH_LOG}"
  exit 1
fi

echo "Validando login dominio..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: credenciais da Etapa 24 ausentes."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_BASE_URL}/api/v1/auth/login" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

echo "Validando endpoints de status..."

DOMAIN_STATUS_MODEL_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MODEL_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_BASE_URL}/api/v1/attendance-status/model" || true)"

if [ "${DOMAIN_STATUS_MODEL_STATUS}" != "200" ]; then
  echo "ERRO: attendance status model falhou. Status ${DOMAIN_STATUS_MODEL_STATUS}"
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

if ! grep -q "conversation" "${DOMAIN_STATUS_MODEL_LOG}"; then
  echo "ERRO: status model nao retornou grupo conversation."
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

if ! grep -q "attendance" "${DOMAIN_STATUS_MODEL_LOG}"; then
  echo "ERRO: status model nao retornou grupo attendance."
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

if ! grep -q "send" "${DOMAIN_STATUS_MODEL_LOG}"; then
  echo "ERRO: status model nao retornou grupo send."
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

if ! grep -q "closure" "${DOMAIN_STATUS_MODEL_LOG}"; then
  echo "ERRO: status model nao retornou grupo closure."
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

DOMAIN_STATUS_OPTIONS_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_OPTIONS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_BASE_URL}/api/v1/attendance-status/options?group=attendance" || true)"

if [ "${DOMAIN_STATUS_OPTIONS_STATUS}" != "200" ]; then
  echo "ERRO: attendance status options falhou. Status ${DOMAIN_STATUS_OPTIONS_STATUS}"
  cat "${DOMAIN_STATUS_OPTIONS_LOG}"
  exit 1
fi

DOMAIN_STATUS_MAP_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MAP_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_BASE_URL}/api/v1/attendance-status/compatibility-map" || true)"

if [ "${DOMAIN_STATUS_MAP_STATUS}" != "200" ]; then
  echo "ERRO: attendance status compatibility map falhou. Status ${DOMAIN_STATUS_MAP_STATUS}"
  cat "${DOMAIN_STATUS_MAP_LOG}"
  exit 1
fi

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_BASE_URL}/api/v1/attendance/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_LIST_STATUS}" != "200" ]; then
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

echo "Gerando contagens do catalogo de status..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DOMAIN_DB_COUNTS_LOG}"
select status_group, count(*) as total
from attendance_status_catalog
group by status_group
order by status_group;

select legacy_scope, count(*) as total
from attendance_status_compatibility_map
group by legacy_scope
order by legacy_scope;
SQL

echo "Validando paginas principais..."

: > "${DOMAIN_PAGES_LOG}"

for page in \
  "/app/inbox" \
  "/app/attendance-dashboard" \
  "/app/send-failures" \
  "/app/dashboard" \
  "/app/audit"
do
  status="$(curl -L -s -o /dev/null -w "%{http_code}" --max-time 30 "${DOMAIN_BASE_URL}${page}" || true)"
  echo "${page} ${status}" | tee -a "${DOMAIN_PAGES_LOG}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: pagina ${page} nao respondeu 200."
    exit 1
  fi
done

echo "Gerando documentacao da Etapa 75..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Status Standardization

## Visao geral

Este documento registra a padronizacao dos status do modulo Atendimento.

## Resultado

Status:

    concluido

## Objetivo

Objetivo:

- separar status tecnico da conversa
- separar status operacional do atendimento
- separar status de envio
- separar status de encerramento e avaliacao
- manter compatibilidade com status antigos
- preparar refino visual do app inbox

## Grupos padronizados

Grupos:

- conversation
- attendance
- send
- closure

## Conversation

Uso:

- ciclo tecnico da conversa

Valores:

- open
- closed
- archived

## Attendance

Uso:

- situacao operacional do atendimento para a central

Valores:

- novo
- em_atendimento
- aguardando_cliente
- aguardando_atendente
- encerrado
- arquivado

## Send

Uso:

- situacao de uma mensagem enviada ou simulada

Valores:

- pending
- sent
- delivered
- read
- failed
- dry_run

## Closure

Uso:

- situacao de encerramento e avaliacao

Valores:

- closure_created
- rating_requested
- rating_received
- rating_not_received

## Compatibilidade

Compatibilidade:

- human para conversation open
- closed para conversation closed
- em atendimento para attendance em_atendimento
- aguardando cliente para attendance aguardando_cliente
- dry run para send dry_run

## Endpoints criados

Endpoints:

- GET api v1 attendance status model
- GET api v1 attendance status options
- GET api v1 attendance status compatibility map

## Tabelas criadas

Tabelas:

- attendance status catalog
- attendance status compatibility map

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-status/attendance-status.types.ts
- apps/backend/src/modules/attendance-status/attendance-status.service.ts
- apps/backend/src/modules/attendance-status/attendance-status.controller.ts
- apps/backend/src/modules/attendance-status/attendance-status.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-status.types.ts
- apps/frontend/src/services/attendance-status.service.ts
- apps/frontend/src/utils/attendance-status.ts
- docs/ATTENDANCE_STATUS_STANDARDIZATION.md
- docs/ATTENDANCE_STATUS_COMPATIBILITY_MAP.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- catalogo padronizado criado
- mapa de compatibilidade criado
- endpoint status model
- endpoint status options
- endpoint status compatibility map
- endpoint attendance conversations
- contagens de banco
- paginas principais do frontend

## Observacao do fix

A primeira execucao da Etapa 75 aplicou a parte tecnica, mas parou antes de gerar documentacao e log final por erro de variavel no script.

Este fix concluiu a documentacao, validacoes finais, controle e manifesto.

## Proxima etapa sugerida

Etapa 76:

    Reorganizacao visual do app inbox
DOC

cat > "${DOC_COMPAT}" <<'DOC'
# Attendance Status Compatibility Map

## Visao geral

Este documento registra o mapa de compatibilidade entre status antigos e o modelo padronizado do Atendimento.

## Objetivo

Objetivo:

- preservar compatibilidade
- evitar quebra de dados antigos
- permitir migracao gradual
- separar status por grupo funcional

## Mapeamentos principais

Mapeamentos:

- conversation human para conversation open
- conversation closed para conversation closed
- conversation open para conversation open
- conversation archived para conversation archived
- attendance novo para attendance novo
- attendance em atendimento para attendance em_atendimento
- attendance em_atendimento para attendance em_atendimento
- attendance aguardando cliente para attendance aguardando_cliente
- attendance aguardando_cliente para attendance aguardando_cliente
- attendance aguardando_atendente para attendance aguardando_atendente
- attendance encerrado para attendance encerrado
- attendance arquivado para attendance arquivado
- send pending para send pending
- send sent para send sent
- send delivered para send delivered
- send read para send read
- send failed para send failed
- send dry run para send dry_run
- send dry_run para send dry_run

## Regra operacional

Regra:

- status tecnico da conversa nao deve ser usado como status operacional
- status operacional nao deve ser usado como status de envio
- status de envio nao deve alterar automaticamente status da conversa
- status de encerramento e avaliacao deve ser tratado separadamente

## Uso futuro

Uso futuro:

- app inbox deve exibir labels usando o grupo correto
- filtros da central devem usar status operacional
- painel de falhas deve usar status de envio
- encerramento deve usar status de closure quando necessario
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 75 - Padronizacao dos status de atendimento",
    "- [x] Etapa 75 - Padronizacao dos status de atendimento\n- [ ] Etapa 76 - Reorganizacao visual do app inbox"
)

text = text.replace(
    "Etapa 75 - Padronizacao dos status de atendimento.",
    "Etapa 76 - Reorganizacao visual do app inbox."
)

text = text.replace(
    "Etapa 74 - Refino estrutural do modulo Atendimento.",
    "Etapa 75 - Padronizacao dos status de atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Padronizacao dos status de atendimento criada." not in text:
    text += "\nPadronizacao dos status de atendimento criada.\n"

for doc in [
    "- docs/ATTENDANCE_STATUS_STANDARDIZATION.md",
    "- docs/ATTENDANCE_STATUS_COMPATIBILITY_MAP.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 74 concluidas",
    "- Etapa 01 ate Etapa 75 concluidas"
)

text = text.replace(
    "- Etapa 75 - Padronizacao dos status de atendimento",
    "- Etapa 76 - Reorganizacao visual do app inbox"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 75 - Padronizacao dos status de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Concluida a padronizacao dos status do modulo Atendimento, com catalogo para conversation, attendance, send e closure, mapa de compatibilidade para status antigos e endpoints de consulta para backend e frontend.
DOC
  fi
done

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${DOC_COMPAT}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 75
Acao: Padronizacao dos status de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Status model status: ${DOMAIN_STATUS_MODEL_STATUS}
Status options status: ${DOMAIN_STATUS_OPTIONS_STATUS}
Status compatibility map status: ${DOMAIN_STATUS_MAP_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Database counts log: logs/setup_75_status_database_counts.log
Pages status log: logs/setup_75_pages_status.log
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Fix: Etapa 75 - Padronizacao dos status de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Motivo: primeira execucao parou antes de gerar documentacao, contagens e log final por erro de variavel.
Acao: validados endpoints, gerados documentos, contagens, setup_75.log e atualizados controle, manifesto e documentos auxiliares.
Status: Concluido
DOC

echo ""
echo "== Etapa 75 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 76 - Reorganizacao visual do app inbox"
