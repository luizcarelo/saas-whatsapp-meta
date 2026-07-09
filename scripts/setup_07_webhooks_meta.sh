#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_07.log"

echo "== Etapa 07: Documentacao de webhooks da Meta =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${DOCS_DIR}/WEBHOOKS_META.md" ]; then
  cp "${DOCS_DIR}/WEBHOOKS_META.md" "${BACKUPS_DIR}/WEBHOOKS_META_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Gerando docs/WEBHOOKS_META.md..."

cat > "${DOCS_DIR}/WEBHOOKS_META.md" <<'DOC'
# Webhooks da Meta para WhatsApp

## Visao geral

Este documento define a estrategia inicial para receber, validar, registrar e processar webhooks da Meta relacionados ao WhatsApp Business Platform.

O webhook sera o ponto de entrada para eventos enviados pela Meta, como mensagens recebidas e atualizacoes de status de mensagens enviadas.

O endpoint de webhook sera publico, por isso deve ser tratado como uma area sensivel do sistema.

## Objetivos

A implementacao de webhooks deve permitir:

- Verificar o endpoint configurado na Meta
- Receber eventos de mensagens
- Receber eventos de status
- Registrar payload bruto
- Identificar tenant pelo phone_number_id
- Enfileirar processamento
- Responder rapidamente para a Meta
- Evitar processamento duplicado
- Registrar falhas
- Manter auditoria tecnica

## Rotas previstas

## GET /api/v1/webhooks/meta/whatsapp

Rota usada para verificacao inicial do webhook.

Responsabilidades:

- Receber parametros de verificacao
- Validar token configurado
- Responder desafio quando token for valido
- Retornar erro quando token for invalido

Parametros esperados:

    hub.mode
    hub.verify_token
    hub.challenge

Fluxo:

1. Receber requisicao GET
2. Ler hub.mode
3. Ler hub.verify_token
4. Ler hub.challenge
5. Comparar hub.verify_token com META_WEBHOOK_VERIFY_TOKEN
6. Se valido, retornar hub.challenge
7. Se invalido, retornar 403

## POST /api/v1/webhooks/meta/whatsapp

Rota usada para receber eventos da Meta.

Responsabilidades:

- Receber payload JSON
- Validar payload minimo
- Salvar payload bruto
- Resolver tenant quando possivel
- Enfileirar evento
- Responder 200 rapidamente

Fluxo:

1. Receber payload
2. Validar estrutura basica
3. Extrair phone_number_id quando existir
4. Buscar whatsapp_account pelo phone_number_id
5. Resolver tenant_id quando possivel
6. Salvar payload bruto em webhook_events
7. Criar job na fila webhook-events
8. Retornar 200

## Estrutura geral do payload

Estrutura esperada de alto nivel:

    {
      "object": "whatsapp_business_account",
      "entry": [
        {
          "id": "WABA_ID",
          "changes": [
            {
              "field": "messages",
              "value": {}
            }
          ]
        }
      ]
    }

Campos importantes:

    object
    entry
    entry.id
    entry.changes
    changes.field
    changes.value
    value.metadata
    value.metadata.phone_number_id
    value.metadata.display_phone_number
    value.contacts
    value.messages
    value.statuses

## Campos usados para roteamento interno

Campo principal:

    value.metadata.phone_number_id

Uso:

- Identificar a conta WhatsApp cadastrada
- Identificar o tenant
- Vincular evento a whatsapp_account
- Direcionar processamento ao worker correto

Campos auxiliares:

    entry.id
    value.metadata.display_phone_number
    contacts.wa_id
    messages.id
    statuses.id

## Tipos de eventos esperados

Eventos iniciais:

- Mensagem recebida
- Status de mensagem enviada
- Mensagem interativa
- Mensagem com midia
- Evento desconhecido ou nao suportado

O sistema deve aceitar eventos desconhecidos sem quebrar.

Eventos desconhecidos devem ser registrados como ignored ou failed, conforme o caso.

## Mensagem recebida

Quando o payload possuir value.messages, o evento deve ser tratado como mensagem recebida.

Dados importantes:

    contacts
    messages
    messages.id
    messages.from
    messages.timestamp
    messages.type
    messages.text.body
    metadata.phone_number_id

Fluxo de processamento:

1. Identificar tenant
2. Identificar conta WhatsApp
3. Extrair contato
4. Normalizar telefone
5. Criar ou atualizar contato
6. Localizar ou criar conversa
7. Criar mensagem inbound
8. Executar chatbot quando aplicavel
9. Emitir evento message.created via Socket.IO

## Status de mensagem

Quando o payload possuir value.statuses, o evento deve ser tratado como atualizacao de status.

Dados importantes:

    statuses.id
    statuses.status
    statuses.timestamp
    statuses.recipient_id

Status esperados inicialmente:

    sent
    delivered
    read
    failed

Fluxo de processamento:

1. Identificar tenant
2. Identificar provider_message_id
3. Localizar mensagem existente
4. Registrar historico em message_statuses
5. Atualizar status atual em messages
6. Emitir evento message.updated via Socket.IO

## Idempotencia

Webhooks podem ser recebidos mais de uma vez.

Regras obrigatorias:

- Nao duplicar mensagem com mesmo provider_message_id
- Nao duplicar evento com mesmo event_id quando existir
- Jobs devem tolerar reprocessamento
- Atualizacao de status deve poder ser repetida
- Processamento duplicado deve ser ignorado com seguranca

Chaves de deduplicacao:

    messages.provider_message_id
    webhook_events.event_id
    message_statuses.provider_message_id + status

## Tabela webhook_events

Campos esperados:

    id
    tenant_id
    whatsapp_account_id
    provider
    event_type
    event_id
    payload
    status
    processed_at
    error_message
    created_at
    updated_at

Provider:

    meta_whatsapp

Status:

    received
    queued
    processed
    failed
    ignored

## Fila webhook-events

A fila webhook-events sera responsavel por processar eventos recebidos.

Job sugerido:

    {
      "webhook_event_id": "uuid",
      "tenant_id": "uuid",
      "whatsapp_account_id": "uuid"
    }

Observacao:

Quando tenant_id ainda nao puder ser identificado no recebimento, o worker devera tentar resolver usando o payload salvo.

## Worker de webhook

Responsabilidades do worker:

- Ler webhook_event_id
- Buscar payload bruto
- Validar estrutura
- Resolver tenant
- Classificar evento
- Processar mensagem recebida
- Processar status de mensagem
- Registrar erro quando falhar
- Atualizar status do webhook_event
- Emitir eventos em tempo real

## Validacao minima do payload

Validacoes iniciais:

- object deve existir
- entry deve ser array
- changes deve ser array
- field deve existir
- value deve existir
- metadata.phone_number_id deve ser usado quando existir

Quando a estrutura for invalida:

- Registrar evento como failed ou ignored
- Nao interromper o sistema
- Nao expor detalhes sensiveis na resposta

## Seguranca

Regras obrigatorias:

- HTTPS obrigatorio em producao
- Token de verificacao no GET
- Validacao de payload no POST
- Rate limit na rota publica
- Nao registrar tokens sensiveis
- Nao executar processamento pesado no endpoint
- Salvar payload bruto
- Processar via fila
- Nao confiar no tenant vindo do frontend
- Resolver tenant pelo phone_number_id cadastrado

## Resposta ao POST

O endpoint POST deve responder rapidamente.

Resposta recomendada:

    200

Corpo opcional:

    {
      "success": true
    }

Regras:

- Evitar processamento pesado antes da resposta
- Nao aguardar envio de mensagem no webhook
- Nao aguardar chatbot completo no webhook
- Nao retornar detalhes internos

## Tratamento de erros

Erros devem ser tratados de forma segura.

Cenarios:

- Payload invalido
- Conta WhatsApp nao encontrada
- Tenant nao encontrado
- Evento duplicado
- Tipo de mensagem nao suportado
- Erro ao salvar mensagem
- Erro ao emitir Socket.IO
- Erro no chatbot

Conduta:

- Registrar erro em logs internos
- Atualizar webhook_event como failed quando necessario
- Reprocessar apenas quando fizer sentido
- Nao retornar stack trace para a Meta
- Manter resposta externa simples

## Eventos em tempo real

Depois do processamento, o backend deve emitir eventos para o frontend.

Eventos previstos:

    message.created
    message.updated
    conversation.created
    conversation.updated
    notification.created

Regras:

- Emitir somente para usuarios do tenant correto
- Validar permissoes quando aplicavel
- Nao emitir payload sensivel
- Enviar dados suficientes para atualizar o chat

## Integracao com chatbot

Apos salvar mensagem inbound, o sistema pode executar regras de chatbot.

Fluxo:

1. Mensagem inbound salva
2. Worker verifica se chatbot esta ativo
3. Worker identifica fluxo aplicavel
4. Worker cria job na fila chatbot-flow
5. Chatbot processa resposta
6. Resposta outbound e criada
7. Envio e colocado na fila send-whatsapp-message

## Integracao com atendimento humano

Quando a conversa estiver em atendimento humano:

- Bot pode ser ignorado
- Mensagem deve aparecer no painel
- Atendente responsavel deve receber notificacao
- Conversa deve atualizar last_message_at
- Status da conversa deve permanecer human ou open

## Boas praticas

- Endpoint de webhook deve ser simples
- Processamento deve ser assincrono
- Payload bruto deve ser preservado
- Usar idempotencia em todos os eventos
- Registrar erros tecnicos
- Separar parser de payload por tipo de evento
- Testar payloads reais
- Criar testes automatizados de payload
- Criar logs suficientes para diagnostico
- Nao misturar regra de chatbot dentro do controller

## Variaveis de ambiente relacionadas

Variaveis esperadas:

    META_WEBHOOK_VERIFY_TOKEN
    META_APP_SECRET
    META_API_VERSION
    META_GRAPH_BASE_URL

Observacao:

META_APP_SECRET podera ser usado futuramente para validacao de assinatura quando implementada.

## Checklist da Etapa de Webhook

Itens obrigatorios:

- Rota GET de verificacao documentada
- Rota POST de eventos documentada
- Payload bruto salvo
- Fila webhook-events definida
- Worker de processamento definido
- Identificacao por phone_number_id definida
- Idempotencia definida
- Status de mensagens definido
- Eventos em tempo real definidos
- Regras de seguranca definidas

## Decisao final desta etapa

A integracao de webhooks da Meta sera implementada com:

- GET publico para verificacao
- POST publico para eventos
- HTTPS obrigatorio em producao
- Registro de payload bruto
- Identificacao de tenant por phone_number_id
- Processamento via fila webhook-events
- Idempotencia por provider_message_id e event_id
- Atualizacao em tempo real via Socket.IO
- Separacao entre recebimento, processamento, chatbot e envio
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Etapas

- [x] Etapa 01 - Preparacao do ambiente de documentacao
- [x] Etapa 02 - Criacao do README principal
- [x] Etapa 03 - Documentacao de arquitetura
- [x] Etapa 04 - Documentacao do banco de dados
- [x] Etapa 05 - Documentacao da API
- [x] Etapa 06 - Documentacao de seguranca
- [x] Etapa 07 - Documentacao de webhooks da Meta
- [ ] Etapa 08 - Documentacao do frontend
- [ ] Etapa 09 - Documentacao do backend
- [ ] Etapa 10 - Documentacao de deploy
- [ ] Etapa 11 - Manifesto final e validacao

## Ultima etapa executada

Etapa 07 - Documentacao de webhooks da Meta.

## Proxima etapa sugerida

Etapa 08 - Criar docs/FRONTEND.md com a documentacao do frontend.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto da Documentacao

Este manifesto lista os arquivos esperados da documentacao inicial do projeto.

## Pasta base

saas-whatsapp-meta/

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md

## Documentos tecnicos

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md

## Pastas de apoio

- scripts/
- logs/
- backups/

## Etapas concluidas

- Etapa 01 - Preparacao do ambiente de documentacao
- Etapa 02 - Criacao do README principal
- Etapa 03 - Documentacao de arquitetura
- Etapa 04 - Documentacao do banco de dados
- Etapa 05 - Documentacao da API
- Etapa 06 - Documentacao de seguranca
- Etapa 07 - Documentacao de webhooks da Meta

## Proxima etapa

- Etapa 08 - Documentacao do frontend

## Arquivos atualizados na Etapa 07

- docs/WEBHOOKS_META.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_07.log
DOC

echo "Validando arquivos obrigatorios..."

test -f "${DOCS_DIR}/WEBHOOKS_META.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${DOCS_DIR}/WEBHOOKS_META.md" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 07
Acao: Documentacao de webhooks da Meta
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/WEBHOOKS_META.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/WEBHOOKS_META_${STAMP}.md
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 07 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo de docs/WEBHOOKS_META.md:"
sed -n '1,160p' "${DOCS_DIR}/WEBHOOKS_META.md"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 08 - Criar docs/FRONTEND.md"
