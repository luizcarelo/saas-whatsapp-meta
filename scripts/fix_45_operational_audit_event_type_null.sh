#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_45.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_45_operational_audit_event_type_null.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_45_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_45_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_45_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_45_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_45_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_45_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_45_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_45_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_45_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_45_auth_login_domain.log"
DOMAIN_SUMMARY_LOG="${LOGS_DIR}/setup_45_audit_summary_domain.log"
DOMAIN_MESSAGES_LOG="${LOGS_DIR}/setup_45_audit_messages_domain.log"
DOMAIN_WEBHOOKS_LOG="${LOGS_DIR}/setup_45_audit_webhooks_domain.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_45_domain_audit_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_45_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/OPERATIONAL_AUDIT_PANEL.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Fix Etapa 45: eventType nulo em auditoria de webhooks =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.types.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
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

for tool in node npm docker curl; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ] || [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: credenciais admin incompletas."
  exit 1
fi

echo "Corrigindo eventType nulo no service de auditoria..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/operational-audit/operational-audit.service.ts")
text = path.read_text()

text = text.replace(
    "eventType: event.eventType,",
    "eventType: event.eventType || 'unknown',"
)

path.write_text(text)
PY

echo "Validando se a correcao foi aplicada..."

if ! grep -q "eventType: event.eventType || 'unknown'," "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts"; then
  echo "ERRO: correcao de eventType nao foi aplicada."
  exit 1
fi

echo "Validando backend sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/operational-audit" \
  "${BACKEND_DIR}/src/app.module.ts"
then
  echo "ERRO: HTML indevido encontrado no backend."
  exit 1
fi

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${BACKEND_TYPECHECK_LOG}"

echo "Rodando build do backend..."

npm run build 2>&1 | tee "${BACKEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BACKEND_BUILD_LOG}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_FRONTEND_BUILD_LOG}"

echo "Subindo backend, frontend e proxy..."

docker compose up -d backend frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

echo "Aguardando backend estabilizar..."

: > "${BACKEND_WAIT_LOG}"

BACKEND_READY="false"

for i in $(seq 1 30); do
  STATUS="$(docker inspect -f '{{.State.Status}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"
  RESTARTING="$(docker inspect -f '{{.State.Restarting}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"

  echo "tentativa=${i} status=${STATUS} restarting=${RESTARTING}" | tee -a "${BACKEND_WAIT_LOG}"

  if [ "${STATUS}" = "running" ] && [ "${RESTARTING}" = "false" ]; then
    if curl -s --max-time 5 "http://127.0.0.1:3300/api/v1/health" >/dev/null 2>&1; then
      BACKEND_READY="true"
      break
    fi
  fi

  sleep 3
done

if [ "${BACKEND_READY}" != "true" ]; then
  echo "ERRO: backend nao estabilizou."
  docker compose logs --tail=220 backend 2>&1 | tee "${BACKEND_CRASH_LOG}"
  exit 1
fi

sleep 8

echo "Validando dominio..."

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

DOMAIN_SUMMARY_STATUS="$(curl -L -s -o "${DOMAIN_SUMMARY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/summary" || true)"

if [ "${DOMAIN_SUMMARY_STATUS}" != "200" ]; then
  echo "ERRO: summary dominio falhou. Status ${DOMAIN_SUMMARY_STATUS}"
  cat "${DOMAIN_SUMMARY_LOG}"
  exit 1
fi

if ! grep -q "messages" "${DOMAIN_SUMMARY_LOG}"; then
  echo "ERRO: summary nao retornou messages."
  cat "${DOMAIN_SUMMARY_LOG}"
  exit 1
fi

DOMAIN_MESSAGES_STATUS="$(curl -L -s -o "${DOMAIN_MESSAGES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/messages?limit=20" || true)"

if [ "${DOMAIN_MESSAGES_STATUS}" != "200" ]; then
  echo "ERRO: messages dominio falhou. Status ${DOMAIN_MESSAGES_STATUS}"
  cat "${DOMAIN_MESSAGES_LOG}"
  exit 1
fi

if ! grep -q "messages" "${DOMAIN_MESSAGES_LOG}"; then
  echo "ERRO: messages nao retornou messages."
  cat "${DOMAIN_MESSAGES_LOG}"
  exit 1
fi

DOMAIN_WEBHOOKS_STATUS="$(curl -L -s -o "${DOMAIN_WEBHOOKS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/webhooks?limit=20" || true)"

if [ "${DOMAIN_WEBHOOKS_STATUS}" != "200" ]; then
  echo "ERRO: webhooks dominio falhou. Status ${DOMAIN_WEBHOOKS_STATUS}"
  cat "${DOMAIN_WEBHOOKS_LOG}"
  exit 1
fi

if ! grep -q "webhooks" "${DOMAIN_WEBHOOKS_LOG}"; then
  echo "ERRO: webhooks nao retornou webhooks."
  cat "${DOMAIN_WEBHOOKS_LOG}"
  exit 1
fi

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina audit nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 45..."

cat > "${DOC_FILE}" <<'DOC'
# Operational Audit Panel

## Visao geral

Este documento registra a criacao do painel de auditoria operacional.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi corrigido o tratamento de webhooks com eventType nulo.

Quando eventType vier nulo do banco, a API retorna unknown para evitar falha de tipagem e quebra do painel.

## Funcionalidades criadas

Funcionalidades:

- endpoint de resumo operacional
- endpoint de mensagens recentes
- endpoint de webhooks recentes
- tela frontend em app audit
- cards com totais de mensagens
- cards com totais de webhooks
- filtro por status, direcao e tipo de mensagem
- filtro por status e tipo de webhook
- exibicao de providerMessageId
- exibicao de erro Meta sem expor token
- link Auditoria na sidebar

## Endpoints criados

Endpoints:

- GET api v1 operational audit summary
- GET api v1 operational audit messages
- GET api v1 operational audit webhooks

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/operational-audit/operational-audit.module.ts
- apps/backend/src/modules/operational-audit/operational-audit.controller.ts
- apps/backend/src/modules/operational-audit/operational-audit.service.ts
- apps/backend/src/modules/operational-audit/operational-audit.types.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit/AuditPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/OPERATIONAL_AUDIT_PANEL.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- aguardo ativo do backend
- login dominio
- endpoint summary dominio
- endpoint messages dominio
- endpoint webhooks dominio
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_45_backend_typecheck.log
- logs/setup_45_backend_build.log
- logs/setup_45_frontend_typecheck.log
- logs/setup_45_frontend_build.log
- logs/setup_45_backend_docker_build.log
- logs/setup_45_frontend_docker_build.log
- logs/setup_45_docker_up.log
- logs/setup_45_backend_wait.log
- logs/setup_45_auth_login_domain.log
- logs/setup_45_audit_summary_domain.log
- logs/setup_45_audit_messages_domain.log
- logs/setup_45_audit_webhooks_domain.log
- logs/setup_45_domain_audit_page.log
- logs/setup_45_domain_dashboard.log
- logs/setup_45.log
- logs/fix_45_operational_audit_event_type_null.log

## Proxima etapa sugerida

Etapa 46:

    Criar relatorio operacional exportavel
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Fase 01 - Documentacao inicial

- [x] Etapa 01 - Preparacao do ambiente de documentacao
- [x] Etapa 02 - Criacao do README principal
- [x] Etapa 03 - Documentacao de arquitetura
- [x] Etapa 04 - Documentacao do banco de dados
- [x] Etapa 05 - Documentacao da API
- [x] Etapa 06 - Documentacao de seguranca
- [x] Etapa 07 - Documentacao de webhooks da Meta
- [x] Etapa 08 - Documentacao do frontend
- [x] Etapa 09 - Documentacao do backend
- [x] Etapa 10 - Documentacao de deploy
- [x] Etapa 11 - Manifesto final e validacao

## Fase 02 - Estrutura real do projeto

- [x] Etapa 12 - Estrutura de pastas do monorepo
- [x] Etapa 13 - Arquivos base do backend
- [x] Etapa 14 - Arquivos base do frontend
- [x] Etapa 15 - Docker Compose inicial
- [x] Etapa 16 - Arquivo env example
- [x] Etapa 17 - Validacao do ambiente inicial
- [x] Etapa 18 - Instalacao e validacao de dependencias

## Fase 03 - Build e execucao inicial com Docker

- [x] Etapa 19 - Ajustar Dockerfiles e validar build dos containers
- [x] Etapa 20A - Auditoria e backup do Nginx
- [x] Etapa 20B - Configurar Nginx para bot.lhsolucao.com.br
- [x] Etapa 20C - Subir containers e testar dominio

## Fase 04 - Backend real inicial

- [x] Etapa 21 - Health, configuracao e database base
- [x] Etapa 22 - ORM e conexao real com PostgreSQL
- [x] Etapa 23 - Schema inicial do banco com Prisma
- [x] Etapa 24 - Seed inicial de tenant, admin, roles e permissoes
- [x] Etapa 25 - Auth inicial com login real

## Fase 05 - Frontend integrado inicial

- [x] Etapa 26 - Frontend login integrado
- [x] Etapa 27 - Protecao visual de rotas e layout base

## Fase 06 - Usuarios e perfil

- [x] Etapa 28 - Modulo backend de usuarios
- [x] Etapa 29 - Frontend com perfil detalhado

## Fase 07 - Contatos

- [x] Etapa 30 - Modulo backend de contatos
- [x] Etapa 31 - Frontend de contatos integrado

## Fase 08 - Conversas

- [x] Etapa 32 - Frontend de conversas com layout inicial
- [x] Etapa 33 - Modulo backend de conversas
- [x] Etapa 34 - Frontend de conversas integrado ao backend

## Fase 09 - WhatsApp

- [x] Etapa 35 - Modulo backend de WhatsApp Accounts
- [x] Etapa 36 - Frontend de WhatsApp Accounts integrado
- [x] Etapa 37 - Modulo backend de webhooks da Meta
- [x] Etapa 38 - Validacao de assinatura dos webhooks da Meta
- [x] Etapa 39 - Processamento de status no frontend
- [x] Etapa 40 - Envio real pela API oficial da Meta
- [x] Etapa 41 - Templates oficiais da Meta
- [x] Etapa 42 - Frontend para templates oficiais
- [x] Etapa 43 - Painel de configuracao operacional da conta Meta
- [x] Etapa 44 - Limpeza operacional de dados de teste
- [x] Etapa 45 - Painel de auditoria operacional
- [ ] Etapa 46 - Relatorio operacional exportavel

## Ultima etapa executada

Etapa 45 - Painel de auditoria operacional.

## Proxima etapa sugerida

Etapa 46 - Criar relatorio operacional exportavel.
DOC

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Painel de auditoria operacional criado." not in text:
    text = text.replace(
        "Limpeza operacional de dados de teste criada.",
        "Limpeza operacional de dados de teste criada.\n\nPainel de auditoria operacional criado."
    )

if "- docs/OPERATIONAL_AUDIT_PANEL.md" not in text:
    text = text.replace(
        "- docs/OPERATIONAL_CLEANUP.md",
        "- docs/OPERATIONAL_CLEANUP.md\n- docs/OPERATIONAL_AUDIT_PANEL.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 44 concluidas",
    "- Etapa 01 ate Etapa 45 concluidas"
)

text = text.replace(
    "- Etapa 45 - Painel de auditoria operacional",
    "- Etapa 46 - Relatorio operacional exportavel"
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

cat > "${LOG_FILE}" <<DOC
Etapa: 45
Acao: Painel de auditoria operacional
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Summary status: ${DOMAIN_SUMMARY_STATUS}
Messages status: ${DOMAIN_MESSAGES_STATUS}
Webhooks status: ${DOMAIN_WEBHOOKS_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 45
Acao: Correcao eventType nulo em auditoria operacional
Data: $(date '+%Y-%m-%d %H:%M:%S')
Status: Concluido
DOC

echo ""
echo "== Etapa 45 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/audit"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 46 - Criar relatorio operacional exportavel"
