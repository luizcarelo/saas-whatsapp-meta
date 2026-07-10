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
