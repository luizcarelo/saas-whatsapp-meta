#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_44.log"
DB_BACKUP_FILE="${BACKUPS_DIR}/setup_44_before_cleanup_${STAMP}.sql"
SQL_FILE="${LOGS_DIR}/setup_44_cleanup.sql"
BEFORE_LOG="${LOGS_DIR}/setup_44_before_counts.log"
AFTER_LOG="${LOGS_DIR}/setup_44_after_counts.log"
REAL_ACCOUNT_LOG="${LOGS_DIR}/setup_44_real_account.log"
CLEANUP_LOG="${LOGS_DIR}/setup_44_cleanup_execution.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_44_auth_login_domain.log"
DOMAIN_ACCOUNTS_LOG="${LOGS_DIR}/setup_44_accounts_domain.log"
DOMAIN_OPERATIONAL_LOG="${LOGS_DIR}/setup_44_operational_domain.log"
DOMAIN_CONVERSATIONS_LOG="${LOGS_DIR}/setup_44_conversations_domain.log"
DOMAIN_META_PAGE_LOG="${LOGS_DIR}/setup_44_meta_settings_page.log"
DOMAIN_CONVERSATIONS_PAGE_LOG="${LOGS_DIR}/setup_44_conversations_page.log"
DOC_FILE="${DOCS_DIR}/OPERATIONAL_CLEANUP.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ACCOUNTS_URL="${DOMAIN_BASE_URL}/api/v1/whatsapp-accounts"
DOMAIN_CONVERSATIONS_URL="${DOMAIN_BASE_URL}/api/v1/conversations"
DOMAIN_META_PAGE_URL="${DOMAIN_BASE_URL}/app/meta-settings"
DOMAIN_CONVERSATIONS_PAGE_URL="${DOMAIN_BASE_URL}/app/conversations"

REAL_PHONE_NUMBER_ID="1235882016268785"
REAL_WABA_ID="1568724001636783"
REAL_VERIFIED_NAME="Test Number"

echo "== Etapa 44: Limpeza operacional de dados de teste =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando ferramentas..."

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERRO: curl nao encontrado."
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "ERRO: node nao encontrado."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ]; then
  echo "ERRO: email admin nao encontrado."
  exit 1
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: senha admin nao encontrada."
  exit 1
fi

echo "Validando containers..."

docker compose ps

if ! docker compose exec -T postgres pg_isready -U saas_user -d saas_whatsapp >/dev/null 2>&1; then
  echo "ERRO: PostgreSQL nao esta pronto."
  exit 1
fi

echo "Criando backup SQL antes da limpeza..."

docker compose exec -T postgres pg_dump -U saas_user -d saas_whatsapp > "${DB_BACKUP_FILE}"

if [ ! -s "${DB_BACKUP_FILE}" ]; then
  echo "ERRO: backup SQL nao foi gerado corretamente."
  exit 1
fi

echo "Validando conta real da Meta no banco..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 -c "
select
  id,
  waba_id,
  phone_number_id,
  display_phone_number,
  verified_name,
  status,
  deleted_at
from whatsapp_accounts
where phone_number_id = '${REAL_PHONE_NUMBER_ID}';
" 2>&1 | tee "${REAL_ACCOUNT_LOG}"

if ! grep -q "${REAL_PHONE_NUMBER_ID}" "${REAL_ACCOUNT_LOG}"; then
  echo "ERRO: conta real ${REAL_PHONE_NUMBER_ID} nao encontrada no banco."
  exit 1
fi

echo "Coletando contagens antes da limpeza..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 -c "
select count(*) as whatsapp_accounts_total from whatsapp_accounts;
select count(*) as whatsapp_accounts_active from whatsapp_accounts where deleted_at is null and status = 'active';
select count(*) as whatsapp_accounts_fake_candidates
from whatsapp_accounts
where deleted_at is null
and phone_number_id <> '${REAL_PHONE_NUMBER_ID}'
and (
  waba_id like 'restore_%'
  or phone_number_id like 'restore_%'
  or waba_id = 'webhook_auto_waba'
  or phone_number_id like 'phone_signature_%'
  or phone_number_id like 'phone_webhook_%'
  or waba_id like 'frontend_%'
  or phone_number_id like 'frontend_%'
  or waba_id like 'domain_%'
  or phone_number_id like 'domain_%'
  or waba_id = 'local_default_waba'
  or phone_number_id = 'local_default_phone_number'
  or verified_name ilike '%restore%'
  or verified_name ilike '%frontend%'
  or verified_name ilike '%dominio%'
  or verified_name ilike '%detectada por webhook%'
);
select count(*) as conversations_total from conversations;
select count(*) as conversations_test_candidates
from conversations c
left join contacts ct on ct.id = c.contact_id
where c.deleted_at is null
and (
  coalesce(ct.name, '') ilike '%etapa%'
  or coalesce(ct.name, '') ilike '%teste%'
  or coalesce(ct.name, '') ilike '%restore%'
  or coalesce(ct.name, '') ilike '%template%'
  or exists (
    select 1
    from messages m
    where m.conversation_id = c.id
    and (
      coalesce(m.body, '') ilike '%etapa%'
      or coalesce(m.body, '') ilike '%teste%'
      or coalesce(m.body, '') ilike '%template%'
      or coalesce(m.body, '') ilike '%lh solucao%'
      or coalesce(m.body, '') ilike '%webhook fix%'
      or coalesce(m.body, '') ilike '%frontend%'
      or coalesce(m.body, '') ilike '%dominio%'
    )
  )
);
" 2>&1 | tee "${BEFORE_LOG}"

echo "Gerando SQL de limpeza..."

cat > "${SQL_FILE}" <<SQL
begin;

do \$\$
declare
  real_account_count integer;
begin
  select count(*)
  into real_account_count
  from whatsapp_accounts
  where phone_number_id = '${REAL_PHONE_NUMBER_ID}'
  and deleted_at is null;

  if real_account_count <> 1 then
    raise exception 'Conta real ativa esperada nao encontrada ou duplicada para phone_number_id ${REAL_PHONE_NUMBER_ID}. Total: %', real_account_count;
  end if;
end
\$\$;

update whatsapp_accounts
set
  deleted_at = now(),
  status = 'inactive',
  updated_at = now()
where deleted_at is null
and phone_number_id <> '${REAL_PHONE_NUMBER_ID}'
and (
  waba_id like 'restore_%'
  or phone_number_id like 'restore_%'
  or waba_id = 'webhook_auto_waba'
  or phone_number_id like 'phone_signature_%'
  or phone_number_id like 'phone_webhook_%'
  or waba_id like 'frontend_%'
  or phone_number_id like 'frontend_%'
  or waba_id like 'domain_%'
  or phone_number_id like 'domain_%'
  or waba_id = 'local_default_waba'
  or phone_number_id = 'local_default_phone_number'
  or verified_name ilike '%restore%'
  or verified_name ilike '%frontend%'
  or verified_name ilike '%dominio%'
  or verified_name ilike '%detectada por webhook%'
);

update conversations c
set
  deleted_at = now(),
  status = 'closed',
  closed_at = coalesce(c.closed_at, now()),
  updated_at = now()
from contacts ct
where c.contact_id = ct.id
and c.deleted_at is null
and (
  coalesce(ct.name, '') ilike '%etapa%'
  or coalesce(ct.name, '') ilike '%teste%'
  or coalesce(ct.name, '') ilike '%restore%'
  or coalesce(ct.name, '') ilike '%template%'
  or exists (
    select 1
    from messages m
    where m.conversation_id = c.id
    and (
      coalesce(m.body, '') ilike '%etapa%'
      or coalesce(m.body, '') ilike '%teste%'
      or coalesce(m.body, '') ilike '%template%'
      or coalesce(m.body, '') ilike '%lh solucao%'
      or coalesce(m.body, '') ilike '%webhook fix%'
      or coalesce(m.body, '') ilike '%frontend%'
      or coalesce(m.body, '') ilike '%dominio%'
    )
  )
);

update whatsapp_accounts
set
  waba_id = '${REAL_WABA_ID}',
  verified_name = '${REAL_VERIFIED_NAME}',
  display_phone_number = '+1 555-158-8463',
  status = 'active',
  deleted_at = null,
  updated_at = now()
where phone_number_id = '${REAL_PHONE_NUMBER_ID}';

commit;
SQL

echo "Executando limpeza operacional..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 < "${SQL_FILE}" 2>&1 | tee "${CLEANUP_LOG}"

echo "Coletando contagens depois da limpeza..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 -c "
select count(*) as whatsapp_accounts_total from whatsapp_accounts;
select count(*) as whatsapp_accounts_active from whatsapp_accounts where deleted_at is null and status = 'active';
select
  id,
  waba_id,
  phone_number_id,
  display_phone_number,
  verified_name,
  status,
  deleted_at
from whatsapp_accounts
where deleted_at is null
order by updated_at desc;
select count(*) as conversations_visible from conversations where deleted_at is null;
select count(*) as conversations_deleted from conversations where deleted_at is not null;
" 2>&1 | tee "${AFTER_LOG}"

echo "Validando dominio apos limpeza..."

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

DOMAIN_ACCOUNTS_STATUS="$(curl -L -s -o "${DOMAIN_ACCOUNTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_STATUS}" != "200" ]; then
  echo "ERRO: contas dominio falhou. Status ${DOMAIN_ACCOUNTS_STATUS}"
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

if ! grep -q "${REAL_PHONE_NUMBER_ID}" "${DOMAIN_ACCOUNTS_LOG}"; then
  echo "ERRO: conta real nao aparece na listagem dominio."
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

ACCOUNT_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const accounts=(data.data&&data.data.accounts)||[]; const found=accounts.find((account)=>account.phoneNumberId==='${REAL_PHONE_NUMBER_ID}' && account.status==='active'); if(!found){process.exit(2)} console.log(found.id)" "${DOMAIN_ACCOUNTS_LOG}" || true)"

if [ -z "${ACCOUNT_ID}" ]; then
  echo "ERRO: conta real ativa nao encontrada via API."
  cat "${DOMAIN_ACCOUNTS_LOG}"
  exit 1
fi

DOMAIN_OPERATIONAL_STATUS="$(curl -L -s -o "${DOMAIN_OPERATIONAL_LOG}" -w "%{http_code}" --max-time 45 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_URL}/${ACCOUNT_ID}/operational" || true)"

if [ "${DOMAIN_OPERATIONAL_STATUS}" != "200" ] && [ "${DOMAIN_OPERATIONAL_STATUS}" != "201" ]; then
  echo "ERRO: operacional dominio falhou. Status ${DOMAIN_OPERATIONAL_STATUS}"
  cat "${DOMAIN_OPERATIONAL_LOG}"
  exit 1
fi

if ! grep -q "quality_rating" "${DOMAIN_OPERATIONAL_LOG}"; then
  echo "ERRO: operacional nao retornou quality_rating."
  cat "${DOMAIN_OPERATIONAL_LOG}"
  exit 1
fi

DOMAIN_CONVERSATIONS_STATUS="$(curl -L -s -o "${DOMAIN_CONVERSATIONS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_CONVERSATIONS_URL}" || true)"

if [ "${DOMAIN_CONVERSATIONS_STATUS}" != "200" ]; then
  echo "ERRO: conversas dominio falhou. Status ${DOMAIN_CONVERSATIONS_STATUS}"
  cat "${DOMAIN_CONVERSATIONS_LOG}"
  exit 1
fi

DOMAIN_META_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_META_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_META_PAGE_URL}" || true)"

if [ "${DOMAIN_META_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina meta-settings nao respondeu 200."
  exit 1
fi

DOMAIN_CONVERSATIONS_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_CONVERSATIONS_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_CONVERSATIONS_PAGE_URL}" || true)"

if [ "${DOMAIN_CONVERSATIONS_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina conversations nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 44..."

cat > "${DOC_FILE}" <<'DOC'
# Operational Cleanup

## Visao geral

Este documento registra a limpeza operacional de dados de teste e artificiais.

## Resultado

Status:

    concluido

## Objetivo

Preservar a conta real da Meta e remover da operacao diaria os dados criados durante testes das etapas anteriores.

## Conta preservada

Phone Number ID:

    1235882016268785

Verified Name:

    Test Number

WABA ID:

    1568724001636783

## Acoes realizadas

Acoes:

- backup SQL completo antes da limpeza
- validacao da conta real antes da limpeza
- soft-delete de contas WhatsApp artificiais
- fechamento e soft-delete de conversas de teste
- preservacao da conta real ativa
- validacao de login no dominio
- validacao de listagem de contas no dominio
- validacao de painel operacional da Meta
- validacao de listagem de conversas
- validacao das rotas app meta settings e app conversations

## Criterios de contas artificiais

Criterios:

- waba ou phone number id com prefixo restore
- contas criadas por webhook automatico
- contas frontend de teste
- contas domain fix
- conta local default
- nomes com restore, frontend, dominio ou detectada por webhook

## Criterios de conversas de teste

Criterios:

- contato ou mensagem contendo etapa
- contato ou mensagem contendo teste
- contato ou mensagem contendo template
- mensagens contendo LH Solucao
- mensagens contendo webhook fix
- mensagens contendo frontend ou dominio

## Arquivos gerados

Arquivos:

- docs/OPERATIONAL_CLEANUP.md
- logs/setup_44_before_counts.log
- logs/setup_44_after_counts.log
- logs/setup_44_cleanup.sql
- logs/setup_44_cleanup_execution.log
- logs/setup_44_real_account.log
- logs/setup_44_auth_login_domain.log
- logs/setup_44_accounts_domain.log
- logs/setup_44_operational_domain.log
- logs/setup_44_conversations_domain.log
- logs/setup_44_meta_settings_page.log
- logs/setup_44_conversations_page.log
- logs/setup_44.log

## Backup

Backup SQL:

    backups/setup_44_before_cleanup_TIMESTAMP.sql

## Observacoes

A limpeza foi feita por soft-delete, preservando rastreabilidade e permitindo auditoria posterior.

## Proxima etapa sugerida

Etapa 45:

    Criar painel de auditoria operacional
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
- [ ] Etapa 45 - Painel de auditoria operacional

## Ultima etapa executada

Etapa 44 - Limpeza operacional das contas de teste e dados artificiais.

## Proxima etapa sugerida

Etapa 45 - Criar painel de auditoria operacional.
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

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml
- .env.example
- .env
- .dockerignore

## Documentos tecnicos

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md
- docs/VALIDACAO_FINAL.md
- docs/ESTRUTURA_PROJETO.md
- docs/BACKEND_BASE.md
- docs/FRONTEND_BASE.md
- docs/DOCKER_COMPOSE_BASE.md
- docs/ENV_EXAMPLE.md
- docs/VALIDACAO_AMBIENTE.md
- docs/DEPENDENCIAS_BASE.md
- docs/DOCKER_BUILD.md
- docs/NGINX_BOT_LHSOLUCAO.md
- docs/EXECUCAO_INICIAL_DOMINIO.md
- docs/BACKEND_HEALTH_CONFIG_DATABASE.md
- docs/BACKEND_PRISMA_POSTGRES.md
- docs/PRISMA_SCHEMA_INICIAL.md
- docs/SEED_INICIAL.md
- docs/AUTH_LOGIN_REAL.md
- docs/FRONTEND_LOGIN_INTEGRADO.md
- docs/FRONTEND_LAYOUT_PROTECAO_ROTAS.md
- docs/BACKEND_USERS_PROFILE.md
- docs/FRONTEND_PROFILE_DETALHADO.md
- docs/BACKEND_CONTACTS.md
- docs/FRONTEND_CONTACTS.md
- docs/FRONTEND_CONVERSATIONS_LAYOUT.md
- docs/BACKEND_CONVERSATIONS.md
- docs/FRONTEND_CONVERSATIONS_INTEGRADO.md
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- docs/FRONTEND_WHATSAPP_ACCOUNTS.md
- docs/BACKEND_META_WEBHOOKS.md
- docs/BACKEND_META_WEBHOOK_SIGNATURE.md
- docs/FRONTEND_MESSAGE_STATUS.md
- docs/BACKEND_META_SEND_MESSAGES.md
- docs/BACKEND_META_TEMPLATES.md
- docs/FRONTEND_META_TEMPLATES.md
- docs/META_OPERATIONAL_PANEL.md
- docs/OPERATIONAL_CLEANUP.md

## Etapas concluidas

- Etapa 01 ate Etapa 44 concluidas

## Proxima etapa

- Etapa 45 - Painel de auditoria operacional
DOC

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
Etapa: 44
Acao: Limpeza operacional de dados de teste
Data: $(date '+%Y-%m-%d %H:%M:%S')
Backup SQL: ${DB_BACKUP_FILE}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Accounts status: ${DOMAIN_ACCOUNTS_STATUS}
Operational status: ${DOMAIN_OPERATIONAL_STATUS}
Conversations status: ${DOMAIN_CONVERSATIONS_STATUS}
Meta page status: ${DOMAIN_META_PAGE_STATUS}
Conversations page status: ${DOMAIN_CONVERSATIONS_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 44 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Backup SQL:"
echo "${DB_BACKUP_FILE}"
echo ""
echo "Contagens depois da limpeza:"
cat "${AFTER_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 45 - Criar painel de auditoria operacional"
