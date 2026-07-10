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

LOG_FILE="${LOGS_DIR}/setup_68.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_68_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_68_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_68_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_68_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_68_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_68_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_68_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_68_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_68_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_68_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_68_attendance_conversations_domain.log"
DOMAIN_QUICK_REPLIES_LOG="${LOGS_DIR}/setup_68_quick_replies_domain.log"
DOMAIN_QUICK_REPLY_SEND_LOG="${LOGS_DIR}/setup_68_quick_reply_send_domain.log"
DOMAIN_SEND_HISTORY_LOG="${LOGS_DIR}/setup_68_send_history_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_68_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_68_domain_dashboard.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_68_domain_attendance_dashboard.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_QUICK_REPLY_SEND.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_SEND_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_ATTENDANCE_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"

echo "== Etapa 68: Envio real usando respostas rapidas =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 67..."

if [ ! -f "${LOGS_DIR}/setup_67.log" ]; then
  echo "ERRO: setup_67.log nao encontrado. Conclua a Etapa 67 antes da Etapa 68."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_67.log"; then
  echo "ERRO: Etapa 67 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_67.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-send.types.ts" \
  "${FRONTEND_DIR}/src/services/attendance-send.service.ts" \
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

echo "Atualizando tabela de envios para resposta rapida..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
alter table attendance_manual_message_sends
  add column if not exists quick_reply_id uuid;

alter table attendance_manual_message_sends
  add column if not exists quick_reply_title text;

create index if not exists idx_attendance_manual_message_sends_quick_reply
on attendance_manual_message_sends (tenant_id, quick_reply_id);
SQL

echo "Atualizando types backend..."

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
  quickReplyId?: string | null;
  quickReplyTitle?: string | null;
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
  quickReplyId: string | null;
  quickReplyTitle: string | null;
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

echo "Atualizando service backend de envio..."

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
  quick_reply_id: string | null;
  quick_reply_title: string | null;
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

    if (origin === 'quick_reply' && !payload.quickReplyId) {
      throw new BadRequestException('Resposta rapida e obrigatoria para origem quick reply');
    }

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
      'insert into attendance_manual_message_sends (tenant_id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, status, dry_run, created_at, updated_at) values ($1::uuid, $2::uuid, $3::uuid, $4, $5::uuid, $6, $7, $8::uuid, $9, $10, $11, $12, $13::uuid, $14, $15, $16, $17, now(), now()) returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at',
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
      payload.quickReplyId || null,
      payload.quickReplyTitle || null,
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
        'update attendance_manual_message_sends set status = $3, provider_message_id = $4, provider_response = $5::jsonb, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at',
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
        'update attendance_manual_message_sends set status = $3, error_message = $4, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at',
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
      'select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at from attendance_manual_message_sends where tenant_id = $1::uuid and conversation_id = $2::uuid order by created_at desc limit 100',
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
      quickReplyId: row.quick_reply_id,
      quickReplyTitle: row.quick_reply_title,
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

echo "Atualizando types frontend..."

cat > "${FRONTEND_DIR}/src/types/attendance-send.types.ts" <<'DOC'
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
  quickReplyId: string | null;
  quickReplyTitle: string | null;
  provider: string;
  providerMessageId: string | null;
  status: string;
  errorMessage: string | null;
  dryRun: boolean;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceSendManualData = {
  send: AttendanceSendItem;
};

export type AttendanceSendHistoryData = {
  sends: AttendanceSendItem[];
};
DOC

echo "Atualizando service frontend..."

cat > "${FRONTEND_DIR}/src/services/attendance-send.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  AttendanceSendHistoryData,
  AttendanceSendManualData
} from '../types/attendance-send.types';

export async function sendAttendanceManualMessageRequest(
  token: string,
  conversationId: string,
  payload: {
    messageBody: string;
    sentByUserId?: string | null;
    sentByName: string;
    departmentName: string;
    messageOrigin: string;
    quickReplyId?: string | null;
    quickReplyTitle?: string | null;
    dryRun: boolean;
  }
) {
  return apiRequest<AttendanceSendManualData>('/attendance-send/conversations/' + conversationId + '/messages', {
    method: 'POST',
    token,
    body: payload
  });
}

export async function listAttendanceSendHistoryRequest(
  token: string,
  conversationId: string
) {
  return apiRequest<AttendanceSendHistoryData>('/attendance-send/conversations/' + conversationId + '/messages', {
    method: 'GET',
    token
  });
}
DOC

echo "Atualizando InboxPage.tsx para resposta rapida com origem..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

if "selectedQuickReplyId" not in text:
    anchor = "const [sendingMessage, setSendingMessage] = useState(false);"
    if anchor not in text:
        raise SystemExit("Nao foi possivel localizar estado sendingMessage")
    text = text.replace(
        anchor,
        anchor + "\n  const [selectedQuickReplyId, setSelectedQuickReplyId] = useState<string | null>(null);\n  const [selectedQuickReplyTitle, setSelectedQuickReplyTitle] = useState<string | null>(null);"
    )

if "function applyQuickReply" not in text:
    marker = "async function handleSendComposerMessage()"
    method = """function applyQuickReply(reply: AttendanceQuickReplyItem) {
    setComposerText(reply.message);
    setSelectedQuickReplyId(reply.id);
    setSelectedQuickReplyTitle(reply.title);
    setNotice('Resposta rapida selecionada: ' + reply.title);
  }

  function clearQuickReplySelection() {
    setSelectedQuickReplyId(null);
    setSelectedQuickReplyTitle(null);
  }

  """
    text = text.replace(marker, method + marker)

old_payload = """messageOrigin: 'manual',
      dryRun: sendDryRun"""
new_payload = """messageOrigin: selectedQuickReplyId ? 'quick_reply' : 'manual',
      quickReplyId: selectedQuickReplyId,
      quickReplyTitle: selectedQuickReplyTitle,
      dryRun: sendDryRun"""

if old_payload in text:
    text = text.replace(old_payload, new_payload)

old_success = """if (sendDryRun) {
        setNotice('Envio validado em modo dryRun. Nenhuma mensagem real foi enviada.');
      } else if (response.data.send.status === 'sent') {
        setComposerText('');
        setNotice('Mensagem enviada com sucesso.');
      } else {"""

new_success = """if (sendDryRun) {
        setNotice(selectedQuickReplyId ? 'Resposta rapida validada em modo dryRun.' : 'Envio validado em modo dryRun. Nenhuma mensagem real foi enviada.');
      } else if (response.data.send.status === 'sent') {
        setComposerText('');
        clearQuickReplySelection();
        setNotice(selectedQuickReplyId ? 'Resposta rapida enviada com sucesso.' : 'Mensagem enviada com sucesso.');
      } else {"""

if old_success in text:
    text = text.replace(old_success, new_success)

old_quick = """<button key={reply.id} onClick={() => setComposerText(reply.message)} type="button">
                {reply.title}
              </button>"""
new_quick = """<button
                className={selectedQuickReplyId === reply.id ? 'active' : ''}
                key={reply.id}
                onClick={() => applyQuickReply(reply)}
                type="button"
              >
                {reply.title}
              </button>"""

if old_quick in text:
    text = text.replace(old_quick, new_quick)

if "quick-reply-selected-box" not in text:
    marker = """          <section className="inbox-quick-replies">"""
    insert = """          {selectedQuickReplyTitle ? (
            <div className="quick-reply-selected-box">
              <span>Resposta rapida selecionada: {selectedQuickReplyTitle}</span>
              <button onClick={clearQuickReplySelection} type="button">Limpar</button>
            </div>
          ) : null}

"""
    text = text.replace(marker, insert + marker)

old_history = """<span>{send.status}{send.dryRun ? ' - dryRun' : ''}</span>"""
new_history = """<span>{send.status}{send.dryRun ? ' - dryRun' : ''}{send.messageOrigin === 'quick_reply' ? ' - resposta rapida' : ''}</span>"""

if old_history in text:
    text = text.replace(old_history, new_history)

old_history_p = """<p>{send.messageBody}</p>"""
new_history_p = """{send.quickReplyTitle ? <small>Resposta rapida: {send.quickReplyTitle}</small> : null}
                  <p>{send.messageBody}</p>"""

if old_history_p in text:
    text = text.replace(old_history_p, new_history_p)

path.write_text(text)
PY

echo "Adicionando CSS de resposta rapida selecionada..."

if ! grep -q "Etapa 68 - Envio usando respostas rapidas" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 68 - Envio usando respostas rapidas */

.inbox-quick-replies button.active {
  background: linear-gradient(135deg, var(--lh-orange-700, #f97316), var(--lh-orange-500, #ff9f1c)) !important;
  color: #ffffff !important;
}

.quick-reply-selected-box {
  align-items: center;
  background: #fff7ed;
  border-top: 1px solid #fed7aa;
  display: flex;
  gap: 10px;
  justify-content: space-between;
  padding: 12px 16px;
}

.quick-reply-selected-box span {
  color: #9a3412;
  font-weight: 900;
}

.quick-reply-selected-box button {
  background: #ffffff;
  border: 1px solid #fed7aa;
  border-radius: 999px;
  color: #9a3412;
  cursor: pointer;
  font-weight: 900;
  padding: 7px 10px;
}
DOC
fi

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance-send"
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

echo "Validando frontend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance-send.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance-send.types.ts" \
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

echo "Validando dominio e envio por resposta rapida..."

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

DOMAIN_QUICK_REPLIES_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies?departmentName=Comercial" || true)"

if [ "${DOMAIN_QUICK_REPLIES_STATUS}" != "200" ]; then
  echo "ERRO: quick replies falhou. Status ${DOMAIN_QUICK_REPLIES_STATUS}"
  cat "${DOMAIN_QUICK_REPLIES_LOG}"
  exit 1
fi

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

QUICK_REPLY_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.quickReplies)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_QUICK_REPLIES_LOG}" || true)"

QUICK_REPLY_TITLE="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.quickReplies)||[]; if(items.length){console.log(items[0].title)}" "${DOMAIN_QUICK_REPLIES_LOG}" || true)"

DOMAIN_QUICK_REPLY_SEND_STATUS="SKIPPED"
DOMAIN_SEND_HISTORY_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ] && [ -n "${QUICK_REPLY_ID}" ]; then
  SEND_PAYLOAD="$(node -e "console.log(JSON.stringify({messageBody:'Validacao dry run resposta rapida Etapa 68', sentByUserId:null, sentByName:'Validacao Etapa 68', departmentName:'Comercial', messageOrigin:'quick_reply', quickReplyId:process.argv[1], quickReplyTitle:process.argv[2], dryRun:true}))" "${QUICK_REPLY_ID}" "${QUICK_REPLY_TITLE}")"

  DOMAIN_QUICK_REPLY_SEND_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLY_SEND_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${SEND_PAYLOAD}" \
    "${DOMAIN_SEND_URL}/conversations/${CONVERSATION_ID}/messages" || true)"

  if [ "${DOMAIN_QUICK_REPLY_SEND_STATUS}" != "200" ] && [ "${DOMAIN_QUICK_REPLY_SEND_STATUS}" != "201" ]; then
    echo "ERRO: quick reply send falhou. Status ${DOMAIN_QUICK_REPLY_SEND_STATUS}"
    cat "${DOMAIN_QUICK_REPLY_SEND_LOG}"
    exit 1
  fi

  if ! grep -q "quick_reply" "${DOMAIN_QUICK_REPLY_SEND_LOG}"; then
    echo "ERRO: envio nao retornou origem quick_reply."
    cat "${DOMAIN_QUICK_REPLY_SEND_LOG}"
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
  echo '{"skipped":"sem conversa ou resposta rapida para dry run"}' > "${DOMAIN_QUICK_REPLY_SEND_LOG}"
  echo '{"skipped":"sem conversa para historico"}' > "${DOMAIN_SEND_HISTORY_LOG}"
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

DOMAIN_ATTENDANCE_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANCE_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_ATTENDANCE_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: attendance dashboard nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 68..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Quick Reply Send

## Visao geral

Este documento registra o envio usando respostas rapidas na central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- origem quick reply no envio pela central
- quick reply id no registro do envio
- quick reply title no registro do envio
- selecao visual de resposta rapida
- destaque visual da resposta rapida selecionada
- botao para limpar resposta rapida selecionada
- envio com message origin quick reply
- historico visual indicando resposta rapida usada
- validacao dryRun de resposta rapida

## Comportamento

Comportamento:

- ao clicar em uma resposta rapida, o campo de mensagem e preenchido
- a resposta rapida fica selecionada visualmente
- ao enviar, o backend recebe message origin quick reply
- o envio grava quick reply id e quick reply title
- em modo dryRun nenhuma mensagem real e enviada
- ao desativar dryRun o backend tenta enviar pela API oficial da Meta

## Alteracoes de banco

Alteracoes:

- quick reply id em attendance manual message sends
- quick reply title em attendance manual message sends
- indice por quick reply id

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-send/attendance-send.types.ts
- apps/backend/src/modules/attendance-send/attendance-send.service.ts
- apps/frontend/src/types/attendance-send.types.ts
- apps/frontend/src/services/attendance-send.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_QUICK_REPLY_SEND.md
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
- endpoint quick replies dominio
- dryRun de envio com origem quick reply
- historico de envios
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_68_backend_typecheck.log
- logs/setup_68_backend_build.log
- logs/setup_68_frontend_typecheck.log
- logs/setup_68_frontend_build.log
- logs/setup_68_backend_docker_build.log
- logs/setup_68_frontend_docker_build.log
- logs/setup_68_docker_up.log
- logs/setup_68_backend_wait.log
- logs/setup_68_auth_login_domain.log
- logs/setup_68_attendance_conversations_domain.log
- logs/setup_68_quick_replies_domain.log
- logs/setup_68_quick_reply_send_domain.log
- logs/setup_68_send_history_domain.log
- logs/setup_68_domain_inbox_page.log
- logs/setup_68_domain_dashboard.log
- logs/setup_68_domain_attendance_dashboard.log
- logs/setup_68.log

## Proxima etapa sugerida

Etapa 69:

    Envio real da mensagem de encerramento com avaliacao
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 68 - Envio real usando respostas rapidas",
    "- [x] Etapa 68 - Envio real usando respostas rapidas\n- [ ] Etapa 69 - Envio real da mensagem de encerramento com avaliacao"
)

text = text.replace(
    "Etapa 68 - Envio real usando respostas rapidas.",
    "Etapa 69 - Envio real da mensagem de encerramento com avaliacao."
)

text = text.replace(
    "Etapa 67 - Frontend de envio real no app inbox.",
    "Etapa 68 - Envio real usando respostas rapidas."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Envio real usando respostas rapidas criado." not in text:
    text = text.replace(
        "Frontend de envio real no app inbox criado.",
        "Frontend de envio real no app inbox criado.\n\nEnvio real usando respostas rapidas criado."
    )

if "- docs/ATTENDANCE_QUICK_REPLY_SEND.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_SEND_FRONTEND.md",
        "- docs/ATTENDANCE_QUICK_REPLY_SEND.md\n- docs/ATTENDANCE_SEND_FRONTEND.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 67 concluidas",
    "- Etapa 01 ate Etapa 68 concluidas"
)

text = text.replace(
    "- Etapa 68 - Envio real usando respostas rapidas",
    "- Etapa 69 - Envio real da mensagem de encerramento com avaliacao"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 68 - Envio real usando respostas rapidas
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Integrado envio pela central com origem quick_reply, registrando resposta rapida selecionada, quick reply id, titulo e historico visual de envio.
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
Etapa: 68
Acao: Envio real usando respostas rapidas
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Quick replies status: ${DOMAIN_QUICK_REPLIES_STATUS}
Quick reply send status: ${DOMAIN_QUICK_REPLY_SEND_STATUS}
Send history status: ${DOMAIN_SEND_HISTORY_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Attendance dashboard status: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 68 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 69 - Envio real da mensagem de encerramento com avaliacao"
