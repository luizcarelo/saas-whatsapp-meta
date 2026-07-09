# Backend WhatsApp Accounts

## Visao geral

Este documento registra a criacao e ajustes do modulo backend de WhatsApp Accounts.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi adicionada restauracao automatica de contas removidas logicamente.

Quando uma conta com o mesmo tenant e phoneNumberId existe com deletedAt preenchido, o cadastro passa a reativar a conta em vez de falhar por duplicidade.

## Endpoints

Endpoints:

- GET api v1 whatsapp accounts
- POST api v1 whatsapp accounts
- GET api v1 whatsapp accounts id
- PATCH api v1 whatsapp accounts id
- DELETE api v1 whatsapp accounts id

## Funcionalidades

Funcionalidades:

- listar contas WhatsApp do tenant autenticado
- buscar conta por id
- criar conta WhatsApp
- restaurar conta removida logicamente pelo mesmo phoneNumberId
- atualizar conta WhatsApp
- remover conta com deletedAt
- validar phoneNumberId duplicado quando a conta ativa ja existe
- filtrar contas por busca simples
- armazenar token em formato codificado local

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/whatsapp-accounts/whatsapp-accounts.service.ts
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- login local
- criar conta local
- remover conta local
- recriar mesma conta local com mesmo phoneNumberId
- login dominio
- criar conta dominio
- remover conta dominio
- recriar mesma conta dominio com mesmo phoneNumberId
- listar contas dominio

## Logs gerados

Logs:

- logs/fix_39_backend_typecheck_whatsapp_restore.log
- logs/fix_39_backend_build_whatsapp_restore.log
- logs/fix_39_backend_docker_build_whatsapp_restore.log
- logs/fix_39_backend_docker_up_whatsapp_restore.log
- logs/fix_39_auth_login_local.log
- logs/fix_39_auth_login_domain.log
- logs/fix_39_whatsapp_account_create_local.log
- logs/fix_39_whatsapp_account_delete_local.log
- logs/fix_39_whatsapp_account_restore_local.log
- logs/fix_39_whatsapp_account_create_domain.log
- logs/fix_39_whatsapp_account_delete_domain.log
- logs/fix_39_whatsapp_account_restore_domain.log
- logs/fix_39_whatsapp_accounts_list_domain.log
- logs/fix_39_whatsapp_accounts_restore_deleted.log

## Observacoes

Este ajuste permite corrigir cadastros errados removidos pela tela sem intervenção manual no banco.

## Proxima etapa sugerida

Etapa 40:

    Criar envio real de mensagens pela API oficial da Meta
