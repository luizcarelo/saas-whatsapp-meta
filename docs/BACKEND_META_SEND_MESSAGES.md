# Backend Meta Send Messages

## Visao geral

Este documento registra a criacao do envio real de mensagens pela API oficial da Meta.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- modulo Meta WhatsApp
- servico de envio de mensagem text pela Meta Graph API
- uso do Phone Number ID da conta WhatsApp
- decodificacao do token salvo da conta WhatsApp
- selecao de conta WhatsApp ativa e real
- envio real ao endpoint da Meta
- gravacao de providerMessageId quando retornado
- atualizacao de status para sent quando aceito
- atualizacao de status para failed quando rejeitado
- gravacao de resposta da Meta em metadata sem expor token

## Endpoint externo utilizado

Endpoint:

    POST graph facebook com version phone number id messages

Headers:

    Authorization Bearer token
    Content Type application json

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.module.ts
- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.service.ts
- apps/backend/src/modules/meta-whatsapp/meta-whatsapp.types.ts
- apps/backend/src/modules/conversations/conversations.module.ts
- apps/backend/src/modules/conversations/conversations.service.ts
- apps/backend/src/modules/conversations/conversations.types.ts
- .env
- .env.example
- docs/BACKEND_META_SEND_MESSAGES.md
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
- listagem de contas WhatsApp dominio
- validacao de conta ativa real
- criacao de conversa dominio
- chamada real de envio pela Meta
- busca da conversa apos envio

## Logs gerados

Logs:

- logs/setup_40_backend_typecheck.log
- logs/setup_40_backend_build.log
- logs/setup_40_backend_docker_build.log
- logs/setup_40_backend_docker_up.log
- logs/setup_40_backend_wait.log
- logs/setup_40_auth_login_domain.log
- logs/setup_40_whatsapp_accounts_list_domain.log
- logs/setup_40_conversation_create_domain.log
- logs/setup_40_meta_send_message_domain.log
- logs/setup_40_conversation_get_domain.log
- logs/setup_40.log

## Observacoes

Se a Meta rejeitar o envio por destinatario nao permitido, token expirado, janela de atendimento ou politica de template, o sistema salva a mensagem com status failed e grava o retorno da Meta em metadata.

O token nao e impresso nos logs.

## Proxima etapa sugerida

Etapa 41:

    Criar suporte a templates oficiais da Meta
