# Attendance Operational Flow

## Visao geral

Este documento define o fluxo operacional proposto para atendimento profissional.

## Fluxo de entrada

Fluxo:

- mensagem recebida pela API oficial da Meta
- conversa criada ou atualizada
- conversa entra na fila geral
- sistema tenta definir departamento padrao
- atendente assume ou supervisor distribui
- conversa passa para em atendimento

## Departamentos

Departamentos iniciais sugeridos:

- Comercial
- Suporte
- Financeiro
- Pos-venda
- Tecnico
- Administrativo

## Filas

Filas sugeridas:

- Fila geral
- Sem responsavel
- Comercial
- Suporte
- Financeiro
- Pos-venda
- Aguardando cliente
- Em atraso
- Encerradas

## Status de conversa

Status sugeridos:

- novo
- em atendimento
- aguardando cliente
- aguardando interno
- resolvido
- encerrado
- arquivado

## Responsavel pelo atendimento

Cada conversa deve permitir:

- responsavel atual
- nome do responsavel
- data de atribuicao
- historico de transferencia
- departamento atual

## Nome do usuario na resposta

O sistema deve registrar:

- usuario que enviou a mensagem
- nome do usuario
- data de envio
- departamento do usuario no momento do envio

Uso sugerido na interface:

- mostrar internamente quem respondeu
- permitir assinatura opcional para o cliente

## Mensagem de encerramento com avaliacao

Mensagem padrao sugerida:

Ola. Seu atendimento foi finalizado.

Para nos e muito importante saber como foi sua experiencia.

Por favor, avalie este atendimento respondendo com uma nota de 1 a 5:

1 - Muito ruim
2 - Ruim
3 - Regular
4 - Bom
5 - Excelente

Se desejar, voce tambem pode enviar um comentario com sua sugestao.

Obrigado por falar com a LH Solucao.

## Dados da avaliacao

Campos sugeridos:

- conversationId
- rating
- comment
- closedByUserId
- closedByName
- closedAt
- departmentId
- departmentName

## Respostas rapidas

Categorias sugeridas:

- Saudacao
- Pedido de dados
- Horario de atendimento
- Encaminhamento
- Encerramento
- Agradecimento
- Link de pagamento
- Prazo de retorno

## Notas internas

Uso:

- registrar informacoes internas
- manter historico operacional
- orientar proximo atendente
- nao enviar ao cliente

## Tags

Tags sugeridas:

- lead
- cliente
- urgente
- financeiro
- suporte
- orcamento
- renovacao
- reclamacao
- pos-venda

## SLA

Indicadores sugeridos:

- tempo em fila
- tempo desde ultima resposta
- tempo medio de primeira resposta
- conversas sem responsavel
- conversas em atraso
- SLA por departamento

## Dashboard de atendimento

Indicadores sugeridos:

- conversas abertas
- conversas por departamento
- conversas sem responsavel
- atendimentos encerrados hoje
- tempo medio de resposta
- avaliacao media
- mensagens recebidas hoje
- mensagens enviadas hoje
- falhas de envio
