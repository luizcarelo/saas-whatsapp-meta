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
  attendant_source: string;
  assigned_user_id_at_send: string | null;
  assigned_user_name_at_send: string | null;
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
    const assignedUserIdAtSend = operational?.assigned_user_id || null;
    const assignedUserNameAtSend = operational?.assigned_user_name || null;
    const attendantSource = payload.attendantSource || (payload.sentByName ? 'payload' : 'fallback');

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
      'insert into attendance_manual_message_sends (tenant_id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, status, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at) values ($1::uuid, $2::uuid, $3::uuid, $4, $5::uuid, $6, $7, $8::uuid, $9, $10, $11, $12, $13::uuid, $14, $15, $16, $17, $18, $19::uuid, $20, now(), now()) returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at',
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
      dryRun,
      attendantSource,
      assignedUserIdAtSend,
      assignedUserNameAtSend
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
        'update attendance_manual_message_sends set status = $3, provider_message_id = $4, provider_response = $5::jsonb, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at',
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
        'update attendance_manual_message_sends set status = $3, error_message = $4, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid returning id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at',
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
      'select id, conversation_id, contact_id, contact_phone, whatsapp_account_id, phone_number_id, message_body, sent_by_user_id, sent_by_name, department_name, conversation_status, message_origin, quick_reply_id, quick_reply_title, provider, provider_message_id, status, error_message, dry_run, attendant_source, assigned_user_id_at_send, assigned_user_name_at_send, created_at, updated_at from attendance_manual_message_sends where tenant_id = $1::uuid and conversation_id = $2::uuid order by created_at desc limit 100',
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
      attendantSource: row.attendant_source,
      assignedUserIdAtSend: row.assigned_user_id_at_send,
      assignedUserNameAtSend: row.assigned_user_name_at_send,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }
}
