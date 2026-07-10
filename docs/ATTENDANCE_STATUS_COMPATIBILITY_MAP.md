# Attendance Status Compatibility Map

## Visao geral

Este documento registra o mapa de compatibilidade entre status antigos e o modelo padronizado do Atendimento.

## Objetivo

Objetivo:

- preservar compatibilidade
- evitar quebra de dados antigos
- permitir migracao gradual
- separar status por grupo funcional

## Mapeamentos principais

Mapeamentos:

- conversation human para conversation open
- conversation closed para conversation closed
- conversation open para conversation open
- conversation archived para conversation archived
- attendance novo para attendance novo
- attendance em atendimento para attendance em_atendimento
- attendance em_atendimento para attendance em_atendimento
- attendance aguardando cliente para attendance aguardando_cliente
- attendance aguardando_cliente para attendance aguardando_cliente
- attendance aguardando_atendente para attendance aguardando_atendente
- attendance encerrado para attendance encerrado
- attendance arquivado para attendance arquivado
- send pending para send pending
- send sent para send sent
- send delivered para send delivered
- send read para send read
- send failed para send failed
- send dry run para send dry_run
- send dry_run para send dry_run

## Regra operacional

Regra:

- status tecnico da conversa nao deve ser usado como status operacional
- status operacional nao deve ser usado como status de envio
- status de envio nao deve alterar automaticamente status da conversa
- status de encerramento e avaliacao deve ser tratado separadamente

## Uso futuro

Uso futuro:

- app inbox deve exibir labels usando o grupo correto
- filtros da central devem usar status operacional
- painel de falhas deve usar status de envio
- encerramento deve usar status de closure quando necessario
