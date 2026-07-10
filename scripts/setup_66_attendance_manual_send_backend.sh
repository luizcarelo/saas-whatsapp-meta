#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_66.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_66_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_66_backend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_66_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_66_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_66_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_66_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_66_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_66_attendance_conversations_domain.log"
DOMAIN_SEND_DRY_RUN_LOG="${LOGS_DIR}/setup_66_send_dry_run_domain.log"
DOMAIN_SEND_HISTORY_LOG="${LOGS_DIR}/setup_66_send_history_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_66_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_66_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_66_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_MANUAL_SEND_BACKEND.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_SEND_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Etapa 66: Backend de envio manual pela central de atendimento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/attendance-send"

echo "Validando conclusao da Etapa 65..."

if [ ! -f "${LOGS_DIR}/setup_65.log" ]; then
  echo "ERRO: setup_65.log nao encontrado. Conclua a Etapa 65 antes da Etapa 66."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_65.log"; then
  echo "ERRO: Etapa 65 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_65.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.controller.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.module.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
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

echo "Criando tabela de envios manuais da central..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists attendance_manual_message_sends (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  conversation_id uuid not null,
  contact_id uuid,
  contact_phone text,
  whatsapp_account_id uuid,
  phone_number_id text,
  message_body text not null,
  sent_by_user_id uuid,
  sent_by_name text not null,
  department_name text not null default 'Fila geral',
  conversation_status text not null default 'novo',
  message_origin text not null default 'manual',
  provider text not null default 'meta',
  provider_message_id text,
  provider_response jsonb,
  status text not null default 'pending',
  error_message text,
  dry_run boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_attendance_manual_message_sends_tenant
on attendance_manual_message_sends (tenant_id);

create index if not exists idx_attendance_manual_message_sends_conversation
on attendance_manual_message_sends (tenant_id, conversation_id);

create index if not exists idx_attendance_manual_message_sends_status
on attendance_manual_message_sends (tenant_id, status);
SQL

echo "Criando types backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.types.ts" <<'DOC'
export type AttendanceSendOrigin =
  | 'manual'
  | 'quick_reply'
  | 'closing_rating'
  | 'automation_greeting'
  | 'automation_transfer'
  | 'automation_waiting_customer'
  | 'automation_out_of_hours'
  | 'automation_unassigned';

export type AttendanceSendStatus =
  | 'pending'
  | 'sent'
  | 'failed'
  | 'dry_run';

export type AttendanceSendManualPayload = {
  messageBody?: string;
  sentByUserId?: string | null;
  sentByName?: string | null;
  departmentName?: string;
  messageOrigin?: AttendanceSendOrigin;
  dryRun?: boolean;
};

export type AttendanceSendItem = {
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
  provider: string;
  providerMessageId: string | null;
  status: string;
  errorMessage: string | null;
  dryRun: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceSendManualResponse = {
  success: true;
  data: {
    send: AttendanceSendItem;
  };
  meta: Record<string, never>;
};

export type AttendanceSendHistoryResponse = {
  success: true;
  data: {
    sends: AttendanceSendItem[];
  };
  meta: Record<string, never>;
};
DOC

echo "Criando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.service.ts" <<'DOC'
import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceSendHistoryResponse,
  AttendanceSendItem,
  AttendanceSendManualPayload,
  AttendanceSendManualResponse
} from './attendance-send.types';

type OperationalStatusRow = {
  status: string;
  department_name: string;
  assigned_user_id: string | null;
  assigned_user_name: string | null;
};

type SendRow = {
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
  provider: string;
  provider_message_id: string | null;
  status: string;
  error_message: string | null;
  dry_run: boolean;
  created_at: Date;
  updated_at: Date;
};

type WhatsAppAccountCandidate = {
  id: string | null;
  phone_number_id: string | null;
  access_token: string | null;
};

@Injectable()
export class AttendanceSendService {
  constructor(private readonly prismaService: PrismaService) {}

  async sendManualMessage(
    tenantId: string,
    conversationId: string,
    payload: AttendanceSendManualPayload
  ): Promise<AttendanceSendManualResponse> {
    const messageBody = this.normalizeMessage(payload.messageBody);
    const sentByName = this.normalizeName(payload.sentByName || 'Atendente');
    const origin = payload.messageOrigin || 'manual';
    const dryRun = Boolean(payload.dryRun);

    const conversation = await this.prismaService.conversation.findFirst({
      where: {
        id: conversationId,
        tenantId,
        deletedAt: null
      },
      include: {
        contact: true
      }
    });

    if (!conversation) {
      throw new BadRequestException('Conversa nao encontrada');
    }

    const contactId = conversation.contact?.id || null;
    const contactPhone = conversation.contact?.phone || null;

    if (!contactPhone) {
      throw new BadRequestException('Contato sem telefone para envio');
    }

    const operationalRows = await this.prismaService.$queryRawUnsafe<OperationalStatusRow[]>(
      'select status, department_name, assigned_user_id, assigned_user_name from conversation_operational_status where tenant_id = $1::uuid and conversation_id = $2::uuid limit 1',
      tenantId,
      conversationId
    );

    const operational = operationalRows[0];
    const conversationStatus = operational?.status || 'novo';
    const departmentName = payload.departmentName || operational?.department_name || 'Fila geral';

    if (conversationStatus === 'arquivado') {
      throw new BadRequestException('Nao e permitido enviar mensagem em conversa arquivada');
    }

    const account = await this.resolveWhatsAppAccount(tenantId);

    if (!account.phone_number_id && !dryRun) {
      throw new BadRequestException('Conta WhatsApp sem phone number id configurado');
    }

    if (!account.access_token && !dryRun) {
      throw new BadRequestException('Conta WhatsApp sem token configurado');
    }

    const initialRows = await this.prismaService.$queryRawUnsafe<SendRow[]>(
      'insert into attendance_manual_message_sends (tenant_id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, provider, status, dry_run, created_at, updated_at) values ($1::uuid, $2::uuid, $3::uuid, $4, $5::uuid, $6, $7, $8::uuid, $9, $10, $11, $12, $13, $14, $15, now(), now()) returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at',
      tenantId,
      conversationId,
      contactId,
      contactPhone,
      account.id,
      account.phone_number_id,
      messageBody,
      payload.sentByUserId || null,
      sentByName,
      departmentName,
      conversationStatus,
      origin,
      'meta',
      dryRun ? 'dry_run' : 'pending',
      dryRun
    );

    const sendId = initialRows[0].id;

    if (dryRun) {
      return {
        success: true,
        data: {
          send: this.mapSend(initialRows[0])
        },
        meta: {}
      };
    }

    try {
      const providerResponse = await this.sendToMeta(account.phone_number_id || '', account.access_token || '', contactPhone, messageBody);
      const providerMessageId = this.extractProviderMessageId(providerResponse);

      const sentRows = await this.prismaService.$queryRawUnsafe<SendRow[]>(
        'update attendance_manual_message_sends set status = $3, provider_message_id = $4, provider_response = $5::jsonb, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at',
        tenantId,
        sendId,
        'sent',
        providerMessageId,
        JSON.stringify(providerResponse)
      );

      return {
        success: true,
        data: {
          send: this.mapSend(sentRows[0])
        },
        meta: {}
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Falha desconhecida no envio';

      const failedRows = await this.prismaService.$queryRawUnsafe<SendRow[]>(
        'update attendance_manual_message_sends set status = $3, error_message = $4, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at',
        tenantId,
        sendId,
        'failed',
        errorMessage
      );

      return {
        success: true,
        data: {
          send: this.mapSend(failedRows[0])
        },
        meta: {}
      };
    }
  }

  async listSendHistory(
    tenantId: string,
    conversationId: string
  ): Promise<AttendanceSendHistoryResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<SendRow[]>(
      'select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at from attendance_manual_message_sends where tenant_id = $1::uuid and conversation_id = $2::uuid order by created_at desc limit 100',
      tenantId,
      conversationId
    );

    return {
      success: true,
      data: {
        sends: rows.map((row) => this.mapSend(row))
      },
      meta: {}
    };
  }

  private async resolveWhatsAppAccount(tenantId: string): Promise<WhatsAppAccountCandidate> {
    const envPhoneNumberId =
      process.env.META_PHONE_NUMBER_ID ||
      process.env.WHATSAPP_PHONE_NUMBER_ID ||
      process.env.WHATSAPP_CLOUD_PHONE_NUMBER_ID ||
      null;

    const envAccessToken =
      process.env.META_ACCESS_TOKEN ||
      process.env.WHATSAPP_ACCESS_TOKEN ||
      process.env.WHATSAPP_CLOUD_ACCESS_TOKEN ||
      null;

    const tableRows = await this.prismaService.$queryRawUnsafe<Array<{ table_name: string }>>(
      "select table_name from information_schema.tables where table_schema = 'public' and table_name in ('whatsapp_accounts', 'WhatsAppAccount') limit 1"
    );

    if (!tableRows.length) {
      return {
        id: null,
        phone_number_id: envPhoneNumberId,
        access_token: envAccessToken
      };
    }

    const tableName = tableRows[0].table_name;
    const columns = await this.prismaService.$queryRawUnsafe<Array<{ column_name: string }>>(
      "select column_name from information_schema.columns where table_schema = 'public' and table_name = $1",
      tableName
    );

    const columnNames = columns.map((column) => column.column_name);
    const idColumn = this.pickColumn(columnNames, ['id']);
    const tenantColumn = this.pickColumn(columnNames, ['tenant_id', 'tenantId']);
    const phoneColumn = this.pickColumn(columnNames, ['phone_number_id', 'phoneNumberId', 'phone_number_id_meta']);
    const tokenColumn = this.pickColumn(columnNames, ['access_token', 'accessToken', 'token']);
    const activeColumn = this.pickColumn(columnNames, ['is_active', 'isActive', 'active']);

    if (!idColumn || !tenantColumn) {
      return {
        id: null,
        phone_number_id: envPhoneNumberId,
        access_token: envAccessToken
      };
    }

    const selectParts = [
      '"' + idColumn + '"::text as id',
      phoneColumn ? '"' + phoneColumn + '"::text as phone_number_id' : 'null::text as phone_number_id',
      tokenColumn ? '"' + tokenColumn + '"::text as access_token' : 'null::text as access_token'
    ];

    const activeFilter = activeColumn ? ' and "' + activeColumn + '" = true' : '';

    const rows = await this.prismaService.$queryRawUnsafe<WhatsAppAccountCandidate[]>(
      'select ' + selectParts.join(', ') + ' from "' + tableName + '" where "' + tenantColumn + '" = $1::uuid' + activeFilter + ' limit 1',
      tenantId
    );

    const row = rows[0];

    return {
      id: row?.id || null,
      phone_number_id: row?.phone_number_id || envPhoneNumberId,
      access_token: row?.access_token || envAccessToken
    };
  }

  private pickColumn(columns: string[], candidates: string[]): string | null {
    for (const candidate of candidates) {
      if (columns.includes(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  private async sendToMeta(
    phoneNumberId: string,
    accessToken: string,
    to: string,
    body: string
  ): Promise<unknown> {
    const graphVersion = process.env.META_GRAPH_API_VERSION || process.env.WHATSAPP_GRAPH_API_VERSION || 'v20.0';
    const url = 'https://graph.facebook.com/' + graphVersion + '/' + phoneNumberId + '/messages';

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + accessToken,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        to,
        type: 'text',
        text: {
          preview_url: false,
          body
        }
      })
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(JSON.stringify(data));
    }

    return data;
  }

  private extractProviderMessageId(providerResponse: unknown): string | null {
    if (!providerResponse || typeof providerResponse !== 'object') {
      return null;
    }

    const value = providerResponse as { messages?: Array<{ id?: string }> };
    return value.messages?.[0]?.id || null;
  }

  private normalizeMessage(value: string | undefined): string {
    const message = (value || '').trim();

    if (!message) {
      throw new BadRequestException('Mensagem e obrigatoria');
    }

    if (message.length > 4096) {
      throw new BadRequestException('Mensagem muito longa');
    }

    return message;
  }

  private normalizeName(value: string | undefined | null): string {
    const name = (value || '').trim();

    if (!name) {
      throw new BadRequestException('Nome do atendente e obrigatorio');
    }

    if (name.length > 120) {
      throw new BadRequestException('Nome do atendente muito longo');
    }

    return name;
  }

  private mapSend(row: SendRow): AttendanceSendItem {
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
      provider: row.provider,
      providerMessageId: row.provider_message_id,
      status: row.status,
      errorMessage: row.error_message,
      dryRun: row.dry_run,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }
}
DOC

echo "Criando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.controller.ts" <<'DOC'
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
import { AttendanceSendService } from './attendance-send.service';
import type { AttendanceSendManualPayload } from './attendance-send.types';

@Controller('attendance-send')
@UseGuards(JwtAuthGuard)
export class AttendanceSendController {
  constructor(private readonly attendanceSendService: AttendanceSendService) {}

  @Post('conversations/:conversationId/messages')
  sendManualMessage(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceSendManualPayload
  ) {
    return this.attendanceSendService.sendManualMessage(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/messages')
  listSendHistory(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.attendanceSendService.listSendHistory(user.tenantId, conversationId);
  }
}
DOC

echo "Criando modulo backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceSendController } from './attendance-send.controller';
import { AttendanceSendService } from './attendance-send.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceSendController
  ],
  providers: [
    AttendanceSendService
  ]
})
export class AttendanceSendModule {}
DOC

echo "Atualizando app.module.ts..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()
import_line = "import { AttendanceSendModule } from './modules/attendance-send/attendance-send.module';"

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

if "AttendanceSendModule" not in match.group(1):
    text = re.sub(r"imports:\s*\[", "imports: [\n    AttendanceSendModule,", text, count=1)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
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

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BACKEND_BUILD_LOG}"

echo "Subindo backend e proxy..."

docker compose up -d backend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

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

DOMAIN_SEND_DRY_RUN_STATUS="SKIPPED"
DOMAIN_SEND_HISTORY_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  SEND_PAYLOAD="$(node -e "console.log(JSON.stringify({messageBody:'Validacao dry run Etapa 66', sentByUserId:null, sentByName:'Validacao Etapa 66', departmentName:'Comercial', messageOrigin:'manual', dryRun:true}))")"

  DOMAIN_SEND_DRY_RUN_STATUS="$(curl -L -s -o "${DOMAIN_SEND_DRY_RUN_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${SEND_PAYLOAD}" \
    "${DOMAIN_SEND_URL}/conversations/${CONVERSATION_ID}/messages" || true)"

  if [ "${DOMAIN_SEND_DRY_RUN_STATUS}" != "200" ] && [ "${DOMAIN_SEND_DRY_RUN_STATUS}" != "201" ]; then
    echo "ERRO: send dry run falhou. Status ${DOMAIN_SEND_DRY_RUN_STATUS}"
    cat "${DOMAIN_SEND_DRY_RUN_LOG}"
    exit 1
  fi

  if ! grep -q "dry_run" "${DOMAIN_SEND_DRY_RUN_LOG}"; then
    echo "ERRO: send dry run nao retornou status dry_run."
    cat "${DOMAIN_SEND_DRY_RUN_LOG}"
    exit 1
  fi

  DOMAIN_SEND_HISTORY_STATUS="$(curl -L -s -o "${DOMAIN_SEND_HISTORY_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    "${DOMAIN_SEND_URL}/conversations/${CONVERSATION_ID}/messages" || true)"

  if [ "${DOMAIN_SEND_HISTORY_STATUS}" != "200" ]; then
    echo "ERRO: send history falhou. Status ${DOMAIN_SEND_HISTORY_STATUS}"
    cat "${DOMAIN_SEND_HISTORY_LOG}"
    exit 1
  fi
else
  echo '{"skipped":"sem conversa real para dry run"}' > "${DOMAIN_SEND_DRY_RUN_LOG}"
  echo '{"skipped":"sem conversa real para historico"}' > "${DOMAIN_SEND_HISTORY_LOG}"
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

echo "Gerando documentacao da Etapa 66..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Manual Send Backend

## Visao geral

Este documento registra a criacao do backend de envio manual pela central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela de tentativas de envio manual pela central
- endpoint para enviar mensagem manual pela central
- endpoint para listar historico de envios da conversa
- modo dryRun para validar sem enviar mensagem real
- validacao de conversa
- validacao de contato e telefone
- validacao de mensagem
- validacao de conta WhatsApp e token quando dryRun for falso
- envio preparado para API oficial da Meta
- registro de atendente
- registro de departamento
- registro de origem da mensagem
- registro de status do envio
- registro de erro de envio

## Endpoints criados

Endpoints:

- POST api v1 attendance send conversations conversation id messages
- GET api v1 attendance send conversations conversation id messages

## Tabela criada

Tabela:

- attendance manual message sends

Campos:

- id
- tenant id
- conversation id
- contact id
- contact phone
- whatsapp account id
- phone number id
- message body
- sent by user id
- sent by name
- department name
- conversation status
- message origin
- provider
- provider message id
- provider response
- status
- error message
- dry run
- created at
- updated at

## Observacao sobre envio real

O endpoint ja esta preparado para enviar texto pela API oficial da Meta quando dryRun for falso e quando houver phone number id e token configurados.

A validacao desta etapa usa dryRun para evitar envio real durante o setup.

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-send/attendance-send.types.ts
- apps/backend/src/modules/attendance-send/attendance-send.service.ts
- apps/backend/src/modules/attendance-send/attendance-send.controller.ts
- apps/backend/src/modules/attendance-send/attendance-send.module.ts
- apps/backend/src/app.module.ts
- docs/ATTENDANCE_MANUAL_SEND_BACKEND.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela attendance manual message sends
- npm run typecheck no backend
- npm run build no backend
- docker compose build backend
- docker compose up backend proxy
- login dominio
- endpoint attendance conversations dominio
- envio dryRun quando ha conversa real
- historico de envios quando ha conversa real
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_66_backend_typecheck.log
- logs/setup_66_backend_build.log
- logs/setup_66_backend_docker_build.log
- logs/setup_66_docker_up.log
- logs/setup_66_backend_wait.log
- logs/setup_66_auth_login_domain.log
- logs/setup_66_attendance_conversations_domain.log
- logs/setup_66_send_dry_run_domain.log
- logs/setup_66_send_history_domain.log
- logs/setup_66_domain_inbox_page.log
- logs/setup_66_domain_dashboard.log
- logs/setup_66_domain_audit_page.log
- logs/setup_66.log

## Proxima etapa sugerida

Etapa 67:

    Frontend de envio real no app inbox
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 66 - Backend de envio manual pela central de atendimento",
    "- [x] Etapa 66 - Backend de envio manual pela central de atendimento\n- [ ] Etapa 67 - Frontend de envio real no app inbox"
)

text = text.replace(
    "Etapa 66 - Backend de envio manual pela central de atendimento.",
    "Etapa 67 - Frontend de envio real no app inbox."
)

text = text.replace(
    "Etapa 65 - Planejamento da proxima fase de automacao e envio real pela central de atendimento.",
    "Etapa 66 - Backend de envio manual pela central de atendimento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Backend de envio manual pela central de atendimento criado." not in text:
    text = text.replace(
        "Planejamento da fase de automacao e envio real pela central de atendimento criado.",
        "Planejamento da fase de automacao e envio real pela central de atendimento criado.\n\nBackend de envio manual pela central de atendimento criado."
    )

if "- docs/ATTENDANCE_MANUAL_SEND_BACKEND.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_AUTOMATION_SEND_PLAN.md",
        "- docs/ATTENDANCE_MANUAL_SEND_BACKEND.md\n- docs/ATTENDANCE_AUTOMATION_SEND_PLAN.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 65 concluidas",
    "- Etapa 01 ate Etapa 66 concluidas"
)

text = text.replace(
    "- Etapa 66 - Backend de envio manual pela central de atendimento",
    "- Etapa 67 - Frontend de envio real no app inbox"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 66 - Backend de envio manual pela central de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criado backend de envio manual pela central, com endpoint de envio, historico, modo dryRun, validacoes operacionais e preparacao para envio real pela API oficial da Meta.
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
Etapa: 66
Acao: Backend de envio manual pela central de atendimento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Send dry run status: ${DOMAIN_SEND_DRY_RUN_STATUS}
Send history status: ${DOMAIN_SEND_HISTORY_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 66 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 67 - Frontend de envio real no app inbox"
