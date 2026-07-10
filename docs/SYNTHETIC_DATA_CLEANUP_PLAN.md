# Synthetic Data Cleanup Plan

## Visao geral

Este documento registra o plano seguro para limpeza futura de dados sinteticos.

## Principios

Principios:

- nao remover dados reais
- nao remover dados sem backup
- nao remover dados sem relatorio previo
- nao remover dados sem aprovacao explicita
- preservar auditoria
- preservar rastreabilidade
- usar soft delete quando disponivel

## Criterios de candidato sintetico

Criterios:

- textos contendo teste
- textos contendo etapa
- textos contendo sintetica
- textos contendo validad
- registros com attendant source validation
- envios com dryRun
- contas com local no identificador
- contas com restore no identificador
- contas com fix no identificador
- contas com frontend no identificador

## Criterios de exclusao da limpeza

Exclusoes:

- mensagens reais de clientes
- mensagens inbound recentes sem marcador sintetico
- contas WhatsApp reais ativas
- eventos de auditoria necessarios para rastreabilidade
- dados relacionados a pendencia Meta
- dados sem marcador claro

## Processo futuro recomendado

Processo:

- revisar logs da Etapa 79
- aprovar lista de IDs
- gerar backup antes da limpeza
- executar limpeza em modo dryRun
- validar contagens
- executar limpeza real apenas com aceite
- atualizar documentos auxiliares
- registrar log final

## Status

Status:

    plano criado e aguardando aprovacao futura
