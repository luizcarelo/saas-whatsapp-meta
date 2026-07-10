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

LOG_FILE="${LOGS_DIR}/setup_62.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_62_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_62_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_62_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_62_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_62_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_62_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_62_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_62_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_62_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_62_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_62_attendance_conversations_domain.log"
DOMAIN_CLOSE_LOG="${LOGS_DIR}/setup_62_close_conversation_domain.log"
DOMAIN_CLOSURES_LOG="${LOGS_DIR}/setup_62_closures_domain.log"
DOMAIN_RATING_CREATE_LOG="${LOGS_DIR}/setup_62_rating_create_domain.log"
DOMAIN_RATINGS_LOG="${LOGS_DIR}/setup_62_ratings_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_62_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_62_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_62_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_CLOSURE_RATING.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 62: Encerramento com avaliacao do atendimento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/attendance-closure"
mkdir -p "${FRONTEND_DIR}/src/pages/inbox"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Validando conclusao da Etapa 61..."

if [ ! -f "${LOGS_DIR}/setup_61.log" ]; then
  echo "ERRO: setup_61.log nao encontrado. Conclua a Etapa 61 antes da Etapa 62."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_61.log"; then
  echo "ERRO: Etapa 61 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_61.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-closure/attendance-closure.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-closure/attendance-closure.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance-closure/attendance-closure.controller.ts" \
  "${BACKEND_DIR}/src/modules/attendance-closure/attendance-closure.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${FRONTEND_DIR}/src/types/attendance-closure.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance-closure.service.ts" \
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

echo "Criando tabelas de encerramento e avaliacao..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists attendance_conversation_closures (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  conversation_id uuid not null,
  closing_message text not null,
  closed_by_user_id uuid,
  closed_by_name text not null,
  department_name text not null default 'Fila geral',
  rating_requested boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_attendance_conversation_closures_tenant
on attendance_conversation_closures (tenant_id);

create index if not exists idx_attendance_conversation_closures_conversation
on attendance_conversation_closures (tenant_id, conversation_id);

create table if not exists attendance_conversation_ratings (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  conversation_id uuid not null,
  rating integer not null,
  comment text,
  created_at timestamptz not null default now(),
  constraint attendance_conversation_ratings_rating_check check (rating >= 1 and rating <= 5)
);

create index if not exists idx_attendance_conversation_ratings_tenant
on attendance_conversation_ratings (tenant_id);

create index if not exists idx_attendance_conversation_ratings_conversation
on attendance_conversation_ratings (tenant_id, conversation_id);

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

echo "Criando types backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-closure/attendance-closure.types.ts" <<'DOC'
export type AttendanceClosureItem = {
  id: string;
  conversationId: string;
  closingMessage: string;
  closedByUserId: string | null;
  closedByName: string;
  departmentName: string;
  ratingRequested: boolean;
  createdAt: string;
};

export type AttendanceClosurePayload = {
  closingMessage?: string;
  closedByUserId?: string | null;
  closedByName?: string | null;
  departmentName?: string;
  ratingRequested?: boolean;
};

export type AttendanceClosureResponse = {
  success: true;
  data: {
    closure: AttendanceClosureItem;
  };
  meta: Record<string, never>;
};

export type AttendanceClosuresResponse = {
  success: true;
  data: {
    closures: AttendanceClosureItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceRatingItem = {
  id: string;
  conversationId: string;
  rating: number;
  comment: string | null;
  createdAt: string;
};

export type AttendanceRatingPayload = {
  rating?: number;
  comment?: string | null;
};

export type AttendanceRatingResponse = {
  success: true;
  data: {
    rating: AttendanceRatingItem;
  };
  meta: Record<string, never>;
};

export type AttendanceRatingsResponse = {
  success: true;
  data: {
    ratings: AttendanceRatingItem[];
  };
  meta: Record<string, never>;
};
DOC

echo "Criando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-closure/attendance-closure.service.ts" <<'DOC'
import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceClosurePayload,
  AttendanceClosureResponse,
  AttendanceClosuresResponse,
  AttendanceRatingPayload,
  AttendanceRatingResponse,
  AttendanceRatingsResponse
} from './attendance-closure.types';

type ClosureRow = {
  id: string;
  conversation_id: string;
  closing_message: string;
  closed_by_user_id: string | null;
  closed_by_name: string;
  department_name: string;
  rating_requested: boolean;
  created_at: Date;
};

type RatingRow = {
  id: string;
  conversation_id: string;
  rating: number;
  comment: string | null;
  created_at: Date;
};

@Injectable()
export class AttendanceClosureService {
  constructor(private readonly prismaService: PrismaService) {}

  async closeConversation(
    tenantId: string,
    conversationId: string,
    payload: AttendanceClosurePayload
  ): Promise<AttendanceClosureResponse> {
    const closedByName = this.normalizeText(payload.closedByName || 'Atendente', 'Nome do atendente');
    const departmentName = payload.departmentName || 'Fila geral';
    const ratingRequested = typeof payload.ratingRequested === 'boolean' ? payload.ratingRequested : true;
    const closingMessage = payload.closingMessage?.trim() || this.defaultClosingMessage();

    const rows = await this.prismaService.$queryRawUnsafe<ClosureRow[]>(
      'insert into attendance_conversation_closures (tenant_id, conversation_id, closing_message, closed_by_user_id, closed_by_name, department_name, rating_requested, created_at) values ($1::uuid, $2::uuid, $3, $4::uuid, $5, $6, $7, now()) returning id, conversation_id, closing_message, closed_by_user_id, closed_by_name, department_name, rating_requested, created_at',
      tenantId,
      conversationId,
      closingMessage,
      payload.closedByUserId || null,
      closedByName,
      departmentName,
      ratingRequested
    );

    await this.prismaService.$executeRawUnsafe(
      'insert into conversation_operational_status (tenant_id, conversation_id, status, priority, department_name, assigned_user_id, assigned_user_name, created_at, updated_at) values ($1::uuid, $2::uuid, $3, $4, $5, $6::uuid, $7, now(), now()) on conflict (tenant_id, conversation_id) do update set status = excluded.status, department_name = excluded.department_name, assigned_user_id = excluded.assigned_user_id, assigned_user_name = excluded.assigned_user_name, updated_at = now()',
      tenantId,
      conversationId,
      'encerrado',
      'normal',
      departmentName,
      payload.closedByUserId || null,
      closedByName
    );

    return {
      success: true,
      data: {
        closure: this.mapClosure(rows[0])
      },
      meta: {}
    };
  }

  async listClosures(
    tenantId: string,
    conversationId: string
  ): Promise<AttendanceClosuresResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<ClosureRow[]>(
      'select id, conversation_id, closing_message, closed_by_user_id, closed_by_name, department_name, rating_requested, created_at from attendance_conversation_closures where tenant_id = $1::uuid and conversation_id = $2::uuid order by created_at desc limit 50',
      tenantId,
      conversationId
    );

    return {
      success: true,
      data: {
        closures: rows.map((row) => this.mapClosure(row))
      },
      meta: {}
    };
  }

  async createRating(
    tenantId: string,
    conversationId: string,
    payload: AttendanceRatingPayload
  ): Promise<AttendanceRatingResponse> {
    const rating = Number(payload.rating);

    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw new BadRequestException('Avaliacao deve ser um numero entre 1 e 5');
    }

    const comment = payload.comment ? payload.comment.trim() : null;

    const rows = await this.prismaService.$queryRawUnsafe<RatingRow[]>(
      'insert into attendance_conversation_ratings (tenant_id, conversation_id, rating, comment, created_at) values ($1::uuid, $2::uuid, $3, $4, now()) returning id, conversation_id, rating, comment, created_at',
      tenantId,
      conversationId,
      rating,
      comment
    );

    return {
      success: true,
      data: {
        rating: this.mapRating(rows[0])
      },
      meta: {}
    };
  }

  async listRatings(
    tenantId: string,
    conversationId: string
  ): Promise<AttendanceRatingsResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<RatingRow[]>(
      'select id, conversation_id, rating, comment, created_at from attendance_conversation_ratings where tenant_id = $1::uuid and conversation_id = $2::uuid order by created_at desc limit 50',
      tenantId,
      conversationId
    );

    return {
      success: true,
      data: {
        ratings: rows.map((row) => this.mapRating(row))
      },
      meta: {}
    };
  }

  private defaultClosingMessage(): string {
    return [
      'Atendimento finalizado.',
      '',
      'Como voce avalia nosso atendimento de 1 a 5?',
      '',
      '1 - Muito ruim',
      '2 - Ruim',
      '3 - Regular',
      '4 - Bom',
      '5 - Excelente',
      '',
      'Obrigado por falar com a LH Solucao.'
    ].join('\n');
  }

  private mapClosure(row: ClosureRow) {
    return {
      id: row.id,
      conversationId: row.conversation_id,
      closingMessage: row.closing_message,
      closedByUserId: row.closed_by_user_id,
      closedByName: row.closed_by_name,
      departmentName: row.department_name,
      ratingRequested: row.rating_requested,
      createdAt: row.created_at.toISOString()
    };
  }

  private mapRating(row: RatingRow) {
    return {
      id: row.id,
      conversationId: row.conversation_id,
      rating: row.rating,
      comment: row.comment,
      createdAt: row.created_at.toISOString()
    };
  }

  private normalizeText(value: string | undefined | null, label: string): string {
    const textValue = (value || '').trim();

    if (!textValue) {
      throw new BadRequestException(label + ' e obrigatorio');
    }

    if (textValue.length > 300) {
      throw new BadRequestException(label + ' muito longo');
    }

    return textValue;
  }
}
DOC

echo "Criando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-closure/attendance-closure.controller.ts" <<'DOC'
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
import { AttendanceClosureService } from './attendance-closure.service';
import type {
  AttendanceClosurePayload,
  AttendanceRatingPayload
} from './attendance-closure.types';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceClosureController {
  constructor(private readonly closureService: AttendanceClosureService) {}

  @Post('conversations/:conversationId/close')
  closeConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceClosurePayload
  ) {
    return this.closureService.closeConversation(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/closures')
  listClosures(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.closureService.listClosures(user.tenantId, conversationId);
  }

  @Post('conversations/:conversationId/rating')
  createRating(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceRatingPayload
  ) {
    return this.closureService.createRating(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/ratings')
  listRatings(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.closureService.listRatings(user.tenantId, conversationId);
  }
}
DOC

echo "Criando modulo backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-closure/attendance-closure.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceClosureController } from './attendance-closure.controller';
import { AttendanceClosureService } from './attendance-closure.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceClosureController
  ],
  providers: [
    AttendanceClosureService
  ]
})
export class AttendanceClosureModule {}
DOC

echo "Atualizando app.module.ts..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()
import_line = "import { AttendanceClosureModule } from './modules/attendance-closure/attendance-closure.module';"

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

if "AttendanceClosureModule" not in match.group(1):
    text = re.sub(r"imports:\s*\[", "imports: [\n    AttendanceClosureModule,", text, count=1)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance-closure" \
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

cat > "${FRONTEND_DIR}/src/types/attendance-closure.types.ts" <<'DOC'
export type AttendanceClosureItem = {
  id: string;
  conversationId: string;
  closingMessage: string;
  closedByUserId: string | null;
  closedByName: string;
  departmentName: string;
  ratingRequested: boolean;
  createdAt: string;
};

export type AttendanceClosureData = {
  closure: AttendanceClosureItem;
};

export type AttendanceClosuresData = {
  closures: AttendanceClosureItem[];
};

export type AttendanceRatingItem = {
  id: string;
  conversationId: string;
  rating: number;
  comment: string | null;
  createdAt: string;
};

export type AttendanceRatingData = {
  rating: AttendanceRatingItem;
};

export type AttendanceRatingsData = {
  ratings: AttendanceRatingItem[];
};
DOC

echo "Criando service frontend..."

cat > "${FRONTEND_DIR}/src/services/attendance-closure.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AttendanceClosureData,
  AttendanceClosuresData,
  AttendanceRatingData,
  AttendanceRatingsData
} from '../types/attendance-closure.types';

export async function closeAttendanceConversationRequest(
  token: string,
  conversationId: string,
  payload: {
    closingMessage: string;
    closedByUserId?: string | null;
    closedByName: string;
    departmentName: string;
    ratingRequested: boolean;
  }
) {
  return apiRequest<AttendanceClosureData>('/attendance/conversations/' + conversationId + '/close', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceClosuresRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceClosuresData>('/attendance/conversations/' + conversationId + '/closures', {
    method: 'GET',
    token
  });
}

export async function createAttendanceRatingRequest(
  token: string,
  conversationId: string,
  payload: {
    rating: number;
    comment?: string | null;
  }
) {
  return apiRequest<AttendanceRatingData>('/attendance/conversations/' + conversationId + '/rating', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceRatingsRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceRatingsData>('/attendance/conversations/' + conversationId + '/ratings', {
    method: 'GET',
    token
  });
}
DOC
cat <<'EOF' >> scripts/setup_62_attendance_closure_rating.sh

echo "Atualizando InboxPage.tsx com encerramento e avaliacao..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "attendance-closure.service" not in text:
    text = text.replace(
        "import { useAuthStore } from '../../stores/auth.store';",
        "import {\n  closeAttendanceConversationRequest,\n  createAttendanceRatingRequest,\n  listAttendanceClosuresRequest,\n  listAttendanceRatingsRequest\n} from '../../services/attendance-closure.service';\nimport { useAuthStore } from '../../stores/auth.store';"
    )

if "AttendanceClosureItem" not in text:
    text = text.replace(
        "} from '../../types/attendance-metadata.types';",
        "} from '../../types/attendance-metadata.types';\nimport type {\n  AttendanceClosureItem,\n  AttendanceRatingItem\n} from '../../types/attendance-closure.types';"
    )

if "const [closures" not in text:
    text = text.replace(
        "const [newTagName, setNewTagName] = useState('');",
        "const [newTagName, setNewTagName] = useState('');\n  const [closures, setClosures] = useState<AttendanceClosureItem[]>([]);\n  const [ratings, setRatings] = useState<AttendanceRatingItem[]>([]);\n  const [closingMessage, setClosingMessage] = useState('Atendimento finalizado.\\n\\nComo voce avalia nosso atendimento de 1 a 5?\\n\\n1 - Muito ruim\\n2 - Ruim\\n3 - Regular\\n4 - Bom\\n5 - Excelente\\n\\nObrigado por falar com a LH Solucao.');\n  const [ratingValue, setRatingValue] = useState('5');\n  const [ratingComment, setRatingComment] = useState('');"
    )

if "listAttendanceClosuresRequest" not in text.split("async function loadMetadata")[1].split("}")text = text.replace(
        "const [notesResponse, tagsResponse, conversationTagsResponse] = await Promise.all([",
        "const [notesResponse, tagsResponse, conversationTagsResponse, closuresResponse, ratingsResponse] = await Promise.all(["
    )
    text = text.replace(
        "listConversationTagsRequest(token, conversationId)\n    ]);",
        "listConversationTagsRequest(token, conversationId),\n      listAttendanceClosuresRequest(token, conversationId),\n      listAttendanceRatingsRequest(token, conversationId)\n    ]);"
    )
    text = text.replace(
        "if (conversationTagsResponse.success) {\n      setConversationTags(conversationTagsResponse.data.tags);\n    }",
        "if (conversationTagsResponse.success) {\n      setConversationTags(conversationTagsResponse.data.tags);\n    }\n\n    if (closuresResponse.success) {\n      setClosures(closuresResponse.data.closures);\n    }\n\n    if (ratingsResponse.success) {\n      setRatings(ratingsResponse.data.ratings);\n    }"
    )

if "async function handleCloseConversation" not in text:
    marker = "  async function handleCreateInternalNote(event: FormEvent<HTMLFormElement>) {"
    method = """  async function handleCloseConversation() {
    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setComposerText(closingMessage);
      setNotice('Mensagem de encerramento preparada para demonstracao.');
      return;
    }

    const response = await closeAttendanceConversationRequest(token, selectedConversation.id, {
      closingMessage,
      closedByUserId: null,
      closedByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente',
      departmentName: selectedConversation.departmentName,
      ratingRequested: true
    });

    if (response.success) {
      setComposerText(response.data.closure.closingMessage);
      await loadInbox();
      await loadMetadata(selectedConversation.id);
      setNotice('Atendimento encerrado e mensagem de avaliacao preparada.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel encerrar atendimento.');
    }
  }

  async function handleCreateRating(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setNotice('Avaliacao registrada localmente para demonstracao.');
      return;
    }

    const response = await createAttendanceRatingRequest(token, selectedConversation.id, {
      rating: Number(ratingValue),
      comment: ratingComment.trim() || null
    });

    if (response.success) {
      setRatingComment('');
      await loadMetadata(selectedConversation.id);
      setNotice('Avaliacao registrada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel registrar avaliacao.');
    }
  }

"""
    text = text.replace(marker, method + marker)

old = """          <section className="closing-card">
            <strong>Encerramento com avaliacao</strong>
            <p>Mensagem padrao pronta para finalizar o atendimento e solicitar nota de 1 a 5.</p>
            <button type="button">Preparar encerramento</button>
          </section>"""

new = """          <section className="closing-card closure-card">
            <strong>Encerramento com avaliacao</strong>
            <p>Prepare a mensagem de encerramento, marque a conversa como encerrada e registre a avaliacao quando o cliente responder.</p>

            <textarea
              onChange={(event) => setClosingMessage(event.target.value)}
              value={closingMessage}
            />

            <button onClick={() => void handleCloseConversation()} type="button">
              Encerrar e preparar mensagem
            </button>

            <form className="rating-form" onSubmit={handleCreateRating}>
              <label>
                Nota
                <select onChange={(event) => setRatingValue(event.target.value)} value={ratingValue}>
                  <option value="1">1 - Muito ruim</option>
                  <option value="2">2 - Ruim</option>
                  <option value="3">3 - Regular</option>
                  <option value="4">4 - Bom</option>
                  <option value="5">5 - Excelente</option>
                </select>
              </label>

              <textarea
                onChange={(event) => setRatingComment(event.target.value)}
                placeholder="Comentario opcional da avaliacao"
                value={ratingComment}
              />

              <button type="submit">Registrar avaliacao</button>
            </form>

            <div className="closure-history">
              <strong>Historico</strong>
              {closures.length ? closures.map((closure) => (
                <article key={closure.id}>
                  <span>{closure.closedByName}</span>
                  <p>{closure.closingMessage}</p>
                  <small>{closure.createdAt}</small>
                </article>
              )) : <small>Nenhum encerramento registrado.</small>}

              {ratings.length ? ratings.map((rating) => (
                <article key={rating.id}>
                  <span>Avaliacao {rating.rating}</span>
                  <p>{rating.comment || 'Sem comentario.'}</p>
                  <small>{rating.createdAt}</small>
                </article>
              )) : <small>Nenhuma avaliacao registrada.</small>}
            </div>
          </section>"""

if old not in text:
    raise SystemExit("Bloco closing-card original nao encontrado em InboxPage.tsx")

text = text.replace(old, new)

path.write_text(text)
PY

echo "Adicionando CSS de encerramento e avaliacao..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 62 - Encerramento com avaliacao */

.closure-card textarea,
.rating-form textarea,
.rating-form select {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 11px 13px;
  width: 100%;
}

.closure-card textarea {
  min-height: 150px;
  resize: vertical;
}

.rating-form {
  display: grid;
  gap: 10px;
}

.rating-form label {
  color: #374151;
  display: grid;
  font-size: 12px;
  font-weight: 950;
  gap: 6px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.closure-history {
  display: grid;
  gap: 10px;
  max-height: 320px;
  overflow: auto;
}

.closure-history article {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 10px;
}

.closure-history span {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-weight: 900;
}

.closure-history p {
  color: #374151;
  white-space: pre-wrap;
  margin: 5px 0;
}

.closure-history small {
  color: var(--lh-muted, #6b7280);
}
DOC

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-closure.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-closure.types.ts" \
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

DOMAIN_CLOSE_STATUS="SKIPPED"
DOMAIN_CLOSURES_STATUS="SKIPPED"
DOMAIN_RATING_CREATE_STATUS="SKIPPED"
DOMAIN_RATINGS_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  CLOSE_PAYLOAD="$(node -e "console.log(JSON.stringify({closingMessage:'Atendimento finalizado. Como voce avalia nosso atendimento de 1 a 5?', closedByUserId:null, closedByName:'Validacao Etapa 62', departmentName:'Comercial', ratingRequested:true}))")"

  DOMAIN_CLOSE_STATUS="$(curl -L -s -o "${DOMAIN_CLOSE_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${CLOSE_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/close" || true)"

  if [ "${DOMAIN_CLOSE_STATUS}" != "200" ] && [ "${DOMAIN_CLOSE_STATUS}" != "201" ]; then
    echo "ERRO: close conversation falhou. Status ${DOMAIN_CLOSE_STATUS}"
    cat "${DOMAIN_CLOSE_LOG}"
    exit 1
  fi

  DOMAIN_CLOSURES_STATUS="$(curl -L -s -o "${DOMAIN_CLOSURES_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/closures" || true)"

  if [ "${DOMAIN_CLOSURES_STATUS}" != "200" ]; then
    echo "ERRO: closures list falhou. Status ${DOMAIN_CLOSURES_STATUS}"
    cat "${DOMAIN_CLOSURES_LOG}"
    exit 1
  fi

  RATING_PAYLOAD="$(node -e "console.log(JSON.stringify({rating:5, comment:'Validacao Etapa 62'}))")"

  DOMAIN_RATING_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_RATING_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${RATING_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/rating" || true)"

  if [ "${DOMAIN_RATING_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_RATING_CREATE_STATUS}" != "201" ]; then
    echo "ERRO: rating create falhou. Status ${DOMAIN_RATING_CREATE_STATUS}"
    cat "${DOMAIN_RATING_CREATE_LOG}"
    exit 1
  fi

  DOMAIN_RATINGS_STATUS="$(curl -L -s -o "${DOMAIN_RATINGS_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/ratings" || true)"

  if [ "${DOMAIN_RATINGS_STATUS}" != "200" ]; then
    echo "ERRO: ratings list falhou. Status ${DOMAIN_RATINGS_STATUS}"
    cat "${DOMAIN_RATINGS_LOG}"
    exit 1
  fi
else
  echo '{"skipped":"sem conversa real para encerramento"}' > "${DOMAIN_CLOSE_LOG}"
  echo '{"skipped":"sem conversa real para listar encerramentos"}' > "${DOMAIN_CLOSURES_LOG}"
  echo '{"skipped":"sem conversa real para avaliacao"}' > "${DOMAIN_RATING_CREATE_LOG}"
  echo '{"skipped":"sem conversa real para listar avaliacoes"}' > "${DOMAIN_RATINGS_LOG}"
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

echo "Gerando documentacao da Etapa 62..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Closure Rating

## Visao geral

Este documento registra a criacao do encerramento com avaliacao do atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela de encerramentos de atendimento
- tabela de avaliacoes de atendimento
- endpoint para encerrar conversa
- endpoint para listar encerramentos
- endpoint para registrar avaliacao
- endpoint para listar avaliacoes
- mensagem padrao de encerramento com nota de 1 a 5
- marcacao da conversa como encerrado
- registro do atendente que encerrou
- painel visual de encerramento na central app inbox
- historico visual de encerramentos e avaliacoes

## Mensagem padrao

Mensagem:

Atendimento finalizado.

Como voce avalia nosso atendimento de 1 a 5?

1 - Muito ruim
2 - Ruim
3 - Regular
4 - Bom
5 - Excelente

Obrigado por falar com a LH Solucao.

## Endpoints criados

Endpoints:

- POST api v1 attendance conversations conversation id close
- GET api v1 attendance conversations conversation id closures
- POST api v1 attendance conversations conversation id rating
- GET api v1 attendance conversations conversation id ratings

## Tabelas criadas

Tabelas:

- attendance conversation closures
- attendance conversation ratings

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-closure/attendance-closure.types.ts
- apps/backend/src/modules/attendance-closure/attendance-closure.service.ts
- apps/backend/src/modules/attendance-closure/attendance-closure.controller.ts
- apps/backend/src/modules/attendance-closure/attendance-closure.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-closure.types.ts
- apps/frontend/src/services/attendance-closure.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_CLOSURE_RATING.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente das tabelas
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint attendance conversations dominio
- encerramento quando ha conversa real
- listagem de encerramentos quando ha conversa real
- registro de avaliacao quando ha conversa real
- listagem de avaliacoes quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_62_backend_typecheck.log
- logs/setup_62_backend_build.log
- logs/setup_62_frontend_typecheck.log
- logs/setup_62_frontend_build.log
- logs/setup_62_backend_docker_build.log
- logs/setup_62_frontend_docker_build.log
- logs/setup_62_docker_up.log
- logs/setup_62_backend_wait.log
- logs/setup_62_auth_login_domain.log
- logs/setup_62_attendance_conversations_domain.log
- logs/setup_62_close_conversation_domain.log
- logs/setup_62_closures_domain.log
- logs/setup_62_rating_create_domain.log
- logs/setup_62_ratings_domain.log
- logs/setup_62_domain_inbox_page.log
- logs/setup_62_domain_dashboard.log
- logs/setup_62_domain_audit_page.log
- logs/setup_62.log

## Proxima etapa sugerida

Etapa 63:

    Criar dashboard de atendimento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 62 - Criar encerramento com avaliacao do atendimento",
    "- [x] Etapa 62 - Criar encerramento com avaliacao do atendimento\n- [ ] Etapa 63 - Criar dashboard de atendimento"
)

text = text.replace(
    "Etapa 62 - Criar encerramento com avaliacao do atendimento.",
    "Etapa 63 - Criar dashboard de atendimento."
)

text = text.replace(
    "Etapa 61 - Criar notas internas e tags.",
    "Etapa 62 - Criar encerramento com avaliacao do atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Encerramento com avaliacao do atendimento criado." not in text:
    text = text.replace(
        "Notas internas e tags criadas.",
        "Notas internas e tags criadas.\n\nEncerramento com avaliacao do atendimento criado."
    )

if "- docs/ATTENDANCE_CLOSURE_RATING.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md",
        "- docs/ATTENDANCE_CLOSURE_RATING.md\n- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 61 concluidas",
    "- Etapa 01 ate Etapa 62 concluidas"
)

text = text.replace(
    "- Etapa 62 - Criar encerramento com avaliacao do atendimento",
    "- Etapa 63 - Criar dashboard de atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 62 - Criar encerramento com avaliacao do atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criados encerramentos de atendimento, avaliacoes de 1 a 5, endpoints correspondentes e painel visual na central app inbox.
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
Etapa: 62
Acao: Criar encerramento com avaliacao do atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Close status: ${DOMAIN_CLOSE_STATUS}
Closures status: ${DOMAIN_CLOSURES_STATUS}
Rating create status: ${DOMAIN_RATING_CREATE_STATUS}
Ratings status: ${DOMAIN_RATINGS_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 62 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 63 - Criar dashboard de atendimento"

echo "Atualizando InboxPage.tsx com encerramento e avaliacao..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "attendance-closure.service" not in text:
    text = text.replace(
        "import { useAuthStore } from '../../stores/auth.store';",
        "import {\n  closeAttendanceConversationRequest,\n  createAttendanceRatingRequest,\n  listAttendanceClosuresRequest,\n  listAttendanceRatingsRequest\n} from '../../services/attendance-closure.service';\nimport { useAuthStore } from '../../stores/auth.store';"
    )

if "AttendanceClosureItem" not in text:
    text = text.replace(
        "} from '../../types/attendance-metadata.types';",
        "} from '../../types/attendance-metadata.types';\nimport type {\n  AttendanceClosureItem,\n  AttendanceRatingItem\n} from '../../types/attendance-closure.types';"
    )

if "const [closures" not in text:
    text = text.replace(
        "const [newTagName, setNewTagName] = useState('');",
        "const [newTagName, setNewTagName] = useState('');\n  const [closures, setClosures] = useState<AttendanceClosureItem[]>([]);\n  const [ratings, setRatings] = useState<AttendanceRatingItem[]>([]);\n  const [closingMessage, setClosingMessage] = useState('Atendimento finalizado.\\n\\nComo voce avalia nosso atendimento de 1 a 5?\\n\\n1 - Muito ruim\\n2 - Ruim\\n3 - Regular\\n4 - Bom\\n5 - Excelente\\n\\nObrigado por falar com a LH Solucao.');\n  const [ratingValue, setRatingValue] = useState('5');\n  const [ratingComment, setRatingComment] = useState('');"
    )

if "listAttendanceClosuresRequest" not in text.split("async function loadMetadata")[1].split("}")text = text.replace(
        "const [notesResponse, tagsResponse, conversationTagsResponse] = await Promise.all([",
        "const [notesResponse, tagsResponse, conversationTagsResponse, closuresResponse, ratingsResponse] = await Promise.all(["
    )
    text = text.replace(
        "listConversationTagsRequest(token, conversationId)\n    ]);",
        "listConversationTagsRequest(token, conversationId),\n      listAttendanceClosuresRequest(token, conversationId),\n      listAttendanceRatingsRequest(token, conversationId)\n    ]);"
    )
    text = text.replace(
        "if (conversationTagsResponse.success) {\n      setConversationTags(conversationTagsResponse.data.tags);\n    }",
        "if (conversationTagsResponse.success) {\n      setConversationTags(conversationTagsResponse.data.tags);\n    }\n\n    if (closuresResponse.success) {\n      setClosures(closuresResponse.data.closures);\n    }\n\n    if (ratingsResponse.success) {\n      setRatings(ratingsResponse.data.ratings);\n    }"
    )

if "async function handleCloseConversation" not in text:
    marker = "  async function handleCreateInternalNote(event: FormEvent<HTMLFormElement>) {"
    method = """  async function handleCloseConversation() {
    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setComposerText(closingMessage);
      setNotice('Mensagem de encerramento preparada para demonstracao.');
      return;
    }

    const response = await closeAttendanceConversationRequest(token, selectedConversation.id, {
      closingMessage,
      closedByUserId: null,
      closedByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente',
      departmentName: selectedConversation.departmentName,
      ratingRequested: true
    });

    if (response.success) {
      setComposerText(response.data.closure.closingMessage);
      await loadInbox();
      await loadMetadata(selectedConversation.id);
      setNotice('Atendimento encerrado e mensagem de avaliacao preparada.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel encerrar atendimento.');
    }
  }

  async function handleCreateRating(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setNotice('Avaliacao registrada localmente para demonstracao.');
      return;
    }

    const response = await createAttendanceRatingRequest(token, selectedConversation.id, {
      rating: Number(ratingValue),
      comment: ratingComment.trim() || null
    });

    if (response.success) {
      setRatingComment('');
      await loadMetadata(selectedConversation.id);
      setNotice('Avaliacao registrada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel registrar avaliacao.');
    }
  }

"""
    text = text.replace(marker, method + marker)

old = """          <section className="closing-card">
            <strong>Encerramento com avaliacao</strong>
            <p>Mensagem padrao pronta para finalizar o atendimento e solicitar nota de 1 a 5.</p>
            <button type="button">Preparar encerramento</button>
          </section>"""

new = """          <section className="closing-card closure-card">
            <strong>Encerramento com avaliacao</strong>
            <p>Prepare a mensagem de encerramento, marque a conversa como encerrada e registre a avaliacao quando o cliente responder.</p>

            <textarea
              onChange={(event) => setClosingMessage(event.target.value)}
              value={closingMessage}
            />

            <button onClick={() => void handleCloseConversation()} type="button">
              Encerrar e preparar mensagem
            </button>

            <form className="rating-form" onSubmit={handleCreateRating}>
              <label>
                Nota
                <select onChange={(event) => setRatingValue(event.target.value)} value={ratingValue}>
                  <option value="1">1 - Muito ruim</option>
                  <option value="2">2 - Ruim</option>
                  <option value="3">3 - Regular</option>
                  <option value="4">4 - Bom</option>
                  <option value="5">5 - Excelente</option>
                </select>
              </label>

              <textarea
                onChange={(event) => setRatingComment(event.target.value)}
                placeholder="Comentario opcional da avaliacao"
                value={ratingComment}
              />

              <button type="submit">Registrar avaliacao</button>
            </form>

            <div className="closure-history">
              <strong>Historico</strong>
              {closures.length ? closures.map((closure) => (
                <article key={closure.id}>
                  <span>{closure.closedByName}</span>
                  <p>{closure.closingMessage}</p>
                  <small>{closure.createdAt}</small>
                </article>
              )) : <small>Nenhum encerramento registrado.</small>}

              {ratings.length ? ratings.map((rating) => (
                <article key={rating.id}>
                  <span>Avaliacao {rating.rating}</span>
                  <p>{rating.comment || 'Sem comentario.'}</p>
                  <small>{rating.createdAt}</small>
                </article>
              )) : <small>Nenhuma avaliacao registrada.</small>}
            </div>
          </section>"""

if old not in text:
    raise SystemExit("Bloco closing-card original nao encontrado em InboxPage.tsx")

text = text.replace(old, new)

path.write_text(text)
PY

echo "Adicionando CSS de encerramento e avaliacao..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 62 - Encerramento com avaliacao */

.closure-card textarea,
.rating-form textarea,
.rating-form select {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 11px 13px;
  width: 100%;
}

.closure-card textarea {
  min-height: 150px;
  resize: vertical;
}

.rating-form {
  display: grid;
  gap: 10px;
}

.rating-form label {
  color: #374151;
  display: grid;
  font-size: 12px;
  font-weight: 950;
  gap: 6px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.closure-history {
  display: grid;
  gap: 10px;
  max-height: 320px;
  overflow: auto;
}

.closure-history article {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  padding: 10px;
}

.closure-history span {
  color: var(--lh-blue-950, #04204f);
  display: block;
  font-weight: 900;
}

.closure-history p {
  color: #374151;
  white-space: pre-wrap;
  margin: 5px 0;
}

.closure-history small {
  color: var(--lh-muted, #6b7280);
}
DOC

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-closure.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-closure.types.ts" \
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

DOMAIN_CLOSE_STATUS="SKIPPED"
DOMAIN_CLOSURES_STATUS="SKIPPED"
DOMAIN_RATING_CREATE_STATUS="SKIPPED"
DOMAIN_RATINGS_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  CLOSE_PAYLOAD="$(node -e "console.log(JSON.stringify({closingMessage:'Atendimento finalizado. Como voce avalia nosso atendimento de 1 a 5?', closedByUserId:null, closedByName:'Validacao Etapa 62', departmentName:'Comercial', ratingRequested:true}))")"

  DOMAIN_CLOSE_STATUS="$(curl -L -s -o "${DOMAIN_CLOSE_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${CLOSE_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/close" || true)"

  if [ "${DOMAIN_CLOSE_STATUS}" != "200" ] && [ "${DOMAIN_CLOSE_STATUS}" != "201" ]; then
    echo "ERRO: close conversation falhou. Status ${DOMAIN_CLOSE_STATUS}"
    cat "${DOMAIN_CLOSE_LOG}"
    exit 1
  fi

  DOMAIN_CLOSURES_STATUS="$(curl -L -s -o "${DOMAIN_CLOSURES_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/closures" || true)"

  if [ "${DOMAIN_CLOSURES_STATUS}" != "200" ]; then
    echo "ERRO: closures list falhou. Status ${DOMAIN_CLOSURES_STATUS}"
    cat "${DOMAIN_CLOSURES_LOG}"
    exit 1
  fi

  RATING_PAYLOAD="$(node -e "console.log(JSON.stringify({rating:5, comment:'Validacao Etapa 62'}))")"

  DOMAIN_RATING_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_RATING_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${RATING_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/rating" || true)"

  if [ "${DOMAIN_RATING_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_RATING_CREATE_STATUS}" != "201" ]; then
    echo "ERRO: rating create falhou. Status ${DOMAIN_RATING_CREATE_STATUS}"
    cat "${DOMAIN_RATING_CREATE_LOG}"
    exit 1
  fi

  DOMAIN_RATINGS_STATUS="$(curl -L -s -o "${DOMAIN_RATINGS_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/ratings" || true)"

  if [ "${DOMAIN_RATINGS_STATUS}" != "200" ]; then
    echo "ERRO: ratings list falhou. Status ${DOMAIN_RATINGS_STATUS}"
    cat "${DOMAIN_RATINGS_LOG}"
    exit 1
  fi
else
  echo '{"skipped":"sem conversa real para encerramento"}' > "${DOMAIN_CLOSE_LOG}"
  echo '{"skipped":"sem conversa real para listar encerramentos"}' > "${DOMAIN_CLOSURES_LOG}"
  echo '{"skipped":"sem conversa real para avaliacao"}' > "${DOMAIN_RATING_CREATE_LOG}"
  echo '{"skipped":"sem conversa real para listar avaliacoes"}' > "${DOMAIN_RATINGS_LOG}"
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

echo "Gerando documentacao da Etapa 62..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Closure Rating

## Visao geral

Este documento registra a criacao do encerramento com avaliacao do atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela de encerramentos de atendimento
- tabela de avaliacoes de atendimento
- endpoint para encerrar conversa
- endpoint para listar encerramentos
- endpoint para registrar avaliacao
- endpoint para listar avaliacoes
- mensagem padrao de encerramento com nota de 1 a 5
- marcacao da conversa como encerrado
- registro do atendente que encerrou
- painel visual de encerramento na central app inbox
- historico visual de encerramentos e avaliacoes

## Mensagem padrao

Mensagem:

Atendimento finalizado.

Como voce avalia nosso atendimento de 1 a 5?

1 - Muito ruim
2 - Ruim
3 - Regular
4 - Bom
5 - Excelente

Obrigado por falar com a LH Solucao.

## Endpoints criados

Endpoints:

- POST api v1 attendance conversations conversation id close
- GET api v1 attendance conversations conversation id closures
- POST api v1 attendance conversations conversation id rating
- GET api v1 attendance conversations conversation id ratings

## Tabelas criadas

Tabelas:

- attendance conversation closures
- attendance conversation ratings

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-closure/attendance-closure.types.ts
- apps/backend/src/modules/attendance-closure/attendance-closure.service.ts
- apps/backend/src/modules/attendance-closure/attendance-closure.controller.ts
- apps/backend/src/modules/attendance-closure/attendance-closure.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-closure.types.ts
- apps/frontend/src/services/attendance-closure.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_CLOSURE_RATING.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente das tabelas
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint attendance conversations dominio
- encerramento quando ha conversa real
- listagem de encerramentos quando ha conversa real
- registro de avaliacao quando ha conversa real
- listagem de avaliacoes quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_62_backend_typecheck.log
- logs/setup_62_backend_build.log
- logs/setup_62_frontend_typecheck.log
- logs/setup_62_frontend_build.log
- logs/setup_62_backend_docker_build.log
- logs/setup_62_frontend_docker_build.log
- logs/setup_62_docker_up.log
- logs/setup_62_backend_wait.log
- logs/setup_62_auth_login_domain.log
- logs/setup_62_attendance_conversations_domain.log
- logs/setup_62_close_conversation_domain.log
- logs/setup_62_closures_domain.log
- logs/setup_62_rating_create_domain.log
- logs/setup_62_ratings_domain.log
- logs/setup_62_domain_inbox_page.log
- logs/setup_62_domain_dashboard.log
- logs/setup_62_domain_audit_page.log
- logs/setup_62.log

## Proxima etapa sugerida

Etapa 63:

    Criar dashboard de atendimento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 62 - Criar encerramento com avaliacao do atendimento",
    "- [x] Etapa 62 - Criar encerramento com avaliacao do atendimento\n- [ ] Etapa 63 - Criar dashboard de atendimento"
)

text = text.replace(
    "Etapa 62 - Criar encerramento com avaliacao do atendimento.",
    "Etapa 63 - Criar dashboard de atendimento."
)

text = text.replace(
    "Etapa 61 - Criar notas internas e tags.",
    "Etapa 62 - Criar encerramento com avaliacao do atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Encerramento com avaliacao do atendimento criado." not in text:
    text = text.replace(
        "Notas internas e tags criadas.",
        "Notas internas e tags criadas.\n\nEncerramento com avaliacao do atendimento criado."
    )

if "- docs/ATTENDANCE_CLOSURE_RATING.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md",
        "- docs/ATTENDANCE_CLOSURE_RATING.md\n- docs/ATTENDANCE_INTERNAL_NOTES_TAGS.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 61 concluidas",
    "- Etapa 01 ate Etapa 62 concluidas"
)

text = text.replace(
    "- Etapa 62 - Criar encerramento com avaliacao do atendimento",
    "- Etapa 63 - Criar dashboard de atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 62 - Criar encerramento com avaliacao do atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criados encerramentos de atendimento, avaliacoes de 1 a 5, endpoints correspondentes e painel visual na central app inbox.
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
Etapa: 62
Acao: Criar encerramento com avaliacao do atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Close status: ${DOMAIN_CLOSE_STATUS}
Closures status: ${DOMAIN_CLOSURES_STATUS}
Rating create status: ${DOMAIN_RATING_CREATE_STATUS}
Ratings status: ${DOMAIN_RATINGS_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 62 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 63 - Criar dashboard de atendimento"
