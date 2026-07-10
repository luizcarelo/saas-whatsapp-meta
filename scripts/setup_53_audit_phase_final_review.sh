#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_53.log"
DOC_FILE="${DOCS_DIR}/AUDIT_PHASE_FINAL_REVIEW.md"
SUMMARY_FILE="${LOGS_DIR}/setup_53_phase_summary.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_53_auth_login_domain.log"
DOMAIN_OPERATIONAL_LOG="${LOGS_DIR}/setup_53_meta_operational_domain.log"
DOMAIN_AUDIT_SUMMARY_LOG="${LOGS_DIR}/setup_53_audit_summary_domain.log"
DOMAIN_AUDIT_MESSAGES_LOG="${LOGS_DIR}/setup_53_audit_messages_domain.log"
DOMAIN_AUDIT_WEBHOOKS_LOG="${LOGS_DIR}/setup_53_audit_webhooks_domain.log"
DOMAIN_RETENTION_POLICY_LOG="${LOGS_DIR}/setup_53_retention_policy_domain.log"
DOMAIN_HYGIENE_RUNS_LOG="${LOGS_DIR}/setup_53_hygiene_runs_domain.log"
DOMAIN_HYGIENE_RUNS_CSV_LOG="${LOGS_DIR}/setup_53_hygiene_runs_csv_domain.log"

DOMAIN_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_53_domain_dashboard_page.log"
DOMAIN_META_PAGE_LOG="${LOGS_DIR}/setup_53_domain_meta_page.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_53_domain_audit_page.log"
DOMAIN_AUDIT_REAL_RUN_PAGE_LOG="${LOGS_DIR}/setup_53_domain_audit_real_run_page.log"
DOMAIN_AUDIT_REAL_HISTORY_PAGE_LOG="${LOGS_DIR}/setup_53_domain_audit_real_history_page.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ACCOUNTS_URL="${DOMAIN_BASE_URL}/api/v1/whatsapp-accounts"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"

DOMAIN_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_META_PAGE_URL="${DOMAIN_BASE_URL}/app/meta-settings"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_AUDIT_REAL_RUN_PAGE_URL="${DOMAIN_BASE_URL}/app/audit-real-run"
DOMAIN_AUDIT_REAL_HISTORY_PAGE_URL="${DOMAIN_BASE_URL}/app/audit-real-history"

echo "== Etapa 53: Encerramento e revisao final da fase operacional de auditoria =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups dos documentos de controle..."

for file in \
  "${DOC_FILE}" \
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

for tool in node curl docker; do
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

echo "Validando documentos obrigatorios da fase operacional..."

REQUIRED_DOCS=(
  "docs/META_OPERATIONAL_PANEL.md"
  "docs/OPERATIONAL_CLEANUP.md"
  "docs/OPERATIONAL_AUDIT_PANEL.md"
  "docs/OPERATIONAL_EXPORT_REPORT.md"
  "docs/AUDIT_DATA_HYGIENE.md"
  "docs/RETENTION_POLICY_VISUAL_CONFIG.md"
  "docs/RETENTION_POLICY_BACKEND.md"
  "docs/CONTROLLED_REAL_HYGIENE.md"
  "docs/REAL_HYGIENE_HISTORY.md"
  "docs/REAL_HYGIENE_HISTORY_CSV_EXPORT.md"
)

: > "${SUMMARY_FILE}"

echo "Documentos da fase:" | tee -a "${SUMMARY_FILE}"

for doc in "${REQUIRED_DOCS[@]}"; do
  if [ ! -f "${BASE_DIR}/${doc}" ]; then
    echo "ERRO: documento obrigatorio ausente: ${doc}"
    exit 1
  fi

  echo "OK: ${doc}" | tee -a "${SUMMARY_FILE}"
done

echo "" | tee -a "${SUMMARY_FILE}"
echo "Validando logs principais das etapas 43 a 52..." | tee -a "${SUMMARY_FILE}"

for step in 43 44 45 46 47 48 49 50 51 52; do
  step_log="${LOGS_DIR}/setup_${step}.log"

  if [ ! -f "${step_log}" ]; then
    echo "ERRO: log ausente: ${step_log}"
    exit 1
  fi

  if ! grep -q "Status: Concluido" "${step_log}"; then
    echo "ERRO: log nao indica conclusao: ${step_log}"
    cat "${step_log}"
    exit 1
  fi

  echo "OK: logs/setup_${step}.log" | tee -a "${SUMMARY_FILE}"
done

echo "" | tee -a "${SUMMARY_FILE}"
echo "Validando containers..." | tee -a "${SUMMARY_FILE}"

docker compose ps | tee -a "${SUMMARY_FILE}"

echo "Validando dominio e endpoints finais..."

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

ACCOUNTS_LOG="${LOGS_DIR}/setup_53_accounts_domain.log"

DOMAIN_ACCOUNTS_STATUS="$(curl -L -s -o "${ACCOUNTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_STATUS}" != "200" ]; then
  echo "ERRO: accounts dominio falhou. Status ${DOMAIN_ACCOUNTS_STATUS}"
  cat "${ACCOUNTS_LOG}"
  exit 1
fi

ACCOUNT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const accounts=(data.data&&data.data.accounts)||[]; const active=accounts.find((item)=>item.status==='active') || accounts[0]; if(!active){process.exit(2)} console.log(active.id)" "${ACCOUNTS_LOG}" || true)"

if [ -z "${ACCOUNT_ID}" ]; then
  echo "ERRO: nenhuma conta WhatsApp encontrada para validacao operacional."
  cat "${ACCOUNTS_LOG}"
  exit 1
fi

DOMAIN_OPERATIONAL_STATUS="$(curl -L -s -o "${DOMAIN_OPERATIONAL_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}/${ACCOUNT_ID}/operational" || true)"

if [ "${DOMAIN_OPERATIONAL_STATUS}" != "200" ]; then
  echo "ERRO: operational dominio falhou. Status ${DOMAIN_OPERATIONAL_STATUS}"
  cat "${DOMAIN_OPERATIONAL_LOG}"
  exit 1
fi

DOMAIN_AUDIT_SUMMARY_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_SUMMARY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/summary" || true)"

if [ "${DOMAIN_AUDIT_SUMMARY_STATUS}" != "200" ]; then
  echo "ERRO: audit summary falhou. Status ${DOMAIN_AUDIT_SUMMARY_STATUS}"
  cat "${DOMAIN_AUDIT_SUMMARY_LOG}"
  exit 1
fi

DOMAIN_AUDIT_MESSAGES_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_MESSAGES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/messages?limit=10" || true)"

if [ "${DOMAIN_AUDIT_MESSAGES_STATUS}" != "200" ]; then
  echo "ERRO: audit messages falhou. Status ${DOMAIN_AUDIT_MESSAGES_STATUS}"
  cat "${DOMAIN_AUDIT_MESSAGES_LOG}"
  exit 1
fi

DOMAIN_AUDIT_WEBHOOKS_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_WEBHOOKS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/webhooks?limit=10" || true)"

if [ "${DOMAIN_AUDIT_WEBHOOKS_STATUS}" != "200" ]; then
  echo "ERRO: audit webhooks falhou. Status ${DOMAIN_AUDIT_WEBHOOKS_STATUS}"
  cat "${DOMAIN_AUDIT_WEBHOOKS_LOG}"
  exit 1
fi

DOMAIN_RETENTION_POLICY_STATUS="$(curl -L -s -o "${DOMAIN_RETENTION_POLICY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/retention-policy" || true)"

if [ "${DOMAIN_RETENTION_POLICY_STATUS}" != "200" ]; then
  echo "ERRO: retention policy falhou. Status ${DOMAIN_RETENTION_POLICY_STATUS}"
  cat "${DOMAIN_RETENTION_POLICY_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_RUNS_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_RUNS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/hygiene-runs" || true)"

if [ "${DOMAIN_HYGIENE_RUNS_STATUS}" != "200" ]; then
  echo "ERRO: hygiene runs falhou. Status ${DOMAIN_HYGIENE_RUNS_STATUS}"
  cat "${DOMAIN_HYGIENE_RUNS_LOG}"
  exit 1
fi

DOMAIN_HYGIENE_RUNS_CSV_STATUS="$(curl -L -s -o "${DOMAIN_HYGIENE_RUNS_CSV_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/hygiene-runs/export" || true)"

if [ "${DOMAIN_HYGIENE_RUNS_CSV_STATUS}" != "200" ]; then
  echo "ERRO: hygiene runs csv falhou. Status ${DOMAIN_HYGIENE_RUNS_CSV_STATUS}"
  cat "${DOMAIN_HYGIENE_RUNS_CSV_LOG}"
  exit 1
fi

if ! head -n 1 "${DOMAIN_HYGIENE_RUNS_CSV_LOG}" | grep -q "retentionDays"; then
  echo "ERRO: CSV do historico nao contem retentionDays."
  head -n 5 "${DOMAIN_HYGIENE_RUNS_CSV_LOG}"
  exit 1
fi

echo "Validando rotas frontend finais..."

DOMAIN_DASHBOARD_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_PAGE_URL}" || true)"

DOMAIN_META_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_META_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_META_PAGE_URL}" || true)"

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

DOMAIN_AUDIT_REAL_RUN_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_REAL_RUN_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_REAL_RUN_PAGE_URL}" || true)"

DOMAIN_AUDIT_REAL_HISTORY_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_REAL_HISTORY_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_REAL_HISTORY_PAGE_URL}" || true)"

for item in \
  "dashboard:${DOMAIN_DASHBOARD_PAGE_STATUS}" \
  "meta:${DOMAIN_META_PAGE_STATUS}" \
  "audit:${DOMAIN_AUDIT_PAGE_STATUS}" \
  "audit-real-run:${DOMAIN_AUDIT_REAL_RUN_PAGE_STATUS}" \
  "audit-real-history:${DOMAIN_AUDIT_REAL_HISTORY_PAGE_STATUS}"
do
  name="${item%%:*}"
  status="${item##*:}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: rota ${name} retornou status ${status}"
    exit 1
  fi
done

echo "" | tee -a "${SUMMARY_FILE}"
echo "Status dos endpoints finais:" | tee -a "${SUMMARY_FILE}"
echo "Login: ${DOMAIN_LOGIN_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Accounts: ${DOMAIN_ACCOUNTS_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Operational: ${DOMAIN_OPERATIONAL_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Audit summary: ${DOMAIN_AUDIT_SUMMARY_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Audit messages: ${DOMAIN_AUDIT_MESSAGES_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Audit webhooks: ${DOMAIN_AUDIT_WEBHOOKS_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Retention policy: ${DOMAIN_RETENTION_POLICY_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Hygiene runs: ${DOMAIN_HYGIENE_RUNS_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Hygiene runs CSV: ${DOMAIN_HYGIENE_RUNS_CSV_STATUS}" | tee -a "${SUMMARY_FILE}"

echo "" | tee -a "${SUMMARY_FILE}"
echo "Status das telas finais:" | tee -a "${SUMMARY_FILE}"
echo "Dashboard: ${DOMAIN_DASHBOARD_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Meta settings: ${DOMAIN_META_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Audit: ${DOMAIN_AUDIT_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Audit real run: ${DOMAIN_AUDIT_REAL_RUN_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"
echo "Audit real history: ${DOMAIN_AUDIT_REAL_HISTORY_PAGE_STATUS}" | tee -a "${SUMMARY_FILE}"

echo "Gerando documentacao da Etapa 53..."

cat > "${DOC_FILE}" <<'DOC'
# Audit Phase Final Review

## Visao geral

Este documento registra o encerramento e revisao final da fase operacional de auditoria.

## Resultado

Status:

    concluido

## Escopo revisado

Escopo:

- painel operacional da Meta
- limpeza operacional de dados de teste
- painel de auditoria operacional
- relatorios operacionais exportaveis
- higienizacao segura de dados antigos
- politica visual de retencao
- persistencia backend da politica de retencao por tenant
- execucao real controlada de higienizacao
- historico de execucoes reais
- exportacao CSV do historico de higienizacoes reais

## Documentos revisados

Documentos:

- docs/META_OPERATIONAL_PANEL.md
- docs/OPERATIONAL_CLEANUP.md
- docs/OPERATIONAL_AUDIT_PANEL.md
- docs/OPERATIONAL_EXPORT_REPORT.md
- docs/AUDIT_DATA_HYGIENE.md
- docs/RETENTION_POLICY_VISUAL_CONFIG.md
- docs/RETENTION_POLICY_BACKEND.md
- docs/CONTROLLED_REAL_HYGIENE.md
- docs/REAL_HYGIENE_HISTORY.md
- docs/REAL_HYGIENE_HISTORY_CSV_EXPORT.md

## Validacoes executadas

Validacoes:

- existencia dos documentos da fase
- logs setup 43 ate setup 52 com Status Concluido
- docker compose ps
- login dominio
- listagem de contas WhatsApp
- painel operacional da Meta
- audit summary
- audit messages
- audit webhooks
- retention policy
- hygiene runs
- hygiene runs CSV
- rota app dashboard
- rota app meta settings
- rota app audit
- rota app audit real run
- rota app audit real history

## Logs gerados

Logs:

- logs/setup_53_phase_summary.log
- logs/setup_53_auth_login_domain.log
- logs/setup_53_accounts_domain.log
- logs/setup_53_meta_operational_domain.log
- logs/setup_53_audit_summary_domain.log
- logs/setup_53_audit_messages_domain.log
- logs/setup_53_audit_webhooks_domain.log
- logs/setup_53_retention_policy_domain.log
- logs/setup_53_hygiene_runs_domain.log
- logs/setup_53_hygiene_runs_csv_domain.log
- logs/setup_53_domain_dashboard_page.log
- logs/setup_53_domain_meta_page.log
- logs/setup_53_domain_audit_page.log
- logs/setup_53_domain_audit_real_run_page.log
- logs/setup_53_domain_audit_real_history_page.log
- logs/setup_53.log

## Conclusao

A fase operacional de auditoria foi encerrada com sucesso.

A fase contempla monitoramento, exportacao, higienizacao segura, execucao real controlada e historico auditavel.

## Proxima etapa sugerida

Etapa 54:

    Planejar proxima fase funcional do produto
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
- [x] Etapa 46 - Relatorio operacional exportavel
- [x] Etapa 47 - Higienizacao de dados de auditoria antigos
- [x] Etapa 48 - Configuracao visual de politica de retencao
- [x] Etapa 49 - Persistencia backend da politica de retencao por tenant
- [x] Etapa 50 - Execucao operacional controlada de higienizacao real
- [x] Etapa 51 - Relatorio historico das execucoes reais de higienizacao
- [x] Etapa 52 - Exportacao CSV do historico de higienizacoes reais
- [x] Etapa 53 - Encerramento e revisao final da fase operacional de auditoria
- [ ] Etapa 54 - Planejamento da proxima fase funcional do produto

## Ultima etapa executada

Etapa 53 - Encerramento e revisao final da fase operacional de auditoria.

## Proxima etapa sugerida

Etapa 54 - Planejar proxima fase funcional do produto.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto do Projeto

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

Estrutura real do monorepo criada.

Backend base criado.

Frontend base criado.

Docker Compose inicial criado.

Env example criado.

Ambiente inicial validado.

Dependencias base instaladas e validadas.

Dockerfiles ajustados e builds validados.

Dominio bot.lhsolucao.com.br configurado e testado.

Backend real inicial iniciado.

Prisma configurado com conexao real ao PostgreSQL.

Schema inicial do banco criado.

Seed inicial criado.

Auth inicial com login real criado.

Frontend login integrado criado.

Layout base e protecao visual de rotas criados.

Modulo backend de usuarios criado.

Frontend com perfil detalhado criado.

Modulo backend de contatos criado.

Frontend de contatos integrado criado.

Frontend de conversas com layout inicial criado.

Modulo backend de conversas criado.

Frontend de conversas integrado ao backend criado.

Modulo backend de WhatsApp Accounts criado.

Frontend de WhatsApp Accounts integrado criado.

Modulo backend de webhooks da Meta criado.

Validacao de assinatura dos webhooks da Meta criada.

Processamento de status de mensagens no frontend criado.

Envio real de mensagens pela API oficial da Meta criado.

Suporte a templates oficiais da Meta criado.

Frontend para envio de templates oficiais criado.

Painel de configuracao operacional da conta Meta criado.

Limpeza operacional de dados de teste criada.

Painel de auditoria operacional criado.

Relatorio operacional exportavel criado.

Higienizacao de dados de auditoria antigos criada.

Configuracao visual de politica de retencao criada.

Persistencia backend da politica de retencao por tenant criada.

Execucao operacional controlada de higienizacao real criada.

Relatorio historico das execucoes reais de higienizacao criado.

Exportacao CSV do historico de higienizacoes reais criada.

Encerramento e revisao final da fase operacional de auditoria concluida.

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml
- .env.example
- .env
- .dockerignore

## Documentos tecnicos

- docs/AUDIT_PHASE_FINAL_REVIEW.md
- docs/REAL_HYGIENE_HISTORY_CSV_EXPORT.md
- docs/REAL_HYGIENE_HISTORY.md
- docs/CONTROLLED_REAL_HYGIENE.md
- docs/RETENTION_POLICY_BACKEND.md
- docs/RETENTION_POLICY_VISUAL_CONFIG.md
- docs/AUDIT_DATA_HYGIENE.md
- docs/OPERATIONAL_EXPORT_REPORT.md
- docs/OPERATIONAL_AUDIT_PANEL.md
- docs/OPERATIONAL_CLEANUP.md
- docs/META_OPERATIONAL_PANEL.md
- docs/FRONTEND_META_TEMPLATES.md
- docs/BACKEND_META_TEMPLATES.md
- docs/BACKEND_META_SEND_MESSAGES.md
- docs/FRONTEND_MESSAGE_STATUS.md
- docs/BACKEND_META_WEBHOOK_SIGNATURE.md
- docs/BACKEND_META_WEBHOOKS.md
- docs/FRONTEND_WHATSAPP_ACCOUNTS.md
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- docs/FRONTEND_CONVERSATIONS_INTEGRADO.md
- docs/BACKEND_CONVERSATIONS.md
- docs/FRONTEND_CONVERSATIONS_LAYOUT.md
- docs/FRONTEND_CONTACTS.md
- docs/BACKEND_CONTACTS.md
- docs/FRONTEND_PROFILE_DETALHADO.md
- docs/BACKEND_USERS_PROFILE.md
- docs/FRONTEND_LAYOUT_PROTECAO_ROTAS.md
- docs/FRONTEND_LOGIN_INTEGRADO.md
- docs/AUTH_LOGIN_REAL.md
- docs/SEED_INICIAL.md
- docs/PRISMA_SCHEMA_INICIAL.md
- docs/BACKEND_PRISMA_POSTGRES.md
- docs/BACKEND_HEALTH_CONFIG_DATABASE.md
- docs/EXECUCAO_INICIAL_DOMINIO.md
- docs/NGINX_BOT_LHSOLUCAO.md
- docs/DOCKER_BUILD.md
- docs/DEPENDENCIAS_BASE.md
- docs/VALIDACAO_AMBIENTE.md
- docs/ENV_EXAMPLE.md
- docs/DOCKER_COMPOSE_BASE.md
- docs/FRONTEND_BASE.md
- docs/BACKEND_BASE.md
- docs/ESTRUTURA_PROJETO.md
- docs/VALIDACAO_FINAL.md
- docs/DEPLOY.md
- docs/BACKEND.md
- docs/FRONTEND.md
- docs/WEBHOOKS_META.md
- docs/SEGURANCA.md
- docs/API.md
- docs/BANCO_DADOS.md
- docs/ARQUITETURA.md

## Etapas concluidas

- Etapa 01 ate Etapa 53 concluidas

## Proxima etapa

- Etapa 54 - Planejamento da proxima fase funcional do produto
DOC

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 53 - Encerramento e revisao final da fase operacional de auditoria
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Revisada e encerrada a fase operacional de auditoria, validando documentos, logs, endpoints e telas principais da fase.
DOC
  fi
done

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
Etapa: 53
Acao: Encerramento e revisao final da fase operacional de auditoria
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Accounts status: ${DOMAIN_ACCOUNTS_STATUS}
Operational status: ${DOMAIN_OPERATIONAL_STATUS}
Audit summary status: ${DOMAIN_AUDIT_SUMMARY_STATUS}
Audit messages status: ${DOMAIN_AUDIT_MESSAGES_STATUS}
Audit webhooks status: ${DOMAIN_AUDIT_WEBHOOKS_STATUS}
Retention policy status: ${DOMAIN_RETENTION_POLICY_STATUS}
Hygiene runs status: ${DOMAIN_HYGIENE_RUNS_STATUS}
Hygiene runs CSV status: ${DOMAIN_HYGIENE_RUNS_CSV_STATUS}
Dashboard page status: ${DOMAIN_DASHBOARD_PAGE_STATUS}
Meta page status: ${DOMAIN_META_PAGE_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Audit real run page status: ${DOMAIN_AUDIT_REAL_RUN_PAGE_STATUS}
Audit real history page status: ${DOMAIN_AUDIT_REAL_HISTORY_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 53 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Resumo tecnico:"
cat "${SUMMARY_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 54 - Planejar proxima fase funcional do produto"
