# Retention Policy Visual Config

## Visao geral

Este documento registra a configuracao visual da politica de retencao no painel de auditoria.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- painel visual de politica de retencao
- campo de dias de retencao
- atalhos de 30, 60, 90, 180 e 365 dias
- salvamento local da politica visual no navegador
- uso da politica visual no preview de higienizacao
- uso da politica visual no dry-run seguro
- manutencao das exportacoes CSV e JSON
- manutencao dos filtros de mensagens e webhooks
- validacao sem apagar dados

## Politica de seguranca

A etapa nao executa higienizacao real.

A validacao executa somente preview e dry-run seguro.

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit/AuditPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/RETENTION_POLICY_VISUAL_CONFIG.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- login dominio
- hygiene preview com 180 dias
- hygiene dry-run com 180 dias
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_48_frontend_typecheck.log
- logs/setup_48_frontend_build.log
- logs/setup_48_frontend_docker_build.log
- logs/setup_48_frontend_docker_up.log
- logs/setup_48_auth_login_domain.log
- logs/setup_48_hygiene_preview_domain.log
- logs/setup_48_hygiene_dryrun_domain.log
- logs/setup_48_domain_audit_page.log
- logs/setup_48_domain_dashboard.log
- logs/setup_48.log

## Observacoes

A politica visual e salva localmente no navegador.

Uma persistencia global em banco por tenant pode ser criada em etapa posterior, se necessario.

## Proxima etapa sugerida

Etapa 49:

    Criar persistencia backend da politica de retencao por tenant
