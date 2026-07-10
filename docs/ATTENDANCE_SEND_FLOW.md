# Attendance Send Flow

## Visao geral

Este documento define o fluxo planejado para envio real pela central de atendimento.

## Fluxo de envio manual

Fluxo:

- atendente acessa app inbox
- atendente seleciona conversa
- sistema carrega conversa e contato
- atendente digita mensagem
- atendente clica em enviar
- frontend chama endpoint de envio da central
- backend valida autenticacao
- backend valida tenant
- backend valida conversa
- backend valida contato e telefone
- backend valida conta WhatsApp ativa
- backend envia mensagem pela API oficial da Meta
- backend grava mensagem no historico
- backend grava origem manual
- backend grava atendente responsavel
- frontend atualiza conversa
- frontend exibe sucesso ou erro

## Fluxo de resposta rapida

Fluxo:

- atendente seleciona resposta rapida
- sistema preenche o campo de mensagem
- atendente pode editar a mensagem
- atendente clica em enviar
- backend grava origem resposta rapida
- mensagem e enviada pela API oficial da Meta
- historico registra resposta usada

## Fluxo de encerramento

Fluxo:

- atendente clica em encerrar atendimento
- sistema prepara mensagem de avaliacao
- atendente revisa mensagem
- backend envia mensagem pela API oficial da Meta
- conversa muda para encerrado
- encerramento fica registrado
- sistema aguarda avaliacao do cliente
- avaliacao de 1 a 5 e registrada quando informada

## Fluxo de automacao

Fluxo:

- evento operacional ocorre
- sistema verifica regra ativa
- sistema verifica departamento
- sistema verifica status da conversa
- sistema valida se automacao pode enviar
- backend envia mensagem automatica
- mensagem fica com origem automacao
- falhas ficam registradas para revisao

## Estados de envio

Estados:

- pending
- sent
- delivered
- read
- failed

## Origem operacional

Origem:

- manual
- quick_reply
- closing_rating
- automation_greeting
- automation_transfer
- automation_waiting_customer
- automation_out_of_hours
- automation_unassigned

## Rastreabilidade

Cada envio deve permitir responder:

- quem enviou
- quando enviou
- de qual departamento enviou
- por qual conta WhatsApp enviou
- para qual contato enviou
- qual foi a origem
- qual retorno a Meta informou
- se houve falha
