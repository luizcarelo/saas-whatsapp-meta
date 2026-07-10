# Controlled Real Hygiene

## Visao geral

Este documento registra a execucao operacional controlada de higienizacao real.

## Resultado

Status:

    concluido

## Politica de seguranca

A execucao real exige:

- backup SQL previo obrigatorio
- endpoint separado
- frase de confirmacao obrigatoria
- autenticacao via JWT
- retencao informada ou politica persistida
- registro da execucao real em tabela de auditoria

Frase de confirmacao:

    EXECUTAR_HIGIENIZACAO_REAL

## Backup SQL

Backup gerado antes da validacao:

    /home/luizcarelo/saas-whatsapp-meta/backups/setup_50_before_real_hygiene_20260709_211653.sql

## Funcionalidades criadas

Funcionalidades:

- endpoint POST api v1 operational audit hygiene real run
- frase obrigatoria para execucao real
- tabela operational audit hygiene runs
- registro de cada execucao real
- tela app audit real run
- preview antes de execucao
- validacao de execucao real controlada com retencao alta
- manutencao do painel de auditoria existente

## Endpoints criados

Endpoints:

- POST api v1 operational audit hygiene real run

## Tabela criada

Tabela:

- operational audit hygiene runs

Campos:

- id
- tenant id
- retention days
- dry run
- confirmation phrase
- old messages
- old failed messages with metadata
- old webhook events
- messages redacted
- webhook events redacted
- created at

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/operational-audit/operational-audit.types.ts
- apps/backend/src/modules/operational-audit/operational-audit.service.ts
- apps/backend/src/modules/operational-audit/operational-audit.controller.ts
- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit-real-run/AuditRealRunPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/CONTROLLED_REAL_HYGIENE.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- backup SQL obrigatorio
- criacao idempotente da tabela operational audit hygiene runs
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- get retention policy dominio
- preview com 3650 dias
- execucao real controlada com frase obrigatoria e 3650 dias
- rota app audit real run
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_50_backend_typecheck.log
- logs/setup_50_backend_build.log
- logs/setup_50_frontend_typecheck.log
- logs/setup_50_frontend_build.log
- logs/setup_50_backend_docker_build.log
- logs/setup_50_frontend_docker_build.log
- logs/setup_50_docker_up.log
- logs/setup_50_backend_wait.log
- logs/setup_50_auth_login_domain.log
- logs/setup_50_retention_policy_get_domain.log
- logs/setup_50_hygiene_preview_domain.log
- logs/setup_50_hygiene_real_run_domain.log
- logs/setup_50_domain_audit_real_run_page.log
- logs/setup_50_domain_audit_page.log
- logs/setup_50_domain_dashboard.log
- logs/setup_50.log

## Proxima etapa sugerida

Etapa 51:

    Criar relatorio historico das execucoes reais de higienizacao
