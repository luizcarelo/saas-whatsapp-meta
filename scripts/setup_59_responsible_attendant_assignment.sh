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

LOG_FILE="${LOGS_DIR}/setup_59.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_59_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_59_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_59_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_59_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_59_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_59_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_59_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_59_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_59_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_59_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_59_attendance_conversations_domain.log"
DOMAIN_ASSIGNMENT_PATCH_LOG="${LOGS_DIR}/setup_59_assignment_patch_domain.log"
DOMAIN_ASSIGNMENT_HISTORY_LOG="${LOGS_DIR}/setup_59_assignment_history_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_59_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_59_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_59_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 59: Atribuicao de responsavel e nome do atendente =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/attendance"
mkdir -p "${FRONTEND_DIR}/src/pages/inbox"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance/attendance.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance/attendance.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance/attendance.controller.ts" \
  "${BACKEND_DIR}/src/modules/attendance/attendance.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${FRONTEND_DIR}/src/types/attendance.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance.service.ts" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
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

echo "Criando tabela de historico de atribuicoes..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists conversation_assignment_history (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  conversation_id uuid not null,
  assigned_user_id uuid,
  assigned_user_name text not null,
  department_name text not null default 'Fila geral',
  action text not null default 'assigned',
  created_at timestamptz not null default now()
);

create index if not exists idx_conversation_assignment_history_tenant
on conversation_assignment_history (tenant_id);

create index if not exists idx_conversation_assignment_history_conversation
on conversation_assignment_history (tenant_id, conversation_id);

create index if not exists idx_conversation_assignment_history_created_at
on conversation_assignment_history (created_at);

create table if not exists conversation_operational_status (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  conversation_id uuid not null,
  status text not null default 'novo',
  priority text not null default 'normal',
  department_name text not null default 'Fila geral',
  assigned_user_id uuid,
  assigned_user_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, conversation_id)
);
SQL

echo "Atualizando types backend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/attendance/attendance.types.ts")
text = path.read_text()

if "AttendanceAssignConversationPayload" not in text:
    text += """

export type AttendanceAssignConversationPayload = {
  assignedUserId?: string | null;
  assignedUserName?: string | null;
  departmentName?: string;
  action?: string;
};

export type AttendanceAssignConversationResponse = {
  success: true;
  data: {
    conversationId: string;
    assignedUserId: string | null;
    assignedUserName: string | null;
    departmentName: string;
    updatedAt: string;
  };
  meta: Record<string, never>;
};

export type AttendanceAssignmentHistoryItem = {
  id: string;
  conversationId: string;
  assignedUserId: string | null;
  assignedUserName: string;
  departmentName: string;
  action: string;
  createdAt: string;
};

export type AttendanceAssignmentHistoryResponse = {
  success: true;
  data: {
    assignments: AttendanceAssignmentHistoryItem[];
  };
  meta: Record<string, never>;
};
"""

path.write_text(text)
PY

echo "Atualizando service backend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/attendance/attendance.service.ts")
text = path.read_text()

if "AttendanceAssignConversationPayload" not in text:
    text = text.replace(
        "AttendanceConversationItem,",
        "AttendanceAssignConversationPayload,\n  AttendanceAssignConversationResponse,\n  AttendanceAssignmentHistoryResponse,\n  AttendanceConversationItem,"
    )

if "type AssignmentHistoryRow" not in text:
    marker = "type DepartmentRow = {"
    insert = """type AssignmentHistoryRow = {
  id: string;
  conversation_id: string;
  assigned_user_id: string | null;
  assigned_user_name: string;
  department_name: string;
  action: string;
  created_at: Date;
};

"""
    text = text.replace(marker, insert + marker)

if "async assignConversation(" not in text:
    marker = "  async updateConversationStatus("
    method = """  async assignConversation(
    tenantId: string,
    conversationId: string,
    payload: AttendanceAssignConversationPayload
  ): Promise<AttendanceAssignConversationResponse> {
    const assignedUserName = (payload.assignedUserName || '').trim();

    if (!assignedUserName) {
      throw new BadRequestException('Nome do responsavel e obrigatorio');
    }

    const currentRows = await this.prismaService.$queryRawUnsafe<OperationalStatusRow[]>(
      'select conversation_id, status, priority, department_name, assigned_user_id, assigned_user_name, updated_at from conversation_operational_status where tenant_id = $1::uuid and conversation_id = $2::uuid limit 1',
      tenantId,
      conversationId
    );

    const current = currentRows[0];
    const departmentName = payload.departmentName || current?.department_name || 'Fila geral';
    const status = current?.status || 'em_atendimento';
    const priority = current?.priority || 'normal';

    await this.ensureDefaultDepartments(tenantId);
    await this.ensureDepartmentByName(tenantId, departmentName);

    await this.prismaService.$executeRawUnsafe(
      'insert into conversation_operational_status (tenant_id, conversation_id, status, priority, department_name, assigned_user_id, assigned_user_name, created_at, updated_at) values ($1::uuid, $2::uuid, $3, $4, $5, $6::uuid, $7, now(), now()) on conflict (tenant_id, conversation_id) do update set status = excluded.status, priority = excluded.priority, department_name = excluded.department_name, assigned_user_id = excluded.assigned_user_id, assigned_user_name = excluded.assigned_user_name, updated_at = now()',
      tenantId,
      conversationId,
      status,
      priority,
      departmentName,
      payload.assignedUserId || null,
      assignedUserName
    );

    await this.prismaService.$executeRawUnsafe(
      'insert into conversation_assignment_history (tenant_id, conversation_id, assigned_user_id, assigned_user_name, department_name, action, created_at) values ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, now())',
      tenantId,
      conversationId,
      payload.assignedUserId || null,
      assignedUserName,
      departmentName,
      payload.action || 'assigned'
    );

    const rows = await this.prismaService.$queryRawUnsafe<OperationalStatusRow[]>(
      'select conversation_id, status, priority, department_name, assigned_user_id, assigned_user_name, updated_at from conversation_operational_status where tenant_id = $1::uuid and conversation_id = $2::uuid limit 1',
      tenantId,
      conversationId
    );

    const row = rows[0];

    return {
      success: true,
      data: {
        conversationId,
        assignedUserId: row?.assigned_user_id || null,
        assignedUserName: row?.assigned_user_name || assignedUserName,
        departmentName: row?.department_name || departmentName,
        updatedAt: row?.updated_at ? row.updated_at.toISOString() : new Date().toISOString()
      },
      meta: {}
    };
  }

  async listAssignmentHistory(
    tenantId: string,
    conversationId: string
  ): Promise<AttendanceAssignmentHistoryResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<AssignmentHistoryRow[]>(
      'select id, conversation_id, assigned_user_id, assigned_user_name, department_name, action, created_at from conversation_assignment_history where tenant_id = $1::uuid and conversation_id = $2::uuid order by created_at desc limit 50',
      tenantId,
      conversationId
    );

    return {
      success: true,
      data: {
        assignments: rows.map((row) => ({
          id: row.id,
          conversationId: row.conversation_id,
          assignedUserId: row.assigned_user_id,
          assignedUserName: row.assigned_user_name,
          departmentName: row.department_name,
          action: row.action,
          createdAt: row.created_at.toISOString()
        }))
      },
      meta: {}
    };
  }

"""
    text = text.replace(marker, method + marker)

path.write_text(text)
PY

echo "Atualizando controller backend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/attendance/attendance.controller.ts")
text = path.read_text()

if "AttendanceAssignConversationPayload" not in text:
    text = text.replace(
        "AttendanceDepartmentPayload,",
        "AttendanceAssignConversationPayload,\n  AttendanceDepartmentPayload,"
    )

if "@Patch('conversations/:conversationId/assignee')" not in text:
    marker = "  @Patch('conversations/:conversationId/status')"
    insert = """  @Patch('conversations/:conversationId/assignee')
  assignConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceAssignConversationPayload
  ) {
    return this.attendanceService.assignConversation(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/assignments')
  listAssignmentHistory(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.attendanceService.listAssignmentHistory(user.tenantId, conversationId);
  }

"""
    text = text.replace(marker, insert + marker)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance" \
  "${BACKEND_DIR}/src/app.module.ts"
then
  echo "ERRO: HTML injetado encontrado no backend."
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

path = Path("apps/frontend/src/types/attendance.types.ts")
text = path.read_text()

if "AttendanceAssignConversationData" not in text:
    text += """

export type AttendanceAssignConversationData = {
  conversationId: string;
  assignedUserId: string | null;
  assignedUserName: string | null;
  departmentName: string;
  updatedAt: string;
};

export type AttendanceAssignmentHistoryItem = {
  id: string;
  conversationId: string;
  assignedUserId: string | null;
  assignedUserName: string;
  departmentName: string;
  action: string;
  createdAt: string;
};

export type AttendanceAssignmentHistoryData = {
  assignments: AttendanceAssignmentHistoryItem[];
};
"""

path.write_text(text)
PY

echo "Atualizando service frontend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/services/attendance.service.ts")
text = path.read_text()

if "AttendanceAssignConversationData" not in text:
    text = text.replace(
        "AttendanceConversationListData,",
        "AttendanceAssignConversationData,\n  AttendanceAssignmentHistoryData,\n  AttendanceConversationListData,"
    )

if "assignAttendanceConversationRequest" not in text:
    text += """

export async function assignAttendanceConversationRequest(
  token: string,
  conversationId: string,
  payload: {
    assignedUserId?: string | null;
    assignedUserName: string;
    departmentName: string;
    action?: string;
  }
) {
  return apiRequest<AttendanceAssignConversationData>('/attendance/conversations/' + conversationId + '/assignee', {
    method: 'PATCH',
    token,
    body: payload
  });
}

export async function listAttendanceAssignmentHistoryRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceAssignmentHistoryData>('/attendance/conversations/' + conversationId + '/assignments', {
    method: 'GET',
    token
  });
}
"""

path.write_text(text)
PY

echo "Atualizando InboxPage.tsx com atribuicao visual..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "assignAttendanceConversationRequest" not in text:
    text = text.replace(
        "createAttendanceDepartmentRequest,",
        "assignAttendanceConversationRequest,\n  createAttendanceDepartmentRequest,"
    )

if "const [assigneeName" not in text:
    text = text.replace(
        "const [newDepartmentName, setNewDepartmentName] = useState('');",
        "const [newDepartmentName, setNewDepartmentName] = useState('');\n  const [assigneeName, setAssigneeName] = useState('');"
    )

if "async function handleAssignConversation" not in text:
    marker = "  async function handleCreateDepartment(event: FormEvent<HTMLFormElement>) {"
    method = """  async function handleAssignConversation(action: string) {
    const token = getToken();
    const name = assigneeName.trim() || 'Atendente atual';

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setConversations((current) => current.map((item) => item.id === selectedConversation.id ? {
        ...item,
        assignedUserName: name,
        status: item.status === 'novo' ? 'em_atendimento' : item.status
      } : item));
      setNotice('Responsavel atribuido localmente para demonstracao.');
      return;
    }

    const response = await assignAttendanceConversationRequest(token, selectedConversation.id, {
      assignedUserId: null,
      assignedUserName: name,
      departmentName: selectedConversation.departmentName,
      action
    });

    if (response.success) {
      await loadInbox();
      setAssigneeName('');
      setNotice('Responsavel atribuido com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel atribuir responsavel.');
    }
  }

"""
    text = text.replace(marker, method + marker)

if "className=\"assignment-card\"" not in text:
    marker = """          <div className="contact-details">
            <span>Departamento: {selectedConversation.departmentName}</span>
            <span>Responsavel: {selectedConversation.assignedUserName || 'Sem responsavel'}</span>
            <span>Prioridade: {priorityLabels[selectedConversation.priority] || selectedConversation.priority}</span>
            <span>Status: {statusLabels[selectedConversation.status] || selectedConversation.status}</span>
          </div>"""
    replacement = marker + """

          <section className="assignment-card">
            <strong>Atribuicao de responsavel</strong>
            <p>Informe o nome do atendente que esta assumindo ou respondendo esta conversa.</p>

            <input
              onChange={(event) => setAssigneeName(event.target.value)}
              placeholder="Nome do atendente"
              value={assigneeName}
            />

            <div>
              <button onClick={() => void handleAssignConversation('assigned')} type="button">
                Salvar responsavel
              </button>

              <button onClick={() => void handleAssignConversation('assumed')} type="button">
                Assumir atendimento
              </button>
            </div>
          </section>"""
    text = text.replace(marker, replacement)

path.write_text(text)
PY

echo "Adicionando CSS da atribuicao..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 59 - Atribuicao de responsavel */

.assignment-card {
  background: #eff6ff;
  border: 1px solid #bfdbfe;
  border-radius: 18px;
  display: grid;
  gap: 10px;
  margin-top: 16px;
  padding: 14px;
}

.assignment-card strong {
  color: var(--lh-blue-950, #04204f);
}

.assignment-card p {
  color: var(--lh-muted, #6b7280);
  margin: 0;
}

.assignment-card input {
  border: 1px solid #93c5fd;
  border-radius: 14px;
  padding: 11px 13px;
  width: 100%;
}

.assignment-card div {
  display: grid;
  gap: 8px;
  grid-template-columns: 1fr;
}

.assignment-card button {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-700, #0a6de8));
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 11px 13px;
}

.assignment-card button:nth-child(2) {
  background: linear-gradient(135deg, var(--lh-orange-700, #f97316), var(--lh-orange-500, #ff9f1c));
}
DOC

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance.types.ts" \
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

echo "Validando credenciais..."

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

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_LIST_STATUS}" != "200" ]; then
  echo "ERRO: listagem attendance falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

DOMAIN_ASSIGNMENT_PATCH_STATUS="SKIPPED"
DOMAIN_ASSIGNMENT_HISTORY_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  ASSIGN_PAYLOAD="$(node -e "console.log(JSON.stringify({assignedUserId:null, assignedUserName:'Validacao Etapa 59', departmentName:'Comercial', action:'assigned'}))")"

  DOMAIN_ASSIGNMENT_PATCH_STATUS="$(curl -L -s -o "${DOMAIN_ASSIGNMENT_PATCH_LOG}" -w "%{http_code}" --max-time 30 \
    -X PATCH \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${ASSIGN_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/assignee" || true)"

  if [ "${DOMAIN_ASSIGNMENT_PATCH_STATUS}" != "200" ] && [ "${DOMAIN_ASSIGNMENT_PATCH_STATUS}" != "201" ]; then
    echo "ERRO: assignment patch falhou. Status ${DOMAIN_ASSIGNMENT_PATCH_STATUS}"
    cat "${DOMAIN_ASSIGNMENT_PATCH_LOG}"
    exit 1
  fi

  if ! grep -q "Validacao Etapa 59" "${DOMAIN_ASSIGNMENT_PATCH_LOG}"; then
    echo "ERRO: assignment patch nao retornou responsavel esperado."
    cat "${DOMAIN_ASSIGNMENT_PATCH_LOG}"
    exit 1
  fi

  DOMAIN_ASSIGNMENT_HISTORY_STATUS="$(curl -L -s -o "${DOMAIN_ASSIGNMENT_HISTORY_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/assignments" || true)"

  if [ "${DOMAIN_ASSIGNMENT_HISTORY_STATUS}" != "200" ]; then
    echo "ERRO: assignment history falhou. Status ${DOMAIN_ASSIGNMENT_HISTORY_STATUS}"
    cat "${DOMAIN_ASSIGNMENT_HISTORY_LOG}"
    exit 1
  fi
else
  echo '{"skipped":"sem conversa real para atribuicao"}' > "${DOMAIN_ASSIGNMENT_PATCH_LOG}"
  echo '{"skipped":"sem conversa real para historico"}' > "${DOMAIN_ASSIGNMENT_HISTORY_LOG}"
fi

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_INBOX_PAGE_URL}" || true)"

if [ "${DOMAIN_INBOX_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina inbox nao respondeu 200."
  exit 1
fi

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: dashboard nao respondeu 200."
  exit 1
fi

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: auditoria nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 59..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Responsible Assignment

## Visao geral

Este documento registra a atribuicao de responsavel e nome do atendente.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela conversation assignment history
- endpoint para atribuir responsavel a uma conversa
- endpoint para consultar historico de atribuicoes
- persistencia do nome do atendente atual
- persistencia do responsavel atual na conversa
- registro de historico de atribuicao
- card visual de atribuicao na central app inbox
- botao salvar responsavel
- botao assumir atendimento

## Endpoints criados

Endpoints:

- PATCH api v1 attendance conversations conversation id assignee
- GET api v1 attendance conversations conversation id assignments

## Tabela criada

Tabela:

- conversation assignment history

Campos:

- id
- tenant id
- conversation id
- assigned user id
- assigned user name
- department name
- action
- created at

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance/attendance.types.ts
- apps/backend/src/modules/attendance/attendance.service.ts
- apps/backend/src/modules/attendance/attendance.controller.ts
- apps/frontend/src/types/attendance.types.ts
- apps/frontend/src/services/attendance.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela conversation assignment history
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint attendance conversations dominio
- patch de atribuicao quando ha conversa real
- historico de atribuicao quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_59_backend_typecheck.log
- logs/setup_59_backend_build.log
- logs/setup_59_frontend_typecheck.log
- logs/setup_59_frontend_build.log
- logs/setup_59_backend_docker_build.log
- logs/setup_59_frontend_docker_build.log
- logs/setup_59_docker_up.log
- logs/setup_59_backend_wait.log
- logs/setup_59_auth_login_domain.log
- logs/setup_59_attendance_conversations_domain.log
- logs/setup_59_assignment_patch_domain.log
- logs/setup_59_assignment_history_domain.log
- logs/setup_59_domain_inbox_page.log
- logs/setup_59_domain_dashboard.log
- logs/setup_59_domain_audit_page.log
- logs/setup_59.log

## Proxima etapa sugerida

Etapa 60:

    Criar respostas rapidas por departamento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 59 - Criar atribuicao de responsavel e nome do atendente",
    "- [x] Etapa 59 - Criar atribuicao de responsavel e nome do atendente\n- [ ] Etapa 60 - Criar respostas rapidas por departamento"
)

text = text.replace(
    "Etapa 59 - Criar atribuicao de responsavel e nome do atendente.",
    "Etapa 60 - Criar respostas rapidas por departamento."
)

text = text.replace(
    "Etapa 58 - Criar departamentos e filas de atendimento.",
    "Etapa 59 - Criar atribuicao de responsavel e nome do atendente."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Atribuicao de responsavel e nome do atendente criada." not in text:
    text = text.replace(
        "Departamentos e filas de atendimento criados.",
        "Departamentos e filas de atendimento criados.\n\nAtribuicao de responsavel e nome do atendente criada."
    )

if "- docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_DEPARTMENTS_QUEUES.md",
        "- docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md\n- docs/ATTENDANCE_DEPARTMENTS_QUEUES.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 58 concluidas",
    "- Etapa 01 ate Etapa 59 concluidas"
)

text = text.replace(
    "- Etapa 59 - Criar atribuicao de responsavel e nome do atendente",
    "- Etapa 60 - Criar respostas rapidas por departamento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 59 - Criar atribuicao de responsavel e nome do atendente
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada atribuicao de responsavel por conversa, historico de atribuicoes e card visual na central app inbox para salvar responsavel ou assumir atendimento.
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
Etapa: 59
Acao: Criar atribuicao de responsavel e nome do atendente
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Assignment patch status: ${DOMAIN_ASSIGNMENT_PATCH_STATUS}
Assignment history status: ${DOMAIN_ASSIGNMENT_HISTORY_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 59 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 60 - Criar respostas rapidas por departamento"
