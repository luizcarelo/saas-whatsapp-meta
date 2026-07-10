# Attendance Manual Send Backend

## Visao geral

Este documento registra a criacao do backend de envio manual pela central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela de tentativas de envio manual pela central
- endpoint para enviar mensagem manual pela central
- endpoint para listar historico de envios da conversa
- modo dryRun para validar sem enviar mensagem real
- validacao de conversa
- validacao de contato e telefone
- validacao de mensagem
- validacao de conta WhatsApp e token quando dryRun for falso
- envio preparado para API oficial da Meta
- registro de atendente
- registro de departamento
- registro de origem da mensagem
- registro de status do envio
- registro de erro de envio

## Endpoints criados

Endpoints:

- POST api v1 attendance send conversations conversation id messages
- GET api v1 attendance send conversations conversation id messages

## Tabela criada

Tabela:

- attendance manual message sends

Campos:

- id
- tenant id
- conversation id
- contact id
- contact phone
- whatsapp account id
- phone number id
- message body
- sent by user id
- sent by name
- department name
- conversation status
- message origin
- provider
- provider message id
- provider response
- status
- error message
- dry run
- created at
- updated at

## Observacao sobre envio real

O endpoint ja esta preparado para enviar texto pela API oficial da Meta quando dryRun for falso e quando houver phone number id e token configurados.

A validacao desta etapa usa dryRun para evitar envio real durante o setup.

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-send/attendance-send.types.ts
- apps/backend/src/modules/attendance-send/attendance-send.service.ts
- apps/backend/src/modules/attendance-send/attendance-send.controller.ts
- apps/backend/src/modules/attendance-send/attendance-send.module.ts
- apps/backend/src/app.module.ts
- docs/ATTENDANCE_MANUAL_SEND_BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela attendance manual message sends
- npm run typecheck no backend
- npm run build no backend
- docker compose build backend
- docker compose up backend proxy
- login dominio
- endpoint attendance conversations dominio
- envio dryRun quando ha conversa real
- historico de envios quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_66_backend_typecheck.log
- logs/setup_66_backend_build.log
- logs/setup_66_backend_docker_build.log
- logs/setup_66_docker_up.log
- logs/setup_66_backend_wait.log
- logs/setup_66_auth_login_domain.log
- logs/setup_66_attendance_conversations_domain.log
- logs/setup_66_send_dry_run_domain.log
- logs/setup_66_send_history_domain.log
- logs/setup_66_domain_inbox_page.log
- logs/setup_66_domain_dashboard.log
- logs/setup_66_domain_audit_page.log
- logs/setup_66.log

## Proxima etapa sugerida

Etapa 67:

    Frontend de envio real no app inbox
