# Backend Meta Webhook Signature

## Visao geral

Este documento registra a criacao da validacao de assinatura dos webhooks da Meta.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi instalado o pacote @nestjs/platform-express para restaurar o driver HTTP padrao do Nest.

Foi mantido o rawBody nativo do Nest.

## Assinatura validada

Cabecalho:

    X-Hub-Signature-256

Algoritmo:

    HMAC SHA256

Prefixo:

    sha256=

## Funcionalidades

Funcionalidades:

- captura do corpo bruto da requisicao
- validacao HMAC SHA256 com META_APP_SECRET
- comparacao segura da assinatura
- rejeicao de assinatura ausente ou invalida
- suporte a assinatura obrigatoria por META_WEBHOOK_SIGNATURE_REQUIRED
- preservacao da verificacao GET com hub challenge

## Arquivos criados ou alterados

Arquivos:

- apps/backend/package.json
- apps/backend/package-lock.json
- apps/backend/src/main.ts
- apps/backend/src/common/middleware/raw-body.middleware.ts
- apps/backend/src/modules/webhooks/meta-webhooks.controller.ts
- docker-compose.yml
- .env
- .env.example
- docs/BACKEND_META_WEBHOOK_SIGNATURE.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- docker compose config
- variaveis no container backend
- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend com recriacao
- aguardo ativo do backend
- GET verify local
- GET verify dominio
- POST assinado local
- POST assinado dominio
- POST com assinatura invalida local retornando 401
- POST com assinatura invalida dominio retornando 401

## Logs gerados

Logs:

- logs/setup_38_backend_typecheck.log
- logs/setup_38_backend_build.log
- logs/setup_38_backend_docker_build.log
- logs/setup_38_backend_docker_up.log
- logs/setup_38_backend_wait.log
- logs/setup_38_container_env.log
- logs/setup_38_webhook_verify_local.log
- logs/setup_38_webhook_verify_domain.log
- logs/setup_38_webhook_signed_post_local.log
- logs/setup_38_webhook_signed_post_domain.log
- logs/setup_38_webhook_bad_signature_local.log
- logs/setup_38_webhook_bad_signature_domain.log
- logs/fix_38_install_platform_express.log
- logs/setup_38.log

## Configuracao

Variaveis:

- META_APP_SECRET
- META_WEBHOOK_SIGNATURE_REQUIRED

## Proxima etapa sugerida

Etapa 39:

    Criar processamento de status de mensagens da Meta no frontend
