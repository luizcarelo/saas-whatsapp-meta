# Attendance Quick Reply Send

## Visao geral

Este documento registra o envio usando respostas rapidas na central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- origem quick reply no envio pela central
- quick reply id no registro do envio
- quick reply title no registro do envio
- selecao visual de resposta rapida
- destaque visual da resposta rapida selecionada
- botao para limpar resposta rapida selecionada
- envio com message origin quick reply
- historico visual indicando resposta rapida usada
- validacao dryRun de resposta rapida

## Comportamento

Comportamento:

- ao clicar em uma resposta rapida, o campo de mensagem e preenchido
- a resposta rapida fica selecionada visualmente
- ao enviar, o backend recebe message origin quick reply
- o envio grava quick reply id e quick reply title
- em modo dryRun nenhuma mensagem real e enviada
- ao desativar dryRun o backend tenta enviar pela API oficial da Meta

## Alteracoes de banco

Alteracoes:

- quick reply id em attendance manual message sends
- quick reply title em attendance manual message sends
- indice por quick reply id

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-send/attendance-send.types.ts
- apps/backend/src/modules/attendance-send/attendance-send.service.ts
- apps/frontend/src/types/attendance-send.types.ts
- apps/frontend/src/services/attendance-send.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_QUICK_REPLY_SEND.md
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
- endpoint quick replies dominio
- dryRun de envio com origem quick reply
- historico de envios
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_68_backend_typecheck.log
- logs/setup_68_backend_build.log
- logs/setup_68_frontend_typecheck.log
- logs/setup_68_frontend_build.log
- logs/setup_68_backend_docker_build.log
- logs/setup_68_frontend_docker_build.log
- logs/setup_68_docker_up.log
- logs/setup_68_backend_wait.log
- logs/setup_68_auth_login_domain.log
- logs/setup_68_attendance_conversations_domain.log
- logs/setup_68_quick_replies_domain.log
- logs/setup_68_quick_reply_send_domain.log
- logs/setup_68_send_history_domain.log
- logs/setup_68_domain_inbox_page.log
- logs/setup_68_domain_dashboard.log
- logs/setup_68_domain_attendance_dashboard.log
- logs/setup_68.log

## Proxima etapa sugerida

Etapa 69:

    Envio real da mensagem de encerramento com avaliacao
