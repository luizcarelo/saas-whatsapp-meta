# Audit Data Hygiene

## Visao geral

Este documento registra a higienizacao de dados antigos de auditoria.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi corrigida a publicacao das rotas backend de higienizacao:

- GET api v1 operational audit hygiene preview
- POST api v1 operational audit hygiene run

O backend foi rebuildado e redeployado para evitar retorno 404.

## Politica implementada

A higienizacao e segura por padrao.

O endpoint de execucao usa dryRun como padrao, a menos que seja enviado dryRun false explicitamente.

A validacao automatica executa somente preview e dry-run seguro.

## Funcionalidades criadas

Funcionalidades:

- preview de dados antigos de auditoria
- dry-run de higienizacao
- endpoint de execucao protegida
- contagem de mensagens antigas
- contagem de mensagens failed antigas com metadata
- contagem de webhooks antigos
- redacao de metadata antiga quando execucao real for solicitada
- redacao de payload antigo de webhook quando execucao real for solicitada
- painel visual no app audit
- validacao sem alteracao automatica de dados

## Endpoints criados

Endpoints:

- GET api v1 operational audit hygiene preview
- POST api v1 operational audit hygiene run

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/operational-audit/operational-audit.types.ts
- apps/backend/src/modules/operational-audit/operational-audit.service.ts
- apps/backend/src/modules/operational-audit/operational-audit.controller.ts
- apps/backend/src/modules/operational-audit/operational-audit.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit/AuditPage.tsx
- docs/AUDIT_DATA_HYGIENE.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- endpoint summary dominio
- endpoint hygiene preview dominio
- endpoint hygiene dry run dominio
- export messages json dominio
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_47_backend_typecheck.log
- logs/setup_47_backend_build.log
- logs/setup_47_frontend_typecheck.log
- logs/setup_47_frontend_build.log
- logs/setup_47_backend_docker_build.log
- logs/setup_47_frontend_docker_build.log
- logs/setup_47_docker_up.log
- logs/setup_47_backend_wait.log
- logs/setup_47_auth_login_domain.log
- logs/setup_47_audit_summary_domain.log
- logs/setup_47_hygiene_preview_domain.log
- logs/setup_47_hygiene_dryrun_domain.log
- logs/setup_47_export_messages_json_domain.log
- logs/setup_47_domain_audit_page.log
- logs/setup_47_domain_dashboard.log
- logs/setup_47.log
- logs/fix_47_audit_data_hygiene_backend_routes.log

## Observacoes

A etapa nao apaga dados automaticamente.

A execucao real deve ser feita somente depois de revisar o preview e confirmar a politica de retencao desejada.

## Proxima etapa sugerida

Etapa 48:

    Criar configuracao visual de politica de retencao
