# Attendance Screen Reorganization

## Visao geral

Este documento define a reorganizacao visual recomendada para o app inbox e telas relacionadas.

## Problema atual

O app inbox concentra muitas funcoes na mesma tela.

Funcoes acumuladas:

- lista de conversas
- filtros
- dados da conversa
- mensagens
- envio
- respostas rapidas
- encerramento
- avaliacao
- notas
- tags
- responsavel
- departamento
- status
- historico de envio
- dryRun

## Estrutura recomendada para app inbox

Estrutura:

- coluna esquerda
- coluna central
- coluna direita
- rodape de envio

## Coluna esquerda

Conteudo:

- busca
- filtros por status
- filtros por departamento
- filtros por responsavel
- lista de conversas
- indicador de nao lidas futuramente

## Coluna central

Conteudo:

- cabecalho da conversa
- historico de mensagens
- separacao visual entre inbound e outbound
- indicadores de status de envio
- mensagens de sistema quando necessario

## Coluna direita

Conteudo:

- contato
- status operacional
- departamento
- responsavel
- tags
- notas internas
- encerramento
- avaliacao
- historico compacto de operacoes

## Rodape de envio

Conteudo:

- campo de mensagem
- botao enviar
- respostas rapidas em menu ou drawer
- estado de envio
- aviso de dryRun somente quando habilitado

## Telas separadas recomendadas

Telas:

- app attendance dashboard
- app send failures
- app attendance settings

## Attendance Settings

Conteudo futuro:

- departamentos
- respostas rapidas
- automacoes
- parametros de dryRun
- mensagens padrao
- configuracoes de encerramento
- configuracoes de avaliacao

## Ordem recomendada de refino visual

Ordem:

- padronizar status
- limpar layout do inbox
- mover configuracoes para tela propria
- integrar falhas ao contexto da conversa
- revisar dados sinteticos
