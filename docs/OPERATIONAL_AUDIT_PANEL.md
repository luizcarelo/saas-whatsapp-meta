# Operational Audit Panel

## Visao geral

Este documento registra a criacao do painel de auditoria operacional.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi corrigido o tratamento de webhooks com eventType nulo.

Quando eventType vier nulo do banco, a API retorna unknown para evitar falha de tipagem e quebra do painel.

## Funcionalidades criadas

Funcionalidades:

- endpoint de resumo operacional
- endpoint de mensagens recentes
- endpoint de webhooks recentes
- tela frontend em app audit
- cards com totais de mensagens
- cards com totais de webhooks
- filtro por status, direcao e tipo de mensagem
- filtro por status e tipo de webhook
- exibicao de providerMessageId
- exibicao de erro Meta sem expor token
- link Auditoria na sidebar

## Endpoints criados

Endpoints:

- GET api v1 operational audit summary
- GET api v1 operational audit messages
- GET api v1 operational audit webhooks

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/operational-audit/operational-audit.module.ts
- apps/backend/src/modules/operational-audit/operational-audit.controller.ts
- apps/backend/src/modules/operational-audit/operational-audit.service.ts
- apps/backend/src/modules/operational-audit/operational-audit.types.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit/AuditPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/OPERATIONAL_AUDIT_PANEL.md
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
- aguardo ativo do backend
- login dominio
- endpoint summary dominio
- endpoint messages dominio
- endpoint webhooks dominio
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_45_backend_typecheck.log
- logs/setup_45_backend_build.log
- logs/setup_45_frontend_typecheck.log
- logs/setup_45_frontend_build.log
- logs/setup_45_backend_docker_build.log
- logs/setup_45_frontend_docker_build.log
- logs/setup_45_docker_up.log
- logs/setup_45_backend_wait.log
- logs/setup_45_auth_login_domain.log
- logs/setup_45_audit_summary_domain.log
- logs/setup_45_audit_messages_domain.log
- logs/setup_45_audit_webhooks_domain.log
- logs/setup_45_domain_audit_page.log
- logs/setup_45_domain_dashboard.log
- logs/setup_45.log
- logs/fix_45_operational_audit_event_type_null.log

## Proxima etapa sugerida

Etapa 46:

    Criar relatorio operacional exportavel
