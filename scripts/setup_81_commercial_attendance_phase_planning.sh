#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_81.log"

DOC_PHASE="${DOCS_DIR}/COMMERCIAL_ATTENDANCE_PHASE_PLAN.md"
DOC_SCOPE="${DOCS_DIR}/COMMERCIAL_ATTENDANCE_SCOPE.md"
DOC_MODEL="${DOCS_DIR}/COMMERCIAL_ATTENDANCE_DOMAIN_MODEL.md"
DOC_ROADMAP="${DOCS_DIR}/COMMERCIAL_ATTENDANCE_ROADMAP.md"
DOC_DECISIONS="${DOCS_DIR}/COMMERCIAL_ATTENDANCE_DECISIONS.md"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_81_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_81_auth_login_domain.log"
DOMAIN_ATTENDANCE_LOG="${LOGS_DIR}/setup_81_attendance_conversations_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_81_status_model_domain.log"
DOMAIN_SETTINGS_PAGE_LOG="${LOGS_DIR}/setup_81_attendance_settings_page.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_81_inbox_page.log"
DOMAIN_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_81_attendance_dashboard_page.log"
DOMAIN_FAILURES_PAGE_LOG="${LOGS_DIR}/setup_81_send_failures_page.log"
DOCS_CHECK_LOG="${LOGS_DIR}/setup_81_docs_check.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_STATUS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-status"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_SETTINGS_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-settings"
DOMAIN_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"
DOMAIN_FAILURES_PAGE_URL="${DOMAIN_BASE_URL}/app/send-failures"

echo "== Etapa 81: Planejamento da fase de gestao comercial do atendimento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 80..."

if [ ! -f "${LOGS_DIR}/setup_80.log" ]; then
  echo "ERRO: setup_80.log nao encontrado. Conclua a Etapa 80 antes da Etapa 81."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_80.log"; then
  echo "ERRO: Etapa 80 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_80.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${DOC_PHASE}" \
  "${DOC_SCOPE}" \
  "${DOC_MODEL}" \
  "${DOC_ROADMAP}" \
  "${DOC_DECISIONS}" \
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

for tool in node docker curl python3 grep sed; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando documentos de base..."

: > "${DOCS_CHECK_LOG}"

for doc_file in \
  "docs/ATTENDANCE_REFINEMENT_FINAL_REVIEW.md" \
  "docs/ATTENDANCE_REFINEMENT_NEXT_DECISIONS.md" \
  "docs/PENDENCIA_META_WEBHOOK_RECEBIMENTO.md" \
  "docs/SYNTHETIC_DATA_OPERATIONAL_REVIEW.md" \
  "docs/SYNTHETIC_DATA_CLEANUP_PLAN.md"
do
  if [ -f "${doc_file}" ]; then
    echo "OK: ${doc_file}" | tee -a "${DOCS_CHECK_LOG}"
  else
    echo "AUSENTE: ${doc_file}" | tee -a "${DOCS_CHECK_LOG}"
    exit 1
  fi
done

echo "Validando health publico..."

DOMAIN_HEALTH_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_HEALTH_URL}" || true)"

if [ "${DOMAIN_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health dominio falhou. Status ${DOMAIN_HEALTH_STATUS}"
  cat "${DOMAIN_HEALTH_LOG}"
  exit 1
fi

echo "Validando login dominio..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: credenciais da Etapa 24 ausentes."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

echo "Validando endpoints base do atendimento..."

DOMAIN_ATTENDANCE_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_STATUS}" != "200" ]; then
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LOG}"
  exit 1
fi

DOMAIN_STATUS_MODEL_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MODEL_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_STATUS_URL}/model" || true)"

if [ "${DOMAIN_STATUS_MODEL_STATUS}" != "200" ]; then
  echo "ERRO: status model falhou. Status ${DOMAIN_STATUS_MODEL_STATUS}"
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

echo "Validando paginas principais..."

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_INBOX_PAGE_URL}" || true)"
DOMAIN_SETTINGS_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_SETTINGS_PAGE_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_SETTINGS_PAGE_URL}" || true)"
DOMAIN_DASHBOARD_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_PAGE_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_DASHBOARD_PAGE_URL}" || true)"
DOMAIN_FAILURES_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_FAILURES_PAGE_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_FAILURES_PAGE_URL}" || true)"

for pair in \
  "inbox:${DOMAIN_INBOX_PAGE_STATUS}" \
  "attendance-settings:${DOMAIN_SETTINGS_PAGE_STATUS}" \
  "attendance-dashboard:${DOMAIN_DASHBOARD_PAGE_STATUS}" \
  "send-failures:${DOMAIN_FAILURES_PAGE_STATUS}"
do
  name="${pair%%:*}"
  status="${pair##*:}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: pagina ${name} falhou com status ${status}"
    exit 1
  fi
done

echo "Gerando documentos da Etapa 81..."

cat > "${DOC_PHASE}" <<'DOC'
# Commercial Attendance Phase Plan

## Visao geral

Este documento registra o planejamento da nova fase funcional do produto.

## Fase

Fase:

    Fase 11 - Produto operacional e gestao comercial do atendimento

## Resultado

Status:

    planejado

## Objetivo da fase

Objetivo:

- transformar o atendimento em uma ferramenta operacional e comercial
- acompanhar oportunidades vinculadas a conversas
- criar tarefas e follow-ups
- permitir visao comercial por cliente
- apoiar retornos, propostas e negociacoes
- criar indicadores comerciais do atendimento

## Contexto

Contexto:

- modulo Atendimento refinado e validado ate a Etapa 80
- pendencia Meta preservada e separada
- limpeza real de dados sinteticos pendente de aprovacao explicita
- nova fase deve iniciar com planejamento antes de alterar codigo

## Principios

Principios:

- evoluir em etapas pequenas
- nao misturar atendimento com configuracoes
- nao alterar fluxo validado sem adaptadores
- evitar criar nova bagunca no app inbox
- manter documentos auxiliares atualizados
- manter dryRun onde houver risco operacional
- preservar dados reais e auditoria

## Resultado esperado

Resultado esperado:

- oportunidades vinculadas a conversas
- tarefas e follow-ups vinculados a clientes
- painel de follow-ups
- dashboard comercial
- historico comercial do cliente
- alertas operacionais
- revisao final da nova fase
DOC

cat > "${DOC_SCOPE}" <<'DOC'
# Commercial Attendance Scope

## Visao geral

Este documento define o escopo da fase de gestao comercial do atendimento.

## Dentro do escopo

Escopo incluido:

- oportunidades comerciais
- tarefas de follow-up
- painel de follow-ups
- dashboard comercial do atendimento
- historico comercial do cliente
- alertas operacionais
- vinculo com conversa
- vinculo com contato
- vinculo com responsavel
- status comercial

## Fora do escopo inicial

Escopo excluido inicialmente:

- CRM completo
- emissao fiscal
- financeiro
- funil configuravel complexo
- integracao com ERP
- campanhas em massa
- automacao avancada de vendas
- limpeza real de dados sinteticos
- correcao da pendencia Meta

## Premissas

Premissas:

- conversa continua sendo a origem operacional
- contato representa o cliente
- oportunidade representa interesse comercial
- tarefa representa acao futura
- follow-up representa retorno programado
- dashboard mostra resumo, nao substitui operacao

## Riscos

Riscos:

- misturar oportunidade com status de atendimento
- misturar tarefa com nota interna
- criar muitos campos antes de validar uso real
- deixar app inbox pesado novamente
- automatizar antes de consolidar o processo
DOC

cat > "${DOC_MODEL}" <<'DOC'
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
DOC

cat > "${DOC_ROADMAP}" <<'DOC'
# Commercial Attendance Roadmap

## Visao geral

Este documento registra o roadmap sugerido da nova fase funcional.

## Sequencia proposta

Etapas:

- Etapa 81 - Planejamento da fase de gestao comercial do atendimento
- Etapa 82 - Modelo de oportunidades no atendimento
- Etapa 83 - Backend de oportunidades
- Etapa 84 - Frontend de oportunidades no atendimento
- Etapa 85 - Tarefas e follow-up
- Etapa 86 - Painel de follow-ups
- Etapa 87 - Dashboard comercial do atendimento
- Etapa 88 - Historico comercial do cliente
- Etapa 89 - Alertas operacionais
- Etapa 90 - Revisao final da fase comercial

## Etapa 82

Objetivo:

- criar modelo de oportunidades
- documentar campos e status
- preparar migracao de banco

## Etapa 83

Objetivo:

- criar backend de oportunidades
- criar endpoints de listagem, criacao e atualizacao
- validar por tenant

## Etapa 84

Objetivo:

- mostrar oportunidade no contexto da conversa
- adicionar card comercial no app inbox
- evitar sobrecarregar o atendimento

## Etapa 85

Objetivo:

- criar tarefas e follow-ups
- vincular tarefas a conversa, contato e oportunidade

## Etapa 86

Objetivo:

- criar tela de follow-ups
- filtrar atrasados, hoje e proximos dias

## Etapa 87

Objetivo:

- criar dashboard comercial
- exibir oportunidades e follow-ups

## Etapa 88

Objetivo:

- criar historico comercial do cliente
- unificar dados comerciais relevantes

## Etapa 89

Objetivo:

- criar alertas operacionais
- destacar riscos e pendencias

## Etapa 90

Objetivo:

- revisar fase comercial
- validar docs, endpoints, paginas e pendencias
DOC

cat > "${DOC_DECISIONS}" <<'DOC'
# Commercial Attendance Decisions

## Visao geral

Este documento registra decisoes iniciais da fase comercial.

## Decisoes aprovadas

Decisoes:

- iniciar nova fase com planejamento documental
- nao alterar banco na Etapa 81
- nao alterar codigo funcional na Etapa 81
- manter pendencia Meta separada
- manter limpeza real de dados sinteticos separada
- tratar oportunidade como entidade diferente de atendimento
- tratar follow-up como entidade diferente de nota interna
- planejar antes de implementar

## Decisoes pendentes

Pendencias:

- confirmar campos finais de oportunidade
- confirmar campos finais de tarefa
- confirmar status comerciais
- confirmar se oportunidade aparece no app inbox ou em tela separada primeiro
- confirmar se follow-up tera lembrete automatico
- confirmar se dashboard comercial sera separado do dashboard de atendimento

## Recomendacao

Recomendacao:

- implementar primeiro modelo e backend de oportunidades
- depois integrar visualmente ao atendimento
- evitar automacoes comerciais antes do uso manual estar validado
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

if "## Fase 11 - Produto operacional e gestao comercial do atendimento" not in text:
    insert = """
<br>
## Fase 11 - Produto operacional e gestao comercial do atendimento
<br>
- [x] Etapa 81 - Planejamento da fase de gestao comercial do atendimento
- [ ] Etapa 82 - Modelo de oportunidades no atendimento
"""
    marker = "## Ultima etapa executada"
    text = text.replace(marker, insert + "\n" + marker)
else:
    text = text.replace(
        "- [ ] Etapa 81 - Planejamento da fase de gestao comercial do atendimento",
        "- [x] Etapa 81 - Planejamento da fase de gestao comercial do atendimento"
    )
    if "- [ ] Etapa 82 - Modelo de oportunidades no atendimento" not in text:
        text = text.replace(
            "- [x] Etapa 81 - Planejamento da fase de gestao comercial do atendimento",
            "- [x] Etapa 81 - Planejamento da fase de gestao comercial do atendimento\n- [ ] Etapa 82 - Modelo de oportunidades no atendimento"
        )

text = text.replace(
    "Planejar nova fase funcional ou retomar pendencias Meta e limpeza real quando houver aprovacao.",
    "Etapa 82 - Modelo de oportunidades no atendimento."
)

text = text.replace(
    "Etapa 80 - Revisao final do modulo Atendimento refinado.",
    "Etapa 81 - Planejamento da fase de gestao comercial do atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Planejamento da fase de gestao comercial do atendimento criado." not in text:
    text += "\nPlanejamento da fase de gestao comercial do atendimento criado.\n"

for doc in [
    "- docs/COMMERCIAL_ATTENDANCE_PHASE_PLAN.md",
    "- docs/COMMERCIAL_ATTENDANCE_SCOPE.md",
    "- docs/COMMERCIAL_ATTENDANCE_DOMAIN_MODEL.md",
    "- docs/COMMERCIAL_ATTENDANCE_ROADMAP.md",
    "- docs/COMMERCIAL_ATTENDANCE_DECISIONS.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 80 concluidas",
    "- Etapa 01 ate Etapa 81 concluidas"
)

text = text.replace(
    "- Planejar nova fase funcional ou retomar pendencias Meta e limpeza real quando houver aprovacao",
    "- Etapa 82 - Modelo de oportunidades no atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 81 - Planejamento da fase de gestao comercial do atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Planejada a Fase 11 de produto operacional e gestao comercial do atendimento, com escopo, modelo conceitual, roadmap das etapas 82 a 90 e decisoes iniciais.
DOC
  fi
done

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_PHASE}" \
  "${DOC_SCOPE}" \
  "${DOC_MODEL}" \
  "${DOC_ROADMAP}" \
  "${DOC_DECISIONS}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 81
Acao: Planejamento da fase de gestao comercial do atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_STATUS}
Status model status: ${DOMAIN_STATUS_MODEL_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Attendance settings page status: ${DOMAIN_SETTINGS_PAGE_STATUS}
Attendance dashboard page status: ${DOMAIN_DASHBOARD_PAGE_STATUS}
Send failures page status: ${DOMAIN_FAILURES_PAGE_STATUS}
Docs check log: logs/setup_81_docs_check.log
Alteracao de banco: nao
Alteracao de codigo funcional: nao
Envio real: nao
Status: Concluido
DOC

echo ""
echo "== Etapa 81 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_PHASE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 82 - Modelo de oportunidades no atendimento"
