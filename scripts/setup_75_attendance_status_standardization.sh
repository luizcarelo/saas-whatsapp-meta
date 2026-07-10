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

LOG_FILE="${LOGS_DIR}/setup_75.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_75_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_75_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_75_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_75_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_75_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_75_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_75_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_75_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_75_backend_crash.log"

DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_75_health_domain.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_75_auth_login_domain.log"
DOMAIN_STATUS_MODEL_LOG="${LOGS_DIR}/setup_75_status_model_domain.log"
DOMAIN_STATUS_OPTIONS_LOG="${LOGS_DIR}/setup_75_status_options_domain.log"
DOMAIN_STATUS_MAP_LOG="${LOGS_DIR}/setup_75_status_compatibility_map_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_75_attendance_conversations_domain.log"
DOMAIN_DB_COUNTS_LOG="${LOGS_DIR}/setup_75_status_database_counts.log"
DOMAIN_PAGES_LOG="${LOGS_DIR}/setup_75_pages_status.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_STATUS_STANDARDIZATION.md"
DOC_COMPAT="${DOCS_DIR}/ATTENDANCE_STATUS_COMPATIBILITY_MAP.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_HEALTH_URL="${DOMAIN_BASE_URL}/api/v1/health"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_STATUS_URL="${DOMAIN_BASE_URL}/api/v1/attendance-status"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"

echo "== Etapa 75: Padronizacao dos status de atendimento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/attendance-status"
mkdir -p "${FRONTEND_DIR}/src/types"
mkdir -p "${FRONTEND_DIR}/src/utils"
mkdir -p "${FRONTEND_DIR}/src/services"

echo "Validando conclusao da Etapa 74..."

if [ ! -f "${LOGS_DIR}/setup_74.log" ]; then
  echo "ERRO: setup_74.log nao encontrado. Conclua a Etapa 74 antes da Etapa 75."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_74.log"; then
  echo "ERRO: Etapa 74 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_74.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-status/attendance-status.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-status/attendance-status.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance-status/attendance-status.controller.ts" \
  "${BACKEND_DIR}/src/modules/attendance-status/attendance-status.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${FRONTEND_DIR}/src/types/attendance-status.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance-status.service.ts" \
  "${FRONTEND_DIR}/src/utils/attendance-status.ts" \
  "${DOC_FILE}" \
  "${DOC_COMPAT}" \
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

echo "Criando catalogo padronizado de status..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists attendance_status_catalog (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  status_group text not null,
  code text not null,
  label text not null,
  description text not null default '',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  is_terminal boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, status_group, code)
);

create index if not exists idx_attendance_status_catalog_tenant_group
on attendance_status_catalog (tenant_id, status_group, sort_order);

create table if not exists attendance_status_compatibility_map (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  legacy_scope text not null,
  legacy_status text not null,
  target_group text not null,
  target_status text not null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, legacy_scope, legacy_status)
);

create index if not exists idx_attendance_status_compatibility_tenant
on attendance_status_compatibility_map (tenant_id, legacy_scope, legacy_status);

insert into attendance_status_catalog (
  tenant_id,
  status_group,
  code,
  label,
  description,
  sort_order,
  is_active,
  is_terminal
)
values
  ('00000000-0000-0000-0000-000000000001', 'conversation', 'open', 'Aberta', 'Conversa tecnica aberta.', 10, true, false),
  ('00000000-0000-0000-0000-000000000001', 'conversation', 'closed', 'Fechada', 'Conversa tecnica fechada.', 20, true, true),
  ('00000000-0000-0000-0000-000000000001', 'conversation', 'archived', 'Arquivada', 'Conversa tecnica arquivada.', 30, true, true),

  ('00000000-0000-0000-0000-000000000001', 'attendance', 'novo', 'Novo', 'Atendimento recem-chegado ou ainda nao iniciado.', 10, true, false),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'em_atendimento', 'Em atendimento', 'Atendimento assumido por atendente ou equipe.', 20, true, false),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'aguardando_cliente', 'Aguardando cliente', 'Atendimento aguardando resposta do cliente.', 30, true, false),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'aguardando_atendente', 'Aguardando atendente', 'Atendimento aguardando acao interna.', 40, true, false),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'encerrado', 'Encerrado', 'Atendimento encerrado operacionalmente.', 50, true, true),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'arquivado', 'Arquivado', 'Atendimento arquivado operacionalmente.', 60, true, true),

  ('00000000-0000-0000-0000-000000000001', 'send', 'pending', 'Pendente', 'Envio aguardando processamento.', 10, true, false),
  ('00000000-0000-0000-0000-000000000001', 'send', 'sent', 'Enviado', 'Mensagem aceita para envio.', 20, true, false),
  ('00000000-0000-0000-0000-000000000001', 'send', 'delivered', 'Entregue', 'Mensagem entregue ao destinatario.', 30, true, false),
  ('00000000-0000-0000-0000-000000000001', 'send', 'read', 'Lida', 'Mensagem marcada como lida.', 40, true, true),
  ('00000000-0000-0000-0000-000000000001', 'send', 'failed', 'Falhou', 'Mensagem com falha de envio.', 50, true, true),
  ('00000000-0000-0000-0000-000000000001', 'send', 'dry_run', 'Simulacao', 'Envio validado sem envio real.', 60, true, true),

  ('00000000-0000-0000-0000-000000000001', 'closure', 'closure_created', 'Encerramento criado', 'Registro de encerramento criado.', 10, true, false),
  ('00000000-0000-0000-0000-000000000001', 'closure', 'rating_requested', 'Avaliacao solicitada', 'Avaliacao solicitada ao cliente.', 20, true, false),
  ('00000000-0000-0000-0000-000000000001', 'closure', 'rating_received', 'Avaliacao recebida', 'Cliente enviou avaliacao.', 30, true, true),
  ('00000000-0000-0000-0000-000000000001', 'closure', 'rating_not_received', 'Avaliacao nao recebida', 'Avaliacao ainda nao foi recebida.', 40, true, false)
on conflict (tenant_id, status_group, code) do update set
  label = excluded.label,
  description = excluded.description,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  is_terminal = excluded.is_terminal,
  updated_at = now();

insert into attendance_status_compatibility_map (
  tenant_id,
  legacy_scope,
  legacy_status,
  target_group,
  target_status,
  notes
)
values
  ('00000000-0000-0000-0000-000000000001', 'conversation', 'human', 'conversation', 'open', 'Status antigo human corresponde a conversa tecnica aberta.'),
  ('00000000-0000-0000-0000-000000000001', 'conversation', 'closed', 'conversation', 'closed', 'Status antigo closed corresponde a conversa tecnica fechada.'),
  ('00000000-0000-0000-0000-000000000001', 'conversation', 'open', 'conversation', 'open', 'Status tecnico aberto mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'conversation', 'archived', 'conversation', 'archived', 'Status tecnico arquivado mantido.'),

  ('00000000-0000-0000-0000-000000000001', 'attendance', 'novo', 'attendance', 'novo', 'Status operacional novo mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'em atendimento', 'attendance', 'em_atendimento', 'Status visual antigo normalizado.'),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'em_atendimento', 'attendance', 'em_atendimento', 'Status operacional mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'aguardando cliente', 'attendance', 'aguardando_cliente', 'Status visual antigo normalizado.'),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'aguardando_cliente', 'attendance', 'aguardando_cliente', 'Status operacional mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'aguardando_atendente', 'attendance', 'aguardando_atendente', 'Status operacional mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'encerrado', 'attendance', 'encerrado', 'Status operacional mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'attendance', 'arquivado', 'attendance', 'arquivado', 'Status operacional mantido.'),

  ('00000000-0000-0000-0000-000000000001', 'send', 'pending', 'send', 'pending', 'Status de envio mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'send', 'sent', 'send', 'sent', 'Status de envio mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'send', 'delivered', 'send', 'delivered', 'Status de envio mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'send', 'read', 'send', 'read', 'Status de envio mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'send', 'failed', 'send', 'failed', 'Status de envio mantido.'),
  ('00000000-0000-0000-0000-000000000001', 'send', 'dry run', 'send', 'dry_run', 'Status visual antigo normalizado.'),
  ('00000000-0000-0000-0000-000000000001', 'send', 'dry_run', 'send', 'dry_run', 'Status de simulacao mantido.')
on conflict (tenant_id, legacy_scope, legacy_status) do update set
  target_group = excluded.target_group,
  target_status = excluded.target_status,
  notes = excluded.notes,
  updated_at = now();
SQL

echo "Criando types backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-status/attendance-status.types.ts" <<'DOC'
export type AttendanceStatusGroup =
  | 'conversation'
  | 'attendance'
  | 'send'
  | 'closure';

export type AttendanceStatusCatalogItem = {
  id: string;
  group: string;
  code: string;
  label: string;
  description: string;
  sortOrder: number;
  isActive: boolean;
  isTerminal: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceStatusCompatibilityItem = {
  id: string;
  legacyScope: string;
  legacyStatus: string;
  targetGroup: string;
  targetStatus: string;
  notes: string;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceStatusModelResponse = {
  success: true;
  data: {
    groups: {
      conversation: AttendanceStatusCatalogItem[];
      attendance: AttendanceStatusCatalogItem[];
      send: AttendanceStatusCatalogItem[];
      closure: AttendanceStatusCatalogItem[];
    };
  };
  meta: Record<string, never>;
};

export type AttendanceStatusOptionsResponse = {
  success: true;
  data: {
    options: AttendanceStatusCatalogItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceStatusCompatibilityMapResponse = {
  success: true;
  data: {
    mappings: AttendanceStatusCompatibilityItem[];
  };
  meta: Record<string, never>;
};
DOC

echo "Criando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-status/attendance-status.service.ts" <<'DOC'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceStatusCatalogItem,
  AttendanceStatusCompatibilityItem,
  AttendanceStatusCompatibilityMapResponse,
  AttendanceStatusModelResponse,
  AttendanceStatusOptionsResponse
} from './attendance-status.types';

type StatusRow = {
  id: string;
  status_group: string;
  code: string;
  label: string;
  description: string;
  sort_order: number;
  is_active: boolean;
  is_terminal: boolean;
  created_at: Date;
  updated_at: Date;
};

type CompatibilityRow = {
  id: string;
  legacy_scope: string;
  legacy_status: string;
  target_group: string;
  target_status: string;
  notes: string;
  created_at: Date;
  updated_at: Date;
};

@Injectable()
export class AttendanceStatusService {
  constructor(private readonly prismaService: PrismaService) {}

  async getModel(tenantId: string): Promise<AttendanceStatusModelResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<StatusRow[]>(
      'select id, status_group, code, label, description, sort_order, is_active, is_terminal, created_at, updated_at from attendance_status_catalog where tenant_id = $1::uuid and is_active = true order by status_group asc, sort_order asc, code asc',
      tenantId
    );

    const mapped = rows.map((row) => this.mapStatus(row));

    return {
      success: true,
      data: {
        groups: {
          conversation: mapped.filter((item) => item.group === 'conversation'),
          attendance: mapped.filter((item) => item.group === 'attendance'),
          send: mapped.filter((item) => item.group === 'send'),
          closure: mapped.filter((item) => item.group === 'closure')
        }
      },
      meta: {}
    };
  }

  async getOptions(
    tenantId: string,
    group: string
  ): Promise<AttendanceStatusOptionsResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<StatusRow[]>(
      'select id, status_group, code, label, description, sort_order, is_active, is_terminal, created_at, updated_at from attendance_status_catalog where tenant_id = $1::uuid and status_group = $2 and is_active = true order by sort_order asc, code asc',
      tenantId,
      group
    );

    return {
      success: true,
      data: {
        options: rows.map((row) => this.mapStatus(row))
      },
      meta: {}
    };
  }

  async getCompatibilityMap(tenantId: string): Promise<AttendanceStatusCompatibilityMapResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<CompatibilityRow[]>(
      'select id, legacy_scope, legacy_status, target_group, target_status, notes, created_at, updated_at from attendance_status_compatibility_map where tenant_id = $1::uuid order by legacy_scope asc, legacy_status asc',
      tenantId
    );

    return {
      success: true,
      data: {
        mappings: rows.map((row) => this.mapCompatibility(row))
      },
      meta: {}
    };
  }

  private mapStatus(row: StatusRow): AttendanceStatusCatalogItem {
    return {
      id: row.id,
      group: row.status_group,
      code: row.code,
      label: row.label,
      description: row.description,
      sortOrder: row.sort_order,
      isActive: row.is_active,
      isTerminal: row.is_terminal,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }

  private mapCompatibility(row: CompatibilityRow): AttendanceStatusCompatibilityItem {
    return {
      id: row.id,
      legacyScope: row.legacy_scope,
      legacyStatus: row.legacy_status,
      targetGroup: row.target_group,
      targetStatus: row.target_status,
      notes: row.notes,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }
}
DOC

echo "Criando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-status/attendance-status.controller.ts" <<'DOC'
import {
  Controller,
  Get,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceStatusService } from './attendance-status.service';

@Controller('attendance-status')
@UseGuards(JwtAuthGuard)
export class AttendanceStatusController {
  constructor(private readonly attendanceStatusService: AttendanceStatusService) {}

  @Get('model')
  getModel(@CurrentUser() user: AuthenticatedUser) {
    return this.attendanceStatusService.getModel(user.tenantId);
  }

  @Get('options')
  getOptions(
    @CurrentUser() user: AuthenticatedUser,
    @Query('group') group: string
  ) {
    return this.attendanceStatusService.getOptions(user.tenantId, group || 'attendance');
  }

  @Get('compatibility-map')
  getCompatibilityMap(@CurrentUser() user: AuthenticatedUser) {
    return this.attendanceStatusService.getCompatibilityMap(user.tenantId);
  }
}
DOC

echo "Criando modulo backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-status/attendance-status.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceStatusController } from './attendance-status.controller';
import { AttendanceStatusService } from './attendance-status.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceStatusController
  ],
  providers: [
    AttendanceStatusService
  ]
})
export class AttendanceStatusModule {}
DOC

echo "Atualizando app.module.ts..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()
import_line = "import { AttendanceStatusModule } from './modules/attendance-status/attendance-status.module';"

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

if "AttendanceStatusModule" not in match.group(1):
    text = re.sub(r"imports:\s*\[", "imports: [\n    AttendanceStatusModule,", text, count=1)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance-status" \
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

cat > "${FRONTEND_DIR}/src/types/attendance-status.types.ts" <<'DOC'
export type AttendanceStatusCatalogItem = {
  id: string;
  group: string;
  code: string;
  label: string;
  description: string;
  sortOrder: number;
  isActive: boolean;
  isTerminal: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceStatusCompatibilityItem = {
  id: string;
  legacyScope: string;
  legacyStatus: string;
  targetGroup: string;
  targetStatus: string;
  notes: string;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceStatusModelData = {
  groups: {
    conversation: AttendanceStatusCatalogItem[];
    attendance: AttendanceStatusCatalogItem[];
    send: AttendanceStatusCatalogItem[];
    closure: AttendanceStatusCatalogItem[];
  };
};

export type AttendanceStatusOptionsData = {
  options: AttendanceStatusCatalogItem[];
};

export type AttendanceStatusCompatibilityMapData = {
  mappings: AttendanceStatusCompatibilityItem[];
};
DOC

echo "Criando service frontend..."

cat > "${FRONTEND_DIR}/src/services/attendance-status.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AttendanceStatusCompatibilityMapData,
  AttendanceStatusModelData,
  AttendanceStatusOptionsData
} from '../types/attendance-status.types';

export async function getAttendanceStatusModelRequest(token: string) {
  return apiRequest<AttendanceStatusModelData>('/attendance-status/model', {
    method: 'GET',
    token
  });
}

export async function getAttendanceStatusOptionsRequest(
  token: string,
  group: string
) {
  return apiRequest<AttendanceStatusOptionsData>('/attendance-status/options?group=' + encodeURIComponent(group), {
    method: 'GET',
    token
  });
}

export async function getAttendanceStatusCompatibilityMapRequest(token: string) {
  return apiRequest<AttendanceStatusCompatibilityMapData>('/attendance-status/compatibility-map', {
    method: 'GET',
    token
  });
}
DOC

echo "Criando util frontend de status..."

cat > "${FRONTEND_DIR}/src/utils/attendance-status.ts" <<'DOC'
export type AttendanceStatusGroup =
  | 'conversation'
  | 'attendance'
  | 'send'
  | 'closure';

type StatusLabelMap = Record<string, string>;

const conversationLabels: StatusLabelMap = {
  open: 'Aberta',
  closed: 'Fechada',
  archived: 'Arquivada',
  human: 'Aberta'
};

const attendanceLabels: StatusLabelMap = {
  novo: 'Novo',
  em_atendimento: 'Em atendimento',
  'em atendimento': 'Em atendimento',
  aguardando_cliente: 'Aguardando cliente',
  'aguardando cliente': 'Aguardando cliente',
  aguardando_atendente: 'Aguardando atendente',
  encerrado: 'Encerrado',
  arquivado: 'Arquivado'
};

const sendLabels: StatusLabelMap = {
  pending: 'Pendente',
  sent: 'Enviado',
  delivered: 'Entregue',
  read: 'Lida',
  failed: 'Falhou',
  dry_run: 'Simulacao',
  'dry run': 'Simulacao'
};

const closureLabels: StatusLabelMap = {
  closure_created: 'Encerramento criado',
  rating_requested: 'Avaliacao solicitada',
  rating_received: 'Avaliacao recebida',
  rating_not_received: 'Avaliacao nao recebida'
};

export function normalizeAttendanceStatus(
  group: AttendanceStatusGroup,
  status: string | null | undefined
) {
  const value = (status || '').trim();

  if (!value) {
    return '';
  }

  const lower = value.toLowerCase();

  if (group === 'conversation') {
    if (lower === 'human') {
      return 'open';
    }

    return lower;
  }

  if (group === 'attendance') {
    if (lower === 'em atendimento') {
      return 'em_atendimento';
    }

    if (lower === 'aguardando cliente') {
      return 'aguardando_cliente';
    }

    return lower;
  }

  if (group === 'send') {
    if (lower === 'dry run') {
      return 'dry_run';
    }

    return lower;
  }

  return lower;
}

export function getAttendanceStatusLabel(
  group: AttendanceStatusGroup,
  status: string | null | undefined
) {
  const original = (status || '').trim();

  if (!original) {
    return 'Nao informado';
  }

  const normalized = normalizeAttendanceStatus(group, original);

  if (group === 'conversation') {
    return conversationLabels[normalized] || conversationLabels[original] || original;
  }

  if (group === 'attendance') {
    return attendanceLabels[normalized] || attendanceLabels[original] || original;
  }

  if (group === 'send') {
    return sendLabels[normalized] || sendLabels[original] || original;
  }

  return closureLabels[normalized] || closureLabels[original] || original;
}

export function isTerminalAttendanceStatus(
  group: AttendanceStatusGroup,
  status: string | null | undefined
) {
  const normalized = normalizeAttendanceStatus(group, status);

  if (group === 'conversation') {
    return normalized === 'closed' || normalized === 'archived';
  }

  if (group === 'attendance') {
    return normalized === 'encerrado' || normalized === 'arquivado';
  }

  if (group === 'send') {
    return normalized === 'failed' || normalized === 'dry_run' || normalized === 'read';
  }

  return normalized === 'rating_received';
}
DOC

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/types/attendance-status.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance-status.service.ts" \
  "${FRONTEND_DIR}/src/utils/attendance-status.ts"
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

DOMAIN_HEALTH_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_BASE_URL}/api/v1/health" || true)"

if [ "${DOMAIN_HEALTH_STATUS}" != "200" ]; then
  echo "ERRO: health dominio falhou. Status ${DOMAIN_HEALTH_STATUS}"
  cat "${DOMAIN_HEALTH_LOG}"
  exit 1
fi

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
  "${DOMAIN_BASE_URL}/api/v1/auth/login" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

DOMAIN_STATUS_MODEL_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MODEL_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_BASE_URL}/api/v1/attendance-status/model" || true)"

if [ "${DOMAIN_STATUS_MODEL_STATUS}" != "200" ]; then
  echo "ERRO: attendance status model falhou. Status ${DOMAIN_STATUS_MODEL_STATUS}"
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

if ! grep -q "conversation" "${DOMAIN_STATUS_MODEL_LOG}"; then
  echo "ERRO: status model nao retornou grupo conversation."
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

if ! grep -q "attendance" "${DOMAIN_STATUS_MODEL_LOG}"; then
  echo "ERRO: status model nao retornou grupo attendance."
  cat "${DOMAIN_STATUS_MODEL_LOG}"
  exit 1
fi

DOMAIN_STATUS_OPTIONS_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_OPTIONS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_BASE_URL}/api/v1/attendance-status/options?group=attendance" || true)"

if [ "${DOMAIN_STATUS_OPTIONS_STATUS}" != "200" ]; then
  echo "ERRO: attendance status options falhou. Status ${DOMAIN_STATUS_OPTIONS_STATUS}"
  cat "${DOMAIN_STATUS_OPTIONS_LOG}"
  exit 1
fi

DOMAIN_STATUS_MAP_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_MAP_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_BASE_URL}/api/v1/attendance-status/compatibility-map" || true)"

if [ "${DOMAIN_STATUS_MAP_STATUS}" != "200" ]; then
  echo "ERRO: attendance status compatibility map falhou. Status ${DOMAIN_STATUS_MAP_STATUS}"
  cat "${DOMAIN_STATUS_MAP_LOG}"
  exit 1
fi

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_BASE_URL}/api/v1/attendance/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_LIST_STATUS}" != "200" ]; then
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

echo "Coletando contagens do catalogo..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL' | tee "${DOMAIN_STATUS_DB_COUNTS_LOG}"
select status_group, count(*) as total
from attendance_status_catalog
group by status_group
order by status_group;

select legacy_scope, count(*) as total
from attendance_status_compatibility_map
group by legacy_scope
order by legacy_scope;
SQL

echo "Validando paginas principais..."

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

echo "Gerando documentacao da Etapa 75..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Status Standardization

## Visao geral

Este documento registra a padronizacao dos status do modulo Atendimento.

## Resultado

Status:

    concluido

## Objetivo

Objetivo:

- separar status tecnico da conversa
- separar status operacional do atendimento
- separar status de envio
- separar status de encerramento e avaliacao
- manter compatibilidade com status antigos
- preparar refino visual do app inbox

## Grupos padronizados

Grupos:

- conversation
- attendance
- send
- closure

## Conversation

Uso:

- ciclo tecnico da conversa

Valores:

- open
- closed
- archived

## Attendance

Uso:

- situacao operacional do atendimento para a central

Valores:

- novo
- em_atendimento
- aguardando_cliente
- aguardando_atendente
- encerrado
- arquivado

## Send

Uso:

- situacao de uma mensagem enviada ou simulada

Valores:

- pending
- sent
- delivered
- read
- failed
- dry_run

## Closure

Uso:

- situacao de encerramento e avaliacao

Valores:

- closure_created
- rating_requested
- rating_received
- rating_not_received

## Compatibilidade

Compatibilidade:

- human para conversation open
- closed para conversation closed
- em atendimento para attendance em_atendimento
- aguardando cliente para attendance aguardando_cliente
- dry run para send dry_run

## Endpoints criados

Endpoints:

- GET api v1 attendance status model
- GET api v1 attendance status options
- GET api v1 attendance status compatibility map

## Tabelas criadas

Tabelas:

- attendance status catalog
- attendance status compatibility map

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-status/attendance-status.types.ts
- apps/backend/src/modules/attendance-status/attendance-status.service.ts
- apps/backend/src/modules/attendance-status/attendance-status.controller.ts
- apps/backend/src/modules/attendance-status/attendance-status.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-status.types.ts
- apps/frontend/src/services/attendance-status.service.ts
- apps/frontend/src/utils/attendance-status.ts
- docs/ATTENDANCE_STATUS_STANDARDIZATION.md
- docs/ATTENDANCE_STATUS_COMPATIBILITY_MAP.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente das tabelas
- seed do catalogo padronizado
- seed do mapa de compatibilidade
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- health dominio
- login dominio
- endpoint status model
- endpoint status options
- endpoint status compatibility map
- endpoint attendance conversations
- paginas principais do frontend

## Proxima etapa sugerida

Etapa 76:

    Reorganizacao visual do app inbox
DOC

cat > "${DOC_COMPAT}" <<'DOC'
# Attendance Status Compatibility Map

## Visao geral

Este documento registra o mapa de compatibilidade entre status antigos e o modelo padronizado do Atendimento.

## Objetivo

Objetivo:

- preservar compatibilidade
- evitar quebra de dados antigos
- permitir migracao gradual
- separar status por grupo funcional

## Mapeamentos principais

Mapeamentos:

- conversation human para conversation open
- conversation closed para conversation closed
- conversation open para conversation open
- conversation archived para conversation archived
- attendance novo para attendance novo
- attendance em atendimento para attendance em_atendimento
- attendance em_atendimento para attendance em_atendimento
- attendance aguardando cliente para attendance aguardando_cliente
- attendance aguardando_cliente para attendance aguardando_cliente
- attendance aguardando_atendente para attendance aguardando_atendente
- attendance encerrado para attendance encerrado
- attendance arquivado para attendance arquivado
- send pending para send pending
- send sent para send sent
- send delivered para send delivered
- send read para send read
- send failed para send failed
- send dry run para send dry_run
- send dry_run para send dry_run

## Regra operacional

Regra:

- status tecnico da conversa nao deve ser usado como status operacional
- status operacional nao deve ser usado como status de envio
- status de envio nao deve alterar automaticamente status da conversa
- status de encerramento e avaliacao deve ser tratado separadamente

## Uso futuro

Uso futuro:

- app inbox deve exibir labels usando o grupo correto
- filtros da central devem usar status operacional
- painel de falhas deve usar status de envio
- encerramento deve usar status de closure quando necessario
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 75 - Padronizacao dos status de atendimento",
    "- [x] Etapa 75 - Padronizacao dos status de atendimento\n- [ ] Etapa 76 - Reorganizacao visual do app inbox"
)

text = text.replace(
    "Etapa 75 - Padronizacao dos status de atendimento.",
    "Etapa 76 - Reorganizacao visual do app inbox."
)

text = text.replace(
    "Etapa 74 - Refino estrutural do modulo Atendimento.",
    "Etapa 75 - Padronizacao dos status de atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Padronizacao dos status de atendimento criada." not in text:
    text += "\nPadronizacao dos status de atendimento criada.\n"

for doc in [
    "- docs/ATTENDANCE_STATUS_STANDARDIZATION.md",
    "- docs/ATTENDANCE_STATUS_COMPATIBILITY_MAP.md",
]:
    if doc not in text:
        text += doc + "\n"

text = text.replace(
    "- Etapa 01 ate Etapa 74 concluidas",
    "- Etapa 01 ate Etapa 75 concluidas"
)

text = text.replace(
    "- Etapa 75 - Padronizacao dos status de atendimento",
    "- Etapa 76 - Reorganizacao visual do app inbox"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 75 - Padronizacao dos status de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criado catalogo padronizado de status para conversation, attendance, send e closure, com mapa de compatibilidade para status antigos e endpoints de consulta para backend e frontend.
DOC
  fi
done

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${DOC_COMPAT}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 75
Acao: Padronizacao dos status de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health status: ${DOMAIN_HEALTH_STATUS}
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Status model status: ${DOMAIN_STATUS_MODEL_STATUS}
Status options status: ${DOMAIN_STATUS_OPTIONS_STATUS}
Status compatibility map status: ${DOMAIN_STATUS_MAP_STATUS}
Attendance conversations status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Database counts log: logs/setup_75_status_database_counts.log
Pages status log: logs/setup_75_pages_status.log
Status: Concluido
DOC

echo ""
echo "== Etapa 75 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 76 - Reorganizacao visual do app inbox"
