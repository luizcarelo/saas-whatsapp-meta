#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_77.log"

FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_77_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_77_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_77_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_77_docker_up.log"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_77_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_77_auth_login_domain.log"
DOMAIN_DEPARTMENTS_LOG="${LOGS_DIR}/setup_77_departments_domain.log"
DOMAIN_QUICK_REPLIES_LOG="${LOGS_DIR}/setup_77_quick_replies_domain.log"
DOMAIN_AUTOMATION_RULES_LOG="${LOGS_DIR}/setup_77_automation_rules_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_77_status_model_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_77_domain_inbox_page.log"
DOMAIN_SETTINGS_PAGE_LOG="${LOGS_DIR}/setup_77_domain_attendance_settings_page.log"
DOMAIN_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_77_domain_attendance_dashboard_page.log"
DOMAIN_FAILURES_PAGE_LOG="${LOGS_DIR}/setup_77_domain_send_failures_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_SETTINGS_PAGE.md"
DOC_CHECKLIST="${DOCS_DIR}/ATTENDANCE_SETTINGS_CHECKLIST.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_AUTOMATIONS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-automations"
DOMAIN_STATUS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-status"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_SETTINGS_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-settings"
DOMAIN_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"
DOMAIN_FAILURES_PAGE_URL="${DOMAIN_BASE_URL}/app/send-failures"

echo "== Etapa 77: Criacao da tela attendance settings =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/pages/attendance-settings"
mkdir -p "${FRONTEND_DIR}/src/services"

echo "Validando conclusao da Etapa 76..."

if [ ! -f "${LOGS_DIR}/setup_76.log" ]; then
  echo "ERRO: setup_76.log nao encontrado. Conclua a Etapa 76 antes da Etapa 77."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_76.log"; then
  echo "ERRO: Etapa 76 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_76.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/pages/attendance-settings/AttendanceSettingsPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-settings.service.ts" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${DOC_FILE}" \
  "${DOC_CHECKLIST}" \
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

for tool in node npm docker curl python3 grep; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Criando service frontend da tela settings..."

cat > "${FRONTEND_DIR}/src/services/attendance-settings.service.ts" <<'DOC'
import { apiRequest } from './api';

export type AttendanceSettingsDepartment = {
  id: string;
  name: string;
  description?: string | null;
  isActive?: boolean;
};

export type AttendanceSettingsQuickReply = {
  id: string;
  title: string;
  body?: string;
  departmentName?: string | null;
  isActive?: boolean;
};

export type AttendanceSettingsAutomationRule = {
  id: string;
  name: string;
  slug: string;
  departmentName: string;
  triggerStatus: string;
  messageOrigin: string;
  isActive: boolean;
  sendDryRun: boolean;
  maxRunsPerConversation: number;
};

export type AttendanceSettingsStatusItem = {
  id: string;
  group: string;
  code: string;
  label: string;
  description: string;
  sortOrder: number;
  isActive: boolean;
  isTerminal: boolean;
};

export type AttendanceSettingsStatusModel = {
  groups: {
    conversation: AttendanceSettingsStatusItem[];
    attendance: AttendanceSettingsStatusItem[];
    send: AttendanceSettingsStatusItem[];
    closure: AttendanceSettingsStatusItem[];
  };
};

export async function listAttendanceSettingsDepartments(token: string) {
  return apiRequest<{ departments: AttendanceSettingsDepartment[] }>('/attendance/departments', {
    method: 'GET',
    token
  });
}

export async function listAttendanceSettingsQuickReplies(token: string) {
  return apiRequest<{ quickReplies: AttendanceSettingsQuickReply[] }>('/attendance/quick-replies', {
    method: 'GET',
    token
  });
}

export async function listAttendanceSettingsAutomationRules(token: string) {
  return apiRequest<{ rules: AttendanceSettingsAutomationRule[] }>('/attendance-automations/rules', {
    method: 'GET',
    token
  });
}

export async function getAttendanceSettingsStatusModel(token: string) {
  return apiRequest<AttendanceSettingsStatusModel>('/attendance-status/model', {
    method: 'GET',
    token
  });
}
DOC

echo "Criando pagina attendance settings..."

cat > "${FRONTEND_DIR}/src/pages/attendance-settings/AttendanceSettingsPage.tsx" <<'DOC'
import { useEffect, useMemo, useState } from 'react';
import {
  getAttendanceSettingsStatusModel,
  listAttendanceSettingsAutomationRules,
  listAttendanceSettingsDepartments,
  listAttendanceSettingsQuickReplies,
  type AttendanceSettingsAutomationRule,
  type AttendanceSettingsDepartment,
  type AttendanceSettingsQuickReply,
  type AttendanceSettingsStatusModel
} from '../../services/attendance-settings.service';
import { useAuthStore } from '../../stores/auth.store';

export function AttendanceSettingsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [departments, setDepartments] = useState<AttendanceSettingsDepartment[]>([]);
  const [quickReplies, setQuickReplies] = useState<AttendanceSettingsQuickReply[]>([]);
  const [automationRules, setAutomationRules] = useState<AttendanceSettingsAutomationRule[]>([]);
  const [statusModel, setStatusModel] = useState<AttendanceSettingsStatusModel | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState('');

  const stats = useMemo(() => {
    const activeDepartments = departments.filter((item) => item.isActive !== false).length;
    const activeQuickReplies = quickReplies.filter((item) => item.isActive !== false).length;
    const activeAutomations = automationRules.filter((item) => item.isActive).length;
    const dryRunAutomations = automationRules.filter((item) => item.sendDryRun).length;

    return {
      activeDepartments,
      activeQuickReplies,
      activeAutomations,
      dryRunAutomations
    };
  }, [departments, quickReplies, automationRules]);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadSettings() {
    const token = getToken();

    if (!token) {
      setNotice('Token de acesso nao encontrado.');
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const [
      departmentsResponse,
      quickRepliesResponse,
      automationRulesResponse,
      statusModelResponse
    ] = await Promise.all([
      listAttendanceSettingsDepartments(token),
      listAttendanceSettingsQuickReplies(token),
      listAttendanceSettingsAutomationRules(token),
      getAttendanceSettingsStatusModel(token)
    ]);

    if (departmentsResponse.success) {
      setDepartments(departmentsResponse.data.departments || []);
    } else {
      setNotice(departmentsResponse.error.message || 'Nao foi possivel carregar departamentos.');
    }

    if (quickRepliesResponse.success) {
      setQuickReplies(quickRepliesResponse.data.quickReplies || []);
    }

    if (automationRulesResponse.success) {
      setAutomationRules(automationRulesResponse.data.rules || []);
    }

    if (statusModelResponse.success) {
      setStatusModel(statusModelResponse.data);
    }

    setLoading(false);
  }

  useEffect(() => {
    void loadSettings();
  }, []);

  return (
    <section className="attendance-settings-shell">
      <section className="inbox-hero">
        <div>
          <span>Configuracoes de atendimento</span>
          <h1>Attendance Settings</h1>
          <p>Centralize departamentos, respostas rapidas, automacoes e status padronizados fora do fluxo principal do inbox.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="attendance-settings-actions">
        <button onClick={() => void loadSettings()} type="button">
          Atualizar configuracoes
        </button>

        /app/inboxVoltar para atendimento</a>
      </section>

      {loading ? <div className="conversation-empty">Carregando configuracoes...</div> : null}

      <section className="attendance-settings-summary">
        <article>
          <strong>{stats.activeDepartments}</strong>
          <span>Departamentos ativos</span>
        </article>

        <article>
          <strong>{stats.activeQuickReplies}</strong>
          <span>Respostas rapidas ativas</span>
        </article>

        <article>
          <strong>{stats.activeAutomations}</strong>
          <span>Automacoes ativas</span>
        </article>

        <article>
          <strong>{stats.dryRunAutomations}</strong>
          <span>Automacoes em dryRun</span>
        </article>
      </section>

      <section className="attendance-settings-grid">
        <article className="attendance-settings-card">
          <header>
            <div>
              <strong>Departamentos</strong>
              <span>Filas e setores usados na central</span>
            </div>
          </header>

          <div className="attendance-settings-list">
            {departments.length ? departments.map((department) => (
              <div key={department.id}>
                <strong>{department.name}</strong>
                <span>{department.description || 'Sem descricao'}</span>
                <em>{department.isActive === false ? 'Inativo' : 'Ativo'}</em>
              </div>
            )) : <p>Nenhum departamento encontrado.</p>}
          </div>
        </article>

        <article className="attendance-settings-card">
          <header>
            <div>
              <strong>Respostas rapidas</strong>
              <span>Textos prontos por departamento</span>
            </div>
          </header>

          <div className="attendance-settings-list">
            {quickReplies.length ? quickReplies.slice(0, 12).map((reply) => (
              <div key={reply.id}>
                <strong>{reply.title}</strong>
                <span>{reply.departmentName || 'Sem departamento'}</span>
                <em>{reply.isActive === false ? 'Inativa' : 'Ativa'}</em>
              </div>
            )) : <p>Nenhuma resposta rapida encontrada.</p>}
          </div>
        </article>

        <article className="attendance-settings-card">
          <header>
            <div>
              <strong>Automacoes</strong>
              <span>Regras por status e departamento</span>
            </div>
          </header>

          <div className="attendance-settings-list">
            {automationRules.length ? automationRules.map((rule) => (
              <div key={rule.id}>
                <strong>{rule.name}</strong>
                <span>{rule.departmentName} / {rule.triggerStatus}</span>
                <em>{rule.isActive ? 'Ativa' : 'Inativa'} {rule.sendDryRun ? '- dryRun' : ''}</em>
              </div>
            )) : <p>Nenhuma automacao encontrada.</p>}
          </div>
        </article>

        <article className="attendance-settings-card">
          <header>
            <div>
              <strong>Status padronizados</strong>
              <span>Modelo operacional do atendimento</span>
            </div>
          </header>

          <div className="attendance-settings-status">
            {statusModel ? (
              <>
                <StatusGroup title="Conversation" items={statusModel.groups.conversation} />
                <StatusGroup title="Attendance" items={statusModel.groups.attendance} />
                <StatusGroup title="Send" items={statusModel.groups.send} />
                <StatusGroup title="Closure" items={statusModel.groups.closure} />
              </>
            ) : <p>Modelo de status nao carregado.</p>}
          </div>
        </article>

        <article className="attendance-settings-card attendance-settings-wide">
          <header>
            <div>
              <strong>Pendencias e proximos refinamentos</strong>
              <span>Itens que ainda devem sair do inbox principal</span>
            </div>
          </header>

          <div className="attendance-settings-roadmap">
            <span>Separar envio, encerramento e historico visual</span>
            <span>Isolar configuracoes avancadas de automacao</span>
            <span>Limpar dados sinteticos em etapa propria</span>
            <span>Retomar recebimento Meta quando houver retorno</span>
          </div>
        </article>
      </section>
    </section>
  );
}

function StatusGroup(props: {
  title: string;
  items: Array<{
    id: string;
    code: string;
    label: string;
    isTerminal: boolean;
  }>;
}) {
  return (
    <div>
      <strong>{props.title}</strong>

      <div>
        {props.items.map((item) => (
          <span key={item.id}>
            {item.label}
            {item.isTerminal ? ' terminal' : ''}
          </span>
        ))}
      </div>
    </div>
  );
}
DOC

echo "Atualizando rotas..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/app/routes.tsx")
text = path.read_text()

if "AttendanceSettingsPage" not in text:
    lines = text.splitlines()
    last_import = -1

    for index, line in enumerate(lines):
        if line.startswith("import "):
            last_import = index

    lines.insert(last_import + 1, "import { AttendanceSettingsPage } from '../pages/attendance-settings/AttendanceSettingsPage';")
    text = "\n".join(lines) + "\n"

if 'path="attendance-settings"' not in text:
    anchor = '<Route path="send-failures" element={<SendFailuresPage />} />'

    if anchor in text:
        text = text.replace(
            anchor,
            anchor + '\n          <Route path="attendance-settings" element={<AttendanceSettingsPage />} />'
        )
    else:
        text = text.replace(
            '<Route path="attendance-dashboard" element={<AttendanceDashboardPage />} />',
            '<Route path="attendance-dashboard" element={<AttendanceDashboardPage />} />\n          <Route path="attendance-settings" element={<AttendanceSettingsPage />} />'
        )

path.write_text(text)
PY

echo "Atualizando menu lateral..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/components/layout/Sidebar.tsx")
text = path.read_text()

if 'to="/app/attendance-settings"' not in text:
    anchor = '<NavLink to="/app/send-failures">Falhas de envio</NavLink>'

    if anchor in text:
        text = text.replace(
            anchor,
            anchor + '\n        <NavLink to="/app/attendance-settings">Configuracoes atendimento</NavLink>'
        )
    else:
        text = text.replace(
            '<NavLink to="/app/inbox">Atendimento</NavLink>',
            '<NavLink to="/app/inbox">Atendimento</NavLink>\n        <NavLink to="/app/attendance-settings">Configuracoes atendimento</NavLink>'
        )

path.write_text(text)
PY

echo "Aplicando CSS da tela settings..."

if ! grep -q "Etapa 77 - Attendance settings page" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 77 - Attendance settings page */

.attendance-settings-shell {
  display: grid;
  gap: 20px;
}

.attendance-settings-actions {
  align-items: center;
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 18px;
  display: flex;
  gap: 12px;
  justify-content: space-between;
  padding: 14px 16px;
}

.attendance-settings-actions button,
.attendance-settings-actions a {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-600, #2563eb));
  border: none;
  border-radius: 999px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 10px 14px;
  text-decoration: none;
}

.attendance-settings-summary {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.attendance-settings-summary article {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 20px;
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  display: grid;
  gap: 6px;
  padding: 18px;
}

.attendance-settings-summary strong {
  color: var(--lh-red-600, #dc2626);
  font-size: 30px;
  line-height: 1;
}

.attendance-settings-summary span {
  color: var(--lh-blue-950, #04204f);
  font-size: 13px;
  font-weight: 900;
}

.attendance-settings-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.attendance-settings-card {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 22px;
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  display: grid;
  gap: 16px;
  padding: 18px;
}

.attendance-settings-card header {
  border-bottom: 1px solid rgba(4, 32, 79, 0.08);
  padding-bottom: 12px;
}

.attendance-settings-card header strong {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-size: 17px;
}

.attendance-settings-card header span {
  color: var(--lh-muted, #6b7280);
  display: block;
  font-size: 13px;
  font-weight: 800;
  margin-top: 4px;
}

.attendance-settings-list {
  display: grid;
  gap: 10px;
  max-height: 380px;
  overflow: auto;
}

.attendance-settings-list > div {
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  display: grid;
  gap: 5px;
  padding: 12px;
}

.attendance-settings-list strong {
  color: var(--lh-blue-950, #04204f);
}

.attendance-settings-list span {
  color: #4b5563;
  font-size: 13px;
}

.attendance-settings-list em {
  color: var(--lh-red-600, #dc2626);
  font-size: 12px;
  font-style: normal;
  font-weight: 950;
}

.attendance-settings-status {
  display: grid;
  gap: 14px;
}

.attendance-settings-status > div {
  display: grid;
  gap: 8px;
}

.attendance-settings-status > div > strong {
  color: var(--lh-blue-950, #04204f);
}

.attendance-settings-status > div > div {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.attendance-settings-status span {
  background: #eef2ff;
  border-radius: 999px;
  color: #1d4ed8;
  font-size: 12px;
  font-weight: 900;
  padding: 7px 10px;
}

.attendance-settings-wide {
  grid-column: 1 / -1;
}

.attendance-settings-roadmap {
  display: grid;
  gap: 10px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.attendance-settings-roadmap span {
  background: linear-gradient(135deg, rgba(7, 87, 200, 0.08), rgba(220, 38, 38, 0.08));
  border: 1px solid rgba(4, 32, 79, 0.08);
  border-radius: 16px;
  color: var(--lh-blue-950, #04204f);
  font-weight: 900;
  padding: 14px;
}

@media (max-width: 1100px) {
  .attendance-settings-summary,
  .attendance-settings-grid,
  .attendance-settings-roadmap {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 720px) {
  .attendance-settings-actions {
    align-items: stretch;
    flex-direction: column;
  }

  .attendance-settings-summary,
  .attendance-settings-grid,
  .attendance-settings-roadmap {
    grid-template-columns: 1fr;
  }
}
DOC
fi

echo "Validando ausencia de HTML injetado no frontend..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/attendance-settings/AttendanceSettingsPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-settings.service.ts" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML injetado encontrado no frontend."
  exit 1
fi

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_FRONTEND_BUILD_LOG}"

echo "Subindo frontend e proxy..."

docker compose up -d frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

sleep 8

echo "Validando dominio..."

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

echo "Validando endpoints usados pela tela settings..."

DOMAIN_DEPARTMENTS_STATUS="$(curl -L -s -o "${DOMAIN_DEPARTMENTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/departments" || true)"

if [ "${DOMAIN_DEPARTMENTS_STATUS}" != "200" ]; then
  echo "ERRO: departments endpoint falhou. Status ${DOMAIN_DEPARTMENTS_STATUS}"
  cat "${DOMAIN_DEPARTMENTS_LOG}"
  exit 1
fi

DOMAIN_QUICK_REPLIES_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies" || true)"

if [ "${DOMAIN_QUICK_REPLIES_STATUS}" != "200" ]; then
  echo "ERRO: quick replies endpoint falhou. Status ${DOMAIN_QUICK_REPLIES_STATUS}"
  cat "${DOMAIN_QUICK_REPLIES_LOG}"
  exit 1
fi

DOMAIN_AUTOMATION_RULES_STATUS="$(curl -L -s -o "${DOMAIN_AUTOMATION_RULES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUTOMATIONS_URL}/rules" || true)"

if [ "${DOMAIN_AUTOMATION_RULES_STATUS}" != "200" ]; then
  echo "ERRO: automation rules endpoint falhou. Status ${DOMAIN_AUTOMATION_RULES_STATUS}"
  cat "${DOMAIN_AUTOMATION_RULES_LOG}"
  exit 1
fi

DOMAIN_STATUS_MODEL_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MODEL_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_STATUS_URL}/model" || true)"

if [ "${DOMAIN_STATUS_MODEL_STATUS}" != "200" ]; then
  echo "ERRO: status model endpoint falhou. Status ${DOMAIN_STATUS_MODEL_STATUS}"
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

echo "Validando paginas principais..."

DOMAIN_SETTINGS_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_SETTINGS_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_SETTINGS_PAGE_URL}" || true)"

if [ "${DOMAIN_SETTINGS_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina attendance settings nao respondeu 200."
  exit 1
fi

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_INBOX_PAGE_URL}" || true)"

if [ "${DOMAIN_INBOX_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina inbox nao respondeu 200."
  exit 1
fi

DOMAIN_DASHBOARD_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_PAGE_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina attendance dashboard nao respondeu 200."
  exit 1
fi

DOMAIN_FAILURES_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_FAILURES_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_FAILURES_PAGE_URL}" || true)"

if [ "${DOMAIN_FAILURES_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina send failures nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 77..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Settings Page

## Visao geral

Este documento registra a criacao da tela attendance settings.

## Resultado

Status:

    concluido

## Objetivo

Objetivo:

- retirar configuracoes do fluxo principal do app inbox
- centralizar departamentos
- centralizar respostas rapidas
- exibir automacoes de atendimento
- exibir status padronizados
- preparar futuras configuracoes do modulo Atendimento

## Tela criada

Tela:

- app attendance settings

## Conteudo da tela

Conteudo:

- resumo de departamentos ativos
- resumo de respostas rapidas ativas
- resumo de automacoes ativas
- resumo de automacoes em dryRun
- lista de departamentos
- lista de respostas rapidas
- lista de automacoes
- modelo de status padronizado
- roadmap de refinamentos pendentes

## Limites da etapa

Limites:

- nao altera regras de negocio
- nao altera banco de dados
- nao cria edicao ainda
- nao envia mensagem real
- nao altera automacoes
- nao resolve pendencia Meta

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/pages/attendance-settings/AttendanceSettingsPage.tsx
- apps/frontend/src/services/attendance-settings.service.ts
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_SETTINGS_PAGE.md
- docs/ATTENDANCE_SETTINGS_CHECKLIST.md
- 00_CONTROLE.md
- MANIFESTO.md

## Endpoints consumidos

Endpoints:

- GET api v1 attendance departments
- GET api v1 attendance quick replies
- GET api v1 attendance automations rules
- GET api v1 attendance status model

## Validacoes executadas

Validacoes:

- frontend sem HTML injetado
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- health dominio
- login dominio
- endpoint departments
- endpoint quick replies
- endpoint automation rules
- endpoint status model
- rota app attendance settings
- rota app inbox
- rota app attendance dashboard
- rota app send failures

## Proxima etapa sugerida

Etapa 78:

    Separacao visual de envio encerramento e historico
DOC

cat > "${DOC_CHECKLIST}" <<'DOC'
# Attendance Settings Checklist

## Visao geral

Este documento registra o checklist para revisar a tela attendance settings.

## Checklist

Itens:

- confirmar acesso pelo menu lateral
- confirmar acesso pela rota app attendance settings
- confirmar listagem de departamentos
- confirmar listagem de respostas rapidas
- confirmar listagem de automacoes
- confirmar exibicao dos status padronizados
- confirmar cards de resumo
- confirmar botao de atualizar configuracoes
- confirmar link de retorno ao atendimento
- confirmar responsividade
- confirmar que nao ha envio real nessa tela

## Observacoes

Observacoes:

- esta etapa cria visualizacao e organizacao
- edicao de configuracoes deve ser planejada em etapa futura
- configuracoes avancadas de automacao devem permanecer controladas
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 77 - Criacao da tela attendance settings",
    "- [x] Etapa 77 - Criacao da tela attendance settings\n- [ ] Etapa 78 - Separacao visual de envio encerramento e historico"
)

text = text.replace(
    "Etapa 77 - Criacao da tela attendance settings.",
    "Etapa 78 - Separacao visual de envio encerramento e historico."
)

text = text.replace(
    "Etapa 76 - Reorganizacao visual do app inbox.",
    "Etapa 77 - Criacao da tela attendance settings."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Tela attendance settings criada." not in text:
    text += "\nTela attendance settings criada.\n"

for doc in [
    "- docs/ATTENDANCE_SETTINGS_PAGE.md",
    "- docs/ATTENDANCE_SETTINGS_CHECKLIST.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 76 concluidas",
    "- Etapa 01 ate Etapa 77 concluidas"
)

text = text.replace(
    "- Etapa 77 - Criacao da tela attendance settings",
    "- Etapa 78 - Separacao visual de envio encerramento e historico"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 77 - Criacao da tela attendance settings
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada tela attendance settings para centralizar visualmente departamentos, respostas rapidas, automacoes e status padronizados fora do fluxo principal do app inbox.
DOC
  fi
done

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${DOC_CHECKLIST}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 77
Acao: Criacao da tela attendance settings
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Departments status: ${DOMAIN_DEPARTMENTS_STATUS}
Quick replies status: ${DOMAIN_QUICK_REPLIES_STATUS}
Automation rules status: ${DOMAIN_AUTOMATION_RULES_STATUS}
Status model status: ${DOMAIN_STATUS_MODEL_STATUS}
Attendance settings page status: ${DOMAIN_SETTINGS_PAGE_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Attendance dashboard page status: ${DOMAIN_DASHBOARD_PAGE_STATUS}
Send failures page status: ${DOMAIN_FAILURES_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 77 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 78 - Separacao visual de envio encerramento e historico"
