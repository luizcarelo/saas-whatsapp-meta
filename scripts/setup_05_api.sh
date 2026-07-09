#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_05.log"

echo "== Etapa 05: Documentacao da API =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${DOCS_DIR}/API.md" ]; then
  cp "${DOCS_DIR}/API.md" "${BACKUPS_DIR}/API_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Gerando docs/API.md..."

cat > "${DOCS_DIR}/API.md" <<'DOC'
# API do Sistema

## Visao geral

Este documento define o contrato inicial da API interna do SaaS de Chatbot WhatsApp com API Oficial da Meta.

A API sera usada pelo frontend, pelos workers internos e por integracoes futuras.

A API principal sera construida no backend com NestJS, Fastify e TypeScript.

## Objetivos da API

A API deve permitir:

- Autenticacao de usuarios
- Controle de tenants
- Gestao de usuarios
- Gestao de papeis e permissoes
- Cadastro de contas WhatsApp
- Recebimento de webhooks da Meta
- Gestao de contatos
- Gestao de conversas
- Envio e consulta de mensagens
- Controle de chatbot
- Consulta de relatorios
- Consulta de logs de auditoria
- Configuracoes do tenant

## Padrao geral

Base sugerida:

    /api/v1

Formato principal:

    application/json

Padrao de comunicacao:

    REST para operacoes principais
    WebSocket para eventos em tempo real
    Webhook HTTP para eventos recebidos da Meta

## Versionamento

A primeira versao da API sera:

    v1

Exemplo:

    /api/v1/auth/login
    /api/v1/conversations
    /api/v1/messages

Regras:

- Toda rota publica deve estar dentro de /api/v1
- Mudancas incompativeis devem gerar nova versao
- Mudancas compativeis podem permanecer na mesma versao
- O frontend deve consumir apenas rotas versionadas

## Autenticacao

A API usara JWT para autenticacao.

Fluxo inicial:

1. Usuario envia email e senha
2. Backend valida credenciais
3. Backend retorna access_token e refresh_token
4. Frontend usa access_token nas chamadas protegidas
5. Frontend renova sessao usando refresh_token

Header esperado:

    Authorization: Bearer TOKEN

Regras:

- access_token deve ter expiracao curta
- refresh_token deve ser protegido
- senha nunca deve trafegar em logs
- senha deve ser armazenada somente como hash
- usuario inativo nao pode autenticar

## Headers padrao

Headers de entrada recomendados:

    Authorization: Bearer TOKEN
    Content-Type: application/json
    Accept: application/json
    X-Tenant-Id: TENANT_ID

Observacao:

O tenant deve ser resolvido preferencialmente pelo usuario autenticado.

O header X-Tenant-Id pode ser usado em cenarios administrativos ou quando o usuario tiver acesso a mais de um tenant.

## Resposta padrao de sucesso

Formato recomendado:

    {
      "success": true,
      "data": {},
      "meta": {}
    }

Exemplo:

    {
      "success": true,
      "data": {
        "id": "uuid",
        "name": "Empresa Exemplo"
      },
      "meta": {}
    }

## Resposta padrao de erro

Formato recomendado:

    {
      "success": false,
      "error": {
        "code": "ERROR_CODE",
        "message": "Mensagem de erro",
        "details": {}
      }
    }

Exemplo:

    {
      "success": false,
      "error": {
        "code": "UNAUTHORIZED",
        "message": "Usuario nao autenticado",
        "details": {}
      }
    }

## Codigos HTTP

Codigos esperados:

    200 sucesso
    201 criado
    204 sem conteudo
    400 requisicao invalida
    401 nao autenticado
    403 sem permissao
    404 nao encontrado
    409 conflito
    422 erro de validacao
    429 limite excedido
    500 erro interno

## Codigos internos de erro

Codigos iniciais:

    VALIDATION_ERROR
    UNAUTHORIZED
    FORBIDDEN
    NOT_FOUND
    CONFLICT
    TENANT_NOT_FOUND
    TENANT_ACCESS_DENIED
    USER_INACTIVE
    INVALID_CREDENTIALS
    WHATSAPP_ACCOUNT_NOT_FOUND
    WHATSAPP_SEND_FAILED
    WEBHOOK_INVALID
    RATE_LIMITED
    INTERNAL_ERROR

## Paginacao

Rotas de listagem devem aceitar paginacao.

Parametros:

    page
    limit

Exemplo:

    /api/v1/contacts?page=1&limit=20

Resposta meta sugerida:

    {
      "page": 1,
      "limit": 20,
      "total": 150,
      "total_pages": 8
    }

Regras:

- limit deve possuir limite maximo
- ordenacao padrao deve ser por created_at desc
- consultas grandes devem ser paginadas

## Filtros e ordenacao

Parametros comuns:

    search
    status
    created_from
    created_to
    sort_by
    sort_direction

Exemplo:

    /api/v1/conversations?status=open&sort_by=last_message_at&sort_direction=desc

Regras:

- Campos de ordenacao devem ser validados
- Filtros devem respeitar tenant_id
- Busca textual deve ser limitada aos campos permitidos

## Rotas de Auth

## POST /api/v1/auth/login

Realiza login do usuario.

Entrada:

    {
      "email": "usuario@empresa.com",
      "password": "senha"
    }

Saida:

    {
      "success": true,
      "data": {
        "access_token": "token",
        "refresh_token": "token",
        "user": {
          "id": "uuid",
          "name": "Usuario",
          "email": "usuario@empresa.com"
        }
      }
    }

Permissao:

    publica

## POST /api/v1/auth/refresh

Renova access_token.

Entrada:

    {
      "refresh_token": "token"
    }

Permissao:

    autenticado por refresh token

## POST /api/v1/auth/logout

Encerra sessao atual.

Permissao:

    autenticado

## GET /api/v1/auth/me

Retorna dados do usuario autenticado.

Permissao:

    autenticado

## Rotas de Tenants

## GET /api/v1/tenants

Lista tenants acessiveis.

Permissao:

    tenants.read

## GET /api/v1/tenants/:id

Consulta tenant por id.

Permissao:

    tenants.read

## POST /api/v1/tenants

Cria tenant.

Permissao:

    tenants.create

## PATCH /api/v1/tenants/:id

Atualiza tenant.

Permissao:

    tenants.update

## Rotas de Usuarios

## GET /api/v1/users

Lista usuarios do tenant.

Permissao:

    users.read

## GET /api/v1/users/:id

Consulta usuario.

Permissao:

    users.read

## POST /api/v1/users

Cria usuario.

Entrada sugerida:

    {
      "name": "Nome",
      "email": "usuario@empresa.com",
      "role_ids": ["uuid"]
    }

Permissao:

    users.create

## PATCH /api/v1/users/:id

Atualiza usuario.

Permissao:

    users.update

## DELETE /api/v1/users/:id

Desativa usuario.

Permissao:

    users.delete

## Rotas de Roles e Permissions

## GET /api/v1/roles

Lista papeis.

Permissao:

    roles.read

## POST /api/v1/roles

Cria papel.

Permissao:

    roles.create

## PATCH /api/v1/roles/:id

Atualiza papel.

Permissao:

    roles.update

## GET /api/v1/permissions

Lista permissoes disponiveis.

Permissao:

    permissions.read

## Rotas de WhatsApp Accounts

## GET /api/v1/whatsapp/accounts

Lista contas WhatsApp do tenant.

Permissao:

    whatsapp_accounts.read

## POST /api/v1/whatsapp/accounts

Cadastra conta WhatsApp.

Entrada sugerida:

    {
      "waba_id": "id",
      "phone_number_id": "id",
      "display_phone_number": "numero",
      "verified_name": "nome",
      "access_token": "token"
    }

Permissao:

    whatsapp_accounts.create

Regras:

- access_token deve ser criptografado antes de salvar
- phone_number_id deve ser unico por tenant
- token nao deve ser retornado em consultas comuns

## PATCH /api/v1/whatsapp/accounts/:id

Atualiza conta WhatsApp.

Permissao:

    whatsapp_accounts.update

## DELETE /api/v1/whatsapp/accounts/:id

Desativa conta WhatsApp.

Permissao:

    whatsapp_accounts.delete

## Rotas de Webhooks Meta

## GET /api/v1/webhooks/meta/whatsapp

Endpoint de verificacao do webhook.

Acesso:

    publico controlado por token de verificacao

## POST /api/v1/webhooks/meta/whatsapp

Recebe eventos da Meta.

Acesso:

    publico com validacao

Fluxo:

1. Receber payload
2. Validar origem quando configurado
3. Salvar payload bruto
4. Resolver tenant pelo phone_number_id quando possivel
5. Enfileirar evento
6. Responder rapidamente

Resposta esperada:

    200

Regras:

- Nao processar regra pesada dentro da requisicao
- Salvar payload bruto antes do processamento
- Usar fila para processamento
- Garantir idempotencia

## Rotas de Contatos

## GET /api/v1/contacts

Lista contatos do tenant.

Permissao:

    contacts.read

Filtros:

    search
    phone
    created_from
    created_to

## GET /api/v1/contacts/:id

Consulta contato.

Permissao:

    contacts.read

## POST /api/v1/contacts

Cria contato.

Entrada sugerida:

    {
      "name": "Cliente",
      "phone": "5521999999999",
      "email": "cliente@email.com"
    }

Permissao:

    contacts.create

## PATCH /api/v1/contacts/:id

Atualiza contato.

Permissao:

    contacts.update

## DELETE /api/v1/contacts/:id

Remove ou desativa contato.

Permissao:

    contacts.delete

## Rotas de Conversas

## GET /api/v1/conversations

Lista conversas.

Permissao:

    conversations.read

Filtros:

    status
    assigned_user_id
    department_id
    contact_id
    search

## GET /api/v1/conversations/:id

Consulta conversa.

Permissao:

    conversations.read

## POST /api/v1/conversations/:id/assign

Atribui conversa a um atendente.

Entrada:

    {
      "user_id": "uuid",
      "reason": "motivo"
    }

Permissao:

    conversations.assign

## POST /api/v1/conversations/:id/close

Fecha conversa.

Permissao:

    conversations.close

## POST /api/v1/conversations/:id/reopen

Reabre conversa.

Permissao:

    conversations.update

## Rotas de Mensagens

## GET /api/v1/conversations/:id/messages

Lista mensagens de uma conversa.

Permissao:

    messages.read

## POST /api/v1/conversations/:id/messages

Envia mensagem na conversa.

Entrada texto:

    {
      "type": "text",
      "body": "Mensagem"
    }

Permissao:

    messages.send

Fluxo:

1. Validar usuario
2. Validar tenant
3. Validar conversa
4. Salvar mensagem como pending
5. Enfileirar envio
6. Retornar mensagem criada

## GET /api/v1/messages/:id

Consulta mensagem.

Permissao:

    messages.read

## Rotas de Chatbot

## GET /api/v1/chatbot/flows

Lista fluxos.

Permissao:

    chatbot.read

## POST /api/v1/chatbot/flows

Cria fluxo.

Permissao:

    chatbot.create

## PATCH /api/v1/chatbot/flows/:id

Atualiza fluxo.

Permissao:

    chatbot.update

## POST /api/v1/chatbot/flows/:id/activate

Ativa fluxo.

Permissao:

    chatbot.update

## POST /api/v1/chatbot/flows/:id/deactivate

Desativa fluxo.

Permissao:

    chatbot.update

## Rotas de Relatorios

## GET /api/v1/reports/conversations

Relatorio de conversas.

Permissao:

    reports.view

Filtros:

    created_from
    created_to
    status
    assigned_user_id

## GET /api/v1/reports/messages

Relatorio de mensagens.

Permissao:

    reports.view

Filtros:

    created_from
    created_to
    direction
    status

## Rotas de Auditoria

## GET /api/v1/audit-logs

Lista logs de auditoria.

Permissao:

    audit_logs.read

Filtros:

    user_id
    action
    entity
    created_from
    created_to

## Rotas de Configuracoes

## GET /api/v1/settings

Lista configuracoes do tenant.

Permissao:

    settings.read

## PATCH /api/v1/settings

Atualiza configuracoes do tenant.

Permissao:

    settings.update

## WebSocket

O sistema usara Socket.IO para eventos em tempo real.

Namespace sugerido:

    /realtime

Autenticacao:

    JWT no handshake

Eventos iniciais enviados pelo servidor:

    message.created
    message.updated
    conversation.created
    conversation.updated
    conversation.assigned
    contact.updated
    notification.created

Regras:

- Usuario deve receber apenas eventos do proprio tenant
- Eventos de conversa devem respeitar permissoes
- Backend deve validar token antes de conectar
- Reconexao deve ser suportada pelo frontend

## Seguranca da API

Regras obrigatorias:

- Toda rota protegida deve exigir JWT
- Toda rota protegida deve validar tenant
- Toda rota sensivel deve validar permissao
- Payloads devem ser validados com DTOs
- Respostas nao devem expor tokens sensiveis
- Logs nao devem conter senhas ou tokens
- Rate limit deve ser aplicado em rotas publicas
- Webhook deve ser validado conforme configuracao
- CORS deve ser restrito em producao

## Padrao de permissao

Formato recomendado:

    modulo.acao

Exemplos:

    conversations.read
    conversations.reply
    conversations.assign
    conversations.close
    contacts.create
    contacts.update
    users.manage
    settings.update
    reports.view

## Boas praticas

- Separar controllers por modulo
- Usar DTOs para entrada
- Usar interceptors para resposta padrao
- Usar filters para tratamento de erro
- Usar guards para autenticacao e permissao
- Nunca confiar no tenant enviado pelo frontend sem validacao
- Centralizar cliente HTTP da Meta
- Enfileirar operacoes demoradas
- Registrar auditoria em acoes sensiveis
- Criar testes para rotas criticas

## Decisao final desta etapa

O contrato inicial da API sera:

- REST versionada em /api/v1
- JSON como formato padrao
- JWT para autenticacao
- RBAC para autorizacao
- tenant_id validado em todas as rotas protegidas
- Webhook publico separado para Meta
- Socket.IO para tempo real
- Resposta padrao para sucesso e erro
- Paginacao obrigatoria em listagens
- Filas para envio e processamento de mensagens
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
- [ ] Etapa 06 - Documentacao de seguranca
- [ ] Etapa 07 - Documentacao de webhooks da Meta
- [ ] Etapa 08 - Documentacao do frontend
- [ ] Etapa 09 - Documentacao do backend
- [ ] Etapa 10 - Documentacao de deploy
- [ ] Etapa 11 - Manifesto final e validacao

## Ultima etapa executada

Etapa 05 - Documentacao da API.

## Proxima etapa sugerida

Etapa 06 - Criar docs/SEGURANCA.md com as regras de seguranca do SaaS.
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

## Proxima etapa

- Etapa 06 - Documentacao de seguranca

## Arquivos atualizados na Etapa 05

- docs/API.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_05.log
DOC

echo "Validando arquivos obrigatorios..."

test -f "${DOCS_DIR}/API.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${DOCS_DIR}/API.md" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 05
Acao: Documentacao da API
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/API.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/API_${STAMP}.md
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 05 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo de docs/API.md:"
sed -n '1,160p' "${DOCS_DIR}/API.md"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 06 - Criar docs/SEGURANCA.md"
