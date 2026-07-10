# Attendance Status Model

## Visao geral

Este documento define o modelo recomendado para separar os diferentes tipos de status no modulo Atendimento.

## Problema identificado

Existem status de naturezas diferentes usando nomes parecidos ou misturados.

Exemplos observados:

- human
- closed
- novo
- em atendimento
- aguardando cliente
- encerrado
- arquivado
- pending
- sent
- failed
- dry run
- delivered
- read

## Separacao recomendada

Separar status em quatro grupos:

- status da conversa base
- status operacional do atendimento
- status de envio da mensagem
- status de encerramento e avaliacao

## Status da conversa base

Uso:

- representa o ciclo tecnico da conversa

Valores recomendados:

- open
- closed
- archived

Observacao:

- este status deve ser simples e tecnico

## Status operacional do atendimento

Uso:

- representa a fila e situacao para o atendente

Valores recomendados:

- novo
- em_atendimento
- aguardando_cliente
- aguardando_atendente
- encerrado
- arquivado

Observacao:

- este status deve ser o principal na central de atendimento

## Status de envio

Uso:

- representa o estado de cada mensagem enviada

Valores recomendados:

- pending
- sent
- delivered
- read
- failed
- dry_run

Observacao:

- este status nao deve ser confundido com status da conversa

## Status de encerramento e avaliacao

Uso:

- representa encerramento e retorno do cliente

Valores recomendados:

- closure_created
- rating_requested
- rating_received
- rating_not_received

## Mapeamento sugerido

Mapeamento:

- human pode ser tratado como conversa open com atendimento em_atendimento
- closed pode ser tratado como conversa closed com atendimento encerrado
- encerrado deve permanecer no status operacional
- failed deve existir somente no envio
- dry_run deve existir somente no envio ou automacao

## Regras

Regras:

- uma mudanca de status operacional nao deve alterar automaticamente status de envio
- uma falha de envio nao deve encerrar conversa
- encerramento nao deve apagar historico
- arquivamento deve ser decisao operacional explicita
- automacao deve respeitar status operacional
