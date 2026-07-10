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

LOG_FILE="${LOGS_DIR}/setup_61.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_61_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_61_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_61_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_61_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_61_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_61_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_61_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_61_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_61_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_61_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_61_attendance_conversations_domain.log"
DOMAIN_NOTES_CREATE_LOG="${LOGS_DIR}/setup_61_note_create_domain.log"
DOMAIN_NOTES_LIST_LOG="${LOGS_DIR}/setup_61_notes_list_domain.log"
DOMAIN_TAGS_LIST_LOG="${LOGS_DIR}/setup_61_tags_list_domain.log"
DOMAIN_TAG_CREATE_LOG="${LOGS_DIR}/setup_61_tag_create_domain.log"
DOMAIN_TAG_ATTACH_LOG="${LOGS_DIR}/setup_61_tag_attach_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_61_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_61_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_61_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_INTERNAL_NOTES_TAGS.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 61: Notas internas e tags =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/attendance-metadata"
mkdir -p "${FRONTEND_DIR}/src/pages/inbox"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Validando conclusao da Etapa 60..."

if [ ! -f "${LOGS_DIR}/setup_60.log" ]; then
  echo "ERRO: setup_60.log nao encontrado. Conclua a Etapa 60 antes da Etapa 61."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_60.log"; then
  echo "ERRO: Etapa 60 ainda nao esta concluida. Execute o fix final da Etapa 60 antes da Etapa 61."
  cat "${LOGS_DIR}/setup_60.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-metadata/attendance-metadata.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-metadata/attendance-metadata.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance-metadata/attendance-metadata.controller.ts" \
  "${BACKEND_DIR}/src/modules/attendance-metadata/attendance-metadata.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${FRONTEND_DIR}/src/types/attendance-metadata.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance-metadata.service.ts" \
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

echo "Criando tabelas de notas internas e tags..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists attendance_conversation_notes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  conversation_id uuid not null,
  note text not null,
  created_by_user_id uuid,
  created_by_name text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_attendance_conversation_notes_tenant
on attendance_conversation_notes (tenant_id);

create index if not exists idx_attendance_conversation_notes_conversation
on attendance_conversation_notes (tenant_id, conversation_id);

create table if not exists attendance_tags (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  name text not null,
  slug text not null,
  color text not null default '#0757c8',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, slug)
);

create index if not exists idx_attendance_tags_tenant
on attendance_tags (tenant_id);

create table if not exists attendance_conversation_tags (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  conversation_id uuid not null,
  tag_id uuid not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, conversation_id, tag_id)
);

create index if not exists idx_attendance_conversation_tags_conversation
on attendance_conversation_tags (tenant_id, conversation_id);

insert into attendance_tags (tenant_id, name, slug, color, is_active)
values
  ('00000000-0000-0000-0000-000000000001', 'lead', 'lead', '#f97316', true),
  ('00000000-0000-0000-0000-000000000001', 'cliente', 'cliente', '#16a34a', true),
  ('00000000-0000-0000-0000-000000000001', 'urgente', 'urgente', '#dc2626', true),
  ('00000000-0000-0000-0000-000000000001', 'financeiro', 'financeiro', '#7c3aed', true),
  ('00000000-0000-0000-0000-000000000001', 'suporte', 'suporte', '#2563eb', true),
  ('00000000-0000-0000-0000-000000000001', 'orcamento', 'orcamento', '#0f766e', true),
  ('00000000-0000-0000-0000-000000000001', 'reclamacao', 'reclamacao', '#b91c1c', true),
  ('00000000-0000-0000-0000-000000000001', 'pos-venda', 'pos-venda', '#475569', true)
on conflict (tenant_id, slug) do update set
  name = excluded.name,
  color = excluded.color,
  is_active = true,
  updated_at = now();
SQL

echo "Criando types backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-metadata/attendance-metadata.types.ts" <<'DOC'
export type AttendanceInternalNoteItem = {
  id: string;
  conversationId: string;
  note: string;
  createdByUserId: string | null;
  createdByName: string;
  createdAt: string;
};

export type AttendanceInternalNotesResponse = {
  success: true;
  data: {
    notes: AttendanceInternalNoteItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceInternalNotePayload = {
  note?: string;
  createdByUserId?: string | null;
  createdByName?: string | null;
};

export type AttendanceInternalNoteResponse = {
  success: true;
  data: {
    note: AttendanceInternalNoteItem;
  };
  meta: Record<string, never>;
};

export type AttendanceTagItem = {
  id: string;
  name: string;
  slug: string;
  color: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceTagsResponse = {
  success: true;
  data: {
    tags: AttendanceTagItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceTagPayload = {
  name?: string;
  color?: string;
};

export type AttendanceTagResponse = {
  success: true;
  data: {
    tag: AttendanceTagItem;
  };
  meta: Record<string, never>;
};

export type AttendanceConversationTagsResponse = {
  success: true;
  data: {
    tags: AttendanceTagItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceAttachTagPayload = {
  tagId?: string;
};
DOC

echo "Criando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-metadata/attendance-metadata.service.ts" <<'DOC'
import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceAttachTagPayload,
  AttendanceConversationTagsResponse,
  AttendanceInternalNotePayload,
  AttendanceInternalNoteResponse,
  AttendanceInternalNotesResponse,
  AttendanceTagPayload,
  AttendanceTagResponse,
  AttendanceTagsResponse
} from './attendance-metadata.types';

type NoteRow = {
  id: string;
  conversation_id: string;
  note: string;
  created_by_user_id: string | null;
  created_by_name: string;
  created_at: Date;
};

type TagRow = {
  id: string;
  name: string;
  slug: string;
  color: string;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
};

@Injectable()
export class AttendanceMetadataService {
  constructor(private readonly prismaService: PrismaService) {}

  async listNotes(
    tenantId: string,
    conversationId: string
  ): Promise<AttendanceInternalNotesResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<NoteRow[]>(
      'select id, conversation_id, note, created_by_user_id, created_by_name, created_at from attendance_conversation_notes where tenant_id = $1::uuid and conversation_id = $2::uuid order by created_at desc limit 100',
      tenantId,
      conversationId
    );

    return {
      success: true,
      data: {
        notes: rows.map((row) => this.mapNote(row))
      },
      meta: {}
    };
  }

  async createNote(
    tenantId: string,
    conversationId: string,
    payload: AttendanceInternalNotePayload
  ): Promise<AttendanceInternalNoteResponse> {
    const note = this.normalizeText(payload.note, 'Nota interna');
    const createdByName = this.normalizeText(payload.createdByName || 'Atendente', 'Nome do atendente');

    const rows = await this.prismaService.$queryRawUnsafe<NoteRow[]>(
      'insert into attendance_conversation_notes (tenant_id, conversation_id, note, created_by_user_id, created_by_name, created_at) values ($1::uuid, $2::uuid, $3, $4::uuid, $5, now()) returning id, conversation_id, note, created_by_user_id, created_by_name, created_at',
      tenantId,
      conversationId,
      note,
      payload.createdByUserId || null,
      createdByName
    );

    return {
      success: true,
      data: {
        note: this.mapNote(rows[0])
      },
      meta: {}
    };
  }

  async listTags(tenantId: string): Promise<AttendanceTagsResponse> {
    await this.ensureDefaultTags(tenantId);

    const rows = await this.prismaService.$queryRawUnsafe<TagRow[]>(
      'select id, name, slug, color, is_active, created_at, updated_at from attendance_tags where tenant_id = $1::uuid and is_active = true order by name asc',
      tenantId
    );

    return {
      success: true,
      data: {
        tags: rows.map((row) => this.mapTag(row))
      },
      meta: {}
    };
  }

  async createTag(
    tenantId: string,
    payload: AttendanceTagPayload
  ): Promise<AttendanceTagResponse> {
    const name = this.normalizeText(payload.name, 'Nome da tag');
    const slug = this.slugify(name);
    const color = payload.color || '#0757c8';

    await this.prismaService.$executeRawUnsafe(
      'insert into attendance_tags (tenant_id, name, slug, color, is_active, created_at, updated_at) values ($1::uuid, $2, $3, $4, true, now(), now()) on conflict (tenant_id, slug) do update set name = excluded.name, color = excluded.color, is_active = true, updated_at = now()',
      tenantId,
      name,
      slug,
      color
    );

    const rows = await this.prismaService.$queryRawUnsafe<TagRow[]>(
      'select id, name, slug, color, is_active, created_at, updated_at from attendance_tags where tenant_id = $1::uuid and slug = $2 limit 1',
      tenantId,
      slug
    );

    return {
      success: true,
      data: {
        tag: this.mapTag(rows[0])
      },
      meta: {}
    };
  }

  async listConversationTags(
    tenantId: string,
    conversationId: string
  ): Promise<AttendanceConversationTagsResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<TagRow[]>(
      'select t.id, t.name, t.slug, t.color, t.is_active, t.created_at, t.updated_at from attendance_tags t inner join attendance_conversation_tags ct on ct.tag_id = t.id where ct.tenant_id = $1::uuid and ct.conversation_id = $2::uuid and t.is_active = true order by t.name asc',
      tenantId,
      conversationId
    );

    return {
      success: true,
      data: {
        tags: rows.map((row) => this.mapTag(row))
      },
      meta: {}
    };
  }

  async attachTag(
    tenantId: string,
    conversationId: string,
    payload: AttendanceAttachTagPayload
  ): Promise<AttendanceConversationTagsResponse> {
    if (!payload.tagId) {
      throw new BadRequestException('Tag e obrigatoria');
    }

    await this.prismaService.$executeRawUnsafe(
      'insert into attendance_conversation_tags (tenant_id, conversation_id, tag_id, created_at) values ($1::uuid, $2::uuid, $3::uuid, now()) on conflict (tenant_id, conversation_id, tag_id) do nothing',
      tenantId,
      conversationId,
      payload.tagId
    );

    return this.listConversationTags(tenantId, conversationId);
  }

  private async ensureDefaultTags(tenantId: string) {
    const tags = [
      ['lead', 'lead', '#f97316'],
      ['cliente', 'cliente', '#16a34a'],
      ['urgente', 'urgente', '#dc2626'],
      ['financeiro', 'financeiro', '#7c3aed'],
      ['suporte', 'suporte', '#2563eb'],
      ['orcamento', 'orcamento', '#0f766e'],
      ['reclamacao', 'reclamacao', '#b91c1c'],
      ['pos-venda', 'pos-venda', '#475569']
    ];

    for (const tag of tags) {
      await this.prismaService.$executeRawUnsafe(
        'insert into attendance_tags (tenant_id, name, slug, color, is_active, created_at, updated_at) values ($1::uuid, $2, $3, $4, true, now(), now()) on conflict (tenant_id, slug) do nothing',
        tenantId,
        tag[0],
        tag[1],
        tag[2]
      );
    }
  }

  private mapNote(row: NoteRow) {
    return {
      id: row.id,
      conversationId: row.conversation_id,
      note: row.note,
      createdByUserId: row.created_by_user_id,
      createdByName: row.created_by_name,
      createdAt: row.created_at.toISOString()
    };
  }

  private mapTag(row: TagRow) {
    return {
      id: row.id,
      name: row.name,
      slug: row.slug,
      color: row.color,
      isActive: row.is_active,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }

  private normalizeText(value: string | undefined | null, label: string): string {
    const textValue = (value || '').trim();

    if (!textValue) {
      throw new BadRequestException(label + ' e obrigatorio');
    }

    if (textValue.length > 1000) {
      throw new BadRequestException(label + ' muito longo');
    }

    return textValue;
  }

  private slugify(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '') || 'tag';
  }
}
DOC

echo "Criando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-metadata/attendance-metadata.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceMetadataService } from './attendance-metadata.service';
import type {
  AttendanceAttachTagPayload,
  AttendanceInternalNotePayload,
  AttendanceTagPayload
} from './attendance-metadata.types';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceMetadataController {
  constructor(private readonly metadataService: AttendanceMetadataService) {}

  @Get('tags')
  listTags(@CurrentUser() user: AuthenticatedUser) {
    return this.metadataService.listTags(user.tenantId);
  }

  @Post('tags')
  createTag(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: AttendanceTagPayload
  ) {
    return this.metadataService.createTag(user.tenantId, body);
  }

  @Get('conversations/:conversationId/notes')
  listNotes(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.metadataService.listNotes(user.tenantId, conversationId);
  }

  @Post('conversations/:conversationId/notes')
  createNote(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceInternalNotePayload
  ) {
    return this.metadataService.createNote(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/tags')
  listConversationTags(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.metadataService.listConversationTags(user.tenantId, conversationId);
  }

  @Post('conversations/:conversationId/tags')
  attachTag(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceAttachTagPayload
  ) {
    return this.metadataService.attachTag(user.tenantId, conversationId, body);
  }
}
DOC

echo "Criando modulo backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-metadata/attendance-metadata.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceMetadataController } from './attendance-metadata.controller';
import { AttendanceMetadataService } from './attendance-metadata.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceMetadataController
  ],
  providers: [
    AttendanceMetadataService
  ]
})
export class AttendanceMetadataModule {}
DOC

echo "Atualizando app.module.ts..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()
import_line = "import { AttendanceMetadataModule } from './modules/attendance-metadata/attendance-metadata.module';"

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

if "AttendanceMetadataModule" not in match.group(1):
    text = re.sub(r"imports:\s*\[", "imports: [\n    AttendanceMetadataModule,", text, count=1)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance-metadata" \
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

cat > "${FRONTEND_DIR}/src/types/attendance-metadata.types.ts" <<'DOC'
export type AttendanceInternalNoteItem = {
  id: string;
  conversationId: string;
  note: string;
  createdByUserId: string | null;
  createdByName: string;
  createdAt: string;
};

export type AttendanceInternalNotesData = {
  notes: AttendanceInternalNoteItem[];
};

export type AttendanceInternalNoteData = {
  note: AttendanceInternalNoteItem;
};

export type AttendanceTagItem = {
  id: string;
  name: string;
  slug: string;
  color: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceTagsData = {
  tags: AttendanceTagItem[];
};
DOC

echo "Criando service frontend..."

cat > "${FRONTEND_DIR}/src/services/attendance-metadata.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AttendanceInternalNoteData,
  AttendanceInternalNotesData,
  AttendanceTagsData
} from '../types/attendance-metadata.types';

export async function listAttendanceTagsRequest(token: string) {
  return apiRequest<AttendanceTagsData>('/attendance/tags', {
    method: 'GET',
    token
  });
}

export async function createAttendanceTagRequest(
  token: string,
  payload: {
    name: string;
    color?: string;
  }
) {
  return apiRequest<AttendanceTagsData>('/attendance/tags', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listConversationNotesRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceInternalNotesData>('/attendance/conversations/' + conversationId + '/notes', {
    method: 'GET',
    token
  });
}

export async function createConversationNoteRequest(
  token: string,
  conversationId: string,
  payload: {
    note: string;
    createdByUserId?: string | null;
    createdByName: string;
  }
) {
  return apiRequest<AttendanceInternalNoteData>('/attendance/conversations/' + conversationId + '/notes', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listConversationTagsRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceTagsData>('/attendance/conversations/' + conversationId + '/tags', {
    method: 'GET',
    token
  });
}

export async function attachConversationTagRequest(
  token: string,
  conversationId: string,
  tagId: string
) {
  return apiRequest<AttendanceTagsData>('/attendance/conversations/' + conversationId + '/tags', {
    method: 'POST',
    token,
    body: {
      tagId
    }
  });
}
DOC
cat <<'EOF' >> scripts/setup_61_internal_notes_tags.sh

echo "Atualizando InboxPage.tsx com notas e tags..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "attendance-metadata.service" not in text:
    text = text.replace(
        "import { useAuthStore } from '../../stores/auth.store';",
        "import {\n  attachConversationTagRequest,\n  createConversationNoteRequest,\n  listAttendanceTagsRequest,\n  listConversationNotesRequest,\n  listConversationTagsRequest\n} from '../../services/attendance-metadata.service';\nimport { useAuthStore } from '../../stores/auth.store';"
    )

if "AttendanceInternalNoteItem" not in text:
    text = text.replace(
        "} from '../../types/attendance.types';",
        "} from '../../types/attendance.types';\nimport type {\n  AttendanceInternalNoteItem,\n  AttendanceTagItem\n} from '../../types/attendance-metadata.types';"
    )

if "const [internalNotes" not in text:
    text = text.replace(
        "const [notice, setNotice] = useState('');",
        "const [notice, setNotice] = useState('');\n  const [internalNotes, setInternalNotes] = useState<AttendanceInternalNoteItem[]>([]);\n  const [availableTags, setAvailableTags] = useState<AttendanceTagItem[]>([]);\n  const [conversationTags, setConversationTags] = useState<AttendanceTagItem[]>([]);\n  const [newInternalNote, setNewInternalNote] = useState('');\n  const [newTagName, setNewTagName] = useState('');"
    )

if "async function loadMetadata" not in text:
    marker = "  async function loadInbox() {"
    method = """  async function loadMetadata(conversationId: string) {
    const token = getToken();

    if (!token || !conversationId || conversationId.startsWith('demo-')) {
      setInternalNotes([]);
      setConversationTags([]);
      return;
    }

    const [notesResponse, tagsResponse, conversationTagsResponse] = await Promise.all([
      listConversationNotesRequest(token, conversationId),
      listAttendanceTagsRequest(token),
      listConversationTagsRequest(token, conversationId)
    ]);

    if (notesResponse.success) {
      setInternalNotes(notesResponse.data.notes);
    }

    if (tagsResponse.success) {
      setAvailableTags(tagsResponse.data.tags);
    }

    if (conversationTagsResponse.success) {
      setConversationTags(conversationTagsResponse.data.tags);
    }
  }

"""
    text = text.replace(marker, method + marker)

if "void loadMetadata(selectedConversation.id)" not in text:
    marker = """  const visibleConversations = useMemo(() => {"""
    hook = """  useEffect(() => {
    if (selectedConversation.id) {
      void loadMetadata(selectedConversation.id);
    }
  }, [selectedConversation.id]);

"""
    text = text.replace(marker, hook + marker)

if "async function handleCreateInternalNote" not in text:
    marker = "  async function handleCreateQuickReply(event: FormEvent<HTMLFormElement>) {"
    method = """  async function handleCreateInternalNote(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !newInternalNote.trim() || selectedConversation.id.startsWith('demo-')) {
      return;
    }

    const response = await createConversationNoteRequest(token, selectedConversation.id, {
      note: newInternalNote.trim(),
      createdByUserId: null,
      createdByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente'
    });

    if (response.success) {
      setNewInternalNote('');
      await loadMetadata(selectedConversation.id);
      setNotice('Nota interna criada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel criar nota interna.');
    }
  }

  async function handleAttachTag(tagId: string) {
    const token = getToken();

    if (!token || !tagId || selectedConversation.id.startsWith('demo-')) {
      return;
    }

    const response = await attachConversationTagRequest(token, selectedConversation.id, tagId);

    if (response.success) {
      setConversationTags(response.data.tags);
      setNotice('Tag vinculada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel vincular tag.');
    }
  }

"""
    text = text.replace(marker, method + marker)

if "className=\"metadata-card\"" not in text:
    marker = """          <section className="assignment-card">
            <strong>Atribuicao de responsavel</strong>"""
    addition = """          <section className="metadata-card">
            <strong>Tags da conversa</strong>
            <div className="tag-list">
              {conversationTags.length ? conversationTags.map((tag) => (
                <span key={tag.id} style={{ backgroundColor: tag.color }}>{tag.name}</span>
              )) : <small>Nenhuma tag vinculada.</small>}
            </div>

            <select onChange={(event) => void handleAttachTag(event.target.value)} value="">
              <option value="">Adicionar tag</option>
              {availableTags.map((tag) => (
                <option key={tag.id} value={tag.id}>{tag.name}</option>
              ))}
            </select>
          </section>

          <form className="metadata-card" onSubmit={handleCreateInternalNote}>
            <strong>Notas internas</strong>
            <textarea
              onChange={(event) => setNewInternalNote(event.target.value)}
              placeholder="Escreva uma nota interna para a equipe"
              value={newInternalNote}
            />
            <button type="submit">Salvar nota interna</button>

            <div className="note-list">
              {internalNotes.length ? internalNotes.map((note) => (
                <article key={note.id}>
                  <span>{note.createdByName}</span>
                  <p>{note.note}</p>
                  <small>{note.createdAt}</small>
                </article>
              )) : <small>Nenhuma nota interna registrada.</small>}
            </div>
          </form>

"""
    text = text.replace(marker, addition + marker)

path.write_text(text)
PY

echo "Adicionando CSS de notas internas e tags..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 61 - Notas internas e tags */

.metadata-card {
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 18px;
  display: grid;
  gap: 10px;
  margin-top: 16px;
  padding: 14px;
}

.metadata-card strong {
  color: var(--lh-blue-950, #04204f);
}

.metadata-card textarea,
.metadata-card select,
.metadata-card input {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 11px 13px;
  width: 100%;
}

.metadata-card textarea {
  min-height: 82px;
  resize: vertical;
}

.metadata-card button {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-700, #0a6de8));
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 11px 13px;
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.tag-list span {
  border-radius: 999px;
  color: #ffffff;
  font-size: 12px;
  font-weight: 950;
  padding: 7px 10px;
}

.note-list {
  display: grid;
  gap: 10px;
  max-height: 260px;
  overflow: auto;
}

.note-list article {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 10px;
}

.note-list span {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-weight: 900;
}

.note-list p {
  color: #374151;
  margin: 5px 0;
}

.note-list small,
.metadata-card small {
  color: var(--lh-muted, #6b7280);
}
DOC

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-metadata.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-metadata.types.ts" \
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
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

DOMAIN_TAGS_LIST_STATUS="$(curl -L -s -o "${DOMAIN_TAGS_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/tags" || true)"

if [ "${DOMAIN_TAGS_LIST_STATUS}" != "200" ]; then
  echo "ERRO: tags list falhou. Status ${DOMAIN_TAGS_LIST_STATUS}"
  cat "${DOMAIN_TAGS_LIST_LOG}"
  exit 1
fi

if ! grep -q "tags" "${DOMAIN_TAGS_LIST_LOG}"; then
  echo "ERRO: tags list nao retornou tags."
  cat "${DOMAIN_TAGS_LIST_LOG}"
  exit 1
fi

TAG_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'validacao-etapa-61', color:'#0757c8'}))")"

DOMAIN_TAG_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_TAG_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${TAG_PAYLOAD}" \
  "${DOMAIN_ATTENDANCE_URL}/tags" || true)"

if [ "${DOMAIN_TAG_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_TAG_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: tag create falhou. Status ${DOMAIN_TAG_CREATE_STATUS}"
  cat "${DOMAIN_TAG_CREATE_LOG}"
  exit 1
fi

TAG_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const tag=data.data&&data.data.tag; if(tag){console.log(tag.id)}" "${DOMAIN_TAG_CREATE_LOG}" || true)"

DOMAIN_NOTES_CREATE_STATUS="SKIPPED"
DOMAIN_NOTES_LIST_STATUS="SKIPPED"
DOMAIN_TAG_ATTACH_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  NOTE_PAYLOAD="$(node -e "console.log(JSON.stringify({note:'Nota interna de validacao da Etapa 61.', createdByUserId:null, createdByName:'Validacao Etapa 61'}))")"

  DOMAIN_NOTES_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_NOTES_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${NOTE_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/notes" || true)"

  if [ "${DOMAIN_NOTES_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_NOTES_CREATE_STATUS}" != "201" ]; then
    echo "ERRO: note create falhou. Status ${DOMAIN_NOTES_CREATE_STATUS}"
    cat "${DOMAIN_NOTES_CREATE_LOG}"
    exit 1
  fi

  DOMAIN_NOTES_LIST_STATUS="$(curl -L -s -o "${DOMAIN_NOTES_LIST_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/notes" || true)"

  if [ "${DOMAIN_NOTES_LIST_STATUS}" != "200" ]; then
    echo "ERRO: notes list falhou. Status ${DOMAIN_NOTES_LIST_STATUS}"
    cat "${DOMAIN_NOTES_LIST_LOG}"
    exit 1
  fi

  if [ -n "${TAG_ID}" ]; then
    ATTACH_PAYLOAD="$(node -e "console.log(JSON.stringify({tagId:process.argv[1]}))" "${TAG_ID}")"

    DOMAIN_TAG_ATTACH_STATUS="$(curl -L -s -o "${DOMAIN_TAG_ATTACH_LOG}" -w "%{http_code}" --max-time 30 \
      -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${ATTACH_PAYLOAD}" \
      "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/tags" || true)"

    if [ "${DOMAIN_TAG_ATTACH_STATUS}" != "200" ] && [ "${DOMAIN_TAG_ATTACH_STATUS}" != "201" ]; then
      echo "ERRO: tag attach falhou. Status ${DOMAIN_TAG_ATTACH_STATUS}"
      cat "${DOMAIN_TAG_ATTACH_LOG}"
      exit 1
    fi
  else
    echo '{"skipped":"tag id ausente"}' > "${DOMAIN_TAG_ATTACH_LOG}"
  fi
else
  echo '{"skipped":"sem conversa real para nota"}' > "${DOMAIN_NOTES_CREATE_LOG}"
  echo '{"skipped":"sem conversa real para listar notas"}' > "${DOMAIN_NOTES_LIST_LOG}"
  echo '{"skipped":"sem conversa real para tag"}' > "${DOMAIN_TAG_ATTACH_LOG}"
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

echo "Gerando documentacao da Etapa 61..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Internal Notes Tags

## Visao geral

Este documento registra a criacao de notas internas e tags para a central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela de notas internas por conversa
- tabela de tags por tenant
- tabela de vinculo de tags com conversas
- seed inicial de tags
- endpoint para listar notas internas
- endpoint para criar nota interna
- endpoint para listar tags
- endpoint para criar tag
- endpoint para listar tags de uma conversa
- endpoint para vincular tag a uma conversa
- painel visual de tags na central app inbox
- painel visual de notas internas na central app inbox

## Tags iniciais

Tags:

- lead
- cliente
- urgente
- financeiro
- suporte
- orcamento
- reclamacao
- pos-venda

## Endpoints criados

Endpoints:

- GET api v1 attendance tags
- POST api v1 attendance tags
- GET api v1 attendance conversations conversation id notes
- POST api v1 attendance conversations conversation id notes
- GET api v1 attendance conversations conversation id tags
- POST api v1 attendance conversations conversation id tags

## Tabelas criadas

Tabelas:

- attendance conversation notes
- attendance tags
- attendance conversation tags

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-metadata/attendance-metadata.types.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.service.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.controller.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-metadata.types.ts
- apps/frontend/src/services/attendance-metadata.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente das tabelas
- seed inicial de tags
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint tags dominio
- criacao de tag dominio
- criacao de nota interna quando ha conversa real
- listagem de notas quando ha conversa real
- vinculo de tag quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_61_backend_typecheck.log
- logs/setup_61_backend_build.log
- logs/setup_61_frontend_typecheck.log
- logs/setup_61_frontend_build.log
- logs/setup_61_backend_docker_build.log
- logs/setup_61_frontend_docker_build.log
- logs/setup_61_docker_up.log
- logs/setup_61_backend_wait.log
- logs/setup_61_auth_login_domain.log
- logs/setup_61_attendance_conversations_domain.log
- logs/setup_61_note_create_domain.log
- logs/setup_61_notes_list_domain.log
- logs/setup_61_tags_list_domain.log
- logs/setup_61_tag_create_domain.log
- logs/setup_61_tag_attach_domain.log
- logs/setup_61_domain_inbox_page.log
- logs/setup_61_domain_dashboard.log
- logs/setup_61_domain_audit_page.log
- logs/setup_61.log

## Proxima etapa sugerida

Etapa 62:

    Criar encerramento com avaliacao do atendimento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 61 - Criar notas internas e tags",
    "- [x] Etapa 61 - Criar notas internas e tags\n- [ ] Etapa 62 - Criar encerramento com avaliacao do atendimento"
)

text = text.replace(
    "Etapa 61 - Criar notas internas e tags.",
    "Etapa 62 - Criar encerramento com avaliacao do atendimento."
)

text = text.replace(
    "Etapa 60 - Criar respostas rapidas por departamento.",
    "Etapa 61 - Criar notas internas e tags."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Notas internas e tags criadas." not in text:
    text = text.replace(
        "Respostas rapidas por departamento criadas.",
        "Respostas rapidas por departamento criadas.\n\nNotas internas e tags criadas."
    )

if "- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_QUICK_REPLIES.md",
        "- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md\n- docs/ATTENDANCE_QUICK_REPLIES.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 60 concluidas",
    "- Etapa 01 ate Etapa 61 concluidas"
)

text = text.replace(
    "- Etapa 61 - Criar notas internas e tags",
    "- Etapa 62 - Criar encerramento com avaliacao do atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 61 - Criar notas internas e tags
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criadas notas internas por conversa, tags por tenant, vinculo de tags com conversas e paineis visuais correspondentes na central app inbox.
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
Etapa: 61
Acao: Criar notas internas e tags
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Tags list status: ${DOMAIN_TAGS_LIST_STATUS}
Tag create status: ${DOMAIN_TAG_CREATE_STATUS}
Note create status: ${DOMAIN_NOTES_CREATE_STATUS}
Notes list status: ${DOMAIN_NOTES_LIST_STATUS}
Tag attach status: ${DOMAIN_TAG_ATTACH_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 61 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 62 - Criar encerramento com avaliacao do atendimento"

echo "Atualizando InboxPage.tsx com notas e tags..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "attendance-metadata.service" not in text:
    text = text.replace(
        "import { useAuthStore } from '../../stores/auth.store';",
        "import {\n  attachConversationTagRequest,\n  createConversationNoteRequest,\n  listAttendanceTagsRequest,\n  listConversationNotesRequest,\n  listConversationTagsRequest\n} from '../../services/attendance-metadata.service';\nimport { useAuthStore } from '../../stores/auth.store';"
    )

if "AttendanceInternalNoteItem" not in text:
    text = text.replace(
        "} from '../../types/attendance.types';",
        "} from '../../types/attendance.types';\nimport type {\n  AttendanceInternalNoteItem,\n  AttendanceTagItem\n} from '../../types/attendance-metadata.types';"
    )

if "const [internalNotes" not in text:
    text = text.replace(
        "const [notice, setNotice] = useState('');",
        "const [notice, setNotice] = useState('');\n  const [internalNotes, setInternalNotes] = useState<AttendanceInternalNoteItem[]>([]);\n  const [availableTags, setAvailableTags] = useState<AttendanceTagItem[]>([]);\n  const [conversationTags, setConversationTags] = useState<AttendanceTagItem[]>([]);\n  const [newInternalNote, setNewInternalNote] = useState('');\n  const [newTagName, setNewTagName] = useState('');"
    )

if "async function loadMetadata" not in text:
    marker = "  async function loadInbox() {"
    method = """  async function loadMetadata(conversationId: string) {
    const token = getToken();

    if (!token || !conversationId || conversationId.startsWith('demo-')) {
      setInternalNotes([]);
      setConversationTags([]);
      return;
    }

    const [notesResponse, tagsResponse, conversationTagsResponse] = await Promise.all([
      listConversationNotesRequest(token, conversationId),
      listAttendanceTagsRequest(token),
      listConversationTagsRequest(token, conversationId)
    ]);

    if (notesResponse.success) {
      setInternalNotes(notesResponse.data.notes);
    }

    if (tagsResponse.success) {
      setAvailableTags(tagsResponse.data.tags);
    }

    if (conversationTagsResponse.success) {
      setConversationTags(conversationTagsResponse.data.tags);
    }
  }

"""
    text = text.replace(marker, method + marker)

if "void loadMetadata(selectedConversation.id)" not in text:
    marker = """  const visibleConversations = useMemo(() => {"""
    hook = """  useEffect(() => {
    if (selectedConversation.id) {
      void loadMetadata(selectedConversation.id);
    }
  }, [selectedConversation.id]);

"""
    text = text.replace(marker, hook + marker)

if "async function handleCreateInternalNote" not in text:
    marker = "  async function handleCreateQuickReply(event: FormEvent<HTMLFormElement>) {"
    method = """  async function handleCreateInternalNote(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !newInternalNote.trim() || selectedConversation.id.startsWith('demo-')) {
      return;
    }

    const response = await createConversationNoteRequest(token, selectedConversation.id, {
      note: newInternalNote.trim(),
      createdByUserId: null,
      createdByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente'
    });

    if (response.success) {
      setNewInternalNote('');
      await loadMetadata(selectedConversation.id);
      setNotice('Nota interna criada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel criar nota interna.');
    }
  }

  async function handleAttachTag(tagId: string) {
    const token = getToken();

    if (!token || !tagId || selectedConversation.id.startsWith('demo-')) {
      return;
    }

    const response = await attachConversationTagRequest(token, selectedConversation.id, tagId);

    if (response.success) {
      setConversationTags(response.data.tags);
      setNotice('Tag vinculada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel vincular tag.');
    }
  }

"""
    text = text.replace(marker, method + marker)

if "className=\"metadata-card\"" not in text:
    marker = """          <section className="assignment-card">
            <strong>Atribuicao de responsavel</strong>"""
    addition = """          <section className="metadata-card">
            <strong>Tags da conversa</strong>
            <div className="tag-list">
              {conversationTags.length ? conversationTags.map((tag) => (
                <span key={tag.id} style={{ backgroundColor: tag.color }}>{tag.name}</span>
              )) : <small>Nenhuma tag vinculada.</small>}
            </div>

            <select onChange={(event) => void handleAttachTag(event.target.value)} value="">
              <option value="">Adicionar tag</option>
              {availableTags.map((tag) => (
                <option key={tag.id} value={tag.id}>{tag.name}</option>
              ))}
            </select>
          </section>

          <form className="metadata-card" onSubmit={handleCreateInternalNote}>
            <strong>Notas internas</strong>
            <textarea
              onChange={(event) => setNewInternalNote(event.target.value)}
              placeholder="Escreva uma nota interna para a equipe"
              value={newInternalNote}
            />
            <button type="submit">Salvar nota interna</button>

            <div className="note-list">
              {internalNotes.length ? internalNotes.map((note) => (
                <article key={note.id}>
                  <span>{note.createdByName}</span>
                  <p>{note.note}</p>
                  <small>{note.createdAt}</small>
                </article>
              )) : <small>Nenhuma nota interna registrada.</small>}
            </div>
          </form>

"""
    text = text.replace(marker, addition + marker)

path.write_text(text)
PY

echo "Adicionando CSS de notas internas e tags..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 61 - Notas internas e tags */

.metadata-card {
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 18px;
  display: grid;
  gap: 10px;
  margin-top: 16px;
  padding: 14px;
}

.metadata-card strong {
  color: var(--lh-blue-950, #04204f);
}

.metadata-card textarea,
.metadata-card select,
.metadata-card input {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 11px 13px;
  width: 100%;
}

.metadata-card textarea {
  min-height: 82px;
  resize: vertical;
}

.metadata-card button {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-700, #0a6de8));
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 11px 13px;
}

.tag-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.tag-list span {
  border-radius: 999px;
  color: #ffffff;
  font-size: 12px;
  font-weight: 950;
  padding: 7px 10px;
}

.note-list {
  display: grid;
  gap: 10px;
  max-height: 260px;
  overflow: auto;
}

.note-list article {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 10px;
}

.note-list span {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-weight: 900;
}

.note-list p {
  color: #374151;
  margin: 5px 0;
}

.note-list small,
.metadata-card small {
  color: var(--lh-muted, #6b7280);
}
DOC

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-metadata.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-metadata.types.ts" \
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
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

DOMAIN_TAGS_LIST_STATUS="$(curl -L -s -o "${DOMAIN_TAGS_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/tags" || true)"

if [ "${DOMAIN_TAGS_LIST_STATUS}" != "200" ]; then
  echo "ERRO: tags list falhou. Status ${DOMAIN_TAGS_LIST_STATUS}"
  cat "${DOMAIN_TAGS_LIST_LOG}"
  exit 1
fi

if ! grep -q "tags" "${DOMAIN_TAGS_LIST_LOG}"; then
  echo "ERRO: tags list nao retornou tags."
  cat "${DOMAIN_TAGS_LIST_LOG}"
  exit 1
fi

TAG_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'validacao-etapa-61', color:'#0757c8'}))")"

DOMAIN_TAG_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_TAG_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${TAG_PAYLOAD}" \
  "${DOMAIN_ATTENDANCE_URL}/tags" || true)"

if [ "${DOMAIN_TAG_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_TAG_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: tag create falhou. Status ${DOMAIN_TAG_CREATE_STATUS}"
  cat "${DOMAIN_TAG_CREATE_LOG}"
  exit 1
fi

TAG_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const tag=data.data&&data.data.tag; if(tag){console.log(tag.id)}" "${DOMAIN_TAG_CREATE_LOG}" || true)"

DOMAIN_NOTES_CREATE_STATUS="SKIPPED"
DOMAIN_NOTES_LIST_STATUS="SKIPPED"
DOMAIN_TAG_ATTACH_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  NOTE_PAYLOAD="$(node -e "console.log(JSON.stringify({note:'Nota interna de validacao da Etapa 61.', createdByUserId:null, createdByName:'Validacao Etapa 61'}))")"

  DOMAIN_NOTES_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_NOTES_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${NOTE_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/notes" || true)"

  if [ "${DOMAIN_NOTES_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_NOTES_CREATE_STATUS}" != "201" ]; then
    echo "ERRO: note create falhou. Status ${DOMAIN_NOTES_CREATE_STATUS}"
    cat "${DOMAIN_NOTES_CREATE_LOG}"
    exit 1
  fi

  DOMAIN_NOTES_LIST_STATUS="$(curl -L -s -o "${DOMAIN_NOTES_LIST_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/notes" || true)"

  if [ "${DOMAIN_NOTES_LIST_STATUS}" != "200" ]; then
    echo "ERRO: notes list falhou. Status ${DOMAIN_NOTES_LIST_STATUS}"
    cat "${DOMAIN_NOTES_LIST_LOG}"
    exit 1
  fi

  if [ -n "${TAG_ID}" ]; then
    ATTACH_PAYLOAD="$(node -e "console.log(JSON.stringify({tagId:process.argv[1]}))" "${TAG_ID}")"

    DOMAIN_TAG_ATTACH_STATUS="$(curl -L -s -o "${DOMAIN_TAG_ATTACH_LOG}" -w "%{http_code}" --max-time 30 \
      -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "${ATTACH_PAYLOAD}" \
      "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/tags" || true)"

    if [ "${DOMAIN_TAG_ATTACH_STATUS}" != "200" ] && [ "${DOMAIN_TAG_ATTACH_STATUS}" != "201" ]; then
      echo "ERRO: tag attach falhou. Status ${DOMAIN_TAG_ATTACH_STATUS}"
      cat "${DOMAIN_TAG_ATTACH_LOG}"
      exit 1
    fi
  else
    echo '{"skipped":"tag id ausente"}' > "${DOMAIN_TAG_ATTACH_LOG}"
  fi
else
  echo '{"skipped":"sem conversa real para nota"}' > "${DOMAIN_NOTES_CREATE_LOG}"
  echo '{"skipped":"sem conversa real para listar notas"}' > "${DOMAIN_NOTES_LIST_LOG}"
  echo '{"skipped":"sem conversa real para tag"}' > "${DOMAIN_TAG_ATTACH_LOG}"
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

echo "Gerando documentacao da Etapa 61..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Internal Notes Tags

## Visao geral

Este documento registra a criacao de notas internas e tags para a central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela de notas internas por conversa
- tabela de tags por tenant
- tabela de vinculo de tags com conversas
- seed inicial de tags
- endpoint para listar notas internas
- endpoint para criar nota interna
- endpoint para listar tags
- endpoint para criar tag
- endpoint para listar tags de uma conversa
- endpoint para vincular tag a uma conversa
- painel visual de tags na central app inbox
- painel visual de notas internas na central app inbox

## Tags iniciais

Tags:

- lead
- cliente
- urgente
- financeiro
- suporte
- orcamento
- reclamacao
- pos-venda

## Endpoints criados

Endpoints:

- GET api v1 attendance tags
- POST api v1 attendance tags
- GET api v1 attendance conversations conversation id notes
- POST api v1 attendance conversations conversation id notes
- GET api v1 attendance conversations conversation id tags
- POST api v1 attendance conversations conversation id tags

## Tabelas criadas

Tabelas:

- attendance conversation notes
- attendance tags
- attendance conversation tags

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-metadata/attendance-metadata.types.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.service.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.controller.ts
- apps/backend/src/modules/attendance-metadata/attendance-metadata.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-metadata.types.ts
- apps/frontend/src/services/attendance-metadata.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente das tabelas
- seed inicial de tags
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint tags dominio
- criacao de tag dominio
- criacao de nota interna quando ha conversa real
- listagem de notas quando ha conversa real
- vinculo de tag quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_61_backend_typecheck.log
- logs/setup_61_backend_build.log
- logs/setup_61_frontend_typecheck.log
- logs/setup_61_frontend_build.log
- logs/setup_61_backend_docker_build.log
- logs/setup_61_frontend_docker_build.log
- logs/setup_61_docker_up.log
- logs/setup_61_backend_wait.log
- logs/setup_61_auth_login_domain.log
- logs/setup_61_attendance_conversations_domain.log
- logs/setup_61_note_create_domain.log
- logs/setup_61_notes_list_domain.log
- logs/setup_61_tags_list_domain.log
- logs/setup_61_tag_create_domain.log
- logs/setup_61_tag_attach_domain.log
- logs/setup_61_domain_inbox_page.log
- logs/setup_61_domain_dashboard.log
- logs/setup_61_domain_audit_page.log
- logs/setup_61.log

## Proxima etapa sugerida

Etapa 62:

    Criar encerramento com avaliacao do atendimento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 61 - Criar notas internas e tags",
    "- [x] Etapa 61 - Criar notas internas e tags\n- [ ] Etapa 62 - Criar encerramento com avaliacao do atendimento"
)

text = text.replace(
    "Etapa 61 - Criar notas internas e tags.",
    "Etapa 62 - Criar encerramento com avaliacao do atendimento."
)

text = text.replace(
    "Etapa 60 - Criar respostas rapidas por departamento.",
    "Etapa 61 - Criar notas internas e tags."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Notas internas e tags criadas." not in text:
    text = text.replace(
        "Respostas rapidas por departamento criadas.",
        "Respostas rapidas por departamento criadas.\n\nNotas internas e tags criadas."
    )

if "- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_QUICK_REPLIES.md",
        "- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md\n- docs/ATTENDANCE_QUICK_REPLIES.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 60 concluidas",
    "- Etapa 01 ate Etapa 61 concluidas"
)

text = text.replace(
    "- Etapa 61 - Criar notas internas e tags",
    "- Etapa 62 - Criar encerramento com avaliacao do atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 61 - Criar notas internas e tags
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criadas notas internas por conversa, tags por tenant, vinculo de tags com conversas e paineis visuais correspondentes na central app inbox.
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
Etapa: 61
Acao: Criar notas internas e tags
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Tags list status: ${DOMAIN_TAGS_LIST_STATUS}
Tag create status: ${DOMAIN_TAG_CREATE_STATUS}
Note create status: ${DOMAIN_NOTES_CREATE_STATUS}
Notes list status: ${DOMAIN_NOTES_LIST_STATUS}
Tag attach status: ${DOMAIN_TAG_ATTACH_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 61 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 62 - Criar encerramento com avaliacao do atendimento"
