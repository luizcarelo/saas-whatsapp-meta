# Attendance Status Standardization

## Visao geral

Este documento registra a padronizacao dos status do modulo Atendimento.

## Resultado

Status:

    concluido

## Objetivo

Objetivo:

- separar status tecnico da conversa
- separar status operacional do atendimento
- separar status de envio
- separar status de encerramento e avaliacao
- manter compatibilidade com status antigos
- preparar refino visual do app inbox

## Grupos padronizados

Grupos:

- conversation
- attendance
- send
- closure

## Conversation

Uso:

- ciclo tecnico da conversa

Valores:

- open
- closed
- archived

## Attendance

Uso:

- situacao operacional do atendimento para a central

Valores:

- novo
- em_atendimento
- aguardando_cliente
- aguardando_atendente
- encerrado
- arquivado

## Send

Uso:

- situacao de uma mensagem enviada ou simulada

Valores:

- pending
- sent
- delivered
- read
- failed
- dry_run

## Closure

Uso:

- situacao de encerramento e avaliacao

Valores:

- closure_created
- rating_requested
- rating_received
- rating_not_received

## Compatibilidade

Compatibilidade:

- human para conversation open
- closed para conversation closed
- em atendimento para attendance em_atendimento
- aguardando cliente para attendance aguardando_cliente
- dry run para send dry_run

## Endpoints criados

Endpoints:

- GET api v1 attendance status model
- GET api v1 attendance status options
- GET api v1 attendance status compatibility map

## Tabelas criadas

Tabelas:

- attendance status catalog
- attendance status compatibility map

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-status/attendance-status.types.ts
- apps/backend/src/modules/attendance-status/attendance-status.service.ts
- apps/backend/src/modules/attendance-status/attendance-status.controller.ts
- apps/backend/src/modules/attendance-status/attendance-status.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-status.types.ts
- apps/frontend/src/services/attendance-status.service.ts
- apps/frontend/src/utils/attendance-status.ts
- docs/ATTENDANCE_STATUS_STANDARDIZATION.md
- docs/ATTENDANCE_STATUS_COMPATIBILITY_MAP.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- catalogo padronizado criado
- mapa de compatibilidade criado
- endpoint status model
- endpoint status options
- endpoint status compatibility map
- endpoint attendance conversations
- contagens de banco
- paginas principais do frontend

## Observacao do fix

A primeira execucao da Etapa 75 aplicou a parte tecnica, mas parou antes de gerar documentacao e log final por erro de variavel no script.

Este fix concluiu a documentacao, validacoes finais, controle e manifesto.

## Proxima etapa sugerida

Etapa 76:

    Reorganizacao visual do app inbox
