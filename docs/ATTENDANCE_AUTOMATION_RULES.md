# Attendance Automation Rules

## Visao geral

Este documento registra as regras planejadas para automacoes da central de atendimento.

## Automacoes iniciais

Automacoes:

- saudacao inicial
- transferencia de departamento
- aguardando cliente
- encerramento com avaliacao
- fora do horario
- conversa sem responsavel

## Saudacao inicial

Regra:

- enviar apenas uma vez por conversa
- usar departamento Fila geral
- nao enviar se ja houver atendente respondendo
- registrar origem automation greeting

## Transferencia de departamento

Regra:

- enviar quando departamento mudar
- informar novo departamento
- registrar origem automation transfer
- nao enviar se transferencia for apenas ajuste interno silencioso

## Aguardando cliente

Regra:

- enviar quando status mudar para aguardando cliente
- usar resposta padrao configuravel
- registrar origem automation waiting customer

## Encerramento com avaliacao

Regra:

- enviar ao encerrar atendimento
- solicitar nota de 1 a 5
- registrar origem closing rating
- salvar encerramento antes do envio
- registrar avaliacao quando cliente responder

## Fora do horario

Regra:

- enviar quando mensagem chegar fora do horario configurado
- evitar envio repetido na mesma conversa
- registrar origem automation out of hours

## Conversa sem responsavel

Regra:

- alertar internamente quando conversa ficar sem responsavel
- opcionalmente enviar mensagem ao cliente informando fila
- registrar origem automation unassigned se houver envio ao cliente

## Limites de seguranca

Limites:

- evitar automacao duplicada
- evitar loop de mensagens
- respeitar status arquivado
- respeitar status encerrado
- registrar falhas
- permitir desativar automacoes por departamento

## Configuracoes futuras

Configuracoes:

- automacao ativa ou inativa
- departamento alvo
- status alvo
- mensagem padrao
- janela de horario
- limite de repeticao
- prioridade
