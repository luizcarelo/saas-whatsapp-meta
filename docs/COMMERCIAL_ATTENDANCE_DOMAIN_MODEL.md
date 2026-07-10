# Commercial Attendance Domain Model

## Visao geral

Este documento registra o modelo conceitual inicial da fase comercial.

## Entidades propostas

Entidades:

- opportunity
- follow up task
- customer commercial history
- commercial alert
- commercial dashboard

## Opportunity

Responsabilidade:

- representar uma possibilidade comercial vinculada a conversa ou contato

Campos sugeridos:

- id
- tenant id
- conversation id
- contact id
- title
- estimated value
- status
- source
- owner user id
- expected close date
- notes
- created at
- updated at
- deleted at

Status sugeridos:

- nova
- em qualificacao
- proposta enviada
- negociacao
- ganha
- perdida
- cancelada

## Follow up task

Responsabilidade:

- representar uma acao futura vinculada a conversa, contato ou oportunidade

Campos sugeridos:

- id
- tenant id
- conversation id
- contact id
- opportunity id
- title
- description
- due date
- status
- priority
- owner user id
- completed at
- created at
- updated at
- deleted at

Status sugeridos:

- aberta
- em andamento
- concluida
- atrasada
- cancelada

## Commercial history

Responsabilidade:

- reunir historico comercial por cliente

Fontes sugeridas:

- conversas
- oportunidades
- tarefas
- notas
- tags
- encerramentos
- avaliacoes

## Commercial alert

Responsabilidade:

- destacar situacoes que precisam de atencao

Alertas sugeridos:

- follow-up vencido
- conversa parada
- oportunidade sem movimentacao
- falha de envio pendente
- cliente aguardando retorno
