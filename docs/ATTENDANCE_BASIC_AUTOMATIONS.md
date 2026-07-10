# Attendance Basic Automations

## Visao geral

Este documento registra a criacao das automacoes basicas por status e departamento.

## Resultado

Status:

    concluido

## Correcao aplicada

A Etapa 71 foi concluida por fix seguro porque a primeira validacao tentou executar uma regra com gatilho diferente do status atual da conversa.

O fix ajustou uma regra de validacao para o status e departamento atuais da conversa e executou a automacao em dryRun.

## Funcionalidades criadas

Funcionalidades:

- tabela de regras de automacao
- tabela de execucoes de automacao
- seed de automacoes basicas
- endpoint para listar regras
- endpoint para atualizar regra
- endpoint para executar regra em conversa
- endpoint para listar execucoes
- validacao por status da conversa
- validacao por departamento
- limite de execucoes por conversa
- envio usando backend attendance send
- suporte a dryRun por regra

## Automacoes criadas

Automacoes:

- Saudacao inicial
- Transferencia de departamento
- Aguardando cliente
- Fora do horario
- Conversa sem responsavel

## Origens usadas

Origens:

- automation greeting
- automation transfer
- automation waiting customer
- automation out of hours
- automation unassigned

## Endpoints criados

Endpoints:

- GET api v1 attendance automations rules
- PATCH api v1 attendance automations rules rule id
- POST api v1 attendance automations rules rule id run
- GET api v1 attendance automations executions

## Tabelas criadas

Tabelas:

- attendance automation rules
- attendance automation executions

## Observacao operacional

As regras sao criadas inativas por padrao e com dryRun ativo.

Isso evita envio real acidental e permite validar cada automacao antes de ativar em producao.

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-automations/attendance-automations.types.ts
- apps/backend/src/modules/attendance-automations/attendance-automations.service.ts
- apps/backend/src/modules/attendance-automations/attendance-automations.controller.ts
- apps/backend/src/modules/attendance-automations/attendance-automations.module.ts
- apps/backend/src/modules/attendance-send/attendance-send.module.ts
- apps/backend/src/app.module.ts
- docs/ATTENDANCE_BASIC_AUTOMATIONS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente das tabelas
- seed das regras basicas
- endpoint attendance conversations dominio
- endpoint automations rules dominio
- endpoint update rule dominio
- endpoint run rule dominio em dryRun
- endpoint executions dominio
- historico de envios
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_71_auth_login_domain.log
- logs/setup_71_attendance_conversations_domain.log
- logs/setup_71_automation_rules_domain.log
- logs/setup_71_automation_rule_update_domain.log
- logs/setup_71_automation_run_domain.log
- logs/setup_71_automation_executions_domain.log
- logs/setup_71_send_history_domain.log
- logs/setup_71_domain_inbox_page.log
- logs/setup_71_domain_dashboard.log
- logs/setup_71_domain_attendance_dashboard.log
- logs/setup_71.log
- logs/fix_71_basic_status_department_automations.log

## Proxima etapa sugerida

Etapa 72:

    Painel de falhas e retentativas de envio
