# Attendance Module Refinement Plan

## Visao geral

Este documento registra o plano de refino estrutural do modulo Atendimento.

## Resultado

Status:

    planejado

## Problema identificado

O modulo Atendimento cresceu por etapas sucessivas e passou a concentrar muitas responsabilidades operacionais na mesma area funcional.

Responsabilidades acumuladas:

- conversas
- mensagens
- status operacional
- departamento
- responsavel
- respostas rapidas
- notas internas
- tags
- encerramento
- avaliacao
- envio manual
- envio por resposta rapida
- envio de encerramento
- automacoes
- falhas de envio
- retentativas
- dashboard
- pendencia de recebimento real via Meta

## Objetivo do refino

Objetivo:

- tornar o modulo Atendimento mais claro
- separar responsabilidades por dominio
- reduzir confusao de status
- simplificar a central app inbox
- preservar funcionalidades ja validadas
- evoluir em etapas pequenas
- evitar refatoracao grande e arriscada
- manter documentacao obrigatoria atualizada

## Principio de evolucao

Principios:

- nao quebrar fluxo validado
- preservar APIs existentes quando possivel
- criar aliases ou adaptadores antes de remover rotas antigas
- documentar toda decisao tecnica
- usar dryRun onde houver risco de envio real
- manter pendencia Meta separada do refino visual e estrutural
- limpar dados sinteticos somente em etapa propria

## Diagnostico sintetico

Diagnostico:

- app inbox esta sobrecarregado
- status base da conversa e status operacional estao misturados
- envio, encerramento e historico visual dividem o mesmo espaco
- automacoes e falhas ja existem mas precisam ser organizadas na experiencia
- dashboard e painel de falhas estao separados, mas precisam de melhor navegacao
- configuracoes de atendimento ainda nao possuem tela propria

## Resultado esperado do refino

Resultado esperado:

- atendimento com modelo de status claro
- app inbox organizado em colunas funcionais
- envio e historico mais simples de entender
- configuracoes separadas em attendance settings
- falhas e retentativas integradas ao contexto da conversa
- automacoes controladas fora do fluxo principal do atendente
- modulo pronto para uso operacional mais profissional
