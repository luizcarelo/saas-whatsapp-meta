#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_46.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_46_operational_export_report.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_46_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_46_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_46_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_46_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_46_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_46_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_46_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_46_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_46_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_46_auth_login_domain.log"
DOMAIN_SUMMARY_LOG="${LOGS_DIR}/setup_46_audit_summary_domain.log"
DOMAIN_MESSAGES_EXPORT_CSV_LOG="${LOGS_DIR}/setup_46_export_messages_csv_domain.log"
DOMAIN_MESSAGES_EXPORT_JSON_LOG="${LOGS_DIR}/setup_46_export_messages_json_domain.log"
DOMAIN_WEBHOOKS_EXPORT_CSV_LOG="${LOGS_DIR}/setup_46_export_webhooks_csv_domain.log"
DOMAIN_WEBHOOKS_EXPORT_JSON_LOG="${LOGS_DIR}/setup_46_export_webhooks_json_domain.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_46_domain_audit_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_46_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/OPERATIONAL_EXPORT_REPORT.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Fix Etapa 46: Relatorio operacional exportavel =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.types.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

for tool in node npm docker curl python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ] || [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: credenciais admin incompletas."
  exit 1
fi

echo "Corrigindo app.module.ts com rotina segura..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()

import_line = "import { OperationalAuditModule } from './modules/operational-audit/operational-audit.module';"

# Remove linhas corrompidas caso tenham sido gravadas por tentativa anterior
lines = []
for line in text.splitlines():
    if "text.split(\"imports: [\", 1)" in line:
        continue
    lines.append(line)

text = "\n".join(lines) + "\n"

if import_line not in text:
    lines = text.splitlines()
    last_import = -1

    for index, line in enumerate(lines):
        if line.startswith("import "):
            last_import = index

    if last_import < 0:
        raise SystemExit("Nao foi possivel localizar imports em app.module.ts")

    lines.insert(last_import + 1, import_line)
    text = "\n".join(lines) + "\n"

match = re.search(r"imports:\s*\[([\s\S]*?)\]", text)

if not match:
    raise SystemExit("Nao foi possivel localizar bloco imports em app.module.ts")

imports_block = match.group(1)

if "OperationalAuditModule" not in imports_block:
    text = re.sub(
        r"imports:\s*\[",
        "imports: [\n    OperationalAuditModule,",
        text,
        count=1
    )

path.write_text(text)
PY

echo "Validando exportacao no backend..."

if ! grep -q "exportReport" "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts"; then
  echo "ERRO: metodo exportReport nao encontrado no service."
  echo "Reexecute o script setup_46 original apos corrigirmos o app.module, ou solicite regeneracao completa."
  exit 1
fi

if ! grep -q "@Get('export')" "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts"; then
  echo "ERRO: endpoint export nao encontrado no controller."
  echo "Reexecute o script setup_46 original apos corrigirmos o app.module, ou solicite regeneracao completa."
  exit 1
fi

echo "Validando backend sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/operational-audit" \
  "${BACKEND_DIR}/src/app.module.ts"
then
  echo "ERRO: HTML indevido encontrado no backend."
  exit 1
fi

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${BACKEND_TYPECHECK_LOG}"

echo "Rodando build do backend..."

npm run build 2>&1 | tee "${BACKEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Garantindo botoes de exportacao no frontend..."

if ! grep -q "downloadAuditExportRequest" "${FRONTEND_DIR}/src/services/operational-audit.service.ts"; then
  cat >> "${FRONTEND_DIR}/src/services/operational-audit.service.ts" <<'DOC'

export async function downloadAuditExportRequest(
  token: string,
  filters: {
    resource: string;
    format: string;
    status?: string;
    direction?: string;
    type?: string;
  }
) {
  const params = new URLSearchParams();

  params.set('resource', filters.resource);
  params.set('format', filters.format);
  params.set('limit', '500');

  if (filters.status) {
    params.set('status', filters.status);
  }

  if (filters.direction) {
    params.set('direction', filters.direction);
  }

  if (filters.type) {
    params.set('type', filters.type);
  }

  const response = await fetch('/api/v1/operational-audit/export?' + params.toString(), {
    method: 'GET',
    headers: {
      Authorization: 'Bearer ' + token
    }
  });

  if (!response.ok) {
    throw new Error('Nao foi possivel exportar o relatorio');
  }

  const blob = await response.blob();
  const disposition = response.headers.get('Content-Disposition') || '';
  const match = disposition.match(/filename="([^"]+)"/);
  const filename = match ? match[1] : 'operational_export.' + filters.format;

  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');

  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();

  window.URL.revokeObjectURL(url);
}
DOC
fi

echo "Aplicando patch simples no AuditPage se necessario..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/audit/AuditPage.tsx")
text = path.read_text()

if "downloadAuditExportRequest" not in text:
    text = text.replace(
        "getAuditSummaryRequest,",
        "downloadAuditExportRequest,\n  getAuditSummaryRequest,"
    )

if "const [exporting, setExporting]" not in text:
    text = text.replace(
        "const [loading, setLoading] = useState(true);",
        "const [loading, setLoading] = useState(true);\n  const [exporting, setExporting] = useState(false);"
    )

if "async function handleExport(" not in text:
    marker = "  async function handleWebhookFilter(event: FormEvent<HTMLFormElement>) {\n    event.preventDefault();\n    await loadAudit();\n  }\n"
    insert = """
  async function handleExport(resource: string, format: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    setExporting(true);
    setNotice('');

    try {
      await downloadAuditExportRequest(token, {
        resource,
        format,
        status: resource === 'messages' ? messageStatus : webhookStatus,
        direction: resource === 'messages' ? messageDirection : '',
        type: resource === 'messages' ? messageType : webhookType
      });

      setNotice('Relatorio exportado com sucesso.');
    } catch (_error) {
      setNotice('Nao foi possivel exportar o relatorio.');
    } finally {
      setExporting(false);
    }
  }
"""
    text = text.replace(marker, marker + insert)

if "audit-export-toolbar" not in text:
    marker = "{notice ? <div className=\"form-message\">{notice}</div> : null}"
    toolbar = """{notice ? <div className=\"form-message\">{notice}</div> : null}

      <div className=\"audit-export-toolbar\">
        <div>
          <strong>Relatorios exportaveis</strong>
          <p>Baixe mensagens ou webhooks em CSV ou JSON usando os filtros atuais.</p>
        </div>

        <button disabled={exporting} onClick={() => void handleExport('messages', 'csv')} type=\"button\">
          Mensagens CSV
        </button>

        <button disabled={exporting} onClick={() => void handleExport('messages', 'json')} type=\"button\">
          Mensagens JSON
        </button>

        <button disabled={exporting} onClick={() => void handleExport('webhooks', 'csv')} type=\"button\">
          Webhooks CSV
        </button>

        <button disabled={exporting} onClick={() => void handleExport('webhooks', 'json')} type=\"button\">
          Webhooks JSON
        </button>
      </div>"""
    text = text.replace(marker, toolbar)

path.write_text(text)
PY

if ! grep -q "audit-export-toolbar" "${FRONTEND_DIR}/src/styles.css"; then
  cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.audit-export-toolbar {
  align-items: center;
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) repeat(4, auto);
  margin-top: 26px;
  padding: 20px;
}

.audit-export-toolbar strong {
  display: block;
}

.audit-export-toolbar p {
  color: #6b7280;
  margin: 4px 0 0;
}

.audit-export-toolbar button {
  background: #111827;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 900;
  padding: 12px 14px;
}

.audit-export-toolbar button:disabled {
  cursor: not-allowed;
  opacity: 0.65;
}

@media (max-width: 1100px) {
  .audit-export-toolbar {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .audit-export-toolbar div {
    grid-column: 1 / -1;
  }
}

@media (max-width: 640px) {
  .audit-export-toolbar {
    grid-template-columns: 1fr;
  }
}
DOC
fi

echo "Validando frontend sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit/AuditPage.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML indevido encontrado no frontend."
  exit 1
fi

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BACKEND_BUILD_LOG}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_FRONTEND_BUILD_LOG}"

echo "Subindo backend, frontend e proxy..."

docker compose up -d backend frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

echo "Aguardando backend estabilizar..."

: > "${BACKEND_WAIT_LOG}"

BACKEND_READY="false"

for i in $(seq 1 30); do
  STATUS="$(docker inspect -f '{{.State.Status}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"
  RESTARTING="$(docker inspect -f '{{.State.Restarting}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"

  echo "tentativa=${i} status=${STATUS} restarting=${RESTARTING}" | tee -a "${BACKEND_WAIT_LOG}"

  if [ "${STATUS}" = "running" ] && [ "${RESTARTING}" = "false" ]; then
    if curl -s --max-time 5 "http://127.0.0.1:3300/api/v1/health" >/dev/null 2>&1; then
      BACKEND_READY="true"
      break
    fi
  fi

  sleep 3
done

if [ "${BACKEND_READY}" != "true" ]; then
  echo "ERRO: backend nao estabilizou."
  docker compose logs --tail=220 backend 2>&1 | tee "${BACKEND_CRASH_LOG}"
  exit 1
fi

sleep 8

echo "Validando dominio..."

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

DOMAIN_SUMMARY_STATUS="$(curl -L -s -o "${DOMAIN_SUMMARY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/summary" || true)"

if [ "${DOMAIN_SUMMARY_STATUS}" != "200" ]; then
  echo "ERRO: summary dominio falhou. Status ${DOMAIN_SUMMARY_STATUS}"
  cat "${DOMAIN_SUMMARY_LOG}"
  exit 1
fi

DOMAIN_MESSAGES_EXPORT_CSV_STATUS="$(curl -L -s -o "${DOMAIN_MESSAGES_EXPORT_CSV_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=messages&format=csv&limit=50" || true)"

if [ "${DOMAIN_MESSAGES_EXPORT_CSV_STATUS}" != "200" ]; then
  echo "ERRO: export messages csv falhou. Status ${DOMAIN_MESSAGES_EXPORT_CSV_STATUS}"
  cat "${DOMAIN_MESSAGES_EXPORT_CSV_LOG}"
  exit 1
fi

if ! head -n 1 "${DOMAIN_MESSAGES_EXPORT_CSV_LOG}" | grep -q "providerMessageId"; then
  echo "ERRO: export messages csv nao tem cabecalho esperado."
  head -n 5 "${DOMAIN_MESSAGES_EXPORT_CSV_LOG}"
  exit 1
fi

DOMAIN_MESSAGES_EXPORT_JSON_STATUS="$(curl -L -s -o "${DOMAIN_MESSAGES_EXPORT_JSON_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=messages&format=json&limit=50" || true)"

if [ "${DOMAIN_MESSAGES_EXPORT_JSON_STATUS}" != "200" ]; then
  echo "ERRO: export messages json falhou. Status ${DOMAIN_MESSAGES_EXPORT_JSON_STATUS}"
  cat "${DOMAIN_MESSAGES_EXPORT_JSON_LOG}"
  exit 1
fi

if ! grep -q '"messages"' "${DOMAIN_MESSAGES_EXPORT_JSON_LOG}"; then
  echo "ERRO: export messages json nao contem messages."
  cat "${DOMAIN_MESSAGES_EXPORT_JSON_LOG}"
  exit 1
fi

DOMAIN_WEBHOOKS_EXPORT_CSV_STATUS="$(curl -L -s -o "${DOMAIN_WEBHOOKS_EXPORT_CSV_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=webhooks&format=csv&limit=50" || true)"

if [ "${DOMAIN_WEBHOOKS_EXPORT_CSV_STATUS}" != "200" ]; then
  echo "ERRO: export webhooks csv falhou. Status ${DOMAIN_WEBHOOKS_EXPORT_CSV_STATUS}"
  cat "${DOMAIN_WEBHOOKS_EXPORT_CSV_LOG}"
  exit 1
fi

if ! head -n 1 "${DOMAIN_WEBHOOKS_EXPORT_CSV_LOG}" | grep -q "eventType"; then
  echo "ERRO: export webhooks csv nao tem cabecalho esperado."
  head -n 5 "${DOMAIN_WEBHOOKS_EXPORT_CSV_LOG}"
  exit 1
fi

DOMAIN_WEBHOOKS_EXPORT_JSON_STATUS="$(curl -L -s -o "${DOMAIN_WEBHOOKS_EXPORT_JSON_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/export?resource=webhooks&format=json&limit=50" || true)"

if [ "${DOMAIN_WEBHOOKS_EXPORT_JSON_STATUS}" != "200" ]; then
  echo "ERRO: export webhooks json falhou. Status ${DOMAIN_WEBHOOKS_EXPORT_JSON_STATUS}"
  cat "${DOMAIN_WEBHOOKS_EXPORT_JSON_LOG}"
  exit 1
fi

if ! grep -q '"webhooks"' "${DOMAIN_WEBHOOKS_EXPORT_JSON_LOG}"; then
  echo "ERRO: export webhooks json nao contem webhooks."
  cat "${DOMAIN_WEBHOOKS_EXPORT_JSON_LOG}"
  exit 1
fi

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina audit nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 46..."

cat > "${DOC_FILE}" <<'DOC'
# Operational Export Report

## Visao geral

Este documento registra a criacao dos relatorios operacionais exportaveis.

## Resultado

Status:

    concluido

## Correcao aplicada

Foi corrigida a insercao do OperationalAuditModule no app.module.ts com rotina segura, evitando erro de sintaxe no script.

## Funcionalidades criadas

Funcionalidades:

- exportar mensagens operacionais em CSV
- exportar mensagens operacionais em JSON
- exportar webhooks operacionais em CSV
- exportar webhooks operacionais em JSON
- aplicar filtros atuais da auditoria na exportacao
- download no frontend sem expor token
- nomes de arquivos com timestamp
- cabecalhos CSV padronizados
- endpoint protegido por autenticacao

## Endpoints criados

Endpoints:

- GET api v1 operational audit export

Parametros:

- resource messages ou webhooks
- format csv ou json
- status opcional
- direction opcional para mensagens
- type opcional
- limit opcional

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/operational-audit/operational-audit.types.ts
- apps/backend/src/modules/operational-audit/operational-audit.service.ts
- apps/backend/src/modules/operational-audit/operational-audit.controller.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit/AuditPage.tsx
- apps/frontend/src/styles.css
- docs/OPERATIONAL_EXPORT_REPORT.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- endpoint summary dominio
- export messages csv dominio
- export messages json dominio
- export webhooks csv dominio
- export webhooks json dominio
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_46_backend_typecheck.log
- logs/setup_46_backend_build.log
- logs/setup_46_frontend_typecheck.log
- logs/setup_46_frontend_build.log
- logs/setup_46_backend_docker_build.log
- logs/setup_46_frontend_docker_build.log
- logs/setup_46_docker_up.log
- logs/setup_46_backend_wait.log
- logs/setup_46_auth_login_domain.log
- logs/setup_46_audit_summary_domain.log
- logs/setup_46_export_messages_csv_domain.log
- logs/setup_46_export_messages_json_domain.log
- logs/setup_46_export_webhooks_csv_domain.log
- logs/setup_46_export_webhooks_json_domain.log
- logs/setup_46_domain_audit_page.log
- logs/setup_46_domain_dashboard.log
- logs/setup_46.log
- logs/fix_46_operational_export_report.log

## Proxima etapa sugerida

Etapa 47:

    Criar higienizacao de dados de auditoria antigos
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Fase 01 - Documentacao inicial

- [x] Etapa 01 - Preparacao do ambiente de documentacao
- [x] Etapa 02 - Criacao do README principal
- [x] Etapa 03 - Documentacao de arquitetura
- [x] Etapa 04 - Documentacao do banco de dados
- [x] Etapa 05 - Documentacao da API
- [x] Etapa 06 - Documentacao de seguranca
- [x] Etapa 07 - Documentacao de webhooks da Meta
- [x] Etapa 08 - Documentacao do frontend
- [x] Etapa 09 - Documentacao do backend
- [x] Etapa 10 - Documentacao de deploy
- [x] Etapa 11 - Manifesto final e validacao

## Fase 02 - Estrutura real do projeto

- [x] Etapa 12 - Estrutura de pastas do monorepo
- [x] Etapa 13 - Arquivos base do backend
- [x] Etapa 14 - Arquivos base do frontend
- [x] Etapa 15 - Docker Compose inicial
- [x] Etapa 16 - Arquivo env example
- [x] Etapa 17 - Validacao do ambiente inicial
- [x] Etapa 18 - Instalacao e validacao de dependencias

## Fase 03 - Build e execucao inicial com Docker

- [x] Etapa 19 - Ajustar Dockerfiles e validar build dos containers
- [x] Etapa 20A - Auditoria e backup do Nginx
- [x] Etapa 20B - Configurar Nginx para bot.lhsolucao.com.br
- [x] Etapa 20C - Subir containers e testar dominio

## Fase 04 - Backend real inicial

- [x] Etapa 21 - Health, configuracao e database base
- [x] Etapa 22 - ORM e conexao real com PostgreSQL
- [x] Etapa 23 - Schema inicial do banco com Prisma
- [x] Etapa 24 - Seed inicial de tenant, admin, roles e permissoes
- [x] Etapa 25 - Auth inicial com login real

## Fase 05 - Frontend integrado inicial

- [x] Etapa 26 - Frontend login integrado
- [x] Etapa 27 - Protecao visual de rotas e layout base

## Fase 06 - Usuarios e perfil

- [x] Etapa 28 - Modulo backend de usuarios
- [x] Etapa 29 - Frontend com perfil detalhado

## Fase 07 - Contatos

- [x] Etapa 30 - Modulo backend de contatos
- [x] Etapa 31 - Frontend de contatos integrado

## Fase 08 - Conversas

- [x] Etapa 32 - Frontend de conversas com layout inicial
- [x] Etapa 33 - Modulo backend de conversas
- [x] Etapa 34 - Frontend de conversas integrado ao backend

## Fase 09 - WhatsApp

- [x] Etapa 35 - Modulo backend de WhatsApp Accounts
- [x] Etapa 36 - Frontend de WhatsApp Accounts integrado
- [x] Etapa 37 - Modulo backend de webhooks da Meta
- [x] Etapa 38 - Validacao de assinatura dos webhooks da Meta
- [x] Etapa 39 - Processamento de status no frontend
- [x] Etapa 40 - Envio real pela API oficial da Meta
- [x] Etapa 41 - Templates oficiais da Meta
- [x] Etapa 42 - Frontend para templates oficiais
- [x] Etapa 43 - Painel de configuracao operacional da conta Meta
- [x] Etapa 44 - Limpeza operacional de dados de teste
- [x] Etapa 45 - Painel de auditoria operacional
- [x] Etapa 46 - Relatorio operacional exportavel
- [ ] Etapa 47 - Higienizacao de dados de auditoria antigos

## Ultima etapa executada

Etapa 46 - Relatorio operacional exportavel.

## Proxima etapa sugerida

Etapa 47 - Criar higienizacao de dados de auditoria antigos.
DOC

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Relatorio operacional exportavel criado." not in text:
    text = text.replace(
        "Painel de auditoria operacional criado.",
        "Painel de auditoria operacional criado.\n\nRelatorio operacional exportavel criado."
    )

if "- docs/OPERATIONAL_EXPORT_REPORT.md" not in text:
    text = text.replace(
        "- docs/OPERATIONAL_AUDIT_PANEL.md",
        "- docs/OPERATIONAL_AUDIT_PANEL.md\n- docs/OPERATIONAL_EXPORT_REPORT.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 45 concluidas",
    "- Etapa 01 ate Etapa 46 concluidas"
)

text = text.replace(
    "- Etapa 46 - Relatorio operacional exportavel",
    "- Etapa 47 - Higienizacao de dados de auditoria antigos"
)

path.write_text(text)
PY

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 46
Acao: Relatorio operacional exportavel
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Summary status: ${DOMAIN_SUMMARY_STATUS}
Messages CSV export status: ${DOMAIN_MESSAGES_EXPORT_CSV_STATUS}
Messages JSON export status: ${DOMAIN_MESSAGES_EXPORT_JSON_STATUS}
Webhooks CSV export status: ${DOMAIN_WEBHOOKS_EXPORT_CSV_STATUS}
Webhooks JSON export status: ${DOMAIN_WEBHOOKS_EXPORT_JSON_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 46
Acao: Fix relatorio operacional exportavel
Data: $(date '+%Y-%m-%d %H:%M:%S')
Status: Concluido
DOC

echo ""
echo "== Etapa 46 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/audit"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 47 - Criar higienizacao de dados de auditoria antigos"
