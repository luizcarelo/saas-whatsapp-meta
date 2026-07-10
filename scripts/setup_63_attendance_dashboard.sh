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

LOG_FILE="${LOGS_DIR}/setup_63.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_63_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_63_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_63_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_63_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_63_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_63_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_63_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_63_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_63_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_63_auth_login_domain.log"
DOMAIN_DASHBOARD_API_LOG="${LOGS_DIR}/setup_63_attendance_dashboard_api_domain.log"
DOMAIN_ATTENDANCE_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_63_domain_attendance_dashboard_page.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_63_domain_inbox_page.log"
DOMAIN_DASHBOARD_PAGE_LOG="${LOGS_DIR}/setup_63_domain_dashboard_page.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_63_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_DASHBOARD.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_DASHBOARD_API_URL="${DOMAIN_BASE_URL}/api/v1/attendance-dashboard/summary"
DOMAIN_ATTENDANCE_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_PAGE_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 63: Dashboard de atendimento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/attendance-dashboard"
mkdir -p "${FRONTEND_DIR}/src/pages/attendance-dashboard"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Validando conclusao da Etapa 62..."

if [ ! -f "${LOGS_DIR}/setup_62.log" ]; then
  echo "ERRO: setup_62.log nao encontrado. Conclua a Etapa 62 antes da Etapa 63."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_62.log"; then
  echo "ERRO: Etapa 62 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_62.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-dashboard/attendance-dashboard.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-dashboard/attendance-dashboard.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance-dashboard/attendance-dashboard.controller.ts" \
  "${BACKEND_DIR}/src/modules/attendance-dashboard/attendance-dashboard.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${FRONTEND_DIR}/src/types/attendance-dashboard.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance-dashboard.service.ts" \
  "${FRONTEND_DIR}/src/pages/attendance-dashboard/AttendanceDashboardPage.tsx" \
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

echo "Criando types backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-dashboard/attendance-dashboard.types.ts" <<'DOC'
export type AttendanceDashboardDepartmentMetric = {
  name: string;
  color: string;
  total: number;
  open: number;
  closed: number;
};

export type AttendanceDashboardSummary = {
  conversations: {
    total: number;
    open: number;
    closed: number;
    unassigned: number;
    highPriority: number;
  };
  departments: AttendanceDashboardDepartmentMetric[];
  ratings: {
    total: number;
    average: number;
  };
  activity: {
    notes: number;
    tags: number;
    quickReplies: number;
    closures: number;
  };
};

export type AttendanceDashboardSummaryResponse = {
  success: true;
  data: AttendanceDashboardSummary;
  meta: Record<string, never>;
};
DOC

echo "Criando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-dashboard/attendance-dashboard.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceDashboardDepartmentMetric,
  AttendanceDashboardSummaryResponse
} from './attendance-dashboard.types';

type StatusRow = {
  conversation_id: string;
  status: string;
  priority: string;
  department_name: string;
  assigned_user_name: string | null;
};

type DepartmentRow = {
  name: string;
  color: string;
};

type CountRow = {
  total: bigint | number | null;
};

type RatingRow = {
  total: bigint | number | null;
  average: number | string | null;
};

@Injectable()
export class AttendanceDashboardService {
  constructor(private readonly prismaService: PrismaService) {}

  async getSummary(tenantId: string): Promise<AttendanceDashboardSummaryResponse> {
    const conversations = await this.prismaService.conversation.findMany({
      where: {
        tenantId,
        deletedAt: null
      },
      select: {
        id: true
      },
      take: 1000
    });

    const conversationIds = conversations.map((conversation) => conversation.id);

    const statusRows = conversationIds.length > 0
      ? await this.prismaService.$queryRawUnsafe<StatusRow[]>(
          'select conversation_id, status, priority, department_name, assigned_user_name from conversation_operational_status where tenant_id = $1::uuid and conversation_id = any($2::uuid[])',
          tenantId,
          conversationIds
        )
      : [];

    const statusByConversation = new Map<string, StatusRow>();

    for (const row of statusRows) {
      statusByConversation.set(row.conversation_id, row);
    }

    const departments = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select name, color from attendance_departments where tenant_id = $1::uuid and is_active = true order by sort_order asc, name asc',
      tenantId
    );

    const departmentMetrics = new Map<string, AttendanceDashboardDepartmentMetric>();

    for (const department of departments) {
      departmentMetrics.set(department.name, {
        name: department.name,
        color: department.color,
        total: 0,
        open: 0,
        closed: 0
      });
    }

    let open = 0;
    let closed = 0;
    let unassigned = 0;
    let highPriority = 0;

    for (const conversation of conversations) {
      const statusRow = statusByConversation.get(conversation.id);
      const status = statusRow?.status || 'novo';
      const priority = statusRow?.priority || 'normal';
      const departmentName = statusRow?.department_name || 'Fila geral';
      const assignedUserName = statusRow?.assigned_user_name || null;

      if (status === 'encerrado' || status === 'arquivado') {
        closed += 1;
      } else {
        open += 1;
      }

      if (!assignedUserName) {
        unassigned += 1;
      }

      if (priority === 'alta' || priority === 'urgente') {
        highPriority += 1;
      }

      if (!departmentMetrics.has(departmentName)) {
        departmentMetrics.set(departmentName, {
          name: departmentName,
          color: '#0757c8',
          total: 0,
          open: 0,
          closed: 0
        });
      }

      const metric = departmentMetrics.get(departmentName);

      if (metric) {
        metric.total += 1;

        if (status === 'encerrado' || status === 'arquivado') {
          metric.closed += 1;
        } else {
          metric.open += 1;
        }
      }
    }

    const ratings = await this.prismaService.$queryRawUnsafe<RatingRow[]>(
      'select count(*) as total, coalesce(avg(rating), 0) as average from attendance_conversation_ratings where tenant_id = $1::uuid',
      tenantId
    );

    const notes = await this.countTable('attendance_conversation_notes', tenantId);
    const tags = await this.countTable('attendance_conversation_tags', tenantId);
    const quickReplies = await this.countTable('attendance_quick_replies', tenantId);
    const closures = await this.countTable('attendance_conversation_closures', tenantId);

    const ratingRow = ratings[0];

    return {
      success: true,
      data: {
        conversations: {
          total: conversations.length,
          open,
          closed,
          unassigned,
          highPriority
        },
        departments: Array.from(departmentMetrics.values()),
        ratings: {
          total: this.toNumber(ratingRow?.total),
          average: Number(Number(ratingRow?.average || 0).toFixed(2))
        },
        activity: {
          notes,
          tags,
          quickReplies,
          closures
        }
      },
      meta: {}
    };
  }

  private async countTable(tableName: string, tenantId: string): Promise<number> {
    const rows = await this.prismaService.$queryRawUnsafe<CountRow[]>(
      'select count(*) as total from ' + tableName + ' where tenant_id = $1::uuid',
      tenantId
    );

    return this.toNumber(rows[0]?.total);
  }

  private toNumber(value: bigint | number | null | undefined): number {
    if (typeof value === 'bigint') {
      return Number(value);
    }

    if (typeof value === 'number') {
      return value;
    }

    return 0;
  }
}
DOC

echo "Criando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-dashboard/attendance-dashboard.controller.ts" <<'DOC'
import {
  Controller,
  Get,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceDashboardService } from './attendance-dashboard.service';

@Controller('attendance-dashboard')
@UseGuards(JwtAuthGuard)
export class AttendanceDashboardController {
  constructor(private readonly dashboardService: AttendanceDashboardService) {}

  @Get('summary')
  getSummary(@CurrentUser() user: AuthenticatedUser) {
    return this.dashboardService.getSummary(user.tenantId);
  }
}
DOC

echo "Criando modulo backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-dashboard/attendance-dashboard.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceDashboardController } from './attendance-dashboard.controller';
import { AttendanceDashboardService } from './attendance-dashboard.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceDashboardController
  ],
  providers: [
    AttendanceDashboardService
  ]
})
export class AttendanceDashboardModule {}
DOC

echo "Atualizando app.module.ts..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()
import_line = "import { AttendanceDashboardModule } from './modules/attendance-dashboard/attendance-dashboard.module';"

if import_line not in text:
    lines = text.splitlines()
    last_import = -1

    for index, line in enumerate(lines):
        if line.startswith("import "):
            last_import = index

    if last_import < 0:
        raise SystemExit("Nao foi possivel localizar imports")

    lines.insert(last_import + 1, import_line)
    text = "\n".join(lines) + "\n"

match = re.search(r"imports:\s*\[([\s\S]*?)\]", text)

if not match:
    raise SystemExit("Nao foi possivel localizar imports array")

if "AttendanceDashboardModule" not in match.group(1):
    text = re.sub(r"imports:\s*\[", "imports: [\n    AttendanceDashboardModule,", text, count=1)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance-dashboard" \
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

echo "Criando types frontend..."

cat > "${FRONTEND_DIR}/src/types/attendance-dashboard.types.ts" <<'DOC'
export type AttendanceDashboardDepartmentMetric = {
  name: string;
  color: string;
  total: number;
  open: number;
  closed: number;
};

export type AttendanceDashboardSummary = {
  conversations: {
    total: number;
    open: number;
    closed: number;
    unassigned: number;
    highPriority: number;
  };
  departments: AttendanceDashboardDepartmentMetric[];
  ratings: {
    total: number;
    average: number;
  };
  activity: {
    notes: number;
    tags: number;
    quickReplies: number;
    closures: number;
  };
};
DOC

echo "Criando service frontend..."

cat > "${FRONTEND_DIR}/src/services/attendance-dashboard.service.ts" <<'DOC'
import { apiRequest } from './api';
import type { AttendanceDashboardSummary } from '../types/attendance-dashboard.types';

export async function getAttendanceDashboardSummaryRequest(token: string) {
  return apiRequest<AttendanceDashboardSummary>('/attendance-dashboard/summary', {
    method: 'GET',
    token
  });
}
DOC

echo "Criando pagina frontend..."

cat > "${FRONTEND_DIR}/src/pages/attendance-dashboard/AttendanceDashboardPage.tsx" <<'DOC'
import { useEffect, useState } from 'react';
import { getAttendanceDashboardSummaryRequest } from '../../services/attendance-dashboard.service';
import { useAuthStore } from '../../stores/auth.store';
import type { AttendanceDashboardSummary } from '../../types/attendance-dashboard.types';

const emptySummary: AttendanceDashboardSummary = {
  conversations: {
    total: 0,
    open: 0,
    closed: 0,
    unassigned: 0,
    highPriority: 0
  },
  departments: [],
  ratings: {
    total: 0,
    average: 0
  },
  activity: {
    notes: 0,
    tags: 0,
    quickReplies: 0,
    closures: 0
  }
};

export function AttendanceDashboardPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [summary, setSummary] = useState<AttendanceDashboardSummary>(emptySummary);
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(true);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadDashboard() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const response = await getAttendanceDashboardSummaryRequest(token);

    if (response.success) {
      setSummary(response.data);
    } else {
      setNotice(response.error.message || 'Nao foi possivel carregar dashboard de atendimento.');
    }

    setLoading(false);
  }

  useEffect(() => {
    void loadDashboard();
  }, []);

  return (
    <section className="attendance-dashboard-shell">
      <section className="inbox-hero">
        <div>
          <span>Dashboard de atendimento</span>
          <h1>Visao operacional da central</h1>
          <p>Acompanhe conversas, filas, responsaveis, avaliacoes e atividades da central de atendimento.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}
      {loading ? <div className="conversation-empty">Carregando dashboard...</div> : null}

      <section className="attendance-dashboard-grid">
        <article>
          <span>Total</span>
          <strong>{summary.conversations.total}</strong>
          <p>Conversas monitoradas</p>
        </article>

        <article>
          <span>Abertas</span>
          <strong>{summary.conversations.open}</strong>
          <p>Em atendimento ou aguardando</p>
        </article>

        <article>
          <span>Encerradas</span>
          <strong>{summary.conversations.closed}</strong>
          <p>Finalizadas ou arquivadas</p>
        </article>

        <article>
          <span>Sem responsavel</span>
          <strong>{summary.conversations.unassigned}</strong>
          <p>Precisam de atribuicao</p>
        </article>

        <article>
          <span>Alta prioridade</span>
          <strong>{summary.conversations.highPriority}</strong>
          <p>Alta ou urgente</p>
        </article>

        <article>
          <span>Avaliacao media</span>
          <strong>{summary.ratings.average}</strong>
          <p>{summary.ratings.total} avaliacoes</p>
        </article>
      </section>

      <section className="attendance-dashboard-panels">
        <article>
          <div className="inbox-panel-title">
            <strong>Filas por departamento</strong>
            <span>Volume aberto e encerrado por fila</span>
          </div>

          <div className="department-metric-list">
            {summary.departments.length ? summary.departments.map((department) => (
              <div key={department.name}>
                <span style={{ backgroundColor: department.color }} />
                <strong>{department.name}</strong>
                <em>Total {department.total}</em>
                <small>Abertas {department.open} - Encerradas {department.closed}</small>
              </div>
            )) : <p>Nenhum departamento encontrado.</p>}
          </div>
        </article>

        <article>
          <div className="inbox-panel-title">
            <strong>Atividades da central</strong>
            <span>Recursos utilizados no atendimento</span>
          </div>

          <div className="activity-metric-list">
            <div>
              <strong>{summary.activity.notes}</strong>
              <span>Notas internas</span>
            </div>

            <div>
              <strong>{summary.activity.tags}</strong>
              <span>Tags vinculadas</span>
            </div>

            <div>
              <strong>{summary.activity.quickReplies}</strong>
              <span>Respostas rapidas</span>
            </div>

            <div>
              <strong>{summary.activity.closures}</strong>
              <span>Encerramentos</span>
            </div>
          </div>
        </article>
      </section>
    </section>
  );
}
DOC

echo "Atualizando rotas..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/app/routes.tsx")
text = path.read_text()

if "AttendanceDashboardPage" not in text:
    text = text.replace(
        "import { InboxPage } from '../pages/inbox/InboxPage';",
        "import { AttendanceDashboardPage } from '../pages/attendance-dashboard/AttendanceDashboardPage';\nimport { InboxPage } from '../pages/inbox/InboxPage';"
    )

if 'path="attendance-dashboard"' not in text:
    text = text.replace(
        '<Route path="inbox" element={<InboxPage />} />',
        '<Route path="inbox" element={<InboxPage />} />\n          <Route path="attendance-dashboard" element={<AttendanceDashboardPage />} />'
    )

path.write_text(text)
PY

echo "Atualizando Sidebar..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/components/layout/Sidebar.tsx")
text = path.read_text()

if 'to="/app/attendance-dashboard"' not in text:
    text = text.replace(
        '<NavLink to="/app/inbox">Atendimento</NavLink>',
        '<NavLink to="/app/inbox">Atendimento</NavLink>\n        <NavLink to="/app/attendance-dashboard">Dashboard atendimento</NavLink>'
    )

path.write_text(text)
PY

echo "Adicionando CSS do dashboard de atendimento..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 63 - Dashboard de atendimento */

.attendance-dashboard-shell {
  display: grid;
  gap: 22px;
}

.attendance-dashboard-grid {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(6, minmax(0, 1fr));
}

.attendance-dashboard-grid article,
.attendance-dashboard-panels article {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 22px;
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  padding: 18px;
}

.attendance-dashboard-grid span {
  color: var(--lh-muted, #6b7280);
  display: block;
  font-size: 12px;
  font-weight: 950;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.attendance-dashboard-grid strong {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-size: 30px;
  margin-top: 6px;
}

.attendance-dashboard-grid p {
  color: var(--lh-muted, #6b7280);
  margin: 6px 0 0;
}

.attendance-dashboard-panels {
  display: grid;
  gap: 16px;
  grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr);
}

.department-metric-list,
.activity-metric-list {
  display: grid;
  gap: 12px;
  margin-top: 16px;
}

.department-metric-list div {
  align-items: center;
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  display: grid;
  gap: 8px;
  grid-template-columns: auto minmax(0, 1fr) auto;
  padding: 12px;
}

.department-metric-list div span {
  border-radius: 999px;
  display: block;
  height: 14px;
  width: 14px;
}

.department-metric-list div strong {
  color: var(--lh-blue-950, #04204f);
}

.department-metric-list div em {
  color: var(--lh-orange-700, #f97316);
  font-style: normal;
  font-weight: 950;
}

.department-metric-list div small {
  color: var(--lh-muted, #6b7280);
  grid-column: 2 / -1;
}

.activity-metric-list {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.activity-metric-list div {
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  padding: 16px;
}

.activity-metric-list strong {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-size: 28px;
}

.activity-metric-list span {
  color: var(--lh-muted, #6b7280);
  display: block;
  margin-top: 4px;
}

@media (max-width: 1300px) {
  .attendance-dashboard-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .attendance-dashboard-panels {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .attendance-dashboard-grid {
    grid-template-columns: 1fr;
  }

  .activity-metric-list {
    grid-template-columns: 1fr;
  }

  .department-metric-list div {
    grid-template-columns: auto minmax(0, 1fr);
  }

  .department-metric-list div em {
    grid-column: 2;
  }
}
DOC

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/attendance-dashboard/AttendanceDashboardPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-dashboard.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-dashboard.types.ts" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
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

echo "Validando dominio..."

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

DOMAIN_DASHBOARD_API_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_API_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_DASHBOARD_API_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_API_STATUS}" != "200" ]; then
  echo "ERRO: attendance dashboard API falhou. Status ${DOMAIN_DASHBOARD_API_STATUS}"
  cat "${DOMAIN_DASHBOARD_API_LOG}"
  exit 1
fi

if ! grep -q "conversations" "${DOMAIN_DASHBOARD_API_LOG}"; then
  echo "ERRO: attendance dashboard API nao retornou conversations."
  cat "${DOMAIN_DASHBOARD_API_LOG}"
  exit 1
fi

DOMAIN_ATTENDANCE_DASHBOARD_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_URL}" || true)"

if [ "${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina attendance dashboard nao respondeu 200."
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
  echo "ERRO: dashboard geral nao respondeu 200."
  exit 1
fi

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: auditoria nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 63..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Dashboard

## Visao geral

Este documento registra a criacao do dashboard de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- endpoint de resumo do dashboard de atendimento
- tela app attendance dashboard
- cards de conversas totais, abertas, encerradas, sem responsavel e alta prioridade
- media e total de avaliacoes
- metricas por departamento
- contadores de notas internas
- contadores de tags vinculadas
- contadores de respostas rapidas
- contadores de encerramentos
- link no menu lateral

## Endpoint criado

Endpoint:

- GET api v1 attendance dashboard summary

## Tela criada

Tela:

- app attendance dashboard

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-dashboard/attendance-dashboard.types.ts
- apps/backend/src/modules/attendance-dashboard/attendance-dashboard.service.ts
- apps/backend/src/modules/attendance-dashboard/attendance-dashboard.controller.ts
- apps/backend/src/modules/attendance-dashboard/attendance-dashboard.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-dashboard.types.ts
- apps/frontend/src/services/attendance-dashboard.service.ts
- apps/frontend/src/pages/attendance-dashboard/AttendanceDashboardPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_DASHBOARD.md
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
- login dominio
- endpoint attendance dashboard summary dominio
- rota app attendance dashboard
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_63_backend_typecheck.log
- logs/setup_63_backend_build.log
- logs/setup_63_frontend_typecheck.log
- logs/setup_63_frontend_build.log
- logs/setup_63_backend_docker_build.log
- logs/setup_63_frontend_docker_build.log
- logs/setup_63_docker_up.log
- logs/setup_63_backend_wait.log
- logs/setup_63_auth_login_domain.log
- logs/setup_63_attendance_dashboard_api_domain.log
- logs/setup_63_domain_attendance_dashboard_page.log
- logs/setup_63_domain_inbox_page.log
- logs/setup_63_domain_dashboard_page.log
- logs/setup_63_domain_audit_page.log
- logs/setup_63.log

## Proxima etapa sugerida

Etapa 64:

    Revisao final da fase de atendimento profissional
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 63 - Criar dashboard de atendimento",
    "- [x] Etapa 63 - Criar dashboard de atendimento\n- [ ] Etapa 64 - Revisao final da fase de atendimento profissional"
)

text = text.replace(
    "Etapa 63 - Criar dashboard de atendimento.",
    "Etapa 64 - Revisao final da fase de atendimento profissional."
)

text = text.replace(
    "Etapa 62 - Criar encerramento com avaliacao do atendimento.",
    "Etapa 63 - Criar dashboard de atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Dashboard de atendimento criado." not in text:
    text = text.replace(
        "Encerramento com avaliacao do atendimento criado.",
        "Encerramento com avaliacao do atendimento criado.\n\nDashboard de atendimento criado."
    )

if "- docs/ATTENDANCE_DASHBOARD.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_CLOSURE_RATING.md",
        "- docs/ATTENDANCE_DASHBOARD.md\n- docs/ATTENDANCE_CLOSURE_RATING.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 62 concluidas",
    "- Etapa 01 ate Etapa 63 concluidas"
)

text = text.replace(
    "- Etapa 63 - Criar dashboard de atendimento",
    "- Etapa 64 - Revisao final da fase de atendimento profissional"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 63 - Criar dashboard de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criado dashboard de atendimento com metricas de conversas, filas, departamentos, avaliacoes, notas, tags, respostas rapidas e encerramentos.
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
Etapa: 63
Acao: Criar dashboard de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance dashboard API status: ${DOMAIN_DASHBOARD_API_STATUS}
Attendance dashboard page status: ${DOMAIN_ATTENDANCE_DASHBOARD_PAGE_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard page status: ${DOMAIN_DASHBOARD_PAGE_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 63 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 64 - Revisao final da fase de atendimento profissional"
