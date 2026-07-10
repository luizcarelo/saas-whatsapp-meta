#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_74.log"

DOC_REFINEMENT="${DOCS_DIR}/ATTENDANCE_MODULE_REFINEMENT_PLAN.md"
DOC_BOUNDARIES="${DOCS_DIR}/ATTENDANCE_DOMAIN_BOUNDARIES.md"
DOC_SCREEN="${DOCS_DIR}/ATTENDANCE_SCREEN_REORGANIZATION.md"
DOC_STATUS="${DOCS_DIR}/ATTENDANCE_STATUS_MODEL.md"
DOC_ROADMAP="${DOCS_DIR}/ATTENDANCE_REFINEMENT_ROADMAP.md"

BACKEND_SCAN_LOG="${LOGS_DIR}/setup_74_backend_attendance_files.log"
FRONTEND_SCAN_LOG="${LOGS_DIR}/setup_74_frontend_attendance_files.log"
ROUTES_SCAN_LOG="${LOGS_DIR}/setup_74_routes_scan.log"
DB_SCAN_LOG="${LOGS_DIR}/setup_74_database_attendance_tables.log"
DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_74_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_74_auth_login_domain.log"
DOMAIN_ATTENDANCE_LOG="${LOGS_DIR}/setup_74_attendance_conversations_domain.log"
DOMAIN_PAGES_LOG="${LOGS_DIR}/setup_74_pages_status.log"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"

echo "== Etapa 74: Refino estrutural do modulo Atendimento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 73..."

if [ ! -f "${LOGS_DIR}/setup_73.log" ]; then
  echo "ERRO: setup_73.log nao encontrado. Conclua a Etapa 73 antes da Etapa 74."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_73.log"; then
  echo "ERRO: Etapa 73 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_73.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${DOC_REFINEMENT}" \
  "${DOC_BOUNDARIES}" \
  "${DOC_SCREEN}" \
  "${DOC_STATUS}" \
  "${DOC_ROADMAP}" \
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

for tool in node docker curl python3 find grep sed; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Mapeando arquivos backend de atendimento..."

find apps/backend/src \
  -type f \
  \( \
    -path '*attendance*' \
    -o -path '*conversation*' \
    -o -path '*webhook*' \
    -o -path '*whatsapp*' \
  \) \
  | sort \
  | tee "${BACKEND_SCAN_LOG}"

echo "Mapeando arquivos frontend de atendimento..."

find apps/frontend/src \
  -type f \
  \( \
    -path '*attendance*' \
    -o -path '*inbox*' \
    -o -path '*send-failures*' \
    -o -path '*conversation*' \
  \) \
  | sort \
  | tee "${FRONTEND_SCAN_LOG}"

echo "Mapeando rotas relacionadas..."

grep -RIn \
  "attendance\\|inbox\\|send-failures\\|conversation\\|webhooks/meta\\|whatsapp" \
  apps/backend/src apps/frontend/src \
  | sed -n '1,260p' \
  | tee "${ROUTES_SCAN_LOG}" || true

echo "Mapeando tabelas relacionadas..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DB_SCAN_LOG}"
select table_name
from information_schema.tables
where table_schema = 'public'
  and (
    table_name ilike '%attendance%'
    or table_name ilike '%conversation%'
    or table_name ilike '%message%'
    or table_name ilike '%webhook%'
    or table_name ilike '%whatsapp%'
  )
order by table_name;
SQL

echo "Validando health publico..."

DOMAIN_HEALTH_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_HEALTH_URL}" || true)"

if [ "${DOMAIN_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health publico falhou. Status ${DOMAIN_HEALTH_STATUS}"
  cat "${DOMAIN_HEALTH_LOG}"
  exit 1
fi

echo "Validando login e endpoint principal de atendimento..."

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

DOMAIN_ATTENDANCE_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_STATUS}" != "200" ]; then
  echo "ERRO: endpoint attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LOG}"
  exit 1
fi

echo "Validando paginas atuais do modulo..."

: > "${DOMAIN_PAGES_LOG}"

for page in \
  "/app/inbox" \
  "/app/attendance-dashboard" \
  "/app/send-failures" \
  "/app/dashboard" \
  "/app/audit"
do
  status="$(curl -L -s -o /dev/null -w "%{http_code}" --max-time 30 "${DOMAIN_BASE_URL}${page}" || true)"
  echo "${page} ${status}" | tee -a "${DOMAIN_PAGES_LOG}"

  if [ "${status}" != "200" ]; then
    echo "ERRO: pagina ${page} nao respondeu 200."
    exit 1
  fi
done

echo "Gerando documento de refino estrutural..."

cat > "${DOC_REFINEMENT}" <<'DOC'
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
DOC

echo "Gerando documento de fronteiras de dominio..."

cat > "${DOC_BOUNDARIES}" <<'DOC'
# Attendance Domain Boundaries

## Visao geral

Este documento define as fronteiras conceituais recomendadas para o modulo Atendimento.

## Dominios recomendados

Dominios:

- conversations
- attendance
- attendance metadata
- attendance closure
- attendance send
- attendance send failures
- attendance automations
- attendance dashboard
- webhooks meta

## Conversations

Responsabilidade:

- conversa base
- contato da conversa
- mensagens recebidas e enviadas
- canal da conversa
- vinculo com conta WhatsApp
- historico bruto de mensagens

Nao deve concentrar:

- regra de automacao
- configuracao de departamento
- dashboard gerencial
- retentativa operacional

## Attendance

Responsabilidade:

- estado operacional do atendimento
- departamento atual
- responsavel atual
- fila
- status operacional
- movimentacoes operacionais

Nao deve concentrar:

- payload bruto de webhook
- chamada direta para Meta
- configuracao de templates
- armazenamento de token

## Attendance Metadata

Responsabilidade:

- departamentos
- respostas rapidas
- tags
- notas internas
- opcoes auxiliares da central

Nao deve concentrar:

- envio real
- encerramento
- retentativa
- regras automaticas complexas

## Attendance Closure

Responsabilidade:

- encerramento
- mensagem de encerramento
- solicitacao de avaliacao
- nota de avaliacao
- comentario de avaliacao
- historico de encerramentos

Nao deve concentrar:

- regra geral de envio
- configuracao de automacoes
- painel de falhas

## Attendance Send

Responsabilidade:

- envio manual
- envio por resposta rapida
- envio de encerramento
- envio de automacao
- origem da mensagem
- status do envio
- retorno do provedor
- dryRun

Nao deve concentrar:

- listagem gerencial de falhas
- configuracoes de respostas rapidas
- regras de automacao

## Attendance Send Failures

Responsabilidade:

- listagem de falhas
- retentativas
- relacao entre envio original e retentativa
- painel operacional de erros

Nao deve concentrar:

- composer principal da conversa
- definicao de automacoes
- configuracao de departamentos

## Attendance Automations

Responsabilidade:

- regras por status e departamento
- execucoes de automacao
- limite por conversa
- origem automation
- dryRun de automacao

Nao deve concentrar:

- atendimento manual do operador
- historico completo da conversa
- painel de falhas globais

## Attendance Dashboard

Responsabilidade:

- metricas
- resumo gerencial
- cards
- indicadores por status
- indicadores por departamento

Nao deve concentrar:

- execucao de envio
- edicao de mensagens
- regras de automacao

## Webhooks Meta

Responsabilidade:

- receber payloads da Meta
- validar assinatura
- registrar eventos
- processar mensagens inbound
- processar status outbound

Nao deve concentrar:

- experiencia visual da central
- regras comerciais de atendimento
- configuracoes de tela
DOC

echo "Gerando documento de reorganizacao visual..."

cat > "${DOC_SCREEN}" <<'DOC'
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
DOC

echo "Gerando documento de modelo de status..."

cat > "${DOC_STATUS}" <<'DOC'
# Attendance Status Model

## Visao geral

Este documento define o modelo recomendado para separar os diferentes tipos de status no modulo Atendimento.

## Problema identificado

Existem status de naturezas diferentes usando nomes parecidos ou misturados.

Exemplos observados:

- human
- closed
- novo
- em atendimento
- aguardando cliente
- encerrado
- arquivado
- pending
- sent
- failed
- dry run
- delivered
- read

## Separacao recomendada

Separar status em quatro grupos:

- status da conversa base
- status operacional do atendimento
- status de envio da mensagem
- status de encerramento e avaliacao

## Status da conversa base

Uso:

- representa o ciclo tecnico da conversa

Valores recomendados:

- open
- closed
- archived

Observacao:

- este status deve ser simples e tecnico

## Status operacional do atendimento

Uso:

- representa a fila e situacao para o atendente

Valores recomendados:

- novo
- em_atendimento
- aguardando_cliente
- aguardando_atendente
- encerrado
- arquivado

Observacao:

- este status deve ser o principal na central de atendimento

## Status de envio

Uso:

- representa o estado de cada mensagem enviada

Valores recomendados:

- pending
- sent
- delivered
- read
- failed
- dry_run

Observacao:

- este status nao deve ser confundido com status da conversa

## Status de encerramento e avaliacao

Uso:

- representa encerramento e retorno do cliente

Valores recomendados:

- closure_created
- rating_requested
- rating_received
- rating_not_received

## Mapeamento sugerido

Mapeamento:

- human pode ser tratado como conversa open com atendimento em_atendimento
- closed pode ser tratado como conversa closed com atendimento encerrado
- encerrado deve permanecer no status operacional
- failed deve existir somente no envio
- dry_run deve existir somente no envio ou automacao

## Regras

Regras:

- uma mudanca de status operacional nao deve alterar automaticamente status de envio
- uma falha de envio nao deve encerrar conversa
- encerramento nao deve apagar historico
- arquivamento deve ser decisao operacional explicita
- automacao deve respeitar status operacional
DOC

echo "Gerando roadmap de refino..."

cat > "${DOC_ROADMAP}" <<'DOC'
# Attendance Refinement Roadmap

## Visao geral

Este documento registra a proposta de proximas etapas para refinar o modulo Atendimento.

## Sequencia recomendada

Etapas recomendadas:

- Etapa 75 - Padronizacao dos status de atendimento
- Etapa 76 - Reorganizacao visual do app inbox
- Etapa 77 - Criacao da tela attendance settings
- Etapa 78 - Separacao visual de envio, encerramento e historico
- Etapa 79 - Revisao de dados sinteticos e limpeza operacional
- Etapa 80 - Revisao final do modulo Atendimento refinado

## Etapa 75

Nome:

    Padronizacao dos status de atendimento

Objetivo:

- separar status tecnico da conversa
- separar status operacional do atendimento
- separar status de envio
- criar mapeamento de compatibilidade

## Etapa 76

Nome:

    Reorganizacao visual do app inbox

Objetivo:

- limpar a central
- organizar tres colunas
- simplificar o rodape de envio
- mover excesso de informacao para painel lateral

## Etapa 77

Nome:

    Criacao da tela attendance settings

Objetivo:

- centralizar configuracoes de atendimento
- mover departamentos e respostas rapidas
- preparar automacoes para gestao futura

## Etapa 78

Nome:

    Separacao visual de envio, encerramento e historico

Objetivo:

- separar composer principal
- separar encerramento
- separar historico de envios
- melhorar entendimento operacional

## Etapa 79

Nome:

    Revisao de dados sinteticos e limpeza operacional

Objetivo:

- identificar dados de validacao
- limpar ou isolar dados sinteticos
- preservar dados reais
- documentar criterios de limpeza

## Etapa 80

Nome:

    Revisao final do modulo Atendimento refinado

Objetivo:

- revisar fluxo completo
- validar paginas e endpoints
- validar documentacao
- registrar pendencias finais
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

if "## Fase 10 - Refino do modulo Atendimento" not in text:
    insert = """
<br>
## Fase 10 - Refino do modulo Atendimento
<br>
- [x] Etapa 74 - Refino estrutural do modulo Atendimento
- [ ] Etapa 75 - Padronizacao dos status de atendimento
"""
    marker = "## Ultima etapa executada"
    text = text.replace(marker, insert + "\n" + marker)
else:
    text = text.replace(
        "- [ ] Etapa 74 - Refino estrutural do modulo Atendimento",
        "- [x] Etapa 74 - Refino estrutural do modulo Atendimento"
    )
    if "- [ ] Etapa 75 - Padronizacao dos status de atendimento" not in text:
        text = text.replace(
            "- [x] Etapa 74 - Refino estrutural do modulo Atendimento",
            "- [x] Etapa 74 - Refino estrutural do modulo Atendimento\n- [ ] Etapa 75 - Padronizacao dos status de atendimento"
        )

text = text.replace(
    "Aguardar decisao da proxima fase do produto ou retomar pendencia Meta.",
    "Etapa 75 - Padronizacao dos status de atendimento."
)

text = text.replace(
    "Etapa 73 - Revisao final da fase de automacao e envio real.",
    "Etapa 74 - Refino estrutural do modulo Atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Refino estrutural do modulo Atendimento planejado." not in text:
    text += "\nRefino estrutural do modulo Atendimento planejado.\n"

for doc in [
    "- docs/ATTENDANCE_MODULE_REFINEMENT_PLAN.md",
    "- docs/ATTENDANCE_DOMAIN_BOUNDARIES.md",
    "- docs/ATTENDANCE_SCREEN_REORGANIZATION.md",
    "- docs/ATTENDANCE_STATUS_MODEL.md",
    "- docs/ATTENDANCE_REFINEMENT_ROADMAP.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 73 concluidas",
    "- Etapa 01 ate Etapa 74 concluidas"
)

text = text.replace(
    "- Aguardar decisao da proxima fase do produto",
    "- Etapa 75 - Padronizacao dos status de atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 74 - Refino estrutural do modulo Atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Planejado o refino estrutural do modulo Atendimento, com separacao de dominios, reorganizacao visual do app inbox, modelo de status e roadmap das etapas 75 a 80.
DOC
  fi
done

echo "Registrando pendencias especificas..."

if [ -f "${BASE_DIR}/PENDENCIAS.md" ]; then
  cat >> "${BASE_DIR}/PENDENCIAS.md" <<'DOC'

Pendencia Atendimento - Refino estrutural
Status: planejado
Resumo: Executar proximas etapas de padronizacao de status, reorganizacao visual do app inbox, tela de configuracoes de atendimento, separacao visual de envio e encerramento, limpeza de dados sinteticos e revisao final.
DOC
fi

echo "Validando documentos criados..."

for file in \
  "${DOC_REFINEMENT}" \
  "${DOC_BOUNDARIES}" \
  "${DOC_SCREEN}" \
  "${DOC_STATUS}" \
  "${DOC_ROADMAP}" \
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
  "${DOC_REFINEMENT}" \
  "${DOC_BOUNDARIES}" \
  "${DOC_SCREEN}" \
  "${DOC_STATUS}" \
  "${DOC_ROADMAP}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 74
Acao: Refino estrutural do modulo Atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_STATUS}
Backend scan: logs/setup_74_backend_attendance_files.log
Frontend scan: logs/setup_74_frontend_attendance_files.log
Routes scan: logs/setup_74_routes_scan.log
Database scan: logs/setup_74_database_attendance_tables.log
Pages status: logs/setup_74_pages_status.log
Documentos: docs/ATTENDANCE_MODULE_REFINEMENT_PLAN.md, docs/ATTENDANCE_DOMAIN_BOUNDARIES.md, docs/ATTENDANCE_SCREEN_REORGANIZATION.md, docs/ATTENDANCE_STATUS_MODEL.md, docs/ATTENDANCE_REFINEMENT_ROADMAP.md
Status: Concluido
DOC

echo ""
echo "== Etapa 74 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_REFINEMENT}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 75 - Padronizacao dos status de atendimento"
