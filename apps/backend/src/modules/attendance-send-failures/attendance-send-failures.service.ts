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
