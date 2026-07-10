#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_65.log"
DOC_FILE="${DOCS_DIR}/ATTENDANCE_AUTOMATION_SEND_PLAN.md"
FLOW_DOC_FILE="${DOCS_DIR}/ATTENDANCE_SEND_FLOW.md"
RULES_DOC_FILE="${DOCS_DIR}/ATTENDANCE_AUTOMATION_RULES.md"

echo "== Etapa 65: Planejamento da fase de automacao e envio real pela central =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 64..."

if [ ! -f "${LOGS_DIR}/setup_64.log" ]; then
  echo "ERRO: setup_64.log nao encontrado. Conclua a Etapa 64 antes da Etapa 65."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_64.log"; then
  echo "ERRO: Etapa 64 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_64.log"
  exit 1
fi

echo "Criando backups dos documentos de controle..."

for file in \
  "${DOC_FILE}" \
  "${FLOW_DOC_FILE}" \
  "${RULES_DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md" \
  "${BASE_DIR}/CONTEXTO_PROJETO.md" \
  "${BASE_DIR}/CHANGELOG.md" \
  "${BASE_DIR}/DECISOES_TECNICAS.md" \
  "${BASE_DIR}/PENDENCIAS.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

for tool in python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

echo "Gerando documento principal da Etapa 65..."

cat > "${DOC_FILE}" <<'DOC'
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
DOC

echo "Gerando documento de fluxo de envio..."

cat > "${FLOW_DOC_FILE}" <<'DOC'
# Attendance Send Flow

## Visao geral

Este documento define o fluxo planejado para envio real pela central de atendimento.

## Fluxo de envio manual

Fluxo:

- atendente acessa app inbox
- atendente seleciona conversa
- sistema carrega conversa e contato
- atendente digita mensagem
- atendente clica em enviar
- frontend chama endpoint de envio da central
- backend valida autenticacao
- backend valida tenant
- backend valida conversa
- backend valida contato e telefone
- backend valida conta WhatsApp ativa
- backend envia mensagem pela API oficial da Meta
- backend grava mensagem no historico
- backend grava origem manual
- backend grava atendente responsavel
- frontend atualiza conversa
- frontend exibe sucesso ou erro

## Fluxo de resposta rapida

Fluxo:

- atendente seleciona resposta rapida
- sistema preenche o campo de mensagem
- atendente pode editar a mensagem
- atendente clica em enviar
- backend grava origem resposta rapida
- mensagem e enviada pela API oficial da Meta
- historico registra resposta usada

## Fluxo de encerramento

Fluxo:

- atendente clica em encerrar atendimento
- sistema prepara mensagem de avaliacao
- atendente revisa mensagem
- backend envia mensagem pela API oficial da Meta
- conversa muda para encerrado
- encerramento fica registrado
- sistema aguarda avaliacao do cliente
- avaliacao de 1 a 5 e registrada quando informada

## Fluxo de automacao

Fluxo:

- evento operacional ocorre
- sistema verifica regra ativa
- sistema verifica departamento
- sistema verifica status da conversa
- sistema valida se automacao pode enviar
- backend envia mensagem automatica
- mensagem fica com origem automacao
- falhas ficam registradas para revisao

## Estados de envio

Estados:

- pending
- sent
- delivered
- read
- failed

## Origem operacional

Origem:

- manual
- quick_reply
- closing_rating
- automation_greeting
- automation_transfer
- automation_waiting_customer
- automation_out_of_hours
- automation_unassigned

## Rastreabilidade

Cada envio deve permitir responder:

- quem enviou
- quando enviou
- de qual departamento enviou
- por qual conta WhatsApp enviou
- para qual contato enviou
- qual foi a origem
- qual retorno a Meta informou
- se houve falha
DOC

echo "Gerando documento de regras de automacao..."

cat > "${RULES_DOC_FILE}" <<'DOC'
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
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 65 - Planejamento da proxima fase de automacao e envio real pela central de atendimento",
    "- [x] Etapa 65 - Planejamento da proxima fase de automacao e envio real pela central de atendimento\n- [ ] Etapa 66 - Backend de envio manual pela central de atendimento"
)

text = text.replace(
    "Etapa 65 - Planejar proxima fase de automacao e envio real pela central de atendimento.",
    "Etapa 66 - Backend de envio manual pela central de atendimento."
)

text = text.replace(
    "Etapa 64 - Revisao final da fase de atendimento profissional.",
    "Etapa 65 - Planejamento da proxima fase de automacao e envio real pela central de atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Planejamento da fase de automacao e envio real pela central de atendimento criado." not in text:
    text = text.replace(
        "Revisao final da fase de atendimento profissional concluida.",
        "Revisao final da fase de atendimento profissional concluida.\n\nPlanejamento da fase de automacao e envio real pela central de atendimento criado."
    )

if "- docs/ATTENDANCE_AUTOMATION_SEND_PLAN.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_PHASE_FINAL_REVIEW.md",
        "- docs/ATTENDANCE_AUTOMATION_SEND_PLAN.md\n- docs/ATTENDANCE_SEND_FLOW.md\n- docs/ATTENDANCE_AUTOMATION_RULES.md\n- docs/ATTENDANCE_PHASE_FINAL_REVIEW.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 64 concluidas",
    "- Etapa 01 ate Etapa 65 concluidas"
)

text = text.replace(
    "- Etapa 65 - Planejamento da proxima fase de automacao e envio real pela central de atendimento",
    "- Etapa 66 - Backend de envio manual pela central de atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 65 - Planejamento da proxima fase de automacao e envio real pela central de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Planejada a fase de automacao e envio real pela central, incluindo envio manual, respostas rapidas, encerramento com avaliacao, rastreabilidade, seguranca e automacoes por status e departamento.
DOC
  fi
done

echo "Validando documentos criados..."

for file in \
  "${DOC_FILE}" \
  "${FLOW_DOC_FILE}" \
  "${RULES_DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ ! -f "${file}" ]; then
    echo "ERRO: arquivo final ausente: ${file}"
    exit 1
  fi
done

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${FLOW_DOC_FILE}" \
  "${RULES_DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 65
Acao: Planejamento da proxima fase de automacao e envio real pela central de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Documento principal: docs/ATTENDANCE_AUTOMATION_SEND_PLAN.md
Documento fluxo: docs/ATTENDANCE_SEND_FLOW.md
Documento regras: docs/ATTENDANCE_AUTOMATION_RULES.md
Status: Concluido
DOC

echo ""
echo "== Etapa 65 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 66 - Backend de envio manual pela central de atendimento"
