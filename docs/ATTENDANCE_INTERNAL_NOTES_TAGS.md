# Attendance Internal Notes Tags

## Visao geral

Este documento registra a criacao de notas internas e tags para a central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela de notas internas por conversa
- tabela de tags por tenant
- tabela de vinculo de tags com conversas
- seed inicial de tags
- endpoint para listar notas internas
- endpoint para criar nota interna
- endpoint para listar tags
- endpoint para criar tag
- endpoint para listar tags de uma conversa
- endpoint para vincular tag a uma conversa
- painel visual de tags na central app inbox
- painel visual de notas internas na central app inbox

## Tags iniciais

Tags:

- lead
- cliente
- urgente
- financeiro
- suporte
- orcamento
- reclamacao
- pos-venda

## Endpoints criados

Endpoints:

- GET api v1 attendance tags
- POST api v1 attendance tags
- GET api v1 attendance conversations conversation id notes
- POST api v1 attendance conversations conversation id notes
- GET api v1 attendance conversations conversation id tags
- POST api v1 attendance conversations conversation id tags

## Tabelas criadas

Tabelas:

- attendance conversation notes
- attendance tags
- attendance conversation tags

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-metadata/attendance-metadata.types.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.service.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.controller.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-metadata.types.ts
- apps/frontend/src/services/attendance-metadata.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente das tabelas
- seed inicial de tags
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint tags dominio
- criacao de tag dominio
- criacao de nota interna quando ha conversa real
- listagem de notas quando ha conversa real
- vinculo de tag quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_61_backend_typecheck.log
- logs/setup_61_backend_build.log
- logs/setup_61_frontend_typecheck.log
- logs/setup_61_frontend_build.log
- logs/setup_61_backend_docker_build.log
- logs/setup_61_frontend_docker_build.log
- logs/setup_61_docker_up.log
- logs/setup_61_backend_wait.log
- logs/setup_61_auth_login_domain.log
- logs/setup_61_attendance_conversations_domain.log
- logs/setup_61_note_create_domain.log
- logs/setup_61_notes_list_domain.log
- logs/setup_61_tags_list_domain.log
- logs/setup_61_tag_create_domain.log
- logs/setup_61_tag_attach_domain.log
- logs/setup_61_domain_inbox_page.log
- logs/setup_61_domain_dashboard.log
- logs/setup_61_domain_audit_page.log
- logs/setup_61.log

## Proxima etapa sugerida

Etapa 62:

    Criar encerramento com avaliacao do atendimento
