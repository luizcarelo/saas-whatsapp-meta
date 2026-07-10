# Attendance Domain Boundaries

## Visao geral

Este documento define as fronteiras conceituais recomendadas para o modulo Atendimento.

## Dominios recomendados

Dominios:

- conversations
- attendance
- attendance metadata
- attendance closure
- attendance send
- attendance send failures
- attendance automations
- attendance dashboard
- webhooks meta

## Conversations

Responsabilidade:

- conversa base
- contato da conversa
- mensagens recebidas e enviadas
- canal da conversa
- vinculo com conta WhatsApp
- historico bruto de mensagens

Nao deve concentrar:

- regra de automacao
- configuracao de departamento
- dashboard gerencial
- retentativa operacional

## Attendance

Responsabilidade:

- estado operacional do atendimento
- departamento atual
- responsavel atual
- fila
- status operacional
- movimentacoes operacionais

Nao deve concentrar:

- payload bruto de webhook
- chamada direta para Meta
- configuracao de templates
- armazenamento de token

## Attendance Metadata

Responsabilidade:

- departamentos
- respostas rapidas
- tags
- notas internas
- opcoes auxiliares da central

Nao deve concentrar:

- envio real
- encerramento
- retentativa
- regras automaticas complexas

## Attendance Closure

Responsabilidade:

- encerramento
- mensagem de encerramento
- solicitacao de avaliacao
- nota de avaliacao
- comentario de avaliacao
- historico de encerramentos

Nao deve concentrar:

- regra geral de envio
- configuracao de automacoes
- painel de falhas

## Attendance Send

Responsabilidade:

- envio manual
- envio por resposta rapida
- envio de encerramento
- envio de automacao
- origem da mensagem
- status do envio
- retorno do provedor
- dryRun

Nao deve concentrar:

- listagem gerencial de falhas
- configuracoes de respostas rapidas
- regras de automacao

## Attendance Send Failures

Responsabilidade:

- listagem de falhas
- retentativas
- relacao entre envio original e retentativa
- painel operacional de erros

Nao deve concentrar:

- composer principal da conversa
- definicao de automacoes
- configuracao de departamentos

## Attendance Automations

Responsabilidade:

- regras por status e departamento
- execucoes de automacao
- limite por conversa
- origem automation
- dryRun de automacao

Nao deve concentrar:

- atendimento manual do operador
- historico completo da conversa
- painel de falhas globais

## Attendance Dashboard

Responsabilidade:

- metricas
- resumo gerencial
- cards
- indicadores por status
- indicadores por departamento

Nao deve concentrar:

- execucao de envio
- edicao de mensagens
- regras de automacao

## Webhooks Meta

Responsabilidade:

- receber payloads da Meta
- validar assinatura
- registrar eventos
- processar mensagens inbound
- processar status outbound

Nao deve concentrar:

- experiencia visual da central
- regras comerciais de atendimento
- configuracoes de tela
