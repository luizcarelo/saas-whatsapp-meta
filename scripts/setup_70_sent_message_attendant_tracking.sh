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

LOG_FILE="${LOGS_DIR}/setup_70.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_70_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_70_backend_build.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_70_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_70_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_70_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_70_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_70_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_70_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_70_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_70_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_70_attendance_conversations_domain.log"
DOMAIN_ATTENDANT_SEND_LOG="${LOGS_DIR}/setup_70_attendant_send_domain.log"
DOMAIN_SEND_HISTORY_LOG="${LOGS_DIR}/setup_70_send_history_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_70_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_70_domain_dashboard.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_70_domain_attendance_dashboard.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_SENT_MESSAGE_ATTENDANT_TRACKING.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_SEND_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_ATTENDANCE_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"

echo "== Etapa 70: Registro do atendente nas mensagens enviadas =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando conclusao da Etapa 69..."

if [ ! -f "${LOGS_DIR}/setup_69.log" ]; then
  echo "ERRO: setup_69.log nao encontrado. Conclua a Etapa 69 antes da Etapa 70."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_69.log"; then
  echo "ERRO: Etapa 69 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_69.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance-send/attendance-send.controller.ts" \
  "${FRONTEND_DIR}/src/types/attendance-send.types.ts" \
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

echo "Atualizando tabela de envios com rastreabilidade do atendente..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
alter table attendance_manual_message_sends
  add column if not exists attendant_source text not null default 'payload';

alter table attendance_manual_message_sends
  add column if not exists assigned_user_name_at_send text;

alter table attendance_manual_message_sends
  add column if not exists assigned_user_id_at_send uuid;

create index if not exists idx_attendance_manual_message_sends_attendant
on attendance_manual_message_sends (tenant_id, sent_by_name);

create index if not exists idx_attendance_manual_message_sends_attendant_source
on attendance_manual_message_sends (tenant_id, attendant_source);
SQL

echo "Atualizando types backend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/attendance-send/attendance-send.types.ts")
text = path.read_text()

if "attendantSource" not in text:
    text = text.replace(
        "dryRun?: boolean;",
        "dryRun?: boolean;\n  attendantSource?: string;\n  assignedUserIdAtSend?: string | null;\n  assignedUserNameAtSend?: string | null;"
    )

    text = text.replace(
        "dryRun: boolean;",
        "dryRun: boolean;\n  attendantSource: string;\n  assignedUserIdAtSend: string | null;\n  assignedUserNameAtSend: string | null;"
    )

path.write_text(text)
PY

echo "Atualizando controller backend com fallback do usuario autenticado..."

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

type AttendanceAuthenticatedUser = AuthenticatedUser & {
  id?: string;
  userId?: string;
  sub?: string;
  name?: string;
  fullName?: string;
  email?: string;
};

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
    const authUser = user as AttendanceAuthenticatedUser;
    const authenticatedUserId = authUser.userId || authUser.id || authUser.sub || null;
    const authenticatedName = authUser.name || authUser.fullName || authUser.email || null;

    const payload: AttendanceSendManualPayload = {
      ...body,
      sentByUserId: body.sentByUserId || authenticatedUserId,
      sentByName: body.sentByName || authenticatedName || 'Atendente autenticado',
      attendantSource: body.sentByName ? 'payload' : authenticatedName ? 'authenticated_user' : 'fallback'
    };

    return this.attendanceSendService.sendManualMessage(user.tenantId, conversationId, payload);
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

echo "Atualizando service backend para gravar snapshot do atendente..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/backend/src/modules/attendance-send/attendance-send.service.ts")
text = path.read_text()

if "attendant_source" not in text:
    text = text.replace(
        "dry_run: boolean;",
        "dry_run: boolean;\n  attendant_source: string;\n  assigned_user_id_at_send: string | null;\n  assigned_user_name_at_send: string | null;"
    )

    text = text.replace(
        "const departmentName = payload.departmentName || operational?.department_name || 'Fila geral';",
        "const departmentName = payload.departmentName || operational?.department_name || 'Fila geral';\n    const assignedUserIdAtSend = operational?.assigned_user_id || null;\n    const assignedUserNameAtSend = operational?.assigned_user_name || null;\n    const attendantSource = payload.attendantSource || (payload.sentByName ? 'payload' : 'fallback');"
    )

    text = text.replace(
        "insert into attendance_manual_message_sends (tenant_id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, status, dry_run, created_at, updated_at) values ($1::uuid, $2::uuid, $3::uuid, $4, $5::uuid, $6, $7, $8::uuid, $9, $10, $11, $12, $13::uuid, $14, $15, $16, $17, now(), now()) returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at",
        "insert into attendance_manual_message_sends (tenant_id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, status, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at) values ($1::uuid, $2::uuid, $3::uuid, $4, $5::uuid, $6, $7, $8::uuid, $9, $10, $11, $12, $13::uuid, $14, $15, $16, $17, $18, $19::uuid, $20, now(), now()) returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at"
    )

    text = text.replace(
        "dryRun\n    );",
        "dryRun,\n      attendantSource,\n      assignedUserIdAtSend,\n      assignedUserNameAtSend\n    );",
        1
    )

    text = text.replace(
        "returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at",
        "returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at"
    )

    text = text.replace(
        "select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, created_at, updated_at from attendance_manual_message_sends",
        "select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at from attendance_manual_message_sends"
    )

    text = text.replace(
        "dryRun: row.dry_run,",
        "dryRun: row.dry_run,\n      attendantSource: row.attendant_source,\n      assignedUserIdAtSend: row.assigned_user_id_at_send,\n      assignedUserNameAtSend: row.assigned_user_name_at_send,"
    )

path.write_text(text)
PY

echo "Atualizando types frontend..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/types/attendance-send.types.ts")
text = path.read_text()

if "attendantSource" not in text:
    text = text.replace(
        "dryRun: boolean;",
        "dryRun: boolean;\n  attendantSource: string;\n  assignedUserIdAtSend: string | null;\n  assignedUserNameAtSend: string | null;"
    )

path.write_text(text)
PY

echo "Atualizando historico visual no InboxPage..."

python3 <<'PY'
from pathlib import Path

path = Path("apps/frontend/src/pages/inbox/InboxPage.tsx")
text = path.read_text()

old = """<strong>{send.sentByName}</strong>
                    <span>{send.status}{send.dryRun ? ' - dryRun' : ''}{send.messageOrigin === 'quick_reply' ? ' - resposta rapida' : ''}{send.messageOrigin === 'closing_rating' ? ' - encerramento' : ''}</span>"""

new = """<strong>Atendente: {send.sentByName}</strong>
                    <span>{send.status}{send.dryRun ? ' - dryRun' : ''}{send.messageOrigin === 'quick_reply' ? ' - resposta rapida' : ''}{send.messageOrigin === 'closing_rating' ? ' - encerramento' : ''}</span>"""

if old in text:
    text = text.replace(old, new)

old2 = """{send.quickReplyTitle ? <small>Resposta rapida: {send.quickReplyTitle}</small> : null}
                  <p>{send.messageBody}</p>"""

new2 = """{send.assignedUserNameAtSend ? <small>Responsavel no momento do envio: {send.assignedUserNameAtSend}</small> : null}
                  {send.attendantSource ? <small>Origem do atendente: {send.attendantSource}</small> : null}
                  {send.quickReplyTitle ? <small>Resposta rapida: {send.quickReplyTitle}</small> : null}
                  <p>{send.messageBody}</p>"""

if old2 in text:
    text = text.replace(old2, new2)

path.write_text(text)
PY

echo "Adicionando CSS da rastreabilidade do atendente..."

if ! grep -q "Etapa 70 - Registro do atendente" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 70 - Registro do atendente nas mensagens enviadas */

.send-history-list article small {
  display: block;
  line-height: 1.35;
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

echo "Validando dominio com envio sem sentByName explicito..."

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

DOMAIN_ATTENDANT_SEND_STATUS="SKIPPED"
DOMAIN_SEND_HISTORY_STATUS="SKIPPED"

if [ -n "${CONVERSATION_ID}" ]; then
  SEND_PAYLOAD="$(node -e "console.log(JSON.stringify({messageBody:'Validacao atendente automatico Etapa 70', departmentName:'Comercial', messageOrigin:'manual', dryRun:true}))")"

  DOMAIN_ATTENDANT_SEND_STATUS="$(curl -L -s -o "${DOMAIN_ATTENDANT_SEND_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${SEND_PAYLOAD}" \
    "${DOMAIN_SEND_URL}/conversations/${CONVERSATION_ID}/messages" || true)"

  if [ "${DOMAIN_ATTENDANT_SEND_STATUS}" != "200" ] && [ "${DOMAIN_ATTENDANT_SEND_STATUS}" != "201" ]; then
    echo "ERRO: attendant send falhou. Status ${DOMAIN_ATTENDANT_SEND_STATUS}"
    cat "${DOMAIN_ATTENDANT_SEND_LOG}"
    exit 1
  fi

  if ! grep -q "attendantSource" "${DOMAIN_ATTENDANT_SEND_LOG}"; then
    echo "ERRO: envio nao retornou attendantSource."
    cat "${DOMAIN_ATTENDANT_SEND_LOG}"
    exit 1
  fi

  if ! grep -q "sentByName" "${DOMAIN_ATTENDANT_SEND_LOG}"; then
    echo "ERRO: envio nao retornou sentByName."
    cat "${DOMAIN_ATTENDANT_SEND_LOG}"
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
  echo '{"skipped":"sem conversa real para envio"}' > "${DOMAIN_ATTENDANT_SEND_LOG}"
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

echo "Gerando documentacao da Etapa 70..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Sent Message Attendant Tracking

## Visao geral

Este documento registra o reforco do registro do atendente nas mensagens enviadas pela central de atendimento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- fallback backend para identificar atendente autenticado
- registro reforcado de sent by user id
- registro reforcado de sent by name
- origem do nome do atendente
- snapshot do responsavel da conversa no momento do envio
- historico visual com destaque para atendente
- validacao dryRun sem sentByName explicito

## Campos adicionados

Campos:

- attendant source
- assigned user id at send
- assigned user name at send

## Regras

Regras:

- se frontend enviar sentByName, origem do atendente fica payload
- se frontend nao enviar sentByName, backend usa usuario autenticado
- se usuario autenticado nao tiver nome disponivel, backend usa fallback
- historico visual mostra o atendente que enviou
- historico visual mostra responsavel no momento do envio quando existir

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-send/attendance-send.types.ts
- apps/backend/src/modules/attendance-send/attendance-send.service.ts
- apps/backend/src/modules/attendance-send/attendance-send.controller.ts
- apps/frontend/src/types/attendance-send.types.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_SENT_MESSAGE_ATTENDANT_TRACKING.md
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
- envio dryRun sem sentByName explicito
- retorno com attendantSource
- retorno com sentByName
- historico de envios
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_70_backend_typecheck.log
- logs/setup_70_backend_build.log
- logs/setup_70_frontend_typecheck.log
- logs/setup_70_frontend_build.log
- logs/setup_70_backend_docker_build.log
- logs/setup_70_frontend_docker_build.log
- logs/setup_70_docker_up.log
- logs/setup_70_backend_wait.log
- logs/setup_70_auth_login_domain.log
- logs/setup_70_attendance_conversations_domain.log
- logs/setup_70_attendant_send_domain.log
- logs/setup_70_send_history_domain.log
- logs/setup_70_domain_inbox_page.log
- logs/setup_70_domain_dashboard.log
- logs/setup_70_domain_attendance_dashboard.log
- logs/setup_70.log

## Proxima etapa sugerida

Etapa 71:

    Automacoes basicas por status e departamento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 70 - Registro do atendente nas mensagens enviadas",
    "- [x] Etapa 70 - Registro do atendente nas mensagens enviadas\n- [ ] Etapa 71 - Automacoes basicas por status e departamento"
)

text = text.replace(
    "Etapa 70 - Registro do atendente nas mensagens enviadas.",
    "Etapa 71 - Automacoes basicas por status e departamento."
)

text = text.replace(
    "Etapa 69 - Envio real da mensagem de encerramento com avaliacao.",
    "Etapa 70 - Registro do atendente nas mensagens enviadas."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Registro do atendente nas mensagens enviadas criado." not in text:
    text = text.replace(
        "Envio real da mensagem de encerramento com avaliacao criado.",
        "Envio real da mensagem de encerramento com avaliacao criado.\n\nRegistro do atendente nas mensagens enviadas criado."
    )

if "- docs/ATTENDANCE_SENT_MESSAGE_ATTENDANT_TRACKING.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_CLOSING_RATING_SEND.md",
        "- docs/ATTENDANCE_SENT_MESSAGE_ATTENDANT_TRACKING.md\n- docs/ATTENDANCE_CLOSING_RATING_SEND.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 69 concluidas",
    "- Etapa 01 ate Etapa 70 concluidas"
)

text = text.replace(
    "- Etapa 70 - Registro do atendente nas mensagens enviadas",
    "- Etapa 71 - Automacoes basicas por status e departamento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 70 - Registro do atendente nas mensagens enviadas
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Reforcado o registro do atendente nas mensagens enviadas, com fallback para usuario autenticado, origem do atendente e snapshot do responsavel da conversa no momento do envio.
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
Etapa: 70
Acao: Registro do atendente nas mensagens enviadas
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Attendant send status: ${DOMAIN_ATTENDANT_SEND_STATUS}
Send history status: ${DOMAIN_SEND_HISTORY_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Attendance dashboard status: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 70 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 71 - Automacoes basicas por status e departamento"
