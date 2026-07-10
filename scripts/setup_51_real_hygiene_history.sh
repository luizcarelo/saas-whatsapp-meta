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

LOG_FILE="${LOGS_DIR}/setup_51.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_51_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_51_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_51_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_51_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_51_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_51_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_51_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_51_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_51_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_51_auth_login_domain.log"
DOMAIN_HISTORY_LOG="${LOGS_DIR}/setup_51_hygiene_runs_domain.log"
DOMAIN_AUDIT_HISTORY_PAGE_LOG="${LOGS_DIR}/setup_51_domain_audit_real_history_page.log"
DOMAIN_AUDIT_REAL_RUN_PAGE_LOG="${LOGS_DIR}/setup_51_domain_audit_real_run_page.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_51_domain_audit_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_51_domain_dashboard.log"

DOC_FILE="${DOCS_DIR}/REAL_HYGIENE_HISTORY.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_AUDIT_URL="${DOMAIN_BASE_URL}/api/v1/operational-audit"
DOMAIN_AUDIT_HISTORY_PAGE_URL="${DOMAIN_BASE_URL}/app/audit-real-history"
DOMAIN_AUDIT_REAL_RUN_PAGE_URL="${DOMAIN_BASE_URL}/app/audit-real-run"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Etapa 51: Relatorio historico das execucoes reais de higienizacao =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/operational-audit"
mkdir -p "${FRONTEND_DIR}/src/pages/audit-real-history"
mkdir -p "${FRONTEND_DIR}/src/types"
mkdir -p "${FRONTEND_DIR}/src/services"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.types.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.service.ts" \
  "${BACKEND_DIR}/src/modules/operational-audit/operational-audit.controller.ts" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit-real-history/AuditRealHistoryPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${DOC_FILE}" \
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

echo "Garantindo tabela de execucoes reais..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists operational_audit_hygiene_runs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  retention_days integer not null,
  dry_run boolean not null,
  confirmation_phrase text,
  old_messages integer not null default 0,
  old_failed_messages_with_metadata integer not null default 0,
  old_webhook_events integer not null default 0,
  messages_redacted integer not null default 0,
  webhook_events_redacted integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_operational_audit_hygiene_runs_tenant_id
on operational_audit_hygiene_runs (tenant_id);

create index if not exists idx_operational_audit_hygiene_runs_created_at
on operational_audit_hygiene_runs (created_at);
SQL

echo "Atualizando types backend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/operational-audit/operational-audit.types.ts")
text = path.read_text()

if "OperationalAuditHygieneRunItem" not in text:
    text += """

export type OperationalAuditHygieneRunItem = {
  id: string;
  tenantId: string;
  retentionDays: number;
  dryRun: boolean;
  oldMessages: number;
  oldFailedMessagesWithMetadata: number;
  oldWebhookEvents: number;
  messagesRedacted: number;
  webhookEventsRedacted: number;
  createdAt: string;
};

export type OperationalAuditHygieneRunsResponse = {
  success: true;
  data: {
    runs: OperationalAuditHygieneRunItem[];
    total: number;
  };
  meta: Record<string, never>;
};
"""

path.write_text(text)
PY

echo "Atualizando service backend com historico..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/operational-audit/operational-audit.service.ts")
text = path.read_text()

if "OperationalAuditHygieneRunsResponse" not in text:
    text = text.replace(
        "OperationalAuditHygieneResponse,",
        "OperationalAuditHygieneResponse,\n  OperationalAuditHygieneRunsResponse,"
    )

if "type HygieneRunRow" not in text:
    marker = "type RetentionPolicyRow = {"
    insert = """type HygieneRunRow = {
  id: string;
  tenant_id: string;
  retention_days: number;
  dry_run: boolean;
  old_messages: number;
  old_failed_messages_with_metadata: number;
  old_webhook_events: number;
  messages_redacted: number;
  webhook_events_redacted: number;
  created_at: Date;
};

"""
    text = text.replace(marker, insert + marker)

if "async listRealHygieneRuns(" not in text:
    marker = "  async getRetentionPolicy(tenantId: string): Promise<OperationalAuditRetentionPolicyResponse> {"
    method = """  async listRealHygieneRuns(tenantId: string): Promise<OperationalAuditHygieneRunsResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<HygieneRunRow[]>(
      'select id, tenant_id, retention_days, dry_run, old_messages, old_failed_messages_with_metadata, old_webhook_events, messages_redacted, webhook_events_redacted, created_at from operational_audit_hygiene_runs where tenant_id = $1::uuid order by created_at desc limit 100',
      tenantId
    );

    return {
      success: true,
      data: {
        runs: rows.map((row) => ({
          id: row.id,
          tenantId: row.tenant_id,
          retentionDays: row.retention_days,
          dryRun: row.dry_run,
          oldMessages: row.old_messages,
          oldFailedMessagesWithMetadata: row.old_failed_messages_with_metadata,
          oldWebhookEvents: row.old_webhook_events,
          messagesRedacted: row.messages_redacted,
          webhookEventsRedacted: row.webhook_events_redacted,
          createdAt: row.created_at.toISOString()
        })),
        total: rows.length
      },
      meta: {}
    };
  }

"""
    text = text.replace(marker, method + marker)

path.write_text(text)
PY

echo "Atualizando controller backend com rota hygiene-runs..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/operational-audit/operational-audit.controller.ts")
text = path.read_text()

if "@Get('hygiene-runs')" not in text:
    marker = "  @Get('retention-policy')"
    insert = """  @Get('hygiene-runs')
  listRealHygieneRuns(@CurrentUser() user: AuthenticatedUser) {
    return this.operationalAuditService.listRealHygieneRuns(user.tenantId);
  }

"""
    text = text.replace(marker, insert + marker)

path.write_text(text)
PY

echo "Validando backend sem HTML indevido..."

if grep -R "<a href" \
  "${BACKEND_DIR}/src/modules/operational-audit"
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

echo "Atualizando types frontend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/types/operational-audit.types.ts")
text = path.read_text()

if "AuditHygieneRunItem" not in text:
    text += """

export type AuditHygieneRunItem = {
  id: string;
  tenantId: string;
  retentionDays: number;
  dryRun: boolean;
  oldMessages: number;
  oldFailedMessagesWithMetadata: number;
  oldWebhookEvents: number;
  messagesRedacted: number;
  webhookEventsRedacted: number;
  createdAt: string;
};

export type AuditHygieneRunsData = {
  runs: AuditHygieneRunItem[];
  total: number;
};
"""

path.write_text(text)
PY

echo "Atualizando service frontend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/services/operational-audit.service.ts")
text = path.read_text()

if "AuditHygieneRunsData" not in text:
    text = text.replace(
        "AuditHygieneData,",
        "AuditHygieneData,\n  AuditHygieneRunsData,"
    )

if "listAuditRealHygieneRunsRequest" not in text:
    insert = """
export async function listAuditRealHygieneRunsRequest(token: string) {
  return apiRequest<AuditHygieneRunsData>('/operational-audit/hygiene-runs', {
    method: 'GET',
    token
  });
}

"""
    text = text.replace("export async function getAuditRetentionPolicyRequest", insert + "export async function getAuditRetentionPolicyRequest")

path.write_text(text)
PY

echo "Criando pagina de historico..."

cat > "${FRONTEND_DIR}/src/pages/audit-real-history/AuditRealHistoryPage.tsx" <<'DOC'
import { useEffect, useState } from 'react';
import { listAuditRealHygieneRunsRequest } from '../../services/operational-audit.service';
import { useAuthStore } from '../../stores/auth.store';
import type { AuditHygieneRunItem } from '../../types/operational-audit.types';

export function AuditRealHistoryPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [runs, setRuns] = useState<AuditHygieneRunItem[]>([]);
  const [total, setTotal] = useState(0);
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(true);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadHistory() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const response = await listAuditRealHygieneRunsRequest(token);

    if (response.success) {
      setRuns(response.data.runs);
      setTotal(response.data.total);
    } else {
      setNotice(response.error.message || 'Nao foi possivel carregar historico.');
    }

    setLoading(false);
  }

  useEffect(() => {
    void loadHistory();
  }, []);

  return (
    <section>
      <div className="page-heading">
        <span>Auditoria</span>
        <h1>Historico de higienizacoes reais</h1>
        <p>Consulte as execucoes reais registradas com retencao, candidatos e dados redigidos.</p>
      </div>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="hygiene-history-summary">
        <article>
          <span>Total de execucoes</span>
          <strong>{total}</strong>
          <p>Ultimas 100 execucoes registradas.</p>
        </article>
      </section>

      {loading ? (
        <div className="conversation-empty">
          Carregando historico...
        </div>
      ) : null}

      {!loading && runs.length === 0 ? (
        <div className="conversation-empty">
          Nenhuma execucao real registrada.
        </div>
      ) : null}

      <section className="hygiene-history-table">
        {runs.map((run) => (
          <article key={run.id}>
            <div>
              <strong>{run.createdAt}</strong>
              <span>ID: {run.id}</span>
              <span>Retencao: {run.retentionDays} dias</span>
            </div>

            <div>
              <span>Dry-run: {run.dryRun ? 'sim' : 'nao'}</span>
              <span>Mensagens antigas: {run.oldMessages}</span>
              <span>Falhas com metadata: {run.oldFailedMessagesWithMetadata}</span>
              <span>Webhooks antigos: {run.oldWebhookEvents}</span>
            </div>

            <div>
              <span>Mensagens redigidas: {run.messagesRedacted}</span>
              <span>Webhooks redigidos: {run.webhookEventsRedacted}</span>
            </div>
          </article>
        ))}
      </section>
    </section>
  );
}
DOC

echo "Atualizando Sidebar e rotas..."

cat > "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" <<'DOC'
import { NavLink } from 'react-router-dom';

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div className="sidebar-logo">LH</div>
        <div>
          <strong>LH Bot</strong>
          <span>WhatsApp Meta</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/app/dashboard">Dashboard</NavLink>
        <NavLink to="/app/contacts">Contatos</NavLink>
        <NavLink to="/app/conversations">Conversas</NavLink>
        <NavLink to="/app/whatsapp-accounts">WhatsApp</NavLink>
        <NavLink to="/app/meta-settings">Meta</NavLink>
        <NavLink to="/app/audit">Auditoria</NavLink>
        <NavLink to="/app/audit-real-run">Higienizacao real</NavLink>
        <NavLink to="/app/audit-real-history">Historico higiene</NavLink>
        <NavLink to="/app/profile">Perfil</NavLink>
      </nav>
    </aside>
  );
}
DOC

cat > "${FRONTEND_DIR}/src/app/routes.tsx" <<'DOC'
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes
} from 'react-router-dom';
import { AppLayout } from '../components/layout/AppLayout';
import { AuditPage } from '../pages/audit/AuditPage';
import { AuditRealHistoryPage } from '../pages/audit-real-history/AuditRealHistoryPage';
import { AuditRealRunPage } from '../pages/audit-real-run/AuditRealRunPage';
import { ContactsPage } from '../pages/contacts/ContactsPage';
import { ConversationsPage } from '../pages/conversations/ConversationsPage';
import { DashboardPage } from '../pages/dashboard/DashboardPage';
import { LoginPage } from '../pages/login/LoginPage';
import { MetaSettingsPage } from '../pages/meta-settings/MetaSettingsPage';
import { ProfilePage } from '../pages/profile/ProfilePage';
import { WhatsappAccountsPage } from '../pages/whatsapp-accounts/WhatsappAccountsPage';
import { ProtectedRoute } from './ProtectedRoute';

export function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/login" element={<LoginPage />} />

        <Route
          path="/app"
          element={
            <ProtectedRoute>
              <AppLayout />
            </ProtectedRoute>
          }
        >
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="contacts" element={<ContactsPage />} />
          <Route path="conversations" element={<ConversationsPage />} />
          <Route path="whatsapp-accounts" element={<WhatsappAccountsPage />} />
          <Route path="meta-settings" element={<MetaSettingsPage />} />
          <Route path="audit" element={<AuditPage />} />
          <Route path="audit-real-run" element={<AuditRealRunPage />} />
          <Route path="audit-real-history" element={<AuditRealHistoryPage />} />
          <Route path="profile" element={<ProfilePage />} />
        </Route>

        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
DOC

echo "Adicionando estilos do historico..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.hygiene-history-summary {
  display: grid;
  gap: 16px;
  grid-template-columns: minmax(0, 1fr);
  margin-top: 24px;
}

.hygiene-history-summary article,
.hygiene-history-table article {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  padding: 20px;
}

.hygiene-history-summary span {
  color: #6b7280;
  display: block;
  font-size: 13px;
  font-weight: 900;
  margin-bottom: 8px;
  text-transform: uppercase;
}

.hygiene-history-summary strong {
  display: block;
  font-size: 30px;
}

.hygiene-history-summary p {
  color: #6b7280;
  margin: 8px 0 0;
}

.hygiene-history-table {
  display: grid;
  gap: 14px;
  margin-top: 22px;
}

.hygiene-history-table article {
  display: grid;
  gap: 14px;
  grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr) minmax(0, 1fr);
}

.hygiene-history-table strong,
.hygiene-history-table span {
  display: block;
  overflow-wrap: anywhere;
}

.hygiene-history-table span {
  color: #4b5563;
  margin-top: 6px;
}

@media (max-width: 900px) {
  .hygiene-history-table article {
    grid-template-columns: 1fr;
  }
}
DOC

echo "Validando frontend sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/types/operational-audit.types.ts" \
  "${FRONTEND_DIR}/src/services/operational-audit.service.ts" \
  "${FRONTEND_DIR}/src/pages/audit-real-history/AuditRealHistoryPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
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

echo "Rebuildando backend e frontend..."

docker compose build backend 2>&1 | tee "${DOCKER_BACKEND_BUILD_LOG}"
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

DOMAIN_HISTORY_STATUS="$(curl -L -s -o "${DOMAIN_HISTORY_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUDIT_URL}/hygiene-runs" || true)"

if [ "${DOMAIN_HISTORY_STATUS}" != "200" ]; then
  echo "ERRO: historico hygiene-runs falhou. Status ${DOMAIN_HISTORY_STATUS}"
  cat "${DOMAIN_HISTORY_LOG}"
  exit 1
fi

if ! grep -q '"runs"' "${DOMAIN_HISTORY_LOG}"; then
  echo "ERRO: historico nao retornou runs."
  cat "${DOMAIN_HISTORY_LOG}"
  exit 1
fi

DOMAIN_AUDIT_HISTORY_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_HISTORY_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_HISTORY_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_HISTORY_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina audit-real-history nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

DOMAIN_AUDIT_REAL_RUN_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_REAL_RUN_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_REAL_RUN_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_REAL_RUN_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina audit-real-run nao respondeu 200."
  exit 1
fi

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina audit nao respondeu 200."
  exit 1
fi

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: dashboard nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 51..."

cat > "${DOC_FILE}" <<'DOC'
# Real Hygiene History

## Visao geral

Este documento registra o relatorio historico das execucoes reais de higienizacao.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- endpoint de historico de execucoes reais
- leitura da tabela operational audit hygiene runs
- tela app audit real history
- listagem das ultimas 100 execucoes
- exibicao da retencao usada
- exibicao de dry run
- exibicao de candidatos encontrados
- exibicao de quantidades redigidas
- link no menu lateral

## Endpoints criados

Endpoints:

- GET api v1 operational audit hygiene runs

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/operational-audit/operational-audit.types.ts
- apps/backend/src/modules/operational-audit/operational-audit.service.ts
- apps/backend/src/modules/operational-audit/operational-audit.controller.ts
- apps/frontend/src/types/operational-audit.types.ts
- apps/frontend/src/services/operational-audit.service.ts
- apps/frontend/src/pages/audit-real-history/AuditRealHistoryPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/REAL_HYGIENE_HISTORY.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- existencia da tabela operational audit hygiene runs
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint hygiene runs dominio
- rota app audit real history
- rota app audit real run
- rota app audit
- rota app dashboard

## Logs gerados

Logs:

- logs/setup_51_backend_typecheck.log
- logs/setup_51_backend_build.log
- logs/setup_51_frontend_typecheck.log
- logs/setup_51_frontend_build.log
- logs/setup_51_backend_docker_build.log
- logs/setup_51_frontend_docker_build.log
- logs/setup_51_docker_up.log
- logs/setup_51_backend_wait.log
- logs/setup_51_auth_login_domain.log
- logs/setup_51_hygiene_runs_domain.log
- logs/setup_51_domain_audit_real_history_page.log
- logs/setup_51_domain_audit_real_run_page.log
- logs/setup_51_domain_audit_page.log
- logs/setup_51_domain_dashboard.log
- logs/setup_51.log

## Proxima etapa sugerida

Etapa 52:

    Criar exportacao CSV do historico de higienizacoes reais
DOC

echo "Atualizando controle e manifesto..."

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
- [x] Etapa 47 - Higienizacao de dados de auditoria antigos
- [x] Etapa 48 - Configuracao visual de politica de retencao
- [x] Etapa 49 - Persistencia backend da politica de retencao por tenant
- [x] Etapa 50 - Execucao operacional controlada de higienizacao real
- [x] Etapa 51 - Relatorio historico das execucoes reais de higienizacao
- [ ] Etapa 52 - Exportacao CSV do historico de higienizacoes reais

## Ultima etapa executada

Etapa 51 - Relatorio historico das execucoes reais de higienizacao.

## Proxima etapa sugerida

Etapa 52 - Criar exportacao CSV do historico de higienizacoes reais.
DOC

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto do Projeto

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

Estrutura real do monorepo criada.

Backend base criado.

Frontend base criado.

Docker Compose inicial criado.

Env example criado.

Ambiente inicial validado.

Dependencias base instaladas e validadas.

Dockerfiles ajustados e builds validados.

Dominio bot.lhsolucao.com.br configurado e testado.

Backend real inicial iniciado.

Prisma configurado com conexao real ao PostgreSQL.

Schema inicial do banco criado.

Seed inicial criado.

Auth inicial com login real criado.

Frontend login integrado criado.

Layout base e protecao visual de rotas criados.

Modulo backend de usuarios criado.

Frontend com perfil detalhado criado.

Modulo backend de contatos criado.

Frontend de contatos integrado criado.

Frontend de conversas com layout inicial criado.

Modulo backend de conversas criado.

Frontend de conversas integrado ao backend criado.

Modulo backend de WhatsApp Accounts criado.

Frontend de WhatsApp Accounts integrado criado.

Modulo backend de webhooks da Meta criado.

Validacao de assinatura dos webhooks da Meta criada.

Processamento de status de mensagens no frontend criado.

Envio real de mensagens pela API oficial da Meta criado.

Suporte a templates oficiais da Meta criado.

Frontend para envio de templates oficiais criado.

Painel de configuracao operacional da conta Meta criado.

Limpeza operacional de dados de teste criada.

Painel de auditoria operacional criado.

Relatorio operacional exportavel criado.

Higienizacao de dados de auditoria antigos criada.

Configuracao visual de politica de retencao criada.

Persistencia backend da politica de retencao por tenant criada.

Execucao operacional controlada de higienizacao real criada.

Relatorio historico das execucoes reais de higienizacao criado.

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml
- .env.example
- .env
- .dockerignore

## Documentos tecnicos

- docs/REAL_HYGIENE_HISTORY.md
- docs/CONTROLLED_REAL_HYGIENE.md
- docs/RETENTION_POLICY_BACKEND.md
- docs/RETENTION_POLICY_VISUAL_CONFIG.md
- docs/AUDIT_DATA_HYGIENE.md
- docs/OPERATIONAL_EXPORT_REPORT.md
- docs/OPERATIONAL_AUDIT_PANEL.md
- docs/OPERATIONAL_CLEANUP.md
- docs/META_OPERATIONAL_PANEL.md
- docs/FRONTEND_META_TEMPLATES.md
- docs/BACKEND_META_TEMPLATES.md
- docs/BACKEND_META_SEND_MESSAGES.md
- docs/FRONTEND_MESSAGE_STATUS.md
- docs/BACKEND_META_WEBHOOK_SIGNATURE.md
- docs/BACKEND_META_WEBHOOKS.md
- docs/FRONTEND_WHATSAPP_ACCOUNTS.md
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- docs/FRONTEND_CONVERSATIONS_INTEGRADO.md
- docs/BACKEND_CONVERSATIONS.md
- docs/FRONTEND_CONVERSATIONS_LAYOUT.md
- docs/FRONTEND_CONTACTS.md
- docs/BACKEND_CONTACTS.md
- docs/FRONTEND_PROFILE_DETALHADO.md
- docs/BACKEND_USERS_PROFILE.md
- docs/FRONTEND_LAYOUT_PROTECAO_ROTAS.md
- docs/FRONTEND_LOGIN_INTEGRADO.md
- docs/AUTH_LOGIN_REAL.md
- docs/SEED_INICIAL.md
- docs/PRISMA_SCHEMA_INICIAL.md
- docs/BACKEND_PRISMA_POSTGRES.md
- docs/BACKEND_HEALTH_CONFIG_DATABASE.md
- docs/EXECUCAO_INICIAL_DOMINIO.md
- docs/NGINX_BOT_LHSOLUCAO.md
- docs/DOCKER_BUILD.md
- docs/DEPENDENCIAS_BASE.md
- docs/VALIDACAO_AMBIENTE.md
- docs/ENV_EXAMPLE.md
- docs/DOCKER_COMPOSE_BASE.md
- docs/FRONTEND_BASE.md
- docs/BACKEND_BASE.md
- docs/ESTRUTURA_PROJETO.md
- docs/VALIDACAO_FINAL.md
- docs/DEPLOY.md
- docs/BACKEND.md
- docs/FRONTEND.md
- docs/WEBHOOKS_META.md
- docs/SEGURANCA.md
- docs/API.md
- docs/BANCO_DADOS.md
- docs/ARQUITETURA.md

## Etapas concluidas

- Etapa 01 ate Etapa 51 concluidas

## Proxima etapa

- Etapa 52 - Exportacao CSV do historico de higienizacoes reais
DOC

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 51 - Relatorio historico das execucoes reais de higienizacao
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criado endpoint GET operational audit hygiene runs e tela app audit real history para listar execucoes reais registradas em operational_audit_hygiene_runs.
DOC
  fi
done

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
Etapa: 51
Acao: Relatorio historico das execucoes reais de higienizacao
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Hygiene runs status: ${DOMAIN_HISTORY_STATUS}
Audit real history page status: ${DOMAIN_AUDIT_HISTORY_PAGE_STATUS}
Audit real run page status: ${DOMAIN_AUDIT_REAL_RUN_PAGE_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 51 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Historico:"
cat "${DOMAIN_HISTORY_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 52 - Criar exportacao CSV do historico de higienizacoes reais"
