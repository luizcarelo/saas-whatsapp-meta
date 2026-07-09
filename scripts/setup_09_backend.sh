#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_09.log"

echo "== Etapa 09: Documentacao do backend =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${DOCS_DIR}/BACKEND.md" ]; then
  cp "${DOCS_DIR}/BACKEND.md" "${BACKUPS_DIR}/BACKEND_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Gerando docs/BACKEND.md..."

cat > "${DOCS_DIR}/BACKEND.md" <<'DOC'
# Backend

## Visao geral

Este documento define a arquitetura inicial do backend do SaaS de Chatbot WhatsApp com API Oficial da Meta.

O backend sera responsavel pelas regras de negocio, APIs REST, autenticacao, autorizacao, integracao com a Meta, processamento de webhooks, filas, workers, auditoria e comunicacao em tempo real.

A stack definida para o backend sera:

- NestJS
- Fastify
- TypeScript
- PostgreSQL
- Redis
- BullMQ
- Socket.IO
- JWT
- RBAC
- Prisma ou TypeORM
- Cliente HTTP para Meta

## Objetivos do backend

O backend deve permitir:

- Autenticar usuarios
- Validar permissoes
- Isolar dados por tenant
- Receber webhooks da Meta
- Enviar mensagens para a API da Meta
- Gerenciar contatos
- Gerenciar conversas
- Gerenciar mensagens
- Processar filas
- Executar chatbot
- Emitir eventos em tempo real
- Registrar auditoria
- Proteger tokens sensiveis
- Servir a API para o frontend

## Decisao tecnica

O backend sera construido com NestJS e Fastify.

Motivos:

- NestJS oferece arquitetura modular
- NestJS possui suporte nativo a TypeScript
- NestJS facilita organizacao por modulos
- Fastify sera usado como adaptador HTTP
- Workers serao separados do processo principal
- Redis e BullMQ serao usados para tarefas assincronas
- PostgreSQL sera o banco principal

## Estrutura sugerida

Estrutura inicial:

    apps/
      backend/
        src/
          main.ts
          app.module.ts
          modules/
          common/
          config/
          database/
          realtime/
          queues/
          integrations/

Estrutura detalhada:

    src/
      main.ts
      app.module.ts

      modules/
        auth/
        tenants/
        users/
        roles/
        permissions/
        whatsapp/
        webhooks/
        contacts/
        conversations/
        messages/
        chatbot/
        billing/
        audit/
        reports/
        settings/

      common/
        guards/
        decorators/
        filters/
        interceptors/
        pipes/
        utils/
        constants/

      config/
        app.config.ts
        database.config.ts
        redis.config.ts
        jwt.config.ts
        meta.config.ts
        cors.config.ts

      database/
        prisma/
        migrations/

      queues/
        queues.module.ts
        queue.constants.ts
        producers/
        processors/

      realtime/
        realtime.module.ts
        realtime.gateway.ts
        realtime.service.ts

      integrations/
        meta/
          meta-whatsapp.client.ts
          meta-whatsapp.types.ts

## Processo principal

O processo principal do backend sera responsavel por:

- Subir API HTTP
- Registrar middlewares
- Configurar CORS
- Configurar validacao global
- Configurar filtros de erro
- Configurar interceptors
- Configurar Swagger futuro quando necessario
- Iniciar Socket.IO
- Receber webhooks
- Enfileirar jobs

O processo principal nao deve executar tarefas pesadas de processamento.

## Workers

Workers serao processos separados.

Responsabilidades dos workers:

- Processar webhook recebido
- Processar mensagem recebida
- Enviar mensagem para a Meta
- Atualizar status de mensagem
- Executar fluxo de chatbot
- Processar notificacoes
- Reprocessar falhas controladas

Workers previstos:

    webhook-worker
    message-worker
    chatbot-worker
    notification-worker

## Modulos principais

## Auth

Responsavel por autenticacao.

Funcionalidades:

- Login
- Logout
- Refresh token
- Recuperacao de senha futura
- Validacao de sessao
- Hash de senha
- Bloqueio de usuario inativo

Arquivos sugeridos:

    auth.module.ts
    auth.controller.ts
    auth.service.ts
    auth.guard.ts
    jwt.strategy.ts
    refresh-token.service.ts

## Tenants

Responsavel pelas empresas clientes.

Funcionalidades:

- Criar tenant
- Atualizar tenant
- Consultar tenant
- Validar status do tenant
- Controlar plano futuro

Arquivos sugeridos:

    tenants.module.ts
    tenants.controller.ts
    tenants.service.ts
    tenant.guard.ts

## Users

Responsavel pelos usuarios internos.

Funcionalidades:

- Criar usuario
- Atualizar usuario
- Desativar usuario
- Listar usuarios
- Associar papeis
- Validar acesso ao tenant

Arquivos sugeridos:

    users.module.ts
    users.controller.ts
    users.service.ts
    users.repository.ts

## Roles e Permissions

Responsavel pelo RBAC.

Funcionalidades:

- Listar papeis
- Criar papeis
- Associar permissoes
- Validar permissao
- Proteger rotas

Arquivos sugeridos:

    roles.module.ts
    permissions.module.ts
    permissions.guard.ts
    permissions.decorator.ts

## WhatsApp

Responsavel por contas WhatsApp e envio de mensagens.

Funcionalidades:

- Cadastrar conta WhatsApp
- Criptografar token
- Consultar conta
- Atualizar conta
- Enviar mensagem
- Tratar erro da Meta
- Mapear status de envio

Arquivos sugeridos:

    whatsapp.module.ts
    whatsapp-accounts.controller.ts
    whatsapp-accounts.service.ts
    whatsapp-message.service.ts
    whatsapp-token.service.ts

## Webhooks

Responsavel pelo recebimento de webhooks da Meta.

Funcionalidades:

- GET de verificacao
- POST de recebimento
- Validacao minima do payload
- Registro de payload bruto
- Identificacao inicial de phone_number_id
- Enfileiramento do evento
- Resposta rapida

Arquivos sugeridos:

    webhooks.module.ts
    meta-whatsapp-webhook.controller.ts
    meta-whatsapp-webhook.service.ts
    webhook-parser.service.ts

## Contacts

Responsavel pelos contatos finais.

Funcionalidades:

- Criar contato
- Atualizar contato
- Listar contatos
- Buscar por telefone
- Normalizar telefone
- Vincular com wa_id

Arquivos sugeridos:

    contacts.module.ts
    contacts.controller.ts
    contacts.service.ts

## Conversations

Responsavel pelos atendimentos.

Funcionalidades:

- Criar conversa
- Atualizar status
- Atribuir atendente
- Transferir conversa
- Fechar conversa
- Reabrir conversa
- Atualizar last_message_at

Arquivos sugeridos:

    conversations.module.ts
    conversations.controller.ts
    conversations.service.ts
    conversation-assignment.service.ts

## Messages

Responsavel pelo historico de mensagens.

Funcionalidades:

- Criar mensagem inbound
- Criar mensagem outbound
- Listar mensagens
- Atualizar status
- Deduplicar por provider_message_id
- Registrar erro de envio

Arquivos sugeridos:

    messages.module.ts
    messages.controller.ts
    messages.service.ts
    message-status.service.ts

## Chatbot

Responsavel por automacoes.

Funcionalidades:

- Criar fluxo
- Atualizar fluxo
- Ativar fluxo
- Desativar fluxo
- Executar fluxo
- Transferir para humano
- Criar resposta automatica

Arquivos sugeridos:

    chatbot.module.ts
    chatbot-flows.controller.ts
    chatbot-flows.service.ts
    chatbot-runtime.service.ts

## Audit

Responsavel por logs de auditoria.

Funcionalidades:

- Registrar acoes sensiveis
- Consultar logs
- Filtrar por usuario
- Filtrar por acao
- Filtrar por periodo

Arquivos sugeridos:

    audit.module.ts
    audit.service.ts
    audit.controller.ts

## Reports

Responsavel por relatorios.

Funcionalidades iniciais:

- Relatorio de conversas
- Relatorio de mensagens
- Filtro por periodo
- Filtro por atendente
- Filtro por status

Arquivos sugeridos:

    reports.module.ts
    reports.controller.ts
    reports.service.ts

## Settings

Responsavel por configuracoes do tenant.

Funcionalidades:

- Listar configuracoes
- Atualizar configuracoes
- Validar valores
- Configurar horario de atendimento
- Configurar chatbot

Arquivos sugeridos:

    settings.module.ts
    settings.controller.ts
    settings.service.ts

## Common

Camada compartilhada do backend.

Conteudos:

    guards
    decorators
    filters
    interceptors
    pipes
    utils
    constants

## Guards

Guards previstos:

    JwtAuthGuard
    TenantGuard
    PermissionsGuard
    WebhookGuard

Responsabilidades:

- Validar autenticacao
- Validar tenant
- Validar permissoes
- Proteger rotas de webhook quando aplicavel

## Decorators

Decorators previstos:

    CurrentUser
    CurrentTenant
    Permissions
    PublicRoute

Objetivo:

- Reduzir repeticao nos controllers
- Padronizar acesso ao usuario autenticado
- Padronizar acesso ao tenant atual
- Declarar permissoes por rota

## Interceptors

Interceptors previstos:

    ResponseInterceptor
    AuditInterceptor
    LoggingInterceptor

Objetivo:

- Padronizar respostas
- Registrar dados de execucao
- Facilitar auditoria
- Controlar formato de retorno

## Filters

Filters previstos:

    HttpExceptionFilter
    ValidationExceptionFilter
    UnknownExceptionFilter

Objetivo:

- Padronizar erros
- Esconder detalhes sensiveis
- Evitar stack trace em producao
- Retornar codigos internos padronizados

## Pipes

Pipes previstos:

    ValidationPipe
    ParseUuidPipe
    TenantValidationPipe

Objetivo:

- Validar dados de entrada
- Rejeitar payloads invalidos
- Normalizar dados quando necessario

## DTOs

Toda entrada de controller deve usar DTO.

Regras:

- Validar tipos
- Validar campos obrigatorios
- Validar tamanhos
- Validar formatos
- Rejeitar campos indevidos quando possivel

Exemplos:

    LoginDto
    CreateUserDto
    UpdateUserDto
    CreateContactDto
    SendMessageDto
    CreateWhatsappAccountDto

## Resposta padrao

Formato de sucesso:

    {
      "success": true,
      "data": {},
      "meta": {}
    }

Formato de erro:

    {
      "success": false,
      "error": {
        "code": "ERROR_CODE",
        "message": "Mensagem",
        "details": {}
      }
    }

## Filas

Ferramenta definida:

- BullMQ

Filas iniciais:

    webhook-events
    process-incoming-message
    send-whatsapp-message
    update-message-status
    chatbot-flow
    notifications

## Producers

Producers sao servicos que adicionam jobs na fila.

Exemplos:

    WebhookQueueProducer
    MessageQueueProducer
    ChatbotQueueProducer
    NotificationQueueProducer

## Processors

Processors sao workers que executam jobs.

Exemplos:

    WebhookEventsProcessor
    IncomingMessageProcessor
    SendWhatsappMessageProcessor
    MessageStatusProcessor
    ChatbotFlowProcessor

## Padrao de job

Formato sugerido:

    {
      "job_id": "uuid",
      "tenant_id": "uuid",
      "entity_id": "uuid",
      "type": "nome_do_job",
      "metadata": {}
    }

Regras:

- Jobs devem conter tenant_id quando possivel
- Jobs devem ser idempotentes
- Jobs devem ter tentativas limitadas
- Erros devem ser registrados
- Dados sensiveis nao devem ser colocados no payload do job

## Banco de dados

Banco principal:

- PostgreSQL

ORM:

- Prisma ou TypeORM

Decisao final entre Prisma e TypeORM sera tomada antes da implementacao.

Regras:

- Toda tabela de negocio deve usar tenant_id quando aplicavel
- Toda query deve validar tenant
- Migracoes devem ser versionadas
- Alteracoes manuais em producao devem ser proibidas
- Backups devem ser feitos antes de migracoes

## Redis

Redis sera usado para:

- Filas BullMQ
- Cache temporario
- Rate limit
- Controle de estado temporario
- Pub/Sub interno quando necessario

Redis nao sera banco principal.

## Integracao com Meta

A integracao com a Meta deve ficar isolada em um cliente proprio.

Arquivo sugerido:

    integrations/meta/meta-whatsapp.client.ts

Responsabilidades:

- Montar URL da API
- Adicionar Authorization Bearer
- Enviar mensagens
- Tratar erros
- Retornar resposta padronizada
- Nao expor token em logs

Regras:

- Frontend nunca chama a Meta diretamente
- Token da Meta fica criptografado no backend
- Falhas da Meta devem ser registradas sem token
- Envio deve ocorrer por fila

## Socket.IO

Responsavel por tempo real.

Arquivos sugeridos:

    realtime.gateway.ts
    realtime.service.ts

Regras:

- Validar JWT no handshake
- Associar socket ao usuario
- Associar socket ao tenant
- Emitir eventos apenas ao tenant correto
- Remover conexao ao desconectar
- Nao emitir dados sensiveis

Eventos iniciais:

    message.created
    message.updated
    conversation.created
    conversation.updated
    conversation.assigned
    contact.updated
    notification.created

## Seguranca

Regras obrigatorias:

- JWT em rotas protegidas
- Refresh token seguro
- RBAC por permissao
- TenantGuard em rotas de negocio
- Validacao de DTOs
- CORS restrito em producao
- Rate limit em rotas publicas
- Tokens da Meta criptografados
- Logs sem dados sensiveis
- Auditoria em acoes sensiveis
- HTTPS em producao

## Logs

Logs devem registrar:

- rota
- metodo
- status
- tempo de resposta
- usuario quando houver
- tenant quando houver
- erro resumido

Nao registrar:

- senha
- access_token
- refresh_token
- token da Meta
- authorization header completo
- secrets

## Configuracao

Variaveis esperadas:

    NODE_ENV
    APP_PORT
    APP_URL
    FRONTEND_URL
    DATABASE_URL
    REDIS_HOST
    REDIS_PORT
    JWT_SECRET
    JWT_REFRESH_SECRET
    ENCRYPTION_KEY
    META_GRAPH_BASE_URL
    META_API_VERSION
    META_WEBHOOK_VERIFY_TOKEN
    META_APP_SECRET

## Ambientes

Ambientes previstos:

    development
    staging
    production

Regras:

- Configuracoes separadas por ambiente
- Banco separado por ambiente
- Redis separado por ambiente
- Secrets separados por ambiente
- Debug desativado em producao
- Logs controlados em producao

## Testes

Testes recomendados:

- Testes unitarios de services
- Testes de guards
- Testes de permissao
- Testes de tenant isolation
- Testes de webhook parser
- Testes de idempotencia
- Testes de envio de mensagem com mock da Meta
- Testes de fila com ambiente controlado

## Qualidade

Regras recomendadas:

- TypeScript estrito quando possivel
- ESLint
- Prettier
- Nomes claros
- Services pequenos
- Controllers sem regra complexa
- Separacao de modulos
- DTOs obrigatorios
- Erros padronizados
- Logs estruturados

## Checklist da etapa backend

Itens definidos:

- Stack backend
- Estrutura de pastas
- Processo principal
- Workers
- Modulos principais
- Common
- Guards
- Decorators
- Interceptors
- Filters
- Pipes
- DTOs
- Filas
- Producers
- Processors
- Banco de dados
- Redis
- Integracao com Meta
- Socket.IO
- Seguranca
- Logs
- Configuracao
- Ambientes
- Testes
- Qualidade

## Decisao final desta etapa

O backend sera implementado com:

- NestJS
- Fastify
- TypeScript
- PostgreSQL
- Redis
- BullMQ
- Socket.IO
- JWT
- RBAC
- Workers separados
- Integracao isolada com a Meta
- Validacao obrigatoria de tenant
- Auditoria em acoes sensiveis
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
- [x] Etapa 05 - Documentacao da API
- [x] Etapa 06 - Documentacao de seguranca
- [x] Etapa 07 - Documentacao de webhooks da Meta
- [x] Etapa 08 - Documentacao do frontend
- [x] Etapa 09 - Documentacao do backend
- [ ] Etapa 10 - Documentacao de deploy
- [ ] Etapa 11 - Manifesto final e validacao

## Ultima etapa executada

Etapa 09 - Documentacao do backend.

## Proxima etapa sugerida

Etapa 10 - Criar docs/DEPLOY.md com a documentacao de deploy.
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
- Etapa 05 - Documentacao da API
- Etapa 06 - Documentacao de seguranca
- Etapa 07 - Documentacao de webhooks da Meta
- Etapa 08 - Documentacao do frontend
- Etapa 09 - Documentacao do backend

## Proxima etapa

- Etapa 10 - Documentacao de deploy

## Arquivos atualizados na Etapa 09

- docs/BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_09.log
DOC

echo "Validando arquivos obrigatorios..."

test -f "${DOCS_DIR}/BACKEND.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${DOCS_DIR}/BACKEND.md" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 09
Acao: Documentacao do backend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/BACKEND_${STAMP}.md
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 09 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo de docs/BACKEND.md:"
sed -n '1,180p' "${DOCS_DIR}/BACKEND.md"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 10 - Criar docs/DEPLOY.md"
