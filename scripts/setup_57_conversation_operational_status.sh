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

LOG_FILE="${LOGS_DIR}/setup_57.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_57_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_57_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_57_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_57_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_57_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_57_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_57_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_57_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_57_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_57_auth_login_domain.log"
DOMAIN_STATUS_OPTIONS_LOG="${LOGS_DIR}/setup_57_status_options_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_57_attendance_conversations_domain.log"
DOMAIN_ATTENDANCE_PATCH_LOG="${LOGS_DIR}/setup_57_attendance_status_patch_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_57_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_57_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_57_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/CONVERSATION_OPERATIONAL_STATUS.md"

DOMAIN_SCHEME="https"
DOMAIN_HOST="bot.lhsolucao.com.br"
DOMAIN_BASE_URL="${DOMAIN_SCHEME}://${DOMAIN_HOST}"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 57: Status operacional das conversas =="

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

echo "Criando tabela operacional de status das conversas..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
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

create index if not exists idx_conversation_operational_status_tenant
on conversation_operational_status (tenant_id);

create index if not exists idx_conversation_operational_status_status
on conversation_operational_status (tenant_id, status);

create index if not exists idx_conversation_operational_status_department
on conversation_operational_status (tenant_id, department_name);
SQL

echo "Criando types backend..."

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

echo "Criando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance/attendance.service.ts" <<'DOC'
import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceConversationItem,
  AttendanceConversationListResponse,
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

  async listConversations(tenantId: string): Promise<AttendanceConversationListResponse> {
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
}
DOC

echo "Criando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance/attendance.controller.ts" <<'DOC'
import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceService } from './attendance.service';
import type { AttendanceUpdateStatusPayload } from './attendance.types';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceController {
  constructor(private readonly attendanceService: AttendanceService) {}

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

echo "Criando modulo backend..."

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

echo "Atualizando app.module.ts..."

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
        raise SystemExit("Nao foi possivel localizar imports no app.module.ts")

    lines.insert(last_import + 1, import_line)
    text = "\n".join(lines) + "\n"

match = re.search(r"imports:\s*\[([\s\S]*?)\]", text)

if not match:
    raise SystemExit("Nao foi possivel localizar bloco imports no app.module.ts")

imports_block = match.group(1)

if "AttendanceModule" not in imports_block:
    text = re.sub(
        r"imports:\s*\[",
        "imports: [\n    AttendanceModule,",
        text,
        count=1
    )

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

echo "Criando types frontend..."

cat > "${FRONTEND_DIR}/src/types/attendance.types.ts" <<'DOC'
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

echo "Criando service frontend..."

cat > "${FRONTEND_DIR}/src/services/attendance.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AttendanceConversationListData,
  AttendanceStatusOptionsData,
  AttendanceUpdateStatusData
} from '../types/attendance.types';

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

echo "Regravando InboxPage.tsx integrado com API..."

cat > "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" <<'DOC'
import { useEffect, useMemo, useState } from 'react';
import {
  getAttendanceStatusOptionsRequest,
  listAttendanceConversationsRequest,
  updateAttendanceConversationStatusRequest
} from '../../services/attendance.service';
import { useAuthStore } from '../../stores/auth.store';
import type { AttendanceConversationItem } from '../../types/attendance.types';

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
  },
  {
    id: 'demo-002',
    contactName: 'Cliente Suporte',
    contactPhone: '5521999990002',
    departmentName: 'Suporte',
    status: 'em_atendimento',
    assignedUserId: null,
    assignedUserName: 'Luiz',
    priority: 'media',
    unreadCount: 1,
    lastMessage: 'Estou com duvida sobre a integracao.',
    lastMessageAt: null,
    updatedAt: new Date().toISOString()
  }
];

const queueTabs = [
  'Fila geral',
  'Sem responsavel',
  'Comercial',
  'Suporte',
  'Financeiro',
  'Aguardando cliente',
  'Em atraso'
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
  const [statusOptions, setStatusOptions] = useState<Array<{ value: string; label: string }>>([]);
  const [priorityOptions, setPriorityOptions] = useState<Array<{ value: string; label: string }>>([]);
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

    const [listResponse, optionsResponse] = await Promise.all([
      listAttendanceConversationsRequest(token),
      getAttendanceStatusOptionsRequest(token)
    ]);

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

  async function handleStatusChange(status: string) {
    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setConversations((current) => current.map((item) => item.id === selectedConversation.id ? { ...item, status } : item));
      return;
    }

    const response = await updateAttendanceConversationStatusRequest(token, selectedConversation.id, {
      status,
      priority: selectedConversation.priority,
      departmentName: selectedConversation.departmentName,
      assignedUserId: selectedConversation.assignedUserId,
      assignedUserName: selectedConversation.assignedUserName
    });

    if (response.success) {
      await loadInbox();
      setNotice('Status operacional atualizado.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel atualizar status.');
    }
  }

  async function handlePriorityChange(priority: string) {
    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setConversations((current) => current.map((item) => item.id === selectedConversation.id ? { ...item, priority } : item));
      return;
    }

    const response = await updateAttendanceConversationStatusRequest(token, selectedConversation.id, {
      status: selectedConversation.status,
      priority,
      departmentName: selectedConversation.departmentName,
      assignedUserId: selectedConversation.assignedUserId,
      assignedUserName: selectedConversation.assignedUserName
    });

    if (response.success) {
      await loadInbox();
      setNotice('Prioridade operacional atualizada.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel atualizar prioridade.');
    }
  }

  return (
    <section className="inbox-shell">
      <section className="inbox-hero">
        <div>
          <span>Central de atendimento</span>
          <h1>Atendimento profissional WhatsApp</h1>
          <p>Organize conversas por fila, departamento, responsavel, SLA e status operacional em qualquer tamanho de tela.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="inbox-metrics">
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
          <span>Alta prioridade</span>
          <strong>{conversations.filter((item) => item.priority === 'alta' || item.priority === 'urgente').length}</strong>
          <p>Requer atencao</p>
        </article>

        <article>
          <span>Status</span>
          <strong>{statusLabels[selectedConversation.status] || selectedConversation.status}</strong>
          <p>Conversa selecionada</p>
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
              Status operacional
              <select onChange={(event) => void handleStatusChange(event.target.value)} value={selectedConversation.status}>
                {(statusOptions.length ? statusOptions : Object.entries(statusLabels).map(([value, label]) => ({ value, label }))).map((item) => (
                  <option key={item.value} value={item.value}>{item.label}</option>
                ))}
              </select>
            </label>

            <label>
              Prioridade
              <select onChange={(event) => void handlePriorityChange(event.target.value)} value={selectedConversation.priority}>
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
              <p>Status operacional persistido por conversa. Proximas etapas adicionam departamentos e responsaveis completos.</p>
            </article>

            <article className="message-bubble outbound">
              <span>Atendente</span>
              <p>Ola. Estou verificando seu atendimento e retorno em instantes.</p>
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

echo "Adicionando CSS do editor de status..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 57 - Status operacional das conversas */

.inbox-status-editor {
  align-items: center;
  border-bottom: 1px solid #e5e7eb;
  display: grid;
  gap: 12px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  padding: 14px 16px;
}

.inbox-status-editor label {
  color: #374151;
  display: grid;
  font-size: 12px;
  font-weight: 950;
  gap: 6px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.inbox-status-editor select {
  background: #ffffff;
  border: 1px solid #d1d5db;
  border-radius: 14px;
  color: #111827;
  font-size: 14px;
  font-weight: 800;
  padding: 10px 12px;
  text-transform: none;
}

@media (max-width: 680px) {
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

DOMAIN_STATUS_OPTIONS_STATUS="$(curl -L -s -o "${DOMAIN_STATUS_OPTIONS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations/status-options" || true)"

if [ "${DOMAIN_STATUS_OPTIONS_STATUS}" != "200" ]; then
  echo "ERRO: status-options falhou. Status ${DOMAIN_STATUS_OPTIONS_STATUS}"
  cat "${DOMAIN_STATUS_OPTIONS_LOG}"
  exit 1
fi

if ! grep -q "em_atendimento" "${DOMAIN_STATUS_OPTIONS_LOG}"; then
  echo "ERRO: status-options nao retornou em_atendimento."
  cat "${DOMAIN_STATUS_OPTIONS_LOG}"
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

if ! grep -q "conversations" "${DOMAIN_ATTENDANCE_LIST_LOG}"; then
  echo "ERRO: listagem attendance nao retornou conversations."
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

DOMAIN_ATTENDANCE_PATCH_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  PATCH_PAYLOAD="$(node -e "console.log(JSON.stringify({status:'em_atendimento', priority:'media', departmentName:'Fila geral', assignedUserId:null, assignedUserName:'Validacao Etapa 57'}))")"

  DOMAIN_ATTENDANCE_PATCH_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_PATCH_LOG}" -w "%{http_code}" --max-time 30 \
    -X PATCH \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${PATCH_PAYLOAD}" \
    "${DOMAIN_ATTENDANCE_URL}/conversations/${CONVERSATION_ID}/status" || true)"

  if [ "${DOMAIN_ATTENDANCE_PATCH_STATUS}" != "200" ] && [ "${DOMAIN_ATTENDANCE_PATCH_STATUS}" != "201" ]; then
    echo "ERRO: patch status falhou. Status ${DOMAIN_ATTENDANCE_PATCH_STATUS}"
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

echo "Gerando documentacao da Etapa 57..."

cat > "${DOC_FILE}" <<'DOC'
# Conversation Operational Status

## Visao geral

Este documento registra a criacao do status operacional das conversas.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela conversation operational status
- status operacional por conversa
- prioridade por conversa
- departamento operacional atual
- responsavel operacional atual
- endpoint de opcoes de status e prioridade
- endpoint de listagem de conversas para atendimento
- endpoint para atualizar status operacional
- integracao da tela app inbox com API real
- fallback visual caso nao existam conversas reais
- editor visual de status e prioridade

## Status criados

Status:

- novo
- em atendimento
- aguardando cliente
- aguardando interno
- resolvido
- encerrado
- arquivado

## Prioridades criadas

Prioridades:

- baixa
- normal
- media
- alta
- urgente

## Endpoints criados

Endpoints:

- GET api v1 attendance conversations status options
- GET api v1 attendance conversations
- PATCH api v1 attendance conversations conversation id status

## Tabela criada

Tabela:

- conversation operational status

Campos:

- id
- tenant id
- conversation id
- status
- priority
- department name
- assigned user id
- assigned user name
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
- docs/CONVERSATION_OPERATIONAL_STATUS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint status options dominio
- endpoint attendance conversations dominio
- patch status quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_57_backend_typecheck.log
- logs/setup_57_backend_build.log
- logs/setup_57_frontend_typecheck.log
- logs/setup_57_frontend_build.log
- logs/setup_57_backend_docker_build.log
- logs/setup_57_frontend_docker_build.log
- logs/setup_57_docker_up.log
- logs/setup_57_backend_wait.log
- logs/setup_57_auth_login_domain.log
- logs/setup_57_status_options_domain.log
- logs/setup_57_attendance_conversations_domain.log
- logs/setup_57_attendance_status_patch_domain.log
- logs/setup_57_domain_inbox_page.log
- logs/setup_57_domain_dashboard.log
- logs/setup_57_domain_audit_page.log
- logs/setup_57.log

## Proxima etapa sugerida

Etapa 58:

    Criar departamentos e filas de atendimento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 57 - Criar status operacional das conversas",
    "- [x] Etapa 57 - Criar status operacional das conversas\n- [ ] Etapa 58 - Criar departamentos e filas de atendimento"
)

text = text.replace(
    "Etapa 57 - Criar status operacional das conversas.",
    "Etapa 58 - Criar departamentos e filas de atendimento."
)

text = text.replace(
    "Etapa 56 - Criar layout responsivo profissional da central de atendimento.",
    "Etapa 57 - Criar status operacional das conversas."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Status operacional das conversas criado." not in text:
    text = text.replace(
        "Layout responsivo profissional da central de atendimento criado.",
        "Layout responsivo profissional da central de atendimento criado.\n\nStatus operacional das conversas criado."
    )

if "- docs/CONVERSATION_OPERATIONAL_STATUS.md" not in text:
    text = text.replace(
        "- docs/RESPONSIVE_ATTENDANCE_CENTER_LAYOUT.md",
        "- docs/CONVERSATION_OPERATIONAL_STATUS.md\n- docs/RESPONSIVE_ATTENDANCE_CENTER_LAYOUT.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 56 concluidas",
    "- Etapa 01 ate Etapa 57 concluidas"
)

text = text.replace(
    "- Etapa 57 - Criar status operacional das conversas",
    "- Etapa 58 - Criar departamentos e filas de atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 57 - Criar status operacional das conversas
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada persistencia de status operacional por conversa, prioridade, departamento e responsavel atual, com modulo backend attendance e integracao na tela app inbox.
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
Etapa: 57
Acao: Criar status operacional das conversas
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Status options status: ${DOMAIN_STATUS_OPTIONS_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Attendance patch status: ${DOMAIN_ATTENDANCE_PATCH_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 57 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 58 - Criar departamentos e filas de atendimento"
