# Attendance Send Failures Retry Panel

## Visao geral

Este documento registra a criacao do painel de falhas e retentativas de envio.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- listagem de envios com falha
- endpoint para retentar envio com falha
- endpoint para listar retentativas
- campos de relacionamento entre envio original e retentativa
- contador de retentativas no envio original
- data da ultima retentativa
- painel visual app send failures
- modo dryRun ativo por padrao na retentativa
- validacao com falha sintetica controlada
- historico visual de retentativas

## Endpoints criados

Endpoints:

- GET api v1 attendance send failures
- POST api v1 attendance send failures send id retry
- GET api v1 attendance send failures retries

## Alteracoes de banco

Alteracoes:

- retry of send id em attendance manual message sends
- retry count em attendance manual message sends
- last retry at em attendance manual message sends
- indices de apoio para falhas e retentativas

## Tela criada

Tela:

- app send failures

## Observacao operacional

A retentativa usa dryRun por padrao na tela e na validacao automatica.

Isso evita envio real acidental e permite validar a correcao antes de retentar em producao.

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-send-failures/attendance-send-failures.types.ts
- apps/backend/src/modules/attendance-send-failures/attendance-send-failures.service.ts
- apps/backend/src/modules/attendance-send-failures/attendance-send-failures.controller.ts
- apps/backend/src/modules/attendance-send-failures/attendance-send-failures.module.ts
- apps/backend/src/modules/attendance-send/attendance-send.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-send-failures.types.ts
- apps/frontend/src/services/attendance-send-failures.service.ts
- apps/frontend/src/pages/send-failures/SendFailuresPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_SEND_FAILURES_RETRY_PANEL.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- alteracao idempotente da tabela de envios
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint attendance conversations dominio
- criacao de falha sintetica controlada
- endpoint failures dominio
- endpoint retry dominio em dryRun
- endpoint retries dominio
- rota app inbox
- rota app send failures
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_72_backend_typecheck.log
- logs/setup_72_backend_build.log
- logs/setup_72_frontend_typecheck.log
- logs/setup_72_frontend_build.log
- logs/setup_72_backend_docker_build.log
- logs/setup_72_frontend_docker_build.log
- logs/setup_72_docker_up.log
- logs/setup_72_backend_wait.log
- logs/setup_72_auth_login_domain.log
- logs/setup_72_attendance_conversations_domain.log
- logs/setup_72_seed_failure.log
- logs/setup_72_failures_domain.log
- logs/setup_72_retry_domain.log
- logs/setup_72_retries_domain.log
- logs/setup_72_domain_inbox_page.log
- logs/setup_72_domain_send_failures_page.log
- logs/setup_72_domain_dashboard.log
- logs/setup_72_domain_attendance_dashboard.log
- logs/setup_72.log

## Proxima etapa sugerida

Etapa 73:

    Revisao final da fase de automacao e envio real
