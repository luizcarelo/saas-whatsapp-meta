# Attendance Closing Rating Send

## Visao geral

Este documento registra o envio da mensagem de encerramento com avaliacao pela central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- envio da mensagem de encerramento pela central app inbox
- origem closing rating no envio
- uso do mesmo modo dryRun da central
- encerramento registrado antes do envio
- mensagem de avaliacao enviada ou validada pelo backend de envio
- historico visual indicando envio de encerramento
- feedback visual para envio validado, enviado ou com falha

## Comportamento

Comportamento:

- atendente prepara a mensagem de encerramento
- atendente clica em encerrar e preparar mensagem
- sistema registra o encerramento
- sistema chama o backend de envio com message origin closing rating
- se dryRun estiver ativo, nenhuma mensagem real e enviada
- se dryRun estiver desativado, o backend tenta enviar pela API oficial da Meta
- historico da conversa exibe o envio com indicador de encerramento

## Validacao de seguranca

Validacao:

- dryRun permanece ativo por padrao
- setup valida apenas dryRun
- envio real depende do atendente desativar dryRun na tela
- backend continua validando conta WhatsApp, token, conversa, contato e telefone

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_CLOSING_RATING_SEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- login dominio
- endpoint attendance conversations dominio
- endpoint close conversation dominio
- dryRun de envio com origem closing rating
- historico de envios
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_69_frontend_typecheck.log
- logs/setup_69_frontend_build.log
- logs/setup_69_frontend_docker_build.log
- logs/setup_69_docker_up.log
- logs/setup_69_auth_login_domain.log
- logs/setup_69_attendance_conversations_domain.log
- logs/setup_69_close_conversation_domain.log
- logs/setup_69_closing_send_domain.log
- logs/setup_69_send_history_domain.log
- logs/setup_69_domain_inbox_page.log
- logs/setup_69_domain_dashboard.log
- logs/setup_69_domain_attendance_dashboard.log
- logs/setup_69.log

## Proxima etapa sugerida

Etapa 70:

    Registro do atendente nas mensagens enviadas
