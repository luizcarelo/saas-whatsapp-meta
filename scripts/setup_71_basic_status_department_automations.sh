#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_71.log"

BACKEND_TYPECHECK_LOG="${LOGS_DIR}/setup_71_backend_typecheck.log"
BACKEND_BUILD_LOG="${LOGS_DIR}/setup_71_backend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_71_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_71_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_71_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_71_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_71_auth_login_domain.log"
DOMAIN_ATTENDANCE_LIST_LOG="${LOGS_DIR}/setup_71_attendance_conversations_domain.log"
DOMAIN_RULES_LIST_LOG="${LOGS_DIR}/setup_71_automation_rules_domain.log"
DOMAIN_RULE_UPDATE_LOG="${LOGS_DIR}/setup_71_automation_rule_update_domain.log"
DOMAIN_AUTOMATION_RUN_LOG="${LOGS_DIR}/setup_71_automation_run_domain.log"
DOMAIN_AUTOMATION_EXECUTIONS_LOG="${LOGS_DIR}/setup_71_automation_executions_domain.log"
DOMAIN_SEND_HISTORY_LOG="${LOGS_DIR}/setup_71_send_history_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_71_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_71_domain_dashboard.log"
DOMAIN_ATTENDANCE_DASHBOARD_LOG="${LOGS_DIR}/setup_71_domain_attendance_dashboard.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_BASIC_AUTOMATIONS.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_AUTOMATION_URL="${DOMAIN_BASE_URL}/api/v1/attendance-automations"
DOMAIN_SEND_URL="${DOMAIN_BASE_URL}/api/v1/attendance-send"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_ATTENDANCE_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/attendance-dashboard"

echo "== Etapa 71: Automacoes basicas por status e departamento =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${BACKEND_DIR}/src/modules/attendance-automations"

echo "Validando conclusao da Etapa 70..."

if [ ! -f "${LOGS_DIR}/setup_70.log" ]; then
  echo "ERRO: setup_70.log nao encontrado. Conclua a Etapa 70 antes da Etapa 71."
  exit 1
fi

if ! grep -q "Status: Concluido" "${LOGS_DIR}/setup_70.log"; then
  echo "ERRO: Etapa 70 ainda nao esta concluida."
  cat "${LOGS_DIR}/setup_70.log"
  exit 1
fi

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/src/modules/attendance-automations/attendance-automations.types.ts" \
  "${BACKEND_DIR}/src/modules/attendance-automations/attendance-automations.service.ts" \
  "${BACKEND_DIR}/src/modules/attendance-automations/attendance-automations.controller.ts" \
  "${BACKEND_DIR}/src/modules/attendance-automations/attendance-automations.module.ts" \
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

echo "Criando tabelas de automacoes..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -v ON_ERROR_STOP=1 <<'SQL'
create table if not exists attendance_automation_rules (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  name text not null,
  slug text not null,
  department_name text not null default 'Fila geral',
  trigger_status text not null default 'novo',
  message_origin text not null,
  message_body text not null,
  is_active boolean not null default false,
  send_dry_run boolean not null default true,
  max_runs_per_conversation integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, slug)
);

create index if not exists idx_attendance_automation_rules_tenant
on attendance_automation_rules (tenant_id);

create index if not exists idx_attendance_automation_rules_trigger
on attendance_automation_rules (tenant_id, department_name, trigger_status);

create table if not exists attendance_automation_executions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  rule_id uuid not null,
  conversation_id uuid not null,
  send_id uuid,
  status text not null default 'pending',
  dry_run boolean not null default true,
  error_message text,
  created_at timestamptz not null default now()
);

create index if not exists idx_attendance_automation_executions_tenant
on attendance_automation_executions (tenant_id);

create index if not exists idx_attendance_automation_executions_conversation
on attendance_automation_executions (tenant_id, conversation_id);

insert into attendance_automation_rules (
  tenant_id,
  name,
  slug,
  department_name,
  trigger_status,
  message_origin,
  message_body,
  is_active,
  send_dry_run,
  max_runs_per_conversation
)
values
  (
    '00000000-0000-0000-0000-000000000001',
    'Saudacao inicial',
    'saudacao-inicial',
    'Fila geral',
    'novo',
    'automation_greeting',
    'Ola. Recebemos sua mensagem e em breve iniciaremos seu atendimento.',
    false,
    true,
    1
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Transferencia de departamento',
    'transferencia-de-departamento',
    'Comercial',
    'em_atendimento',
    'automation_transfer',
    'Seu atendimento foi direcionado para o departamento Comercial.',
    false,
    true,
    3
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Aguardando cliente',
    'aguardando-cliente',
    'Fila geral',
    'aguardando_cliente',
    'automation_waiting_customer',
    'Estamos aguardando seu retorno para continuar o atendimento.',
    false,
    true,
    2
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Fora do horario',
    'fora-do-horario',
    'Fila geral',
    'novo',
    'automation_out_of_hours',
    'Recebemos sua mensagem fora do horario de atendimento. Retornaremos assim que possivel.',
    false,
    true,
    1
  ),
  (
    '00000000-0000-0000-0000-000000000001',
    'Conversa sem responsavel',
    'conversa-sem-responsavel',
    'Fila geral',
    'novo',
    'automation_unassigned',
    'Sua conversa esta na fila e sera atendida em breve.',
    false,
    true,
    1
  )
on conflict (tenant_id, slug) do update set
  name = excluded.name,
  department_name = excluded.department_name,
  trigger_status = excluded.trigger_status,
  message_origin = excluded.message_origin,
  message_body = excluded.message_body,
  send_dry_run = true,
  updated_at = now();
SQL

echo "Criando types backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-automations/attendance-automations.types.ts" <<'DOC'
export type AttendanceAutomationRuleItem = {
  id: string;
  name: string;
  slug: string;
  departmentName: string;
  triggerStatus: string;
  messageOrigin: string;
  messageBody: string;
  isActive: boolean;
  sendDryRun: boolean;
  maxRunsPerConversation: number;
  createdAt: string;
  updatedAt: string;
};

export type AttendanceAutomationRulesResponse = {
  success: true;
  data: {
    rules: AttendanceAutomationRuleItem[];
  };
  meta: Record<string, never>;
};

export type AttendanceAutomationRuleUpdatePayload = {
  name?: string;
  departmentName?: string;
  triggerStatus?: string;
  messageBody?: string;
  isActive?: boolean;
  sendDryRun?: boolean;
  maxRunsPerConversation?: number;
};

export type AttendanceAutomationRuleResponse = {
  success: true;
  data: {
    rule: AttendanceAutomationRuleItem;
  };
  meta: Record<string, never>;
};

export type AttendanceAutomationRunPayload = {
  conversationId?: string;
  dryRun?: boolean;
  sentByName?: string | null;
};

export type AttendanceAutomationExecutionItem = {
  id: string;
  ruleId: string;
  conversationId: string;
  sendId: string | null;
  status: string;
  dryRun: boolean;
  errorMessage: string | null;
  createdAt: string;
};

export type AttendanceAutomationRunResponse = {
  success: true;
  data: {
    execution: AttendanceAutomationExecutionItem;
  };
  meta: Record<string, never>;
};

export type AttendanceAutomationExecutionsResponse = {
  success: true;
  data: {
    executions: AttendanceAutomationExecutionItem[];
  };
  meta: Record<string, never>;
};
DOC

echo "Criando service backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-automations/attendance-automations.service.ts" <<'DOC'
import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { AttendanceSendService } from '../attendance-send/attendance-send.service';
import type {
  AttendanceAutomationExecutionItem,
  AttendanceAutomationExecutionsResponse,
  AttendanceAutomationRuleItem,
  AttendanceAutomationRuleResponse,
  AttendanceAutomationRulesResponse,
  AttendanceAutomationRuleUpdatePayload,
  AttendanceAutomationRunPayload,
  AttendanceAutomationRunResponse
} from './attendance-automations.types';

type RuleRow = {
  id: string;
  name: string;
  slug: string;
  department_name: string;
  trigger_status: string;
  message_origin: string;
  message_body: string;
  is_active: boolean;
  send_dry_run: boolean;
  max_runs_per_conversation: number;
  created_at: Date;
  updated_at: Date;
};

type ExecutionRow = {
  id: string;
  rule_id: string;
  conversation_id: string;
  send_id: string | null;
  status: string;
  dry_run: boolean;
  error_message: string | null;
  created_at: Date;
};

type OperationalStatusRow = {
  status: string;
  department_name: string;
  assigned_user_name: string | null;
};

@Injectable()
export class AttendanceAutomationsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly attendanceSendService: AttendanceSendService
  ) {}

  async listRules(tenantId: string): Promise<AttendanceAutomationRulesResponse> {
    await this.ensureDefaultRules(tenantId);

    const rows = await this.prismaService.$queryRawUnsafe<RuleRow[]>(
      'select id, name, slug, department_name, trigger_status, message_origin, message_body, is_active, send_dry_run, max_runs_per_conversation, created_at, updated_at from attendance_automation_rules where tenant_id = $1::uuid order by name asc',
      tenantId
    );

    return {
      success: true,
      data: {
        rules: rows.map((row) => this.mapRule(row))
      },
      meta: {}
    };
  }

  async updateRule(
    tenantId: string,
    ruleId: string,
    payload: AttendanceAutomationRuleUpdatePayload
  ): Promise<AttendanceAutomationRuleResponse> {
    const currentRows = await this.prismaService.$queryRawUnsafe<RuleRow[]>(
      'select id, name, slug, department_name, trigger_status, message_origin, message_body, is_active, send_dry_run, max_runs_per_conversation, created_at, updated_at from attendance_automation_rules where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      ruleId
    );

    const current = currentRows[0];

    if (!current) {
      throw new BadRequestException('Regra de automacao nao encontrada');
    }

    const name = payload.name?.trim() || current.name;
    const departmentName = payload.departmentName?.trim() || current.department_name;
    const triggerStatus = payload.triggerStatus?.trim() || current.trigger_status;
    const messageBody = payload.messageBody?.trim() || current.message_body;
    const isActive = typeof payload.isActive === 'boolean' ? payload.isActive : current.is_active;
    const sendDryRun = typeof payload.sendDryRun === 'boolean' ? payload.sendDryRun : current.send_dry_run;
    const maxRunsPerConversation = typeof payload.maxRunsPerConversation === 'number'
      ? payload.maxRunsPerConversation
      : current.max_runs_per_conversation;

    if (!messageBody) {
      throw new BadRequestException('Mensagem da automacao e obrigatoria');
    }

    const rows = await this.prismaService.$queryRawUnsafe<RuleRow[]>(
      'update attendance_automation_rules set name = $3, department_name = $4, trigger_status = $5, message_body = $6, is_active = $7, send_dry_run = $8, max_runs_per_conversation = $9, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, name, slug, department_name, trigger_status, message_origin, message_body, is_active, send_dry_run, max_runs_per_conversation, created_at, updated_at',
      tenantId,
      ruleId,
      name,
      departmentName,
      triggerStatus,
      messageBody,
      isActive,
      sendDryRun,
      maxRunsPerConversation
    );

    return {
      success: true,
      data: {
        rule: this.mapRule(rows[0])
      },
      meta: {}
    };
  }

  async runRule(
    tenantId: string,
    ruleId: string,
    payload: AttendanceAutomationRunPayload
  ): Promise<AttendanceAutomationRunResponse> {
    if (!payload.conversationId) {
      throw new BadRequestException('Conversa e obrigatoria');
    }

    const rules = await this.prismaService.$queryRawUnsafe<RuleRow[]>(
      'select id, name, slug, department_name, trigger_status, message_origin, message_body, is_active, send_dry_run, max_runs_per_conversation, created_at, updated_at from attendance_automation_rules where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      ruleId
    );

    const rule = rules[0];

    if (!rule) {
      throw new BadRequestException('Regra de automacao nao encontrada');
    }

    const operationalRows = await this.prismaService.$queryRawUnsafe<OperationalStatusRow[]>(
      'select status, department_name, assigned_user_name from conversation_operational_status where tenant_id = $1::uuid and conversation_id = $2::uuid limit 1',
      tenantId,
      payload.conversationId
    );

    const operational = operationalRows[0];
    const currentStatus = operational?.status || 'novo';
    const currentDepartment = operational?.department_name || 'Fila geral';

    if (currentStatus !== rule.trigger_status) {
      throw new BadRequestException('Status da conversa nao corresponde ao gatilho da automacao');
    }

    if (currentDepartment !== rule.department_name && rule.department_name !== 'Fila geral') {
      throw new BadRequestException('Departamento da conversa nao corresponde ao gatilho da automacao');
    }

    const executionCountRows = await this.prismaService.$queryRawUnsafe<Array<{ total: bigint }>>(
      'select count(*) as total from attendance_automation_executions where tenant_id = $1::uuid and rule_id = $2::uuid and conversation_id = $3::uuid and status in ($4, $5)',
      tenantId,
      ruleId,
      payload.conversationId,
      'sent',
      'dry_run'
    );

    const executionCount = Number(executionCountRows[0]?.total || 0);

    if (executionCount >= rule.max_runs_per_conversation) {
      throw new BadRequestException('Limite de execucoes da automacao atingido para esta conversa');
    }

    const dryRun = typeof payload.dryRun === 'boolean' ? payload.dryRun : rule.send_dry_run;

    const pendingRows = await this.prismaService.$queryRawUnsafe<ExecutionRow[]>(
      'insert into attendance_automation_executions (tenant_id, rule_id, conversation_id, status, dry_run, created_at) values ($1::uuid, $2::uuid, $3::uuid, $4, $5, now()) returning id, rule_id, conversation_id, send_id, status, dry_run, error_message, created_at',
      tenantId,
      ruleId,
      payload.conversationId,
      'pending',
      dryRun
    );

    const executionId = pendingRows[0].id;

    try {
      const sendResponse = await this.attendanceSendService.sendManualMessage(tenantId, payload.conversationId, {
        messageBody: rule.message_body,
        sentByName: payload.sentByName || 'Automacao',
        departmentName: currentDepartment,
        messageOrigin: rule.message_origin as never,
        dryRun
      });

      const send = sendResponse.data.send;
      const finalStatus = dryRun ? 'dry_run' : send.status;

      const rows = await this.prismaService.$queryRawUnsafe<ExecutionRow[]>(
        'update attendance_automation_executions set send_id = $3::uuid, status = $4, error_message = $5, dry_run = $6 where tenant_id = $1::uuid and id = $2::uuid returning id, rule_id, conversation_id, send_id, status, dry_run, error_message, created_at',
        tenantId,
        executionId,
        send.id,
        finalStatus,
        send.errorMessage,
        dryRun
      );

      return {
        success: true,
        data: {
          execution: this.mapExecution(rows[0])
        },
        meta: {}
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Falha desconhecida ao executar automacao';

      const rows = await this.prismaService.$queryRawUnsafe<ExecutionRow[]>(
        'update attendance_automation_executions set status = $3, error_message = $4 where tenant_id = $1::uuid and id = $2::uuid returning id, rule_id, conversation_id, send_id, status, dry_run, error_message, created_at',
        tenantId,
        executionId,
        'failed',
        errorMessage
      );

      return {
        success: true,
        data: {
          execution: this.mapExecution(rows[0])
        },
        meta: {}
      };
    }
  }

  async listExecutions(tenantId: string): Promise<AttendanceAutomationExecutionsResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<ExecutionRow[]>(
      'select id, rule_id, conversation_id, send_id, status, dry_run, error_message, created_at from attendance_automation_executions where tenant_id = $1::uuid order by created_at desc limit 100',
      tenantId
    );

    return {
      success: true,
      data: {
        executions: rows.map((row) => this.mapExecution(row))
      },
      meta: {}
    };
  }

  private async ensureDefaultRules(tenantId: string) {
    const defaults = [
      ['Saudacao inicial', 'saudacao-inicial', 'Fila geral', 'novo', 'automation_greeting', 'Ola. Recebemos sua mensagem e em breve iniciaremos seu atendimento.', 1],
      ['Transferencia de departamento', 'transferencia-de-departamento', 'Comercial', 'em_atendimento', 'automation_transfer', 'Seu atendimento foi direcionado para o departamento Comercial.', 3],
      ['Aguardando cliente', 'aguardando-cliente', 'Fila geral', 'aguardando_cliente', 'automation_waiting_customer', 'Estamos aguardando seu retorno para continuar o atendimento.', 2],
      ['Fora do horario', 'fora-do-horario', 'Fila geral', 'novo', 'automation_out_of_hours', 'Recebemos sua mensagem fora do horario de atendimento. Retornaremos assim que possivel.', 1],
      ['Conversa sem responsavel', 'conversa-sem-responsavel', 'Fila geral', 'novo', 'automation_unassigned', 'Sua conversa esta na fila e sera atendida em breve.', 1]
    ];

    for (const item of defaults) {
      await this.prismaService.$executeRawUnsafe(
        'insert into attendance_automation_rules (tenant_id, name, slug, department_name, trigger_status, message_origin, message_body, is_active, send_dry_run, max_runs_per_conversation, created_at, updated_at) values ($1::uuid, $2, $3, $4, $5, $6, $7, false, true, $8, now(), now()) on conflict (tenant_id, slug) do nothing',
        tenantId,
        item[0],
        item[1],
        item[2],
        item[3],
        item[4],
        item[5],
        item[6]
      );
    }
  }

  private mapRule(row: RuleRow): AttendanceAutomationRuleItem {
    return {
      id: row.id,
      name: row.name,
      slug: row.slug,
      departmentName: row.department_name,
      triggerStatus: row.trigger_status,
      messageOrigin: row.message_origin,
      messageBody: row.message_body,
      isActive: row.is_active,
      sendDryRun: row.send_dry_run,
      maxRunsPerConversation: row.max_runs_per_conversation,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }

  private mapExecution(row: ExecutionRow): AttendanceAutomationExecutionItem {
    return {
      id: row.id,
      ruleId: row.rule_id,
      conversationId: row.conversation_id,
      sendId: row.send_id,
      status: row.status,
      dryRun: row.dry_run,
      errorMessage: row.error_message,
      createdAt: row.created_at.toISOString()
    };
  }
}
DOC

echo "Criando controller backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-automations/attendance-automations.controller.ts" <<'DOC'
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
import { AttendanceAutomationsService } from './attendance-automations.service';
import type {
  AttendanceAutomationRuleUpdatePayload,
  AttendanceAutomationRunPayload
} from './attendance-automations.types';

@Controller('attendance-automations')
@UseGuards(JwtAuthGuard)
export class AttendanceAutomationsController {
  constructor(private readonly automationsService: AttendanceAutomationsService) {}

  @Get('rules')
  listRules(@CurrentUser() user: AuthenticatedUser) {
    return this.automationsService.listRules(user.tenantId);
  }

  @Patch('rules/:ruleId')
  updateRule(
    @CurrentUser() user: AuthenticatedUser,
    @Param('ruleId') ruleId: string,
    @Body() body: AttendanceAutomationRuleUpdatePayload
  ) {
    return this.automationsService.updateRule(user.tenantId, ruleId, body);
  }

  @Post('rules/:ruleId/run')
  runRule(
    @CurrentUser() user: AuthenticatedUser,
    @Param('ruleId') ruleId: string,
    @Body() body: AttendanceAutomationRunPayload
  ) {
    return this.automationsService.runRule(user.tenantId, ruleId, body);
  }

  @Get('executions')
  listExecutions(@CurrentUser() user: AuthenticatedUser) {
    return this.automationsService.listExecutions(user.tenantId);
  }
}
DOC

echo "Criando modulo backend..."

cat > "${BACKEND_DIR}/src/modules/attendance-automations/attendance-automations.module.ts" <<'DOC'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AttendanceSendModule } from '../attendance-send/attendance-send.module';
import { DatabaseModule } from '../database/database.module';
import { AttendanceAutomationsController } from './attendance-automations.controller';
import { AttendanceAutomationsService } from './attendance-automations.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({}),
    AttendanceSendModule
  ],
  controllers: [
    AttendanceAutomationsController
  ],
  providers: [
    AttendanceAutomationsService
  ]
})
export class AttendanceAutomationsModule {}
DOC

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

echo "Atualizando app.module.ts..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/backend/src/app.module.ts")
text = path.read_text()
import_line = "import { AttendanceAutomationsModule } from './modules/attendance-automations/attendance-automations.module';"

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

if "AttendanceAutomationsModule" not in match.group(1):
    text = re.sub(r"imports:\s*\[", "imports: [\n    AttendanceAutomationsModule,", text, count=1)

path.write_text(text)
PY

echo "Validando backend sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${BACKEND_DIR}/src/modules/attendance-automations" \
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

echo "Validando dominio e automacoes..."

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

DOMAIN_RULES_LIST_STATUS="$(curl -L -s -o "${DOMAIN_RULES_LIST_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUTOMATION_URL}/rules" || true)"

if [ "${DOMAIN_RULES_LIST_STATUS}" != "200" ]; then
  echo "ERRO: automation rules falhou. Status ${DOMAIN_RULES_LIST_STATUS}"
  cat "${DOMAIN_RULES_LIST_LOG}"
  exit 1
fi

RULE_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.rules)||[]; const rule=items.find((item)=>item.slug==='conversa-sem-responsavel')||items[0]; if(rule){console.log(rule.id)}" "${DOMAIN_RULES_LIST_LOG}" || true)"

CONVERSATION_ID="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const items=(data.data&&data.data.conversations)||[]; if(items.length){console.log(items[0].id)}" "${DOMAIN_ATTENDANCE_LIST_LOG}" || true)"

DOMAIN_RULE_UPDATE_STATUS="SKIPPED"
DOMAIN_AUTOMATION_RUN_STATUS="SKIPPED"
DOMAIN_AUTOMATION_EXECUTIONS_STATUS="SKIPPED"
DOMAIN_SEND_HISTORY_STATUS="SKIPPED"

if [ -n "${RULE_ID}" ]; then
  UPDATE_PAYLOAD="$(node -e "console.log(JSON.stringify({isActive:false, sendDryRun:true, maxRunsPerConversation:5}))")"

  DOMAIN_RULE_UPDATE_STATUS="$(curl -L -s -o "${DOMAIN_RULE_UPDATE_LOG}" -w "%{http_code}" --max-time 30 \
    -X PATCH \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${UPDATE_PAYLOAD}" \
    "${DOMAIN_AUTOMATION_URL}/rules/${RULE_ID}" || true)"

  if [ "${DOMAIN_RULE_UPDATE_STATUS}" != "200" ]; then
    echo "ERRO: automation rule update falhou. Status ${DOMAIN_RULE_UPDATE_STATUS}"
    cat "${DOMAIN_RULE_UPDATE_LOG}"
    exit 1
  fi
fi

if [ -n "${RULE_ID}" ] && [ -n "${CONVERSATION_ID}" ]; then
  RUN_PAYLOAD="$(node -e "console.log(JSON.stringify({conversationId:process.argv[1], dryRun:true, sentByName:'Automacao Etapa 71'}))" "${CONVERSATION_ID}")"

  DOMAIN_AUTOMATION_RUN_STATUS="$(curl -L -s -o "${DOMAIN_AUTOMATION_RUN_LOG}" -w "%{http_code}" --max-time 30 \
    -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${RUN_PAYLOAD}" \
    "${DOMAIN_AUTOMATION_URL}/rules/${RULE_ID}/run" || true)"

  if [ "${DOMAIN_AUTOMATION_RUN_STATUS}" != "200" ] && [ "${DOMAIN_AUTOMATION_RUN_STATUS}" != "201" ]; then
    echo "ERRO: automation run falhou. Status ${DOMAIN_AUTOMATION_RUN_STATUS}"
    cat "${DOMAIN_AUTOMATION_RUN_LOG}"
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
  echo '{"skipped":"sem regra ou conversa para executar"}' > "${DOMAIN_AUTOMATION_RUN_LOG}"
  echo '{"skipped":"sem conversa para historico"}' > "${DOMAIN_SEND_HISTORY_LOG}"
fi

DOMAIN_AUTOMATION_EXECUTIONS_STATUS="$(curl -L -s -o "${DOMAIN_AUTOMATION_EXECUTIONS_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_AUTOMATION_URL}/executions" || true)"

if [ "${DOMAIN_AUTOMATION_EXECUTIONS_STATUS}" != "200" ]; then
  echo "ERRO: automation executions falhou. Status ${DOMAIN_AUTOMATION_EXECUTIONS_STATUS}"
  cat "${DOMAIN_AUTOMATION_EXECUTIONS_LOG}"
  exit 1
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

echo "Gerando documentacao da Etapa 71..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Basic Automations

## Visao geral

Este documento registra a criacao das automacoes basicas por status e departamento.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tabela de regras de automacao
- tabela de execucoes de automacao
- seed de automacoes basicas
- endpoint para listar regras
- endpoint para atualizar regra
- endpoint para executar regra em conversa
- endpoint para listar execucoes
- validacao por status da conversa
- validacao por departamento
- limite de execucoes por conversa
- envio usando backend attendance send
- suporte a dryRun por regra

## Automacoes criadas

Automacoes:

- Saudacao inicial
- Transferencia de departamento
- Aguardando cliente
- Fora do horario
- Conversa sem responsavel

## Origens usadas

Origens:

- automation greeting
- automation transfer
- automation waiting customer
- automation out of hours
- automation unassigned

## Endpoints criados

Endpoints:

- GET api v1 attendance automations rules
- PATCH api v1 attendance automations rules rule id
- POST api v1 attendance automations rules rule id run
- GET api v1 attendance automations executions

## Tabelas criadas

Tabelas:

- attendance automation rules
- attendance automation executions

## Observacao operacional

As regras sao criadas inativas por padrao e com dryRun ativo.

Isso evita envio real acidental e permite validar cada automacao antes de ativar em producao.

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance-automations/attendance-automations.types.ts
- apps/backend/src/modules/attendance-automations/attendance-automations.service.ts
- apps/backend/src/modules/attendance-automations/attendance-automations.controller.ts
- apps/backend/src/modules/attendance-automations/attendance-automations.module.ts
- apps/backend/src/modules/attendance-send/attendance-send.module.ts
- apps/backend/src/app.module.ts
- docs/ATTENDANCE_BASIC_AUTOMATIONS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente das tabelas
- seed das regras basicas
- npm run typecheck no backend
- npm run build no backend
- docker compose build backend
- docker compose up backend proxy
- login dominio
- endpoint attendance conversations dominio
- endpoint automations rules dominio
- endpoint update rule dominio
- endpoint run rule dominio quando ha conversa e regra
- endpoint executions dominio
- historico de envios quando ha conversa
- rota app inbox
- rota app dashboard
- rota app attendance dashboard

## Logs gerados

Logs:

- logs/setup_71_backend_typecheck.log
- logs/setup_71_backend_build.log
- logs/setup_71_backend_docker_build.log
- logs/setup_71_docker_up.log
- logs/setup_71_backend_wait.log
- logs/setup_71_auth_login_domain.log
- logs/setup_71_attendance_conversations_domain.log
- logs/setup_71_automation_rules_domain.log
- logs/setup_71_automation_rule_update_domain.log
- logs/setup_71_automation_run_domain.log
- logs/setup_71_automation_executions_domain.log
- logs/setup_71_send_history_domain.log
- logs/setup_71_domain_inbox_page.log
- logs/setup_71_domain_dashboard.log
- logs/setup_71_domain_attendance_dashboard.log
- logs/setup_71.log

## Proxima etapa sugerida

Etapa 72:

    Painel de falhas e retentativas de envio
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 71 - Automacoes basicas por status e departamento",
    "- [x] Etapa 71 - Automacoes basicas por status e departamento\n- [ ] Etapa 72 - Painel de falhas e retentativas de envio"
)

text = text.replace(
    "Etapa 71 - Automacoes basicas por status e departamento.",
    "Etapa 72 - Painel de falhas e retentativas de envio."
)

text = text.replace(
    "Etapa 70 - Registro do atendente nas mensagens enviadas.",
    "Etapa 71 - Automacoes basicas por status e departamento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Automacoes basicas por status e departamento criadas." not in text:
    text = text.replace(
        "Registro do atendente nas mensagens enviadas criado.",
        "Registro do atendente nas mensagens enviadas criado.\n\nAutomacoes basicas por status e departamento criadas."
    )

if "- docs/ATTENDANCE_BASIC_AUTOMATIONS.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_SENT_MESSAGE_ATTENDANT_TRACKING.md",
        "- docs/ATTENDANCE_BASIC_AUTOMATIONS.md\n- docs/ATTENDANCE_SENT_MESSAGE_ATTENDANT_TRACKING.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 70 concluidas",
    "- Etapa 01 ate Etapa 71 concluidas"
)

text = text.replace(
    "- Etapa 71 - Automacoes basicas por status e departamento",
    "- Etapa 72 - Painel de falhas e retentativas de envio"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 71 - Automacoes basicas por status e departamento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criadas automacoes basicas por status e departamento, com regras inativas por padrao, dryRun ativo, execucoes auditaveis e integracao com backend de envio da central.
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
Etapa: 71
Acao: Automacoes basicas por status e departamento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Attendance list status: ${DOMAIN_ATTENDANCE_LIST_STATUS}
Automation rules status: ${DOMAIN_RULES_LIST_STATUS}
Automation rule update status: ${DOMAIN_RULE_UPDATE_STATUS}
Automation run status: ${DOMAIN_AUTOMATION_RUN_STATUS}
Automation executions status: ${DOMAIN_AUTOMATION_EXECUTIONS_STATUS}
Send history status: ${DOMAIN_SEND_HISTORY_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Attendance dashboard status: ${DOMAIN_ATTENDANCE_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 71 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 72 - Painel de falhas e retentativas de envio"
