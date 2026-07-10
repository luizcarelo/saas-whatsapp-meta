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

LOG_FILE="${LOGS_DIR}/setup_60.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_60_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_60_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_60_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_60_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_60_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_60_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_60_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_60_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_60_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_60_auth_login_domain.log"
DOMAIN_QUICK_REPLIES_LOG="${LOGS_DIR}/setup_60_quick_replies_domain.log"
DOMAIN_QUICK_REPLY_CREATE_LOG="${LOGS_DIR}/setup_60_quick_reply_create_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_60_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_60_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_60_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_QUICK_REPLIES.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 60: Respostas rapidas por departamento =="

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

echo "Criando tabela e seed de respostas rapidas..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists attendance_quick_replies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  department_name text not null default 'Fila geral',
  title text not null,
  message text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_attendance_quick_replies_tenant
on attendance_quick_replies (tenant_id);

create index if not exists idx_attendance_quick_replies_department
on attendance_quick_replies (tenant_id, department_name);

insert into attendance_quick_replies (
  tenant_id,
  department_name,
  title,
  message,
  is_active,
  sort_order
)
values
  (
    '00000000-0000-0000-0000-000000000001',
    'Fila geral',
    'Saudacao inicial',
    'Ola. Como posso ajudar?',
    true,
    1
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Fila geral',
    'Pedido de dados',
    'Pode me informar seu nome completo e o melhor telefone para contato?',
    true,
    2
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Comercial',
    'Solicitar interesse',
    'Perfeito. Pode me informar qual produto ou servico voce deseja contratar?',
    true,
    3
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Suporte',
    'Solicitar detalhes',
    'Pode me enviar mais detalhes do problema e, se possivel, um print da tela?',
    true,
    4
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Financeiro',
    'Comprovante',
    'Pode me enviar o comprovante para localizarmos o pagamento?',
    true,
    5
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Fila geral',
    'Encerramento com avaliacao',
    'Atendimento finalizado. Como voce avalia nosso atendimento de 1 a 5?',
    true,
    6
  )
on conflict do nothing;
SQL

echo "Atualizando types backend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/attendance/attendance.types.ts")
text = path.read_text()

if "AttendanceQuickReplyItem" not in text:
    text += """

export type AttendanceQuickReplyItem = {
  id: string;
  departmentName: string;
  title: string;
  message: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceQuickRepliesResponse = {
  success: true;
  data: {
    quickReplies: AttendanceQuickReplyItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceQuickReplyPayload = {
  departmentName?: string;
  title?: string;
  message?: string;
  isActive?: boolean;
  sortOrder?: number;
};

export type AttendanceQuickReplyResponse = {
  success: true;
  data: {
    quickReply: AttendanceQuickReplyItem;
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

if "AttendanceQuickRepliesResponse" not in text:
    text = text.replace(
        "AttendanceDepartmentResponse,",
        "AttendanceDepartmentResponse,\n  AttendanceQuickRepliesResponse,\n  AttendanceQuickReplyPayload,\n  AttendanceQuickReplyResponse,"
    )

if "type QuickReplyRow" not in text:
    marker = "type AssignmentHistoryRow = {"
    if marker not in text:
        marker = "type DepartmentRow = {"
    insert = """type QuickReplyRow = {
  id: string;
  department_name: string;
  title: string;
  message: string;
  is_active: boolean;
  sort_order: number;
  created_at: Date;
  updated_at: Date;
};

"""
    text = text.replace(marker, insert + marker)

if "async listQuickReplies(" not in text:
    marker = "  getStatusOptions(): AttendanceStatusOptionsResponse {"
    method = """  async listQuickReplies(
    tenantId: string,
    departmentName?: string
  ): Promise<AttendanceQuickRepliesResponse> {
    await this.ensureDefaultQuickReplies(tenantId);

    const rows = departmentName
      ? await this.prismaService.$queryRawUnsafe<QuickReplyRow[]>(
          'select id, department_name, title, message, is_active, sort_order, created_at, updated_at from attendance_quick_replies where tenant_id = $1::uuid and is_active = true and (department_name = $2 or department_name = $3) order by sort_order asc, title asc',
          tenantId,
          departmentName,
          'Fila geral'
        )
      : await this.prismaService.$queryRawUnsafe<QuickReplyRow[]>(
          'select id, department_name, title, message, is_active, sort_order, created_at, updated_at from attendance_quick_replies where tenant_id = $1::uuid and is_active = true order by sort_order asc, title asc',
          tenantId
        );

    return {
      success: true,
      data: {
        quickReplies: rows.map((row) => this.mapQuickReply(row))
      },
      meta: {}
    };
  }

  async createQuickReply(
    tenantId: string,
    payload: AttendanceQuickReplyPayload
  ): Promise<AttendanceQuickReplyResponse> {
    const departmentName = payload.departmentName || 'Fila geral';
    const title = this.normalizeRequiredText(payload.title, 'Titulo da resposta rapida');
    const message = this.normalizeRequiredText(payload.message, 'Mensagem da resposta rapida');
    const sortOrder = typeof payload.sortOrder === 'number' ? payload.sortOrder : 50;

    await this.ensureDepartmentByName(tenantId, departmentName);

    const rows = await this.prismaService.$queryRawUnsafe<QuickReplyRow[]>(
      'insert into attendance_quick_replies (tenant_id, department_name, title, message, is_active, sort_order, created_at, updated_at) values ($1::uuid, $2, $3, $4, true, $5, now(), now()) returning id, department_name, title, message, is_active, sort_order, created_at, updated_at',
      tenantId,
      departmentName,
      title,
      message,
      sortOrder
    );

    return {
      success: true,
      data: {
        quickReply: this.mapQuickReply(rows[0])
      },
      meta: {}
    };
  }

  async updateQuickReply(
    tenantId: string,
    quickReplyId: string,
    payload: AttendanceQuickReplyPayload
  ): Promise<AttendanceQuickReplyResponse> {
    const currentRows = await this.prismaService.$queryRawUnsafe<QuickReplyRow[]>(
      'select id, department_name, title, message, is_active, sort_order, created_at, updated_at from attendance_quick_replies where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      quickReplyId
    );

    const current = currentRows[0];

    if (!current) {
      throw new BadRequestException('Resposta rapida nao encontrada');
    }

    const departmentName = payload.departmentName || current.department_name;
    const title = payload.title ? this.normalizeRequiredText(payload.title, 'Titulo da resposta rapida') : current.title;
    const message = payload.message ? this.normalizeRequiredText(payload.message, 'Mensagem da resposta rapida') : current.message;
    const isActive = typeof payload.isActive === 'boolean' ? payload.isActive : current.is_active;
    const sortOrder = typeof payload.sortOrder === 'number' ? payload.sortOrder : current.sort_order;

    await this.ensureDepartmentByName(tenantId, departmentName);

    const rows = await this.prismaService.$queryRawUnsafe<QuickReplyRow[]>(
      'update attendance_quick_replies set department_name = $3, title = $4, message = $5, is_active = $6, sort_order = $7, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, department_name, title, message, is_active, sort_order, created_at, updated_at',
      tenantId,
      quickReplyId,
      departmentName,
      title,
      message,
      isActive,
      sortOrder
    );

    return {
      success: true,
      data: {
        quickReply: this.mapQuickReply(rows[0])
      },
      meta: {}
    };
  }

"""
    text = text.replace(marker, method + marker)

if "private async ensureDefaultQuickReplies" not in text:
    marker = "  private async ensureDefaultDepartments"
    method = """  private async ensureDefaultQuickReplies(tenantId: string) {
    const defaults = [
      ['Fila geral', 'Saudacao inicial', 'Ola. Como posso ajudar?', 1],
      ['Fila geral', 'Pedido de dados', 'Pode me informar seu nome completo e o melhor telefone para contato?', 2],
      ['Comercial', 'Solicitar interesse', 'Perfeito. Pode me informar qual produto ou servico voce deseja contratar?', 3],
      ['Suporte', 'Solicitar detalhes', 'Pode me enviar mais detalhes do problema e, se possivel, um print da tela?', 4],
      ['Financeiro', 'Comprovante', 'Pode me enviar o comprovante para localizarmos o pagamento?', 5],
      ['Fila geral', 'Encerramento com avaliacao', 'Atendimento finalizado. Como voce avalia nosso atendimento de 1 a 5?', 6]
    ];

    for (const item of defaults) {
      await this.prismaService.$executeRawUnsafe(
        'insert into attendance_quick_replies (tenant_id, department_name, title, message, is_active, sort_order, created_at, updated_at) select $1::uuid, $2, $3, $4, true, $5, now(), now() where not exists (select 1 from attendance_quick_replies where tenant_id = $1::uuid and department_name = $2 and title = $3)',
        tenantId,
        item[0],
        item[1],
        item[2],
        item[3]
      );
    }
  }

"""
    text = text.replace(marker, method + marker)

if "private mapQuickReply" not in text:
    marker = "  private mapDepartment(row: DepartmentRow): AttendanceDepartmentItem {"
    method = """  private mapQuickReply(row: QuickReplyRow) {
    return {
      id: row.id,
      departmentName: row.department_name,
      title: row.title,
      message: row.message,
      isActive: row.is_active,
      sortOrder: row.sort_order,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }

"""
    text = text.replace(marker, method + marker)

if "private normalizeRequiredText" not in text:
    marker = "  private normalizeDepartmentName(value?: string): string {"
    method = """  private normalizeRequiredText(value: string | undefined, label: string): string {
    const textValue = (value || '').trim();

    if (!textValue) {
      throw new BadRequestException(label + ' e obrigatorio');
    }

    if (textValue.length > 1000) {
      throw new BadRequestException(label + ' muito longo');
    }

    return textValue;
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

if "Query" not in text.split("} from '@nestjs/common';")text = text.replace("  Post,", "  Post,\n  Query,")

if "AttendanceQuickReplyPayload" not in text:
    text = text.replace(
        "AttendanceDepartmentPayload,",
        "AttendanceDepartmentPayload,\n  AttendanceQuickReplyPayload,"
    )

if "@Get('quick-replies')" not in text:
    marker = "  @Get('departments')"
    insert = """  @Get('quick-replies')
  listQuickReplies(
    @CurrentUser() user: AuthenticatedUser,
    @Query('departmentName') departmentName?: string
  ) {
    return this.attendanceService.listQuickReplies(user.tenantId, departmentName);
  }

  @Post('quick-replies')
  createQuickReply(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: AttendanceQuickReplyPayload
  ) {
    return this.attendanceService.createQuickReply(user.tenantId, body);
  }

  @Patch('quick-replies/:quickReplyId')
  updateQuickReply(
    @CurrentUser() user: AuthenticatedUser,
    @Param('quickReplyId') quickReplyId: string,
    @Body() body: AttendanceQuickReplyPayload
  ) {
    return this.attendanceService.updateQuickReply(user.tenantId, quickReplyId, body);
  }

"""
    text = text.replace(marker, insert + marker)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance"
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

if "AttendanceQuickReplyItem" not in text:
    text += """

export type AttendanceQuickReplyItem = {
  id: string;
  departmentName: string;
  title: string;
  message: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceQuickRepliesData = {
  quickReplies: AttendanceQuickReplyItem[];
};

export type AttendanceQuickReplyData = {
  quickReply: AttendanceQuickReplyItem;
};
"""

path.write_text(text)
PY

echo "Atualizando service frontend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/services/attendance.service.ts")
text = path.read_text()

if "AttendanceQuickRepliesData" not in text:
    text = text.replace(
        "AttendanceDepartmentsData,",
        "AttendanceDepartmentsData,\n  AttendanceQuickRepliesData,\n  AttendanceQuickReplyData,"
    )

if "listAttendanceQuickRepliesRequest" not in text:
    text += """

export async function listAttendanceQuickRepliesRequest(
  token: string,
  departmentName?: string
) {
  const suffix = departmentName ? '?departmentName=' + encodeURIComponent(departmentName) : '';

  return apiRequest<AttendanceQuickRepliesData>('/attendance/quick-replies' + suffix, {
    method: 'GET',
    token
  });
}

export async function createAttendanceQuickReplyRequest(
  token: string,
  payload: {
    departmentName: string;
    title: string;
    message: string;
    sortOrder?: number;
  }
) {
  return apiRequest<AttendanceQuickReplyData>('/attendance/quick-replies', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function updateAttendanceQuickReplyRequest(
  token: string,
  quickReplyId: string,
  payload: {
    departmentName?: string;
    title?: string;
    message?: string;
    isActive?: boolean;
    sortOrder?: number;
  }
) {
  return apiRequest<AttendanceQuickReplyData>('/attendance/quick-replies/' + quickReplyId, {
    method: 'PATCH',
    token,
    body: payload
  });
}
"""

path.write_text(text)
PY

echo "Atualizando InboxPage.tsx com respostas rapidas reais..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "createAttendanceQuickReplyRequest" not in text:
    text = text.replace(
        "createAttendanceDepartmentRequest,",
        "createAttendanceDepartmentRequest,\n  createAttendanceQuickReplyRequest,\n  listAttendanceQuickRepliesRequest,"
    )

if "AttendanceQuickReplyItem" not in text:
    text = text.replace(
        "AttendanceDepartmentItem",
        "AttendanceDepartmentItem,\n  AttendanceQuickReplyItem"
    )

if "const [composerText" not in text:
    text = text.replace(
        "const [notice, setNotice] = useState('');",
        "const [notice, setNotice] = useState('');\n  const [composerText, setComposerText] = useState('');\n  const [quickReplies, setQuickReplies] = useState<AttendanceQuickReplyItem[]>([]);\n  const [newQuickReplyTitle, setNewQuickReplyTitle] = useState('');\n  const [newQuickReplyMessage, setNewQuickReplyMessage] = useState('');"
    )

if "listAttendanceQuickRepliesRequest(token" not in text:
    text = text.replace(
        "listAttendanceDepartmentsRequest(token)\n    ]);",
        "listAttendanceDepartmentsRequest(token),\n      listAttendanceQuickRepliesRequest(token)\n    ]);"
    )
    text = text.replace(
        "const [listResponse, optionsResponse, departmentsResponse] = await Promise.all([",
        "const [listResponse, optionsResponse, departmentsResponse, quickRepliesResponse] = await Promise.all(["
    )
    text = text.replace(
        "if (departmentsResponse.success && departmentsResponse.data.departments.length > 0) {",
        "if (quickRepliesResponse.success) {\n      setQuickReplies(quickRepliesResponse.data.quickReplies);\n    }\n\n    if (departmentsResponse.success && departmentsResponse.data.departments.length > 0) {"
    )

if "async function handleCreateQuickReply" not in text:
    marker = "  async function handleCreateDepartment(event: FormEvent<HTMLFormElement>) {"
    method = """  async function handleCreateQuickReply(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !newQuickReplyTitle.trim() || !newQuickReplyMessage.trim()) {
      return;
    }

    const response = await createAttendanceQuickReplyRequest(token, {
      departmentName: selectedConversation.departmentName,
      title: newQuickReplyTitle.trim(),
      message: newQuickReplyMessage.trim(),
      sortOrder: quickReplies.length + 1
    });

    if (response.success) {
      setNewQuickReplyTitle('');
      setNewQuickReplyMessage('');
      const listResponse = await listAttendanceQuickRepliesRequest(token);
      if (listResponse.success) {
        setQuickReplies(listResponse.data.quickReplies);
      }
      setNotice('Resposta rapida criada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel criar resposta rapida.');
    }
  }

"""
    text = text.replace(marker, method + marker)

if "const visibleQuickReplies" not in text:
    marker = "  const visibleConversations = useMemo(() => {"
    helper = """  const visibleQuickReplies = useMemo(() => {
    const departmentReplies = quickReplies.filter((item) => item.departmentName === selectedConversation.departmentName);
    const generalReplies = quickReplies.filter((item) => item.departmentName === 'Fila geral');

    return [...departmentReplies, ...generalReplies].filter((item, index, array) => {
      return array.findIndex((candidate) => candidate.id === item.id) === index;
    });
  }, [quickReplies, selectedConversation.departmentName]);

"""
    text = text.replace(marker, helper + marker)

text = text.replace(
    "{quickReplies.map((reply) => (\n              <button key={reply} type=\"button\">\n                {reply}\n              </button>\n            ))}",
    "{visibleQuickReplies.length ? visibleQuickReplies.map((reply) => (\n              <button key={reply.id} onClick={() => setComposerText(reply.message)} type=\"button\">\n                {reply.title}\n              </button>\n            )) : quickReplies.map((reply) => (\n              <button key={reply} onClick={() => setComposerText(reply)} type=\"button\">\n                {reply}\n              </button>\n            ))}"
)

text = text.replace(
    "<textarea placeholder=\"Digite uma mensagem para o cliente\" />",
    "<textarea onChange={(event) => setComposerText(event.target.value)} placeholder=\"Digite uma mensagem para o cliente\" value={composerText} />"
)

if "className=\"quick-reply-manager\"" not in text:
    marker = """          <section className="inbox-quick-replies">
            {visibleQuickReplies.length ? visibleQuickReplies.map((reply) => (
              <button key={reply.id} onClick={() => setComposerText(reply.message)} type="button">
                {reply.title}
              </button>
            )) : quickReplies.map((reply) => (
              <button key={reply} onClick={() => setComposerText(reply)} type="button">
                {reply}
              </button>
            ))}
          </section>"""
    addition = marker + """

          <form className="quick-reply-manager" onSubmit={handleCreateQuickReply}>
            <strong>Nova resposta rapida para {selectedConversation.departmentName}</strong>
            <input
              onChange={(event) => setNewQuickReplyTitle(event.target.value)}
              placeholder="Titulo"
              value={newQuickReplyTitle}
            />
            <textarea
              onChange={(event) => setNewQuickReplyMessage(event.target.value)}
              placeholder="Mensagem da resposta rapida"
              value={newQuickReplyMessage}
            />
            <button type="submit">Salvar resposta rapida</button>
          </form>"""
    text = text.replace(marker, addition)

path.write_text(text)
PY

echo "Adicionando CSS das respostas rapidas..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 60 - Respostas rapidas por departamento */

.quick-reply-manager {
  background: #f8fafc;
  border-top: 1px solid #e5e7eb;
  display: grid;
  gap: 10px;
  padding: 14px 16px;
}

.quick-reply-manager strong {
  color: var(--lh-blue-950, #04204f);
}

.quick-reply-manager input,
.quick-reply-manager textarea {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 11px 13px;
  width: 100%;
}

.quick-reply-manager textarea {
  min-height: 70px;
  resize: vertical;
}

.quick-reply-manager button {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-700, #0a6de8));
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 11px 13px;
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

DOMAIN_QUICK_REPLIES_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies?departmentName=Comercial" || true)"

if [ "${DOMAIN_QUICK_REPLIES_STATUS}" != "200" ]; then
  echo "ERRO: quick replies falhou. Status ${DOMAIN_QUICK_REPLIES_STATUS}"
  cat "${DOMAIN_QUICK_REPLIES_LOG}"
  exit 1
fi

if ! grep -q "quickReplies" "${DOMAIN_QUICK_REPLIES_LOG}"; then
  echo "ERRO: quick replies nao retornou lista esperada."
  cat "${DOMAIN_QUICK_REPLIES_LOG}"
  exit 1
fi

CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({departmentName:'Comercial', title:'Validacao Etapa 60', message:'Resposta rapida criada na validacao da Etapa 60.', sortOrder:99}))")"

DOMAIN_QUICK_REPLY_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLY_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CREATE_PAYLOAD}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies" || true)"

if [ "${DOMAIN_QUICK_REPLY_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_QUICK_REPLY_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: create quick reply falhou. Status ${DOMAIN_QUICK_REPLY_CREATE_STATUS}"
  cat "${DOMAIN_QUICK_REPLY_CREATE_LOG}"
  exit 1
fi

if ! grep -q "Validacao Etapa 60" "${DOMAIN_QUICK_REPLY_CREATE_LOG}"; then
  echo "ERRO: create quick reply nao retornou titulo esperado."
  cat "${DOMAIN_QUICK_REPLY_CREATE_LOG}"
  exit 1
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

echo "Gerando documentacao da Etapa 60..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Quick Replies

## Visao geral

Este documento registra a criacao de respostas rapidas por departamento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela attendance quick replies
- respostas rapidas por tenant
- respostas rapidas por departamento
- seed inicial de respostas
- endpoint para listar respostas rapidas
- endpoint para criar resposta rapida
- endpoint para atualizar resposta rapida
- integracao da central app inbox com respostas rapidas reais
- botao para aplicar resposta rapida ao campo de mensagem
- formulario visual para criar nova resposta rapida por departamento

## Respostas iniciais

Respostas:

- Saudacao inicial
- Pedido de dados
- Solicitar interesse
- Solicitar detalhes
- Comprovante
- Encerramento com avaliacao

## Endpoints criados

Endpoints:

- GET api v1 attendance quick replies
- POST api v1 attendance quick replies
- PATCH api v1 attendance quick replies quick reply id

## Tabela criada

Tabela:

- attendance quick replies

Campos:

- id
- tenant id
- department name
- title
- message
- is active
- sort order
- created at
- updated at

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance/attendance.types.ts
- apps/backend/src/modules/attendance/attendance.service.ts
- apps/backend/src/modules/attendance/attendance.controller.ts
- apps/frontend/src/types/attendance.types.ts
- apps/frontend/src/services/attendance.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_QUICK_REPLIES.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela attendance quick replies
- seed das respostas iniciais
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint quick replies dominio
- criacao de resposta rapida dominio
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_60_backend_typecheck.log
- logs/setup_60_backend_build.log
- logs/setup_60_frontend_typecheck.log
- logs/setup_60_frontend_build.log
- logs/setup_60_backend_docker_build.log
- logs/setup_60_frontend_docker_build.log
- logs/setup_60_docker_up.log
- logs/setup_60_backend_wait.log
- logs/setup_60_auth_login_domain.log
- logs/setup_60_quick_replies_domain.log
- logs/setup_60_quick_reply_create_domain.log
- logs/setup_60_domain_inbox_page.log
- logs/setup_60_domain_dashboard.log
- logs/setup_60_domain_audit_page.log
- logs/setup_60.log

## Proxima etapa sugerida

Etapa 61:

    Criar notas internas e tags
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 60 - Criar respostas rapidas por departamento",
    "- [x] Etapa 60 - Criar respostas rapidas por departamento\n- [ ] Etapa 61 - Criar notas internas e tags"
)

text = text.replace(
    "Etapa 60 - Criar respostas rapidas por departamento.",
    "Etapa 61 - Criar notas internas e tags."
)

text = text.replace(
    "Etapa 59 - Criar atribuicao de responsavel e nome do atendente.",
    "Etapa 60 - Criar respostas rapidas por departamento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Respostas rapidas por departamento criadas." not in text:
    text = text.replace(
        "Atribuicao de responsavel e nome do atendente criada.",
        "Atribuicao de responsavel e nome do atendente criada.\n\nRespostas rapidas por departamento criadas."
    )

if "- docs/ATTENDANCE_QUICK_REPLIES.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md",
        "- docs/ATTENDANCE_QUICK_REPLIES.md\n- docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 59 concluidas",
    "- Etapa 01 ate Etapa 60 concluidas"
)

text = text.replace(
    "- Etapa 60 - Criar respostas rapidas por departamento",
    "- Etapa 61 - Criar notas internas e tags"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 60 - Criar respostas rapidas por departamento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada persistencia de respostas rapidas por departamento, endpoints de listagem e criacao, e integracao da central app inbox com aplicacao da resposta no campo de mensagem.
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
Etapa: 60
Acao: Criar respostas rapidas por departamento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Quick replies status: ${DOMAIN_QUICK_REPLIES_STATUS}
Quick reply create status: ${DOMAIN_QUICK_REPLY_CREATE_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 60 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 61 - Criar notas internas e tags"
