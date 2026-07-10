# Retention Policy Backend

## Visao geral

Este documento registra a persistencia backend da politica de retencao por tenant.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela operational audit settings
- politica de retencao por tenant
- endpoint para consultar politica de retencao
- endpoint para atualizar politica de retencao
- uso da politica persistida no preview de higienizacao
- uso da politica persistida no dry-run de higienizacao
- integracao do painel app audit com backend
- fallback local caso backend nao carregue
- validacao sem executar higienizacao real

## Endpoints criados

Endpoints:

- GET api v1 operational audit retention policy
- PATCH api v1 operational audit retention policy

## Tabela criada

Tabela:

- operational audit settings

Campos:

- id
- tenant id
- audit retention days
- created at
- updated at

## Politica de seguranca

A etapa nao executa higienizacao real.

A validacao executa GET e PATCH da politica e depois usa preview e dry-run seguro.

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
- apps/frontend/src/styles.css
- docs/RETENTION_POLICY_BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela operational audit settings
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- GET retention policy dominio
- PATCH retention policy dominio com 180 dias
- GET retention policy after dominio
- hygiene preview usando politica persistida
- hygiene dry-run usando politica persistida
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_49_backend_typecheck.log
- logs/setup_49_backend_build.log
- logs/setup_49_frontend_typecheck.log
- logs/setup_49_frontend_build.log
- logs/setup_49_backend_docker_build.log
- logs/setup_49_frontend_docker_build.log
- logs/setup_49_docker_up.log
- logs/setup_49_backend_wait.log
- logs/setup_49_auth_login_domain.log
- logs/setup_49_retention_policy_get_domain.log
- logs/setup_49_retention_policy_patch_domain.log
- logs/setup_49_retention_policy_get_after_domain.log
- logs/setup_49_hygiene_preview_domain.log
- logs/setup_49_hygiene_dryrun_domain.log
- logs/setup_49_domain_audit_page.log
- logs/setup_49_domain_dashboard.log
- logs/setup_49.log

## Proxima etapa sugerida

Etapa 50:

    Criar execucao operacional controlada de higienizacao real
