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
