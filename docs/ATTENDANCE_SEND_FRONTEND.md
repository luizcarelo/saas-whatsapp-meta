# Attendance Send Frontend

## Visao geral

Este documento registra a criacao do frontend de envio real no app inbox.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- types frontend para envios da central
- service frontend para envio manual pela central
- service frontend para historico de envios
- botao Enviar conectado ao backend attendance send
- modo dryRun ativo por padrao
- opcao visual para ativar ou desativar dryRun
- historico visual de envios da conversa
- feedback visual de validacao, envio ou falha
- validacao frontend para mensagem vazia

## Comportamento do envio

Comportamento:

- quando dryRun esta ativo, o sistema valida o envio sem enviar mensagem real
- quando dryRun esta desativado, o backend tenta enviar pela API oficial da Meta
- todo envio aparece no historico visual da conversa
- falhas sao exibidas no painel de historico
- o atendente e registrado no envio

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/attendance-send.types.ts
- apps/frontend/src/services/attendance-send.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_SEND_FRONTEND.md
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
- endpoint attendance send dryRun dominio
- endpoint attendance send history dominio
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_67_frontend_typecheck.log
- logs/setup_67_frontend_build.log
- logs/setup_67_frontend_docker_build.log
- logs/setup_67_docker_up.log
- logs/setup_67_auth_login_domain.log
- logs/setup_67_attendance_conversations_domain.log
- logs/setup_67_send_dry_run_domain.log
- logs/setup_67_send_history_domain.log
- logs/setup_67_domain_inbox_page.log
- logs/setup_67_domain_dashboard.log
- logs/setup_67_domain_attendance_dashboard.log
- logs/setup_67.log

## Proxima etapa sugerida

Etapa 68:

    Envio real usando respostas rapidas
