# Conversation Operational Status

## Visao geral

Este documento registra a criacao do status operacional das conversas.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela conversation operational status
- status operacional por conversa
- prioridade por conversa
- departamento operacional atual
- responsavel operacional atual
- endpoint de opcoes de status e prioridade
- endpoint de listagem de conversas para atendimento
- endpoint para atualizar status operacional
- integracao da tela app inbox com API real
- fallback visual caso nao existam conversas reais
- editor visual de status e prioridade

## Status criados

Status:

- novo
- em atendimento
- aguardando cliente
- aguardando interno
- resolvido
- encerrado
- arquivado

## Prioridades criadas

Prioridades:

- baixa
- normal
- media
- alta
- urgente

## Endpoints criados

Endpoints:

- GET api v1 attendance conversations status options
- GET api v1 attendance conversations
- PATCH api v1 attendance conversations conversation id status

## Tabela criada

Tabela:

- conversation operational status

Campos:

- id
- tenant id
- conversation id
- status
- priority
- department name
- assigned user id
- assigned user name
- created at
- updated at

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance/attendance.types.ts
- apps/backend/src/modules/attendance/attendance.service.ts
- apps/backend/src/modules/attendance/attendance.controller.ts
- apps/backend/src/modules/attendance/attendance.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance.types.ts
- apps/frontend/src/services/attendance.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/CONVERSATION_OPERATIONAL_STATUS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint status options dominio
- endpoint attendance conversations dominio
- patch status quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_57_backend_typecheck.log
- logs/setup_57_backend_build.log
- logs/setup_57_frontend_typecheck.log
- logs/setup_57_frontend_build.log
- logs/setup_57_backend_docker_build.log
- logs/setup_57_frontend_docker_build.log
- logs/setup_57_docker_up.log
- logs/setup_57_backend_wait.log
- logs/setup_57_auth_login_domain.log
- logs/setup_57_status_options_domain.log
- logs/setup_57_attendance_conversations_domain.log
- logs/setup_57_attendance_status_patch_domain.log
- logs/setup_57_domain_inbox_page.log
- logs/setup_57_domain_dashboard.log
- logs/setup_57_domain_audit_page.log
- logs/setup_57.log

## Proxima etapa sugerida

Etapa 58:

    Criar departamentos e filas de atendimento
