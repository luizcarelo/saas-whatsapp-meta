# Backend Meta Webhooks

## Visao geral

Este documento registra a criacao do modulo backend de webhooks da Meta.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi garantido que WHATSAPP_VERIFY_TOKEN seja carregado dentro do container backend via docker-compose.yml.

## Endpoints criados

Endpoints:

- GET api v1 webhooks meta
- POST api v1 webhooks meta

## Funcionalidades

Funcionalidades:

- verificacao do webhook usando hub mode
- validacao do verify token
- retorno do hub challenge
- recebimento de payload POST
- gravacao de webhook events
- criacao automatica de conta WhatsApp quando necessario
- criacao ou atualizacao de contato por wa id
- criacao de conversa quando necessario
- gravacao de mensagem inbound
- processamento basico de status de mensagem

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/webhooks/webhooks.module.ts
- apps/backend/src/modules/webhooks/meta-webhooks.controller.ts
- apps/backend/src/modules/webhooks/meta-webhooks.service.ts
- apps/backend/src/modules/webhooks/meta-webhooks.types.ts
- apps/backend/src/app.module.ts
- docker-compose.yml
- .env
- .env.example
- docs/BACKEND_META_WEBHOOKS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- docker compose config
- validacao de WHATSAPP_VERIFY_TOKEN dentro do container backend
- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend com recriacao
- verificacao local com hub challenge
- verificacao dominio com hub challenge
- POST local com payload de mensagem
- POST dominio com payload de mensagem
- contagem de webhook events no banco
- contagem de mensagens de teste no banco

## Logs gerados

Logs:

- logs/setup_37_backend_typecheck.log
- logs/setup_37_backend_build.log
- logs/setup_37_backend_docker_build.log
- logs/setup_37_backend_docker_up.log
- logs/setup_37_container_env.log
- logs/setup_37_webhook_verify_local.log
- logs/setup_37_webhook_verify_domain.log
- logs/setup_37_webhook_post_local.log
- logs/setup_37_webhook_post_domain.log
- logs/setup_37_webhook_events_local.log
- logs/fix_37_webhook_verify_token_container.log
- logs/setup_37.log

## Configuracao para Meta

Callback URL:

    https bot lhsolucao com br api v1 webhooks meta

Verify Token:

    definido em WHATSAPP_VERIFY_TOKEN no arquivo .env

## Observacoes

A validacao de assinatura X-Hub-Signature-256 ainda nao foi implementada nesta etapa.

Essa validacao exige acesso ao corpo bruto da requisicao antes do parse JSON.

## Proxima etapa sugerida

Etapa 38:

    Criar validacao de assinatura dos webhooks da Meta
