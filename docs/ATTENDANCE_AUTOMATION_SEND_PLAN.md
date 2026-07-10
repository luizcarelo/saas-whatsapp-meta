# Attendance Automation Send Plan

## Visao geral

Este documento registra o planejamento da proxima fase de automacao e envio real pela central de atendimento.

## Nome da fase

Fase 11 - Automacao e envio real pela central de atendimento

## Objetivo

Planejar a conexao da central app inbox com o envio real de mensagens pela API oficial da Meta, preservando seguranca, rastreabilidade, auditoria e fluxo operacional profissional.

## Premissas

Premissas:

- manter a API oficial da Meta como canal principal
- preservar a central app inbox criada na fase anterior
- preservar a auditoria operacional existente
- preservar departamentos, filas, responsaveis, tags, notas internas e respostas rapidas
- registrar o atendente que enviou a mensagem
- registrar origem da mensagem
- validar conta WhatsApp ativa antes de enviar
- validar conteudo antes de enviar
- tratar falhas de envio com mensagem amigavel
- implementar em etapas pequenas
- atualizar documentacao e controle a cada etapa

## Escopo planejado

Escopo:

- envio manual pela central app inbox
- envio usando respostas rapidas
- envio de mensagem de encerramento com avaliacao
- registro do atendente nas mensagens enviadas
- origem da mensagem enviada
- historico de envio pela central
- automacoes basicas por status e departamento
- painel de falhas de envio
- retentativas controladas
- revisao final da fase

## Origem das mensagens

Origens planejadas:

- manual
- resposta rapida
- encerramento
- automacao de saudacao
- automacao de transferencia
- automacao de aguardando cliente
- automacao de fora do horario
- automacao de conversa sem responsavel

## Dados obrigatorios por envio

Dados:

- tenant id
- conversation id
- contact id
- whatsapp account id
- phone number id
- message body
- sent by user id
- sent by name
- department name
- conversation status
- message origin
- provider
- provider message id
- provider response
- status
- created at
- updated at

## Regras de seguranca

Regras:

- nao enviar mensagem vazia
- nao enviar sem conversa valida
- nao enviar sem contato valido
- nao enviar sem telefone valido
- nao enviar sem conta WhatsApp ativa
- nao enviar sem token configurado
- nao enviar se a conversa estiver arquivada
- exigir usuario autenticado
- registrar falha de envio
- preservar erro tecnico em log
- exibir mensagem simples para o atendente

## Etapas propostas

Etapas:

- Etapa 66 - Backend de envio manual pela central de atendimento
- Etapa 67 - Frontend de envio real no app inbox
- Etapa 68 - Envio real usando respostas rapidas
- Etapa 69 - Envio real da mensagem de encerramento com avaliacao
- Etapa 70 - Registro do atendente nas mensagens enviadas
- Etapa 71 - Automacoes basicas por status e departamento
- Etapa 72 - Painel de falhas e retentativas de envio
- Etapa 73 - Revisao final da fase de automacao e envio real

## Primeira implementacao recomendada

Primeira implementacao:

Etapa 66 - Backend de envio manual pela central de atendimento

Motivo:

- cria base segura de envio
- centraliza validacoes
- evita acoplamento direto do frontend com a Meta
- permite auditar cada envio
- prepara respostas rapidas e encerramento para envio real

## Resultado esperado da fase

Resultado esperado:

- atendente envia mensagens reais pela central
- respostas rapidas podem ser enviadas ao cliente
- encerramento com avaliacao pode ser enviado ao cliente
- mensagens enviadas registram atendente e origem
- falhas de envio ficam visiveis
- sistema fica pronto para automacoes operacionais
