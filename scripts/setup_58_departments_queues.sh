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

LOG_FILE="${LOGS_DIR}/setup_58.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_58_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_58_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_58_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_58_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_58_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_58_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_58_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_58_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_58_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_58_auth_login_domain.log"
DOMAIN_DEPARTMENTS_LOG="${LOGS_DIR}/setup_58_departments_domain.log"
DOMAIN_DEPARTMENT_CREATE_LOG="${LOGS_DIR}/setup_58_department_create_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_58_attendance_conversations_domain.log"
DOMAIN_ATTENDANCE_PATCH_LOG="${LOGS_DIR}/setup_58_attendance_department_patch_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_58_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_58_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_58_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_DEPARTMENTS_QUEUES.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 58: Departamentos e filas de atendimento =="

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

echo "Criando tabelas e seed de departamentos..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists attendance_departments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  name text not null,
  slug text not null,
  color text not null default '#0757c8',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, slug)
);

create index if not exists idx_attendance_departments_tenant
on attendance_departments (tenant_id);

create index if not exists idx_attendance_departments_active
on attendance_departments (tenant_id, is_active);

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

insert into attendance_departments (tenant_id, name, slug, color, sort_order)
values
  ('00000000-0000-0000-0000-000000000001', 'Fila geral', 'fila-geral', '#0757c8', 1),
  ('00000000-0000-0000-0000-000000000001', 'Comercial', 'comercial', '#f97316', 2),
  ('00000000-0000-0000-0000-000000000001', 'Suporte', 'suporte', '#16a34a', 3),
  ('00000000-0000-0000-0000-000000000001', 'Financeiro', 'financeiro', '#7c3aed', 4),
  ('00000000-0000-0000-0000-000000000001', 'Pos-venda', 'pos-venda', '#0f766e', 5),
  ('00000000-0000-0000-0000-000000000001', 'Tecnico', 'tecnico', '#2563eb', 6),
  ('00000000-0000-0000-0000-000000000001', 'Administrativo', 'administrativo', '#475569', 7)
on conflict (tenant_id, slug) do update set
  name = excluded.name,
  color = excluded.color,
  sort_order = excluded.sort_order,
  is_active = true,
  updated_at = now();
SQL

echo "Regravando types backend..."

cat > "${BACKEND_DIR}/src/modules/attendance/attendance.types.ts" <<'DOC'
export type AttendanceConversationStatus =
  | 'novo'
  | 'em_atendimento'
  | 'aguardando_cliente'
  | 'aguardando_interno'
  | 'resolvido'
  | 'encerrado'
  | 'arquivado';

export type AttendancePriority =
  | 'baixa'
  | 'normal'
  | 'media'
  | 'alta'
  | 'urgente';

export type AttendanceDepartmentItem = {
  id: string;
  name: string;
  slug: string;
  color: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceDepartmentsResponse = {
  success: true;
  data: {
    departments: AttendanceDepartmentItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceDepartmentPayload = {
  name?: string;
  color?: string;
  isActive?: boolean;
  sortOrder?: number;
};

export type AttendanceDepartmentResponse = {
  success: true;
  data: {
    department: AttendanceDepartmentItem;
  };
  meta: Record<string, never>;
};

export type AttendanceConversationItem = {
  id: string;
  contactName: string | null;
  contactPhone: string | null;
  status: string;
  priority: string;
  departmentName: string;
  assignedUserId: string | null;
  assignedUserName: string | null;
  lastMessage: string | null;
  lastMessageAt: string | null;
  unreadCount: number;
  updatedAt: string;
};

export type AttendanceConversationListResponse = {
  success: true;
  data: {
    conversations: AttendanceConversationItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceStatusOptionsResponse = {
  success: true;
  data: {
    statuses: Array<{
      value: string;
      label: string;
    }>;
    priorities: Array<{
      value: string;
      label: string;
    }>;
  };
  meta: Record<string, never>;
};

export type AttendanceUpdateStatusPayload = {
  status?: string;
  priority?: string;
  departmentName?: string;
  assignedUserId?: string | null;
  assignedUserName?: string | null;
};

export type AttendanceUpdateStatusResponse = {
  success: true;
  data: {
    conversationId: string;
    status: string;
    priority: string;
    departmentName: string;
    assignedUserId: string | null;
    assignedUserName: string | null;
    updatedAt: string;
  };
  meta: Record<string, never>;
};
DOC

echo "Regravando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance/attendance.service.ts" <<'DOC'
import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceConversationItem,
  AttendanceConversationListResponse,
  AttendanceDepartmentItem,
  AttendanceDepartmentPayload,
  AttendanceDepartmentResponse,
  AttendanceDepartmentsResponse,
  AttendanceStatusOptionsResponse,
  AttendanceUpdateStatusPayload,
  AttendanceUpdateStatusResponse
} from './attendance.types';

type OperationalStatusRow = {
  conversation_id: string;
  status: string;
  priority: string;
  department_name: string;
  assigned_user_id: string | null;
  assigned_user_name: string | null;
  updated_at: Date;
};

type DepartmentRow = {
  id: string;
  name: string;
  slug: string;
  color: string;
  is_active: boolean;
  sort_order: number;
  created_at: Date;
  updated_at: Date;
};

const statusOptions = [
  { value: 'novo', label: 'Novo' },
  { value: 'em_atendimento', label: 'Em atendimento' },
  { value: 'aguardando_cliente', label: 'Aguardando cliente' },
  { value: 'aguardando_interno', label: 'Aguardando interno' },
  { value: 'resolvido', label: 'Resolvido' },
  { value: 'encerrado', label: 'Encerrado' },
  { value: 'arquivado', label: 'Arquivado' }
];

const priorityOptions = [
  { value: 'baixa', label: 'Baixa' },
  { value: 'normal', label: 'Normal' },
  { value: 'media', label: 'Media' },
  { value: 'alta', label: 'Alta' },
  { value: 'urgente', label: 'Urgente' }
];

@Injectable()
export class AttendanceService {
  constructor(private readonly prismaService: PrismaService) {}

  getStatusOptions(): AttendanceStatusOptionsResponse {
    return {
      success: true,
      data: {
        statuses: statusOptions,
        priorities: priorityOptions
      },
      meta: {}
    };
  }

  async listDepartments(tenantId: string): Promise<AttendanceDepartmentsResponse> {
    await this.ensureDefaultDepartments(tenantId);

    const rows = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select id, name, slug, color, is_active, sort_order, created_at, updated_at from attendance_departments where tenant_id = $1::uuid order by sort_order asc, name asc',
      tenantId
    );

    return {
      success: true,
      data: {
        departments: rows.map((row) => this.mapDepartment(row))
      },
      meta: {}
    };
  }

  async createDepartment(
    tenantId: string,
    payload: AttendanceDepartmentPayload
  ): Promise<AttendanceDepartmentResponse> {
    const name = this.normalizeDepartmentName(payload.name);
    const slug = this.slugify(name);
    const color = payload.color || '#0757c8';
    const sortOrder = Number(payload.sortOrder || 50);

    await this.prismaService.$executeRawUnsafe(
      'insert into attendance_departments (tenant_id, name, slug, color, is_active, sort_order, created_at, updated_at) values ($1::uuid, $2, $3, $4, true, $5, now(), now()) on conflict (tenant_id, slug) do update set name = excluded.name, color = excluded.color, is_active = true, sort_order = excluded.sort_order, updated_at = now()',
      tenantId,
      name,
      slug,
      color,
      sortOrder
    );

    const row = await this.findDepartmentBySlug(tenantId, slug);

    if (!row) {
      throw new BadRequestException('Nao foi possivel criar departamento');
    }

    return {
      success: true,
      data: {
        department: this.mapDepartment(row)
      },
      meta: {}
    };
  }

  async updateDepartment(
    tenantId: string,
    departmentId: string,
    payload: AttendanceDepartmentPayload
  ): Promise<AttendanceDepartmentResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select id, name, slug, color, is_active, sort_order, created_at, updated_at from attendance_departments where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      departmentId
    );

    const current = rows[0];

    if (!current) {
      throw new BadRequestException('Departamento nao encontrado');
    }

    const name = payload.name ? this.normalizeDepartmentName(payload.name) : current.name;
    const slug = this.slugify(name);
    const color = payload.color || current.color;
    const isActive = typeof payload.isActive === 'boolean' ? payload.isActive : current.is_active;
    const sortOrder = typeof payload.sortOrder === 'number' ? payload.sortOrder : current.sort_order;

    await this.prismaService.$executeRawUnsafe(
      'update attendance_departments set name = $3, slug = $4, color = $5, is_active = $6, sort_order = $7, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid',
      tenantId,
      departmentId,
      name,
      slug,
      color,
      isActive,
      sortOrder
    );

    const updatedRows = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select id, name, slug, color, is_active, sort_order, created_at, updated_at from attendance_departments where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      departmentId
    );

    return {
      success: true,
      data: {
        department: this.mapDepartment(updatedRows[0])
      },
      meta: {}
    };
  }

  async listConversations(tenantId: string): Promise<AttendanceConversationListResponse> {
    await this.ensureDefaultDepartments(tenantId);

    const conversations = await this.prismaService.conversation.findMany({
      where: {
        tenantId,
        deletedAt: null
      },
      include: {
        contact: true,
        messages: {
          orderBy: {
            createdAt: 'desc'
          },
          take: 1
        }
      },
      orderBy: {
        updatedAt: 'desc'
      },
      take: 50
    });

    const ids = conversations.map((conversation) => conversation.id);
    const statusRows = ids.length > 0
      ? await this.prismaService.$queryRawUnsafe<OperationalStatusRow[]>(
          'select conversation_id, status, priority, department_name, assigned_user_id, assigned_user_name, updated_at from conversation_operational_status where tenant_id = $1::uuid and conversation_id = any($2::uuid[])',
          tenantId,
          ids
        )
      : [];

    const statusByConversation = new Map<string, OperationalStatusRow>();

    for (const row of statusRows) {
      statusByConversation.set(row.conversation_id, row);
    }

    const items: AttendanceConversationItem[] = conversations.map((conversation) => {
      const statusRow = statusByConversation.get(conversation.id);
      const lastMessage = conversation.messages[0] || null;

      return {
        id: conversation.id,
        contactName: conversation.contact?.name || null,
        contactPhone: conversation.contact?.phone || null,
        status: statusRow?.status || 'novo',
        priority: statusRow?.priority || 'normal',
        departmentName: statusRow?.department_name || 'Fila geral',
        assignedUserId: statusRow?.assigned_user_id || null,
        assignedUserName: statusRow?.assigned_user_name || null,
        lastMessage: lastMessage?.body || null,
        lastMessageAt: lastMessage?.createdAt ? lastMessage.createdAt.toISOString() : null,
        unreadCount: 0,
        updatedAt: statusRow?.updated_at ? statusRow.updated_at.toISOString() : conversation.updatedAt.toISOString()
      };
    });

    return {
      success: true,
      data: {
        conversations: items
      },
      meta: {}
    };
  }

  async updateConversationStatus(
    tenantId: string,
    conversationId: string,
    payload: AttendanceUpdateStatusPayload
  ): Promise<AttendanceUpdateStatusResponse> {
    const status = payload.status || 'novo';
    const priority = payload.priority || 'normal';
    const departmentName = payload.departmentName || 'Fila geral';

    if (!statusOptions.some((item) => item.value === status)) {
      throw new BadRequestException('Status operacional invalido');
    }

    if (!priorityOptions.some((item) => item.value === priority)) {
      throw new BadRequestException('Prioridade invalida');
    }

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
      payload.assignedUserName || null
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
        status: row?.status || status,
        priority: row?.priority || priority,
        departmentName: row?.department_name || departmentName,
        assignedUserId: row?.assigned_user_id || null,
        assignedUserName: row?.assigned_user_name || null,
        updatedAt: row?.updated_at ? row.updated_at.toISOString() : new Date().toISOString()
      },
      meta: {}
    };
  }

  private async ensureDefaultDepartments(tenantId: string) {
    const defaults = [
      ['Fila geral', 'fila-geral', '#0757c8', 1],
      ['Comercial', 'comercial', '#f97316', 2],
      ['Suporte', 'suporte', '#16a34a', 3],
      ['Financeiro', 'financeiro', '#7c3aed', 4],
      ['Pos-venda', 'pos-venda', '#0f766e', 5],
      ['Tecnico', 'tecnico', '#2563eb', 6],
      ['Administrativo', 'administrativo', '#475569', 7]
    ];

    for (const item of defaults) {
      await this.prismaService.$executeRawUnsafe(
        'insert into attendance_departments (tenant_id, name, slug, color, sort_order, is_active, created_at, updated_at) values ($1::uuid, $2, $3, $4, $5, true, now(), now()) on conflict (tenant_id, slug) do nothing',
        tenantId,
        item[0],
        item[1],
        item[2],
        item[3]
      );
    }
  }

  private async ensureDepartmentByName(tenantId: string, name: string) {
    const normalized = this.normalizeDepartmentName(name);
    const slug = this.slugify(normalized);
    await this.prismaService.$executeRawUnsafe(
      'insert into attendance_departments (tenant_id, name, slug, color, sort_order, is_active, created_at, updated_at) values ($1::uuid, $2, $3, $4, 99, true, now(), now()) on conflict (tenant_id, slug) do nothing',
      tenantId,
      normalized,
      slug,
      '#0757c8'
    );
  }

  private async findDepartmentBySlug(tenantId: string, slug: string): Promise<DepartmentRow | null> {
    const rows = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select id, name, slug, color, is_active, sort_order, created_at, updated_at from attendance_departments where tenant_id = $1::uuid and slug = $2 limit 1',
      tenantId,
      slug
    );

    return rows[0] || null;
  }

  private mapDepartment(row: DepartmentRow): AttendanceDepartmentItem {
    return {
      id: row.id,
      name: row.name,
      slug: row.slug,
      color: row.color,
      isActive: row.is_active,
      sortOrder: row.sort_order,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }

  private normalizeDepartmentName(value?: string): string {
    const name = (value || '').trim();

    if (!name) {
      throw new BadRequestException('Nome do departamento e obrigatorio');
    }

    if (name.length > 80) {
      throw new BadRequestException('Nome do departamento muito longo');
    }

    return name;
  }

  private slugify(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '') || 'departamento';
  }
}
DOC

echo "Regravando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance/attendance.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceService } from './attendance.service';
import type {
  AttendanceDepartmentPayload,
  AttendanceUpdateStatusPayload
} from './attendance.types';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceController {
  constructor(private readonly attendanceService: AttendanceService) {}

  @Get('departments')
  listDepartments(@CurrentUser() user: AuthenticatedUser) {
    return this.attendanceService.listDepartments(user.tenantId);
  }

  @Post('departments')
  createDepartment(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: AttendanceDepartmentPayload
  ) {
    return this.attendanceService.createDepartment(user.tenantId, body);
  }

  @Patch('departments/:departmentId')
  updateDepartment(
    @CurrentUser() user: AuthenticatedUser,
    @Param('departmentId') departmentId: string,
    @Body() body: AttendanceDepartmentPayload
  ) {
    return this.attendanceService.updateDepartment(user.tenantId, departmentId, body);
  }

  @Get('conversations/status-options')
  getStatusOptions() {
    return this.attendanceService.getStatusOptions();
  }

  @Get('conversations')
  listConversations(@CurrentUser() user: AuthenticatedUser) {
    return this.attendanceService.listConversations(user.tenantId);
  }

  @Patch('conversations/:conversationId/status')
  updateConversationStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceUpdateStatusPayload
  ) {
    return this.attendanceService.updateConversationStatus(user.tenantId, conversationId, body);
  }
}
DOC

echo "Garantindo modulo attendance no app.module..."

cat > "${BACKEND_DIR}/src/modules/attendance/attendance.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceController } from './attendance.controller';
import { AttendanceService } from './attendance.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceController
  ],
  providers: [
    AttendanceService
  ]
})
export class AttendanceModule {}
DOC

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()
import_line = "import { AttendanceModule } from './modules/attendance/attendance.module';"

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

if "AttendanceModule" not in match.group(1):
    text = re.sub(r"imports:\s*\[", "imports: [\n    AttendanceModule,", text, count=1)

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

echo "Regravando types frontend..."

cat > "${FRONTEND_DIR}/src/types/attendance.types.ts" <<'DOC'
export type AttendanceDepartmentItem = {
  id: string;
  name: string;
  slug: string;
  color: string;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceDepartmentsData = {
  departments: AttendanceDepartmentItem[];
};

export type AttendanceDepartmentData = {
  department: AttendanceDepartmentItem;
};

export type AttendanceConversationItem = {
  id: string;
  contactName: string | null;
  contactPhone: string | null;
  status: string;
  priority: string;
  departmentName: string;
  assignedUserId: string | null;
  assignedUserName: string | null;
  lastMessage: string | null;
  lastMessageAt: string | null;
  unreadCount: number;
  updatedAt: string;
};

export type AttendanceConversationListData = {
  conversations: AttendanceConversationItem[];
};

export type AttendanceStatusOptionsData = {
  statuses: Array<{
    value: string;
    label: string;
  }>;
  priorities: Array<{
    value: string;
    label: string;
  }>;
};

export type AttendanceUpdateStatusData = {
  conversationId: string;
  status: string;
  priority: string;
  departmentName: string;
  assignedUserId: string | null;
  assignedUserName: string | null;
  updatedAt: string;
};
DOC

echo "Regravando service frontend..."

cat > "${FRONTEND_DIR}/src/services/attendance.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AttendanceConversationListData,
  AttendanceDepartmentData,
  AttendanceDepartmentsData,
  AttendanceStatusOptionsData,
  AttendanceUpdateStatusData
} from '../types/attendance.types';

export async function listAttendanceDepartmentsRequest(token: string) {
  return apiRequest<AttendanceDepartmentsData>('/attendance/departments', {
    method: 'GET',
    token
  });
}

export async function createAttendanceDepartmentRequest(
  token: string,
  payload: {
    name: string;
    color?: string;
    sortOrder?: number;
  }
) {
  return apiRequest<AttendanceDepartmentData>('/attendance/departments', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function updateAttendanceDepartmentRequest(
  token: string,
  departmentId: string,
  payload: {
    name?: string;
    color?: string;
    isActive?: boolean;
    sortOrder?: number;
  }
) {
  return apiRequest<AttendanceDepartmentData>('/attendance/departments/' + departmentId, {
    method: 'PATCH',
    token,
    body: payload
  });
}

export async function listAttendanceConversationsRequest(token: string) {
  return apiRequest<AttendanceConversationListData>('/attendance/conversations', {
    method: 'GET',
    token
  });
}

export async function getAttendanceStatusOptionsRequest(token: string) {
  return apiRequest<AttendanceStatusOptionsData>('/attendance/conversations/status-options', {
    method: 'GET',
    token
  });
}

export async function updateAttendanceConversationStatusRequest(
  token: string,
  conversationId: string,
  payload: {
    status: string;
    priority: string;
    departmentName: string;
    assignedUserId?: string | null;
    assignedUserName?: string | null;
  }
) {
  return apiRequest<AttendanceUpdateStatusData>('/attendance/conversations/' + conversationId + '/status', {
    method: 'PATCH',
    token,
    body: payload
  });
}
DOC

echo "Regravando InboxPage.tsx com departamentos e filas reais..."

cat > "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" <<'DOC'
import { FormEvent, useEffect, useMemo, useState } from 'react';
import {
  createAttendanceDepartmentRequest,
  getAttendanceStatusOptionsRequest,
  listAttendanceConversationsRequest,
  listAttendanceDepartmentsRequest,
  updateAttendanceConversationStatusRequest
} from '../../services/attendance.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  AttendanceConversationItem,
  AttendanceDepartmentItem
} from '../../types/attendance.types';

const fallbackConversations: AttendanceConversationItem[] = [
  {
    id: 'demo-001',
    contactName: 'Cliente Comercial',
    contactPhone: '5521999990001',
    departmentName: 'Comercial',
    status: 'novo',
    assignedUserId: null,
    assignedUserName: 'Sem responsavel',
    priority: 'alta',
    unreadCount: 3,
    lastMessage: 'Gostaria de receber uma proposta.',
    lastMessageAt: null,
    updatedAt: new Date().toISOString()
  }
];

const fallbackDepartments: AttendanceDepartmentItem[] = [
  {
    id: 'fallback-geral',
    name: 'Fila geral',
    slug: 'fila-geral',
    color: '#0757c8',
    isActive: true,
    sortOrder: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }
];

const quickReplies = [
  'Ola. Como posso ajudar?',
  'Pode me informar seu nome completo?',
  'Vou encaminhar seu atendimento para o departamento responsavel.',
  'Seu atendimento foi finalizado. Avalie de 1 a 5.'
];

const statusLabels: Record<string, string> = {
  novo: 'Novo',
  em_atendimento: 'Em atendimento',
  aguardando_cliente: 'Aguardando cliente',
  aguardando_interno: 'Aguardando interno',
  resolvido: 'Resolvido',
  encerrado: 'Encerrado',
  arquivado: 'Arquivado'
};

const priorityLabels: Record<string, string> = {
  baixa: 'Baixa',
  normal: 'Normal',
  media: 'Media',
  alta: 'Alta',
  urgente: 'Urgente'
};

export function InboxPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [selectedQueue, setSelectedQueue] = useState('Fila geral');
  const [selectedConversationId, setSelectedConversationId] = useState('');
  const [conversations, setConversations] = useState<AttendanceConversationItem[]>(fallbackConversations);
  const [departments, setDepartments] = useState<AttendanceDepartmentItem[]>(fallbackDepartments);
  const [statusOptions, setStatusOptions] = useState<Array<{ value: string; label: string }>>([]);
  const [priorityOptions, setPriorityOptions] = useState<Array<{ value: string; label: string }>>([]);
  const [newDepartmentName, setNewDepartmentName] = useState('');
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(true);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadInbox() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const [listResponse, optionsResponse, departmentsResponse] = await Promise.all([
      listAttendanceConversationsRequest(token),
      getAttendanceStatusOptionsRequest(token),
      listAttendanceDepartmentsRequest(token)
    ]);

    if (departmentsResponse.success && departmentsResponse.data.departments.length > 0) {
      setDepartments(departmentsResponse.data.departments.filter((item) => item.isActive));
    }

    if (listResponse.success && listResponse.data.conversations.length > 0) {
      setConversations(listResponse.data.conversations);
      setSelectedConversationId((current) => current || listResponse.data.conversations[0].id);
    } else if (listResponse.success) {
      setConversations(fallbackConversations);
      setSelectedConversationId((current) => current || fallbackConversations[0].id);
      setNotice('Nenhuma conversa real encontrada. Exibindo estrutura visual de exemplo.');
    } else {
      setNotice(listResponse.error.message || 'Nao foi possivel carregar conversas reais.');
    }

    if (optionsResponse.success) {
      setStatusOptions(optionsResponse.data.statuses);
      setPriorityOptions(optionsResponse.data.priorities);
    }

    setLoading(false);
  }

  useEffect(() => {
    void loadInbox();
  }, []);

  const selectedConversation = useMemo(() => {
    return conversations.find((item) => item.id === selectedConversationId) || conversations[0] || fallbackConversations[0];
  }, [conversations, selectedConversationId]);

  const queueTabs = useMemo(() => {
    return [
      'Fila geral',
      'Sem responsavel',
      ...departments.filter((item) => item.name !== 'Fila geral').map((item) => item.name),
      'Aguardando cliente',
      'Em atraso'
    ];
  }, [departments]);

  const visibleConversations = useMemo(() => {
    if (selectedQueue === 'Fila geral') {
      return conversations;
    }

    if (selectedQueue === 'Sem responsavel') {
      return conversations.filter((item) => !item.assignedUserName || item.assignedUserName === 'Sem responsavel');
    }

    if (selectedQueue === 'Em atraso') {
      return conversations.filter((item) => item.priority === 'alta' || item.priority === 'urgente');
    }

    if (selectedQueue === 'Aguardando cliente') {
      return conversations.filter((item) => item.status === 'aguardando_cliente');
    }

    return conversations.filter((item) => item.departmentName === selectedQueue);
  }, [conversations, selectedQueue]);

  async function updateConversation(payload: {
    status?: string;
    priority?: string;
    departmentName?: string;
  }) {
    const token = getToken();

    const nextStatus = payload.status || selectedConversation.status;
    const nextPriority = payload.priority || selectedConversation.priority;
    const nextDepartment = payload.departmentName || selectedConversation.departmentName;

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setConversations((current) => current.map((item) => item.id === selectedConversation.id ? {
        ...item,
        status: nextStatus,
        priority: nextPriority,
        departmentName: nextDepartment
      } : item));
      return;
    }

    const response = await updateAttendanceConversationStatusRequest(token, selectedConversation.id, {
      status: nextStatus,
      priority: nextPriority,
      departmentName: nextDepartment,
      assignedUserId: selectedConversation.assignedUserId,
      assignedUserName: selectedConversation.assignedUserName
    });

    if (response.success) {
      await loadInbox();
      setNotice('Conversa atualizada.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel atualizar conversa.');
    }
  }

  async function handleCreateDepartment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !newDepartmentName.trim()) {
      return;
    }

    const response = await createAttendanceDepartmentRequest(token, {
      name: newDepartmentName.trim(),
      color: '#0757c8',
      sortOrder: departments.length + 1
    });

    if (response.success) {
      setNewDepartmentName('');
      await loadInbox();
      setNotice('Departamento criado com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel criar departamento.');
    }
  }

  return (
    <section className="inbox-shell">
      <section className="inbox-hero">
        <div>
          <span>Central de atendimento</span>
          <h1>Departamentos e filas</h1>
          <p>Distribua conversas por departamentos, acompanhe filas e altere o setor responsavel pelo atendimento.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="department-manager">
        <div>
          <strong>Departamentos</strong>
          <p>Crie filas operacionais para organizar o atendimento.</p>
        </div>

        <form onSubmit={handleCreateDepartment}>
          <input
            onChange={(event) => setNewDepartmentName(event.target.value)}
            placeholder="Novo departamento"
            value={newDepartmentName}
          />
          <button type="submit">Criar</button>
        </form>
      </section>

      <section className="inbox-metrics">
        <article>
          <span>Departamentos</span>
          <strong>{departments.length}</strong>
          <p>Filas ativas</p>
        </article>

        <article>
          <span>Abertas</span>
          <strong>{conversations.filter((item) => item.status !== 'encerrado' && item.status !== 'arquivado').length}</strong>
          <p>Conversas em andamento</p>
        </article>

        <article>
          <span>Sem responsavel</span>
          <strong>{conversations.filter((item) => !item.assignedUserName || item.assignedUserName === 'Sem responsavel').length}</strong>
          <p>Aguardando distribuicao</p>
        </article>

        <article>
          <span>Fila atual</span>
          <strong>{visibleConversations.length}</strong>
          <p>{selectedQueue}</p>
        </article>
      </section>

      <section className="inbox-workspace">
        <aside className="inbox-queues">
          <div className="inbox-panel-title">
            <strong>Filas</strong>
            <span>Departamentos e status</span>
          </div>

          <div className="inbox-queue-list">
            {queueTabs.map((queue) => (
              <button
                className={queue === selectedQueue ? 'active' : ''}
                key={queue}
                onClick={() => setSelectedQueue(queue)}
                type="button"
              >
                {queue}
              </button>
            ))}
          </div>
        </aside>

        <aside className="inbox-conversation-list">
          <div className="inbox-panel-title">
            <strong>Conversas</strong>
            <span>{visibleConversations.length} itens nesta fila</span>
          </div>

          <div className="inbox-search">
            <input placeholder="Buscar por nome ou telefone" />
          </div>

          {loading ? <div className="conversation-empty">Carregando central...</div> : null}

          <div className="inbox-conversation-items">
            {visibleConversations.map((conversation) => (
              <button
                className={conversation.id === selectedConversation.id ? 'active' : ''}
                key={conversation.id}
                onClick={() => setSelectedConversationId(conversation.id)}
                type="button"
              >
                <div>
                  <strong>{conversation.contactName || conversation.contactPhone || 'Contato sem nome'}</strong>
                  <span>{conversation.lastMessage || 'Sem mensagem recente'}</span>
                  <small>{conversation.departmentName} - {conversation.assignedUserName || 'Sem responsavel'}</small>
                </div>

                <em>{conversation.lastMessageAt || conversation.updatedAt}</em>

                {conversation.unreadCount ? (
                  <b>{conversation.unreadCount}</b>
                ) : null}
              </button>
            ))}
          </div>
        </aside>

        <main className="inbox-chat">
          <header className="inbox-chat-header">
            <div>
              <strong>{selectedConversation.contactName || selectedConversation.contactPhone || 'Contato sem nome'}</strong>
              <span>{selectedConversation.contactPhone || 'Telefone nao informado'}</span>
            </div>

            <div className="inbox-chat-badges">
              <span>{selectedConversation.departmentName}</span>
              <span>{statusLabels[selectedConversation.status] || selectedConversation.status}</span>
              <span>{priorityLabels[selectedConversation.priority] || selectedConversation.priority}</span>
            </div>
          </header>

          <section className="inbox-status-editor">
            <label>
              Departamento
              <select onChange={(event) => void updateConversation({ departmentName: event.target.value })} value={selectedConversation.departmentName}>
                {departments.map((item) => (
                  <option key={item.id} value={item.name}>{item.name}</option>
                ))}
              </select>
            </label>

            <label>
              Status
              <select onChange={(event) => void updateConversation({ status: event.target.value })} value={selectedConversation.status}>
                {(statusOptions.length ? statusOptions : Object.entries(statusLabels).map(([value, label]) => ({ value, label }))).map((item) => (
                  <option key={item.value} value={item.value}>{item.label}</option>
                ))}
              </select>
            </label>

            <label>
              Prioridade
              <select onChange={(event) => void updateConversation({ priority: event.target.value })} value={selectedConversation.priority}>
                {(priorityOptions.length ? priorityOptions : Object.entries(priorityLabels).map(([value, label]) => ({ value, label }))).map((item) => (
                  <option key={item.value} value={item.value}>{item.label}</option>
                ))}
              </select>
            </label>
          </section>

          <section className="inbox-message-area">
            <article className="message-bubble inbound">
              <span>Cliente</span>
              <p>{selectedConversation.lastMessage || 'Mensagem recebida do cliente.'}</p>
            </article>

            <article className="message-bubble internal">
              <span>Nota interna</span>
              <p>Departamentos e filas agora sao persistidos no backend e usados na central de atendimento.</p>
            </article>

            <article className="message-bubble outbound">
              <span>Atendente</span>
              <p>Ola. Vou direcionar seu atendimento ao departamento responsavel.</p>
            </article>
          </section>

          <section className="inbox-quick-replies">
            {quickReplies.map((reply) => (
              <button key={reply} type="button">
                {reply}
              </button>
            ))}
          </section>

          <footer className="inbox-composer">
            <textarea placeholder="Digite uma mensagem para o cliente" />
            <button type="button">Enviar</button>
          </footer>
        </main>

        <aside className="inbox-contact-panel">
          <div className="inbox-panel-title">
            <strong>Contato</strong>
            <span>Historico e operacao</span>
          </div>

          <div className="contact-card">
            <img alt="LH Solucao Chat Bot" src="/assets/lh_chatbot_favicon.png" />
            <strong>{selectedConversation.contactName || 'Contato sem nome'}</strong>
            <span>{selectedConversation.contactPhone || 'Telefone nao informado'}</span>
          </div>

          <div className="contact-details">
            <span>Departamento: {selectedConversation.departmentName}</span>
            <span>Responsavel: {selectedConversation.assignedUserName || 'Sem responsavel'}</span>
            <span>Prioridade: {priorityLabels[selectedConversation.priority] || selectedConversation.priority}</span>
            <span>Status: {statusLabels[selectedConversation.status] || selectedConversation.status}</span>
          </div>

          <section className="closing-card">
            <strong>Encerramento com avaliacao</strong>
            <p>Mensagem padrao pronta para finalizar o atendimento e solicitar nota de 1 a 5.</p>
            <button type="button">Preparar encerramento</button>
          </section>
        </aside>
      </section>
    </section>
  );
}
DOC

echo "Adicionando CSS de departamentos..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 58 - Departamentos e filas */

.department-manager {
  align-items: center;
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 24px;
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  display: grid;
  gap: 16px;
  grid-template-columns: minmax(0, 1fr) minmax(260px, auto);
  padding: 20px;
}

.department-manager strong {
  color: var(--lh-blue-950, #04204f);
  display: block;
}

.department-manager p {
  color: var(--lh-muted, #6b7280);
  margin: 4px 0 0;
}

.department-manager form {
  display: flex;
  gap: 10px;
}

.department-manager input {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  min-width: 220px;
  padding: 11px 13px;
}

.department-manager button {
  background: linear-gradient(135deg, var(--lh-orange-700, #f97316), var(--lh-orange-500, #ff9f1c));
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 11px 16px;
}

.inbox-status-editor {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

@media (max-width: 900px) {
  .department-manager {
    grid-template-columns: 1fr;
  }

  .department-manager form {
    flex-direction: column;
  }

  .department-manager input {
    min-width: 0;
    width: 100%;
  }

  .inbox-status-editor {
    grid-template-columns: 1fr;
  }
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

DOMAIN_DEPARTMENTS_STATUS="$(curl -L -s -o "${DOMAIN_DEPARTMENTS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/departments" || true)"

if [ "${DOMAIN_DEPARTMENTS_STATUS}" != "200" ]; then
  echo "ERRO: departments falhou. Status ${DOMAIN_DEPARTMENTS_STATUS}"
  cat "${DOMAIN_DEPARTMENTS_LOG}"
  exit 1
fi

if ! grep -q "Comercial" "${DOMAIN_DEPARTMENTS_LOG}"; then
  echo "ERRO: departments nao retornou Comercial."
  cat "${DOMAIN_DEPARTMENTS_LOG}"
  exit 1
fi

CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Triagem Etapa 58', color:'#0757c8', sortOrder:88}))")"

DOMAIN_DEPARTMENT_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_DEPARTMENT_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CREATE_PAYLOAD}" \
  "${DOMAIN_ATTENDANCE_URL}/departments" || true)"

if [ "${DOMAIN_DEPARTMENT_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_DEPARTMENT_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: create department falhou. Status ${DOMAIN_DEPARTMENT_CREATE_STATUS}"
  cat "${DOMAIN_DEPARTMENT_CREATE_LOG}"
  exit 1
fi

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_LIST_STATUS}" != "200" ]; then
  echo "ERRO: listagem attendance falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

DOMAIN_ATTENDANCE_PATCH_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  PATCH_PAYLOAD="$(node -e "console.log(JSON.stringify({status:'em_atendimento', priority:'media', departmentName:'Comercial', assignedUserId:null, assignedUserName:'Validacao Etapa 58'}))")"

  DOMAIN_ATTENDANCE_PATCH_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_PATCH_LOG}" -w "%{http_code}" --max-time 30 \
    -X PATCH \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${PATCH_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/status" || true)"

  if [ "${DOMAIN_ATTENDANCE_PATCH_STATUS}" != "200" ] && [ "${DOMAIN_ATTENDANCE_PATCH_STATUS}" != "201" ]; then
    echo "ERRO: patch department falhou. Status ${DOMAIN_ATTENDANCE_PATCH_STATUS}"
    cat "${DOMAIN_ATTENDANCE_PATCH_LOG}"
    exit 1
  fi
else
  echo '{"skipped":"sem conversa real para patch"}' > "${DOMAIN_ATTENDANCE_PATCH_LOG}"
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

echo "Gerando documentacao da Etapa 58..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Departments Queues

## Visao geral

Este documento registra a criacao de departamentos e filas de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela attendance departments
- departamentos por tenant
- seed dos departamentos iniciais
- endpoint de listagem de departamentos
- endpoint de criacao de departamento
- endpoint de atualizacao de departamento
- uso de departamentos como filas na central app inbox
- criacao visual de novo departamento
- alteracao do departamento da conversa na central
- persistencia do departamento atual da conversa

## Departamentos iniciais

Departamentos:

- Fila geral
- Comercial
- Suporte
- Financeiro
- Pos-venda
- Tecnico
- Administrativo

## Endpoints criados

Endpoints:

- GET api v1 attendance departments
- POST api v1 attendance departments
- PATCH api v1 attendance departments department id

## Tabela criada

Tabela:

- attendance departments

Campos:

- id
- tenant id
- name
- slug
- color
- is active
- sort order
- created at
- updated at

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance/attendance.types.ts
- apps/backend/src/modules/attendance/attendance.service.ts
- apps/backend/src/modules/attendance/attendance.controller.ts
- apps/backend/src/modules/attendance/attendance.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance.types.ts
- apps/frontend/src/services/attendance.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_DEPARTMENTS_QUEUES.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela
- seed dos departamentos iniciais
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint departments dominio
- criacao de departamento dominio
- endpoint attendance conversations dominio
- patch de conversa para departamento Comercial quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_58_backend_typecheck.log
- logs/setup_58_backend_build.log
- logs/setup_58_frontend_typecheck.log
- logs/setup_58_frontend_build.log
- logs/setup_58_backend_docker_build.log
- logs/setup_58_frontend_docker_build.log
- logs/setup_58_docker_up.log
- logs/setup_58_backend_wait.log
- logs/setup_58_auth_login_domain.log
- logs/setup_58_departments_domain.log
- logs/setup_58_department_create_domain.log
- logs/setup_58_attendance_conversations_domain.log
- logs/setup_58_attendance_department_patch_domain.log
- logs/setup_58_domain_inbox_page.log
- logs/setup_58_domain_dashboard.log
- logs/setup_58_domain_audit_page.log
- logs/setup_58.log

## Proxima etapa sugerida

Etapa 59:

    Criar atribuicao de responsavel e nome do atendente
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 58 - Criar departamentos e filas de atendimento",
    "- [x] Etapa 58 - Criar departamentos e filas de atendimento\n- [ ] Etapa 59 - Criar atribuicao de responsavel e nome do atendente"
)

text = text.replace(
    "Etapa 58 - Criar departamentos e filas de atendimento.",
    "Etapa 59 - Criar atribuicao de responsavel e nome do atendente."
)

text = text.replace(
    "Etapa 57 - Criar status operacional das conversas.",
    "Etapa 58 - Criar departamentos e filas de atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Departamentos e filas de atendimento criados." not in text:
    text = text.replace(
        "Status operacional das conversas criado.",
        "Status operacional das conversas criado.\n\nDepartamentos e filas de atendimento criados."
    )

if "- docs/ATTENDANCE_DEPARTMENTS_QUEUES.md" not in text:
    text = text.replace(
        "- docs/CONVERSATION_OPERATIONAL_STATUS.md",
        "- docs/ATTENDANCE_DEPARTMENTS_QUEUES.md\n- docs/CONVERSATION_OPERATIONAL_STATUS.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 57 concluidas",
    "- Etapa 01 ate Etapa 58 concluidas"
)

text = text.replace(
    "- Etapa 58 - Criar departamentos e filas de atendimento",
    "- Etapa 59 - Criar atribuicao de responsavel e nome do atendente"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 58 - Criar departamentos e filas de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada persistencia de departamentos por tenant, endpoints de departamentos e integracao da central app inbox com filas por departamento.
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
Etapa: 58
Acao: Criar departamentos e filas de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Departments status: ${DOMAIN_DEPARTMENTS_STATUS}
Department create status: ${DOMAIN_DEPARTMENT_CREATE_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Attendance patch status: ${DOMAIN_ATTENDANCE_PATCH_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 58 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 59 - Criar atribuicao de responsavel e nome do atendente"
