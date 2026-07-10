# Pendencia Meta Webhook Recebimento

## Visao geral

Este documento registra a pendencia operacional relacionada ao recebimento real de mensagens pela API oficial da Meta.

## Status

Status:

    aguardando configuracoes ou retorno da Meta

## Situacao atual

Situacao:

- endpoint publico de webhook responde com sucesso ao GET de verificacao
- endpoint validou usando WHATSAPP VERIFY TOKEN
- variavel antiga META WEBHOOK VERIFY TOKEN foi removida do .env
- phone number consultado apresentou webhook application apontando para o endpoint correto
- testes ao vivo recentes nao receberam POST novo da Meta
- messages inbound e webhook events nao aumentaram nos testes ao vivo

## Endpoint correto

Endpoint:

    bot.lhsolucao.com.br api v1 webhooks meta

## Pontos pendentes na Meta

Pendencias:

- confirmar campo messages inscrito
- confirmar app em modo adequado
- confirmar permissao whatsapp business messaging
- confirmar WABA e phone number corretos
- confirmar ausencia de override externo inesperado
- aguardar processamento ou retorno da Meta

## Observacao

A pendencia nao bloqueia a revisao final da fase de automacao e envio real, pois o fluxo de backend, frontend, dryRun, falhas, retentativas e auditoria operacional foi validado internamente.
