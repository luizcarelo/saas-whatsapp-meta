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

LOG_FILE="${LOGS_DIR}/setup_72.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_72_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_72_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_72_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_72_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_72_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_72_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_72_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_72_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_72_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_72_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_72_attendance_conversations_domain.log"
DOMAIN_SEED_FAILURE_LOG="${LOGS_DIR}/setup_72_seed_failure.log"
DOMAIN_FAILURES_LOG="${LOGS_DIR}/setup_72_failures_domain.log"
DOMAIN_RETRY_LOG="${LOGS_DIR}/setup_72_retry_domain.log"
DOMAIN_RETRIES_LOG="${LOGS_DIR}/setup_72_retries_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_72_domain_inbox_page.log"
DOMAIN_SEND_FAILURES_PAGE_LOG="${LOGS_DIR}/setup_72_domain_send_failures_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_72_domain_dashboard.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_72_domain_attendance_dashboard.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_SEND_FAILURES_RETRY_PANEL.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_FAILURES_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send-failures"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_SEND_FAILURES_PAGE_URL="${DOMAIN_BASE_URL}/app/send-failures"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_ATTENDANCE_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"

echo "== Etapa 72: Painel de falhas e retentativas de envio =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/attendance-send-failures"
mkdir -p "${FRONTEND_DIR}/src/pages/send-failures"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Validando conclusao da Etapa 71..."

if [ ! -f "${LOGS_DIR}/setup_71.log" ]; then
  echo "ERRO: setup_71.log nao encontrado. Conclua a Etapa 71 antes da Etapa 72."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_71.log"; then
  echo "ERRO: Etapa 71 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_71.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-send-failures/attendance-send-failures.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send-failures/attendance-send-failures.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send-failures/attendance-send-failures.controller.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send-failures/attendance-send-failures.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.module.ts" \
  "${FRONTEND_DIR}/src/types/attendance-send-failures.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance-send-failures.service.ts" \
  "${FRONTEND_DIR}/src/pages/send-failures/SendFailuresPage.tsx" \
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

echo "Atualizando tabela de envios para retentativas..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
alter table attendance_manual_message_sends
  add column if not exists retry_of_send_id uuid;

alter table attendance_manual_message_sends
  add column if not exists retry_count integer not null default 0;

alter table attendance_manual_message_sends
  add column if not exists last_retry_at timestamptz;

create index if not exists idx_attendance_manual_message_sends_retry_of
on attendance_manual_message_sends (tenant_id, retry_of_send_id);

create index if not exists idx_attendance_manual_message_sends_failed
on attendance_manual_message_sends (tenant_id, status, created_at);
SQL

echo "Garantindo export do AttendanceSendModule..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/attendance-send/attendance-send.module.ts")
text = path.read_text()

if "exports:" not in text:
    text = text.replace(
        "providers: [\n    AttendanceSendService\n  ]",
        "providers: [\n    AttendanceSendService\n  ],\n  exports: [\n    AttendanceSendService\n  ]"
    )

path.write_text(text)
PY

echo "Criando types backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-send-failures/attendance-send-failures.types.ts" <<'DOC'
export type AttendanceSendFailureItem = {
  id: string;
  conversationId: string;
  contactId: string | null;
  contactPhone: string | null;
  whatsappAccountId: string | null;
  phoneNumberId: string | null;
  messageBody: string;
  sentByUserId: string | null;
  sentByName: string;
  departmentName: string;
  conversationStatus: string;
  messageOrigin: string;
  quickReplyId: string | null;
  quickReplyTitle: string | null;
  provider: string;
  providerMessageId: string | null;
  status: string;
  errorMessage: string | null;
  dryRun: boolean;
  attendantSource: string | null;
  assignedUserIdAtSend: string | null;
  assignedUserNameAtSend: string | null;
  retryOfSendId: string | null;
  retryCount: number;
  lastRetryAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceSendFailuresResponse = {
  success: true;
  data: {
    failures: AttendanceSendFailureItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceSendRetryPayload = {
  dryRun?: boolean;
  sentByName?: string | null;
};

export type AttendanceSendRetryResponse = {
  success: true;
  data: {
    original: AttendanceSendFailureItem;
    retry: AttendanceSendFailureItem;
  };
  meta: Record<string, never>;
};

export type AttendanceSendRetriesResponse = {
  success: true;
  data: {
    retries: AttendanceSendFailureItem[];
  };
  meta: Record<string, never>;
};
DOC

echo "Criando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-send-failures/attendance-send-failures.service.ts" <<'DOC'
import { BadRequestException, Injectable } from '@nestjs/common';
import { AttendanceSendService } from '../attendance-send/attendance-send.service';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceSendFailureItem,
  AttendanceSendFailuresResponse,
  AttendanceSendRetriesResponse,
  AttendanceSendRetryPayload,
  AttendanceSendRetryResponse
} from './attendance-send-failures.types';

type SendFailureRow = {
  id: string;
  conversation_id: string;
  contact_id: string | null;
  contact_phone: string | null;
  whatsapp_account_id: string | null;
  phone_number_id: string | null;
  message_body: string;
  sent_by_user_id: string | null;
  sent_by_name: string;
  department_name: string;
  conversation_status: string;
  message_origin: string;
  quick_reply_id: string | null;
  quick_reply_title: string | null;
  provider: string;
  provider_message_id: string | null;
  status: string;
  error_message: string | null;
  dry_run: boolean;
  attendant_source: string | null;
  assigned_user_id_at_send: string | null;
  assigned_user_name_at_send: string | null;
  retry_of_send_id: string | null;
  retry_count: number;
  last_retry_at: Date | null;
  created_at: Date;
  updated_at: Date;
};

@Injectable()
export class AttendanceSendFailuresService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly attendanceSendService: AttendanceSendService
  ) {}

  async listFailures(tenantId: string): Promise<AttendanceSendFailuresResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<SendFailureRow[]>(
      'select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, retry_of_send_id, retry_count, last_retry_at, created_at, updated_at from attendance_manual_message_sends where tenant_id = $1::uuid and status = $2 order by created_at desc limit 100',
      tenantId,
      'failed'
    );

    return {
      success: true,
      data: {
        failures: rows.map((row) => this.mapRow(row))
      },
      meta: {}
    };
  }

  async retryFailure(
    tenantId: string,
    sendId: string,
    payload: AttendanceSendRetryPayload
  ): Promise<AttendanceSendRetryResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<SendFailureRow[]>(
      'select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, retry_of_send_id, retry_count, last_retry_at, created_at, updated_at from attendance_manual_message_sends where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      sendId
    );

    const original = rows[0];

    if (!original) {
      throw new BadRequestException('Envio nao encontrado');
    }

    if (original.status !== 'failed') {
      throw new BadRequestException('Somente envios com falha podem ser retentados');
    }

    const retryDryRun = typeof payload.dryRun === 'boolean' ? payload.dryRun : true;
    const retryName = payload.sentByName || original.sent_by_name || 'Retentativa';

    const retryResponse = await this.attendanceSendService.sendManualMessage(tenantId, original.conversation_id, {
      messageBody: original.message_body,
      sentByUserId: original.sent_by_user_id,
      sentByName: retryName,
      departmentName: original.department_name,
      messageOrigin: original.message_origin as never,
      quickReplyId: original.quick_reply_id,
      quickReplyTitle: original.quick_reply_title,
      dryRun: retryDryRun
    });

    const retrySendId = retryResponse.data.send.id;

    await this.prismaService.$executeRawUnsafe(
      'update attendance_manual_message_sends set retry_of_send_id = $3::uuid, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid',
      tenantId,
      retrySendId,
      sendId
    );

    const updatedOriginalRows = await this.prismaService.$queryRawUnsafe<SendFailureRow[]>(
      'update attendance_manual_message_sends set retry_count = retry_count + 1, last_retry_at = now(), updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, retry_of_send_id, retry_count, last_retry_at, created_at, updated_at',
      tenantId,
      sendId
    );

    const retryRows = await this.prismaService.$queryRawUnsafe<SendFailureRow[]>(
      'select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, retry_of_send_id, retry_count, last_retry_at, created_at, updated_at from attendance_manual_message_sends where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      retrySendId
    );

    return {
      success: true,
      data: {
        original: this.mapRow(updatedOriginalRows[0]),
        retry: this.mapRow(retryRows[0])
      },
      meta: {}
    };
  }

  async listRetries(tenantId: string): Promise<AttendanceSendRetriesResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<SendFailureRow[]>(
      'select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, retry_of_send_id, retry_count, last_retry_at, created_at, updated_at from attendance_manual_message_sends where tenant_id = $1::uuid and retry_of_send_id is not null order by created_at desc limit 100',
      tenantId
    );

    return {
      success: true,
      data: {
        retries: rows.map((row) => this.mapRow(row))
      },
      meta: {}
    };
  }

  private mapRow(row: SendFailureRow): AttendanceSendFailureItem {
    return {
      id: row.id,
      conversationId: row.conversation_id,
      contactId: row.contact_id,
      contactPhone: row.contact_phone,
      whatsappAccountId: row.whatsapp_account_id,
      phoneNumberId: row.phone_number_id,
      messageBody: row.message_body,
      sentByUserId: row.sent_by_user_id,
      sentByName: row.sent_by_name,
      departmentName: row.department_name,
      conversationStatus: row.conversation_status,
      messageOrigin: row.message_origin,
      quickReplyId: row.quick_reply_id,
      quickReplyTitle: row.quick_reply_title,
      provider: row.provider,
      providerMessageId: row.provider_message_id,
      status: row.status,
      errorMessage: row.error_message,
      dryRun: row.dry_run,
      attendantSource: row.attendant_source,
      assignedUserIdAtSend: row.assigned_user_id_at_send,
      assignedUserNameAtSend: row.assigned_user_name_at_send,
      retryOfSendId: row.retry_of_send_id,
      retryCount: row.retry_count,
      lastRetryAt: row.last_retry_at ? row.last_retry_at.toISOString() : null,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }
}
DOC

echo "Criando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-send-failures/attendance-send-failures.controller.ts" <<'DOC'
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
import { AttendanceSendFailuresService } from './attendance-send-failures.service';
import type { AttendanceSendRetryPayload } from './attendance-send-failures.types';

@Controller('attendance-send-failures')
@UseGuards(JwtAuthGuard)
export class AttendanceSendFailuresController {
  constructor(private readonly failuresService: AttendanceSendFailuresService) {}

  @Get()
  listFailures(@CurrentUser() user: AuthenticatedUser) {
    return this.failuresService.listFailures(user.tenantId);
  }

  @Post(':sendId/retry')
  retryFailure(
    @CurrentUser() user: AuthenticatedUser,
    @Param('sendId') sendId: string,
    @Body() body: AttendanceSendRetryPayload
  ) {
    return this.failuresService.retryFailure(user.tenantId, sendId, body);
  }

  @Get('retries')
  listRetries(@CurrentUser() user: AuthenticatedUser) {
    return this.failuresService.listRetries(user.tenantId);
  }
}
DOC

echo "Criando modulo backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-send-failures/attendance-send-failures.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AttendanceSendModule } from '../attendance-send/attendance-send.module';
import { DatabaseModule } from '../database/database.module';
import { AttendanceSendFailuresController } from './attendance-send-failures.controller';
import { AttendanceSendFailuresService } from './attendance-send-failures.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({}),
    AttendanceSendModule
  ],
  controllers: [
    AttendanceSendFailuresController
  ],
  providers: [
    AttendanceSendFailuresService
  ]
})
export class AttendanceSendFailuresModule {}
DOC

echo "Atualizando app.module.ts..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()
import_line = "import { AttendanceSendFailuresModule } from './modules/attendance-send-failures/attendance-send-failures.module';"

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

if "AttendanceSendFailuresModule" not in match.group(1):
    text = re.sub(r"imports:\s*\[", "imports: [\n    AttendanceSendFailuresModule,", text, count=1)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance-send-failures" \
  "${BACKEND_DIR}/src/modules/attendance-send" \
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

cat > "${FRONTEND_DIR}/src/types/attendance-send-failures.types.ts" <<'DOC'
export type AttendanceSendFailureItem = {
  id: string;
  conversationId: string;
  contactId: string | null;
  contactPhone: string | null;
  whatsappAccountId: string | null;
  phoneNumberId: string | null;
  messageBody: string;
  sentByUserId: string | null;
  sentByName: string;
  departmentName: string;
  conversationStatus: string;
  messageOrigin: string;
  quickReplyId: string | null;
  quickReplyTitle: string | null;
  provider: string;
  providerMessageId: string | null;
  status: string;
  errorMessage: string | null;
  dryRun: boolean;
  attendantSource: string | null;
  assignedUserIdAtSend: string | null;
  assignedUserNameAtSend: string | null;
  retryOfSendId: string | null;
  retryCount: number;
  lastRetryAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceSendFailuresData = {
  failures: AttendanceSendFailureItem[];
};

export type AttendanceSendRetryData = {
  original: AttendanceSendFailureItem;
  retry: AttendanceSendFailureItem;
};

export type AttendanceSendRetriesData = {
  retries: AttendanceSendFailureItem[];
};
DOC

echo "Criando service frontend..."

cat > "${FRONTEND_DIR}/src/services/attendance-send-failures.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AttendanceSendFailuresData,
  AttendanceSendRetriesData,
  AttendanceSendRetryData
} from '../types/attendance-send-failures.types';

export async function listAttendanceSendFailuresRequest(token: string) {
  return apiRequest<AttendanceSendFailuresData>('/attendance-send-failures', {
    method: 'GET',
    token
  });
}

export async function retryAttendanceSendFailureRequest(
  token: string,
  sendId: string,
  payload: {
    dryRun: boolean;
    sentByName: string;
  }
) {
  return apiRequest<AttendanceSendRetryData>('/attendance-send-failures/' + sendId + '/retry', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceSendRetriesRequest(token: string) {
  return apiRequest<AttendanceSendRetriesData>('/attendance-send-failures/retries', {
    method: 'GET',
    token
  });
}
DOC

echo "Criando pagina frontend..."

cat > "${FRONTEND_DIR}/src/pages/send-failures/SendFailuresPage.tsx" <<'DOC'
import { useEffect, useState } from 'react';
import {
  listAttendanceSendFailuresRequest,
  listAttendanceSendRetriesRequest,
  retryAttendanceSendFailureRequest
} from '../../services/attendance-send-failures.service';
import { useAuthStore } from '../../stores/auth.store';
import type { AttendanceSendFailureItem } from '../../types/attendance-send-failures.types';

export function SendFailuresPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [failures, setFailures] = useState<AttendanceSendFailureItem[]>([]);
  const [retries, setRetries] = useState<AttendanceSendFailureItem[]>([]);
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(true);
  const [retryingId, setRetryingId] = useState('');
  const [dryRun, setDryRun] = useState(true);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadData() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const [failuresResponse, retriesResponse] = await Promise.all([
      listAttendanceSendFailuresRequest(token),
      listAttendanceSendRetriesRequest(token)
    ]);

    if (failuresResponse.success) {
      setFailures(failuresResponse.data.failures);
    } else {
      setNotice(failuresResponse.error.message || 'Nao foi possivel carregar falhas de envio.');
    }

    if (retriesResponse.success) {
      setRetries(retriesResponse.data.retries);
    }

    setLoading(false);
  }

  async function retryFailure(sendId: string) {
    const token = getToken();

    if (!token) {
      setNotice('Token de acesso nao encontrado.');
      return;
    }

    setRetryingId(sendId);

    const response = await retryAttendanceSendFailureRequest(token, sendId, {
      dryRun,
      sentByName: 'Retentativa painel'
    });

    if (response.success) {
      if (response.data.retry.dryRun) {
        setNotice('Retentativa validada em dryRun. Nenhuma mensagem real foi enviada.');
      } else if (response.data.retry.status === 'sent') {
        setNotice('Retentativa enviada com sucesso.');
      } else {
        setNotice(response.data.retry.errorMessage || 'Retentativa registrada.');
      }

      await loadData();
    } else {
      setNotice(response.error.message || 'Nao foi possivel retentar envio.');
    }

    setRetryingId('');
  }

  useEffect(() => {
    void loadData();
  }, []);

  return (
    <section className="send-failures-shell">
      <section className="inbox-hero">
        <div>
          <span>Falhas e retentativas</span>
          <h1>Painel de envios com falha</h1>
          <p>Analise falhas retornadas pela Meta ou pelo backend e execute retentativas controladas.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="send-failures-toolbar">
        <label>
          <input
            checked={dryRun}
            onChange={(event) => setDryRun(event.target.checked)}
            type="checkbox"
          />
          Retentar em modo dryRun
        </label>

        <button onClick={() => void loadData()} type="button">
          Atualizar
        </button>
      </section>

      {loading ? <div className="conversation-empty">Carregando falhas...</div> : null}

      <section className="send-failures-grid">
        <article>
          <div className="inbox-panel-title">
            <strong>Envios com falha</strong>
            <span>{failures.length} registros encontrados</span>
          </div>

          <div className="send-failure-list">
            {failures.length ? failures.map((failure) => (
              <div key={failure.id}>
                <header>
                  <strong>{failure.sentByName}</strong>
                  <span>{failure.status}</span>
                </header>

                <p>{failure.messageBody}</p>

                <small>Origem: {failure.messageOrigin}</small>
                <small>Departamento: {failure.departmentName}</small>
                <small>Retentativas: {failure.retryCount}</small>
                <small>Criado em: {failure.createdAt}</small>

                {failure.errorMessage ? <em>{failure.errorMessage}</em> : null}

                <button
                  disabled={retryingId === failure.id}
                  onClick={() => void retryFailure(failure.id)}
                  type="button"
                >
                  {retryingId === failure.id ? 'Retentando...' : dryRun ? 'Validar retentativa' : 'Retentar envio'}
                </button>
              </div>
            )) : <p>Nenhum envio com falha encontrado.</p>}
          </div>
        </article>

        <article>
          <div className="inbox-panel-title">
            <strong>Retentativas recentes</strong>
            <span>{retries.length} registros encontrados</span>
          </div>

          <div className="send-failure-list">
            {retries.length ? retries.map((retry) => (
              <div key={retry.id}>
                <header>
                  <strong>{retry.sentByName}</strong>
                  <span>{retry.status}{retry.dryRun ? ' - dryRun' : ''}</span>
                </header>

                <p>{retry.messageBody}</p>

                <small>Origem original: {retry.retryOfSendId}</small>
                <small>Criado em: {retry.createdAt}</small>

                {retry.errorMessage ? <em>{retry.errorMessage}</em> : null}
              </div>
            )) : <p>Nenhuma retentativa registrada.</p>}
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

if "SendFailuresPage" not in text:
    lines = text.splitlines()
    insert_index = 0

    for index, line in enumerate(lines):
        if line.startswith("import "):
            insert_index = index

    lines.insert(insert_index + 1, "import { SendFailuresPage } from '../pages/send-failures/SendFailuresPage';")
    text = "\n".join(lines) + "\n"

if 'path="send-failures"' not in text:
    text = text.replace(
        '<Route path="attendance-dashboard" element={<AttendanceDashboardPage />} />',
        '<Route path="attendance-dashboard" element={<AttendanceDashboardPage />} />\n          <Route path="send-failures" element={<SendFailuresPage />} />'
    )

path.write_text(text)
PY

echo "Atualizando Sidebar..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/components/layout/Sidebar.tsx")
text = path.read_text()

if 'to="/app/send-failures"' not in text:
    anchor = '<NavLink to="/app/attendance-dashboard">Dashboard atendimento</NavLink>'

    if anchor in text:
        text = text.replace(
            anchor,
            anchor + '\n        <NavLink to="/app/send-failures">Falhas de envio</NavLink>'
        )
    else:
        text = text.replace(
            '<NavLink to="/app/inbox">Atendimento</NavLink>',
            '<NavLink to="/app/inbox">Atendimento</NavLink>\n        <NavLink to="/app/send-failures">Falhas de envio</NavLink>'
        )

path.write_text(text)
PY

echo "Adicionando CSS do painel de falhas..."

if ! grep -q "Etapa 72 - Painel de falhas" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 72 - Painel de falhas e retentativas de envio */

.send-failures-shell {
  display: grid;
  gap: 20px;
}

.send-failures-toolbar {
  align-items: center;
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 18px;
  display: flex;
  gap: 14px;
  justify-content: space-between;
  padding: 14px 16px;
}

.send-failures-toolbar label {
  align-items: center;
  color: #374151;
  display: flex;
  font-weight: 900;
  gap: 8px;
}

.send-failures-toolbar button,
.send-failure-list button {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-600, #2563eb));
  border: none;
  border-radius: 999px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 10px 14px;
}

.send-failure-list button:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.send-failures-grid {
  display: grid;
  gap: 16px;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
}

.send-failures-grid > article {
  background: #ffffff;
  border: 1px solid var(--lh-border, #e5e7eb);
  border-radius: 22px;
  box-shadow: var(--lh-shadow, 0 18px 50px rgba(4, 32, 79, 0.12));
  padding: 18px;
}

.send-failure-list {
  display: grid;
  gap: 12px;
  margin-top: 16px;
  max-height: 640px;
  overflow: auto;
}

.send-failure-list > div {
  background: #f8fafc;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  display: grid;
  gap: 8px;
  padding: 14px;
}

.send-failure-list header {
  align-items: center;
  display: flex;
  gap: 8px;
  justify-content: space-between;
}

.send-failure-list strong {
  color: var(--lh-blue-950, #04204f);
}

.send-failure-list header span {
  background: #fee2e2;
  border-radius: 999px;
  color: #991b1b;
  font-size: 12px;
  font-weight: 950;
  padding: 5px 8px;
}

.send-failure-list p {
  color: #374151;
  margin: 0;
  white-space: pre-wrap;
}

.send-failure-list small {
  color: var(--lh-muted, #6b7280);
  display: block;
}

.send-failure-list em {
  color: #b91c1c;
  font-style: normal;
  font-weight: 850;
}

@media (max-width: 1000px) {
  .send-failures-grid {
    grid-template-columns: 1fr;
  }

  .send-failures-toolbar {
    align-items: stretch;
    flex-direction: column;
  }
}
DOC
fi

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/send-failures/SendFailuresPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-send-failures.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-send-failures.types.ts" \
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

DOMAIN_ATTENDANCE_LIST_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/conversations" || true)"

if [ "${DOMAIN_ATTENDANCE_LIST_STATUS}" != "200" ]; then
  echo "ERRO: attendance conversations falhou. Status ${DOMAIN_ATTENDANCE_LIST_STATUS}"
  cat "${DOMAIN_ATTENDANCE_LIST_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

if [ -n "${CONVERSATION_ID}" ]; then
  docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<SQL | tee "${DOMAIN_SEED_FAILURE_LOG}"
insert into attendance_manual_message_sends (
  tenant_id,
  conversation_id,
  contact_id,
  contact_phone,
  whatsapp_account_id,
  phone_number_id,
  message_body,
  sent_by_user_id,
  sent_by_name,
  department_name,
  conversation_status,
  message_origin,
  provider,
  status,
  error_message,
  dry_run,
  attendant_source,
  created_at,
  updated_at
)
select
  c.tenant_id,
  c.id,
  c.contact_id,
  coalesce(ct.phone, '5500000000000'),
  c.whatsapp_account_id,
  wa.phone_number_id,
  'Falha sintetica controlada para validacao da Etapa 72',
  null,
  'Validacao Etapa 72',
  coalesce(cos.department_name, 'Comercial'),
  coalesce(cos.status, 'novo'),
  'manual',
  'meta',
  'failed',
  'Falha sintetica controlada para validar painel de retentativas',
  true,
  'validation',
  now(),
  now()
from conversations c
left join contacts ct on ct.id = c.contact_id
left join whatsapp_accounts wa on wa.id = c.whatsapp_account_id
left join conversation_operational_status cos on cos.conversation_id = c.id
where c.id = '${CONVERSATION_ID}'::uuid
returning id;
SQL
else
  echo "SKIPPED: sem conversa real para seed de falha" > "${DOMAIN_SEED_FAILURE_LOG}"
fi

DOMAIN_FAILURES_STATUS="$(curl -L -s -o "${DOMAIN_FAILURES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_FAILURES_URL}" || true)"

if [ "${DOMAIN_FAILURES_STATUS}" != "200" ]; then
  echo "ERRO: failures endpoint falhou. Status ${DOMAIN_FAILURES_STATUS}"
  cat "${DOMAIN_FAILURES_LOG}"
  exit 1
fi

FAILURE_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.failures)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_FAILURES_LOG}" || true)"

DOMAIN_RETRY_STATUS="SKIPPED"

if [ -n "${FAILURE_ID}" ]; then
  RETRY_PAYLOAD="$(node -e "console.log(JSON.stringify({dryRun:true, sentByName:'Retentativa Etapa 72'}))")"

  DOMAIN_RETRY_STATUS="$(curl -L -s -o "${DOMAIN_RETRY_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${RETRY_PAYLOAD}" \
    "${DOMAIN_FAILURES_URL}/${FAILURE_ID}/retry" || true)"

  if [ "${DOMAIN_RETRY_STATUS}" != "200" ] && [ "${DOMAIN_RETRY_STATUS}" != "201" ]; then
    echo "ERRO: retry endpoint falhou. Status ${DOMAIN_RETRY_STATUS}"
    cat "${DOMAIN_RETRY_LOG}"
    exit 1
  fi

  if ! grep -q "retry" "${DOMAIN_RETRY_LOG}"; then
    echo "ERRO: retry endpoint nao retornou retry."
    cat "${DOMAIN_RETRY_LOG}"
    exit 1
  fi
else
  echo '{"skipped":"sem falha para retentativa"}' > "${DOMAIN_RETRY_LOG}"
fi

DOMAIN_RETRIES_STATUS="$(curl -L -s -o "${DOMAIN_RETRIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_FAILURES_URL}/retries" || true)"

if [ "${DOMAIN_RETRIES_STATUS}" != "200" ]; then
  echo "ERRO: retries endpoint falhou. Status ${DOMAIN_RETRIES_STATUS}"
  cat "${DOMAIN_RETRIES_LOG}"
  exit 1
fi

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_INBOX_PAGE_URL}" || true)"

if [ "${DOMAIN_INBOX_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina inbox nao respondeu 200."
  exit 1
fi

DOMAIN_SEND_FAILURES_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_SEND_FAILURES_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_SEND_FAILURES_PAGE_URL}" || true)"

if [ "${DOMAIN_SEND_FAILURES_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina send failures nao respondeu 200."
  exit 1
fi

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: dashboard nao respondeu 200."
  exit 1
fi

DOMAIN_ATTENDANCE_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_ATTENDANCE_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: attendance dashboard nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 72..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Send Failures Retry Panel

## Visao geral

Este documento registra a criacao do painel de falhas e retentativas de envio.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- listagem de envios com falha
- endpoint para retentar envio com falha
- endpoint para listar retentativas
- campos de relacionamento entre envio original e retentativa
- contador de retentativas no envio original
- data da ultima retentativa
- painel visual app send failures
- modo dryRun ativo por padrao na retentativa
- validacao com falha sintetica controlada
- historico visual de retentativas

## Endpoints criados

Endpoints:

- GET api v1 attendance send failures
- POST api v1 attendance send failures send id retry
- GET api v1 attendance send failures retries

## Alteracoes de banco

Alteracoes:

- retry of send id em attendance manual message sends
- retry count em attendance manual message sends
- last retry at em attendance manual message sends
- indices de apoio para falhas e retentativas

## Tela criada

Tela:

- app send failures

## Observacao operacional

A retentativa usa dryRun por padrao na tela e na validacao automatica.

Isso evita envio real acidental e permite validar a correcao antes de retentar em producao.

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-send-failures/attendance-send-failures.types.ts
- apps/backend/src/modules/attendance-send-failures/attendance-send-failures.service.ts
- apps/backend/src/modules/attendance-send-failures/attendance-send-failures.controller.ts
- apps/backend/src/modules/attendance-send-failures/attendance-send-failures.module.ts
- apps/backend/src/modules/attendance-send/attendance-send.module.ts
- apps/backend/src/app.module.ts
- apps/frontend/src/types/attendance-send-failures.types.ts
- apps/frontend/src/services/attendance-send-failures.service.ts
- apps/frontend/src/pages/send-failures/SendFailuresPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_SEND_FAILURES_RETRY_PANEL.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- alteracao idempotente da tabela de envios
- npm run typecheck no backend
- npm run build no backend
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint attendance conversations dominio
- criacao de falha sintetica controlada
- endpoint failures dominio
- endpoint retry dominio em dryRun
- endpoint retries dominio
- rota app inbox
- rota app send failures
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_72_backend_typecheck.log
- logs/setup_72_backend_build.log
- logs/setup_72_frontend_typecheck.log
- logs/setup_72_frontend_build.log
- logs/setup_72_backend_docker_build.log
- logs/setup_72_frontend_docker_build.log
- logs/setup_72_docker_up.log
- logs/setup_72_backend_wait.log
- logs/setup_72_auth_login_domain.log
- logs/setup_72_attendance_conversations_domain.log
- logs/setup_72_seed_failure.log
- logs/setup_72_failures_domain.log
- logs/setup_72_retry_domain.log
- logs/setup_72_retries_domain.log
- logs/setup_72_domain_inbox_page.log
- logs/setup_72_domain_send_failures_page.log
- logs/setup_72_domain_dashboard.log
- logs/setup_72_domain_attendance_dashboard.log
- logs/setup_72.log

## Proxima etapa sugerida

Etapa 73:

    Revisao final da fase de automacao e envio real
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 72 - Painel de falhas e retentativas de envio",
    "- [x] Etapa 72 - Painel de falhas e retentativas de envio\n- [ ] Etapa 73 - Revisao final da fase de automacao e envio real"
)

text = text.replace(
    "Etapa 72 - Painel de falhas e retentativas de envio.",
    "Etapa 73 - Revisao final da fase de automacao e envio real."
)

text = text.replace(
    "Etapa 71 - Automacoes basicas por status e departamento.",
    "Etapa 72 - Painel de falhas e retentativas de envio."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Painel de falhas e retentativas de envio criado." not in text:
    text = text.replace(
        "Automacoes basicas por status e departamento criadas.",
        "Automacoes basicas por status e departamento criadas.\n\nPainel de falhas e retentativas de envio criado."
    )

if "- docs/ATTENDANCE_SEND_FAILURES_RETRY_PANEL.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_BASIC_AUTOMATIONS.md",
        "- docs/ATTENDANCE_SEND_FAILURES_RETRY_PANEL.md\n- docs/ATTENDANCE_BASIC_AUTOMATIONS.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 71 concluidas",
    "- Etapa 01 ate Etapa 72 concluidas"
)

text = text.replace(
    "- Etapa 72 - Painel de falhas e retentativas de envio",
    "- Etapa 73 - Revisao final da fase de automacao e envio real"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 72 - Painel de falhas e retentativas de envio
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criado painel de falhas e retentativas de envio, com listagem de falhas, retentativa em dryRun, historico de retentativas e vinculacao entre envio original e nova tentativa.
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
Etapa: 72
Acao: Painel de falhas e retentativas de envio
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Failures status: ${DOMAIN_FAILURES_STATUS}
Retry status: ${DOMAIN_RETRY_STATUS}
Retries status: ${DOMAIN_RETRIES_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Send failures page status: ${DOMAIN_SEND_FAILURES_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Attendance dashboard status: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 72 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 73 - Revisao final da fase de automacao e envio real"
