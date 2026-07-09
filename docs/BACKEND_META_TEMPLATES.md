# Backend Meta Templates

## Visao geral

Este documento registra o suporte a templates oficiais da Meta.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- listar templates oficiais da WABA
- enviar template oficial para contato de conversa
- suporte ao template hello_world
- suporte a idioma do template
- gravar providerMessageId quando retornado
- marcar status sent quando aceito
- marcar status failed quando rejeitado
- salvar retorno da Meta em metadata sem expor token

## Endpoints criados

Endpoints:

- GET api v1 whatsapp accounts id templates
- POST api v1 conversations id templates

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.types.ts
- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.service.ts
- apps/backend/src/modules/conversations/conversations.controller.ts
- apps/backend/src/modules/conversations/conversations.service.ts
- apps/backend/src/modules/conversations/conversations.types.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.controller.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.module.ts
- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.types.ts
- .env
- .env.example
- docs/BACKEND_META_TEMPLATES.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- aguardo ativo do backend
- login dominio
- listagem de contas dominio
- listagem de templates dominio
- criacao de conversa dominio
- envio de template dominio
- busca da conversa apos envio

## Logs gerados

Logs:

- logs/setup_41_backend_typecheck.log
- logs/setup_41_backend_build.log
- logs/setup_41_backend_docker_build.log
- logs/setup_41_backend_docker_up.log
- logs/setup_41_backend_wait.log
- logs/setup_41_auth_login_domain.log
- logs/setup_41_whatsapp_accounts_domain.log
- logs/setup_41_templates_list_domain.log
- logs/setup_41_conversation_create_domain.log
- logs/setup_41_template_send_domain.log
- logs/setup_41_conversation_get_domain.log
- logs/setup_41.log

## Observacoes

Templates sao importantes para mensagens iniciadas pela empresa e para testes oficiais como hello_world.

## Proxima etapa sugerida

Etapa 42:

    Criar frontend para envio de templates oficiais
