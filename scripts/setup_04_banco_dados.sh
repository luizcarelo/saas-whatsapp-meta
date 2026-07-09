#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_04.log"

echo "== Etapa 04: Documentacao do banco de dados =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${DOCS_DIR}/BANCO_DADOS.md" ]; then
  cp "${DOCS_DIR}/BANCO_DADOS.md" "${BACKUPS_DIR}/BANCO_DADOS_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Gerando docs/BANCO_DADOS.md..."

cat > "${DOCS_DIR}/BANCO_DADOS.md" <<'DOC'
# Banco de Dados

## Visao geral

Este documento define o modelo inicial de banco de dados do SaaS de Chatbot WhatsApp com API Oficial da Meta.

O banco principal sera PostgreSQL.

O PostgreSQL sera responsavel por armazenar os dados permanentes do sistema, incluindo tenants, usuarios, permissoes, contatos, conversas, mensagens, eventos de webhook, configuracoes, auditoria e dados de cobranca futura.

O Redis sera usado para cache, filas, rate limit e estado temporario, mas nao sera usado como banco principal do sistema.

## Decisao tecnica

Banco principal:

- PostgreSQL

Cache e filas:

- Redis
- BullMQ

Motivos da decisao:

- PostgreSQL e adequado para dados relacionais
- PostgreSQL permite transacoes consistentes
- PostgreSQL permite indices eficientes
- PostgreSQL permite integridade referencial
- PostgreSQL permite evolucao com migracoes versionadas
- Redis e adequado para dados temporarios e filas
- BullMQ permite processamento assincrono com Redis

## Estrategia multi-tenant

A estrategia inicial sera usar tenant_id nas tabelas principais.

Cada empresa cliente sera representada por um tenant.

Toda entidade de negocio devera pertencer a um tenant.

Regras obrigatorias:

- Toda tabela de negocio deve possuir tenant_id quando aplicavel
- Toda consulta deve filtrar pelo tenant atual
- Toda criacao deve receber tenant_id
- Toda atualizacao deve validar tenant_id
- Toda exclusao deve validar tenant_id
- Nenhum usuario pode acessar dados de outro tenant
- Workers devem identificar tenant antes de processar eventos
- Logs de auditoria devem registrar tenant_id

## Padrao de nomes

Padroes adotados:

- Nomes de tabelas em ingles
- Nomes de tabelas no plural
- Nomes de colunas em snake_case
- Chaves primarias chamadas id
- Chaves estrangeiras com sufixo _id
- Datas com sufixo _at
- Status em campo status
- Payloads externos em campo payload ou metadata
- Campos booleanos iniciando com is_ ou has_ quando aplicavel

Exemplos:

- tenants
- users
- whatsapp_accounts
- webhook_events
- created_at
- updated_at
- deleted_at
- tenant_id
- user_id
- conversation_id

## Tipos de campos recomendados

Identificadores:

- UUID para id principal
- UUID para chaves estrangeiras internas

Textos curtos:

- varchar ou text conforme necessidade

Datas:

- timestamptz para datas com fuso

Valores monetarios:

- numeric com precisao definida

Status:

- varchar inicialmente
- enum no codigo da aplicacao

Dados externos:

- jsonb para payloads da Meta
- jsonb para metadata

Exclusao logica:

- deleted_at quando necessario

Auditoria basica:

- created_at
- updated_at
- deleted_at

## Tabelas principais

## tenants

Representa empresas clientes do SaaS.

Campos sugeridos:

    id
    name
    document
    email
    phone
    status
    plan_id
    created_at
    updated_at
    deleted_at

Status sugeridos:

    active
    inactive
    suspended
    trial
    canceled

Indices recomendados:

    tenants_status_idx
    tenants_document_idx

## users

Representa usuarios internos de cada tenant.

Campos sugeridos:

    id
    tenant_id
    name
    email
    password_hash
    status
    last_login_at
    created_at
    updated_at
    deleted_at

Status sugeridos:

    active
    inactive
    blocked
    invited

Indices recomendados:

    users_tenant_id_idx
    users_email_idx
    users_tenant_email_unique

Regras:

- Email deve ser unico dentro do tenant
- Senha deve ser armazenada apenas como hash
- Usuario inativo nao pode autenticar

## roles

Representa papeis de acesso.

Campos sugeridos:

    id
    tenant_id
    name
    description
    is_system
    created_at
    updated_at
    deleted_at

Papeis iniciais:

    owner
    admin
    manager
    agent
    viewer

Indices recomendados:

    roles_tenant_id_idx
    roles_tenant_name_unique

## permissions

Representa permissoes do sistema.

Campos sugeridos:

    id
    key
    description
    module
    created_at
    updated_at

Exemplos de permissoes:

    conversations.read
    conversations.reply
    conversations.assign
    contacts.create
    contacts.update
    users.manage
    settings.manage
    reports.view
    billing.view

Indices recomendados:

    permissions_key_unique
    permissions_module_idx

## role_permissions

Relaciona papeis e permissoes.

Campos sugeridos:

    id
    role_id
    permission_id
    created_at

Indices recomendados:

    role_permissions_role_id_idx
    role_permissions_permission_id_idx
    role_permissions_unique

## user_roles

Relaciona usuarios e papeis.

Campos sugeridos:

    id
    tenant_id
    user_id
    role_id
    created_at

Indices recomendados:

    user_roles_tenant_id_idx
    user_roles_user_id_idx
    user_roles_role_id_idx
    user_roles_unique

## whatsapp_accounts

Representa contas WhatsApp conectadas a um tenant.

Campos sugeridos:

    id
    tenant_id
    waba_id
    phone_number_id
    display_phone_number
    verified_name
    access_token_encrypted
    token_expires_at
    status
    created_at
    updated_at
    deleted_at

Status sugeridos:

    active
    inactive
    pending
    disconnected
    error

Indices recomendados:

    whatsapp_accounts_tenant_id_idx
    whatsapp_accounts_phone_number_id_idx
    whatsapp_accounts_waba_id_idx
    whatsapp_accounts_tenant_phone_unique

Regras:

- access_token_encrypted deve ser criptografado
- phone_number_id sera usado para identificar tenant nos webhooks
- uma conta WhatsApp deve pertencer a apenas um tenant

## contacts

Representa contatos finais atendidos pelo tenant.

Campos sugeridos:

    id
    tenant_id
    name
    phone
    wa_id
    email
    document
    metadata
    created_at
    updated_at
    deleted_at

Indices recomendados:

    contacts_tenant_id_idx
    contacts_phone_idx
    contacts_wa_id_idx
    contacts_tenant_phone_unique

Regras:

- phone deve ser normalizado
- wa_id deve ser salvo quando recebido da Meta
- metadata pode guardar dados adicionais

## departments

Representa setores de atendimento.

Campos sugeridos:

    id
    tenant_id
    name
    description
    status
    created_at
    updated_at
    deleted_at

Indices recomendados:

    departments_tenant_id_idx
    departments_tenant_name_unique

## conversations

Representa atendimentos ou conversas.

Campos sugeridos:

    id
    tenant_id
    contact_id
    whatsapp_account_id
    assigned_user_id
    department_id
    status
    channel
    last_message_at
    closed_at
    created_at
    updated_at
    deleted_at

Status sugeridos:

    open
    pending
    bot
    human
    resolved
    closed

Canal inicial:

    whatsapp

Indices recomendados:

    conversations_tenant_id_idx
    conversations_contact_id_idx
    conversations_assigned_user_id_idx
    conversations_status_idx
    conversations_last_message_at_idx

Regras:

- Uma conversa pertence a um tenant
- Uma conversa pertence a um contato
- Uma conversa pode estar atribuida a um usuario
- Uma conversa pode estar vinculada a um departamento

## conversation_assignments

Registra historico de atribuicoes de conversas.

Campos sugeridos:

    id
    tenant_id
    conversation_id
    from_user_id
    to_user_id
    assigned_by_user_id
    reason
    created_at

Indices recomendados:

    conversation_assignments_tenant_id_idx
    conversation_assignments_conversation_id_idx
    conversation_assignments_to_user_id_idx

## messages

Representa mensagens recebidas e enviadas.

Campos sugeridos:

    id
    tenant_id
    conversation_id
    contact_id
    whatsapp_account_id
    provider_message_id
    direction
    type
    body
    media_url
    media_mime_type
    media_file_name
    status
    error_message
    metadata
    sent_at
    delivered_at
    read_at
    created_at
    updated_at
    deleted_at

Direcoes:

    inbound
    outbound

Tipos:

    text
    image
    audio
    video
    document
    location
    contact
    interactive
    template
    unknown

Status:

    pending
    sent
    delivered
    read
    failed
    received

Indices recomendados:

    messages_tenant_id_idx
    messages_conversation_id_idx
    messages_contact_id_idx
    messages_provider_message_id_idx
    messages_created_at_idx
    messages_tenant_conversation_created_idx

Regras:

- provider_message_id deve ser usado para evitar duplicidade
- Mensagens inbound devem vir do webhook
- Mensagens outbound devem ser geradas pelo painel, bot ou automacao
- Campos de midia devem ser preenchidos apenas quando aplicavel

## message_statuses

Registra historico de status de mensagens.

Campos sugeridos:

    id
    tenant_id
    message_id
    provider_message_id
    status
    payload
    created_at

Status:

    sent
    delivered
    read
    failed

Indices recomendados:

    message_statuses_tenant_id_idx
    message_statuses_message_id_idx
    message_statuses_provider_message_id_idx

## webhook_events

Registra eventos brutos recebidos da Meta.

Campos sugeridos:

    id
    tenant_id
    whatsapp_account_id
    provider
    event_type
    event_id
    payload
    status
    processed_at
    error_message
    created_at
    updated_at

Provider inicial:

    meta_whatsapp

Status:

    received
    queued
    processed
    failed
    ignored

Indices recomendados:

    webhook_events_tenant_id_idx
    webhook_events_event_id_idx
    webhook_events_status_idx
    webhook_events_created_at_idx

Regras:

- Payload bruto deve ser salvo antes do processamento
- Evento deve ser processado por worker
- Evento duplicado deve ser ignorado com seguranca
- Quando tenant ainda nao for conhecido, tenant_id pode ser resolvido apos leitura do phone_number_id

## chatbot_flows

Representa fluxos de chatbot.

Campos sugeridos:

    id
    tenant_id
    name
    description
    status
    trigger_type
    trigger_value
    created_at
    updated_at
    deleted_at

Status:

    active
    inactive
    draft

Trigger type:

    welcome
    keyword
    schedule
    fallback
    manual

Indices recomendados:

    chatbot_flows_tenant_id_idx
    chatbot_flows_status_idx
    chatbot_flows_trigger_idx

## chatbot_steps

Representa etapas de um fluxo de chatbot.

Campos sugeridos:

    id
    tenant_id
    flow_id
    parent_step_id
    step_order
    type
    content
    conditions
    next_step_id
    created_at
    updated_at
    deleted_at

Tipos:

    message
    question
    menu
    action
    transfer
    end

Indices recomendados:

    chatbot_steps_tenant_id_idx
    chatbot_steps_flow_id_idx
    chatbot_steps_parent_step_id_idx

## plans

Representa planos comerciais do SaaS.

Campos sugeridos:

    id
    name
    description
    price
    currency
    max_users
    max_whatsapp_accounts
    max_monthly_messages
    status
    created_at
    updated_at
    deleted_at

Status:

    active
    inactive
    archived

Indices recomendados:

    plans_status_idx

## subscriptions

Representa assinatura de um tenant.

Campos sugeridos:

    id
    tenant_id
    plan_id
    status
    started_at
    expires_at
    canceled_at
    created_at
    updated_at

Status:

    trial
    active
    past_due
    canceled
    expired

Indices recomendados:

    subscriptions_tenant_id_idx
    subscriptions_plan_id_idx
    subscriptions_status_idx

## settings

Representa configuracoes por tenant.

Campos sugeridos:

    id
    tenant_id
    key
    value
    created_at
    updated_at

Indices recomendados:

    settings_tenant_id_idx
    settings_tenant_key_unique

Exemplos:

    business_hours
    default_department
    chatbot_enabled
    auto_close_after_minutes
    timezone

## audit_logs

Registra acoes relevantes no sistema.

Campos sugeridos:

    id
    tenant_id
    user_id
    action
    entity
    entity_id
    metadata
    ip_address
    user_agent
    created_at

Indices recomendados:

    audit_logs_tenant_id_idx
    audit_logs_user_id_idx
    audit_logs_action_idx
    audit_logs_created_at_idx

Eventos auditaveis:

    login
    logout
    create_user
    update_user
    delete_user
    send_message
    connect_whatsapp
    update_settings
    change_role
    close_conversation
    assign_conversation

## Relacionamentos principais

Relacionamentos iniciais:

    tenants possui users
    tenants possui roles
    tenants possui contacts
    tenants possui conversations
    tenants possui messages
    tenants possui whatsapp_accounts
    tenants possui webhook_events
    tenants possui audit_logs

    users possui user_roles
    roles possui role_permissions
    permissions possui role_permissions

    contacts possui conversations
    conversations possui messages
    conversations possui conversation_assignments
    whatsapp_accounts possui conversations
    whatsapp_accounts possui messages
    whatsapp_accounts possui webhook_events

    chatbot_flows possui chatbot_steps
    plans possui subscriptions
    tenants possui subscriptions

## Indices gerais recomendados

Indices obrigatorios por padrao:

    tenant_id
    created_at
    updated_at quando usado em filtros
    status
    foreign keys principais
    provider_message_id
    phone_number_id
    conversation_id
    contact_id

Indices compostos recomendados:

    tenant_id + email em users
    tenant_id + phone em contacts
    tenant_id + conversation_id + created_at em messages
    tenant_id + status em conversations
    tenant_id + key em settings
    tenant_id + phone_number_id em whatsapp_accounts

## Idempotencia

O sistema deve ser idempotente para webhooks e mensagens.

Regras:

- Webhooks repetidos nao devem duplicar mensagens
- provider_message_id deve ser usado para deduplicacao
- event_id deve ser usado quando disponivel
- Jobs de fila devem tolerar reprocessamento
- Atualizacoes de status devem poder ser repetidas sem corromper dados

## Auditoria

Todas as acoes relevantes devem ser registradas.

A auditoria deve responder:

- Quem fez
- Em qual tenant
- Qual acao
- Qual entidade
- Quando
- De qual IP
- Com quais metadados

## Seguranca dos dados

Regras obrigatorias:

- Senhas apenas com hash
- Tokens da Meta criptografados
- Segredos fora do banco quando possivel
- Dados sensiveis nao devem aparecer em logs comuns
- Toda consulta deve respeitar tenant_id
- Backups devem ser protegidos
- Acesso ao banco em producao deve ser restrito

## Backup e retencao

Politica inicial sugerida:

- Backup diario do PostgreSQL
- Retencao minima de 7 dias em ambiente inicial
- Backup antes de migracoes importantes
- Teste periodico de restauracao
- Logs de backup
- Separacao entre ambiente de desenvolvimento e producao

## Migracoes

Todas as mudancas de schema devem ser feitas por migracoes versionadas.

Regras:

- Nunca alterar banco de producao manualmente
- Toda migracao deve ter nome claro
- Toda migracao deve ser revisada
- Toda migracao deve ter backup antes em producao
- Toda migracao deve ser testada em ambiente de homologacao

## Evolucao futura

Evolucoes possiveis:

- Particionamento de messages por data
- Particionamento por tenant em clientes grandes
- Schema dedicado por tenant enterprise
- Banco dedicado por tenant enterprise
- Read replicas para relatorios
- Data warehouse para analytics
- Retencao configuravel de mensagens
- Arquivamento de conversas antigas

## Decisao final desta etapa

O modelo inicial do banco sera:

- PostgreSQL como banco principal
- tenant_id nas tabelas de negocio
- Redis apenas para cache, filas e estado temporario
- UUID como identificador principal
- jsonb para payloads externos e metadata
- auditoria obrigatoria para acoes sensiveis
- deduplicacao por provider_message_id e event_id
- migracoes versionadas para toda mudanca de schema
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Etapas

- [x] Etapa 01 - Preparacao do ambiente de documentacao
- [x] Etapa 02 - Criacao do README principal
- [x] Etapa 03 - Documentacao de arquitetura
- [x] Etapa 04 - Documentacao do banco de dados
- [ ] Etapa 05 - Documentacao da API
- [ ] Etapa 06 - Documentacao de seguranca
- [ ] Etapa 07 - Documentacao de webhooks da Meta
- [ ] Etapa 08 - Documentacao do frontend
- [ ] Etapa 09 - Documentacao do backend
- [ ] Etapa 10 - Documentacao de deploy
- [ ] Etapa 11 - Manifesto final e validacao

## Ultima etapa executada

Etapa 04 - Documentacao do banco de dados.

## Proxima etapa sugerida

Etapa 05 - Criar docs/API.md com o contrato inicial da API.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto da Documentacao

Este manifesto lista os arquivos esperados da documentacao inicial do projeto.

## Pasta base

saas-whatsapp-meta/

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md

## Documentos tecnicos

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md

## Pastas de apoio

- scripts/
- logs/
- backups/

## Etapas concluidas

- Etapa 01 - Preparacao do ambiente de documentacao
- Etapa 02 - Criacao do README principal
- Etapa 03 - Documentacao de arquitetura
- Etapa 04 - Documentacao do banco de dados

## Proxima etapa

- Etapa 05 - Documentacao da API

## Arquivos atualizados na Etapa 04

- docs/BANCO_DADOS.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_04.log
DOC

echo "Validando arquivos obrigatorios..."

test -f "${DOCS_DIR}/BANCO_DADOS.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${DOCS_DIR}/BANCO_DADOS.md" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 04
Acao: Documentacao do banco de dados
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/BANCO_DADOS.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/BANCO_DADOS_${STAMP}.md
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 04 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo de docs/BANCO_DADOS.md:"
sed -n '1,140p' "${DOCS_DIR}/BANCO_DADOS.md"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 05 - Criar docs/API.md"
