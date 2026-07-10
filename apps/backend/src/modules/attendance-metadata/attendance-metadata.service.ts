import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceAttachTagPayload,
  AttendanceConversationTagsResponse,
  AttendanceInternalNotePayload,
  AttendanceInternalNoteResponse,
  AttendanceInternalNotesResponse,
  AttendanceTagPayload,
  AttendanceTagResponse,
  AttendanceTagsResponse
} from './attendance-metadata.types';

type NoteRow = {
  id: string;
  conversation_id: string;
  note: string;
  created_by_user_id: string | null;
  created_by_name: string;
  created_at: Date;
};

type TagRow = {
  id: string;
  name: string;
  slug: string;
  color: string;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
};

@Injectable()
export class AttendanceMetadataService {
  constructor(private readonly prismaService: PrismaService) {}

  async listNotes(
    tenantId: string,
    conversationId: string
  ): Promise<AttendanceInternalNotesResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<NoteRow[]>(
      'select id, conversation_id, note, created_by_user_id, created_by_name, created_at from attendance_conversation_notes where tenant_id = $1::uuid and conversation_id = $2::uuid order by created_at desc limit 100',
      tenantId,
      conversationId
    );

    return {
      success: true,
      data: {
        notes: rows.map((row) => this.mapNote(row))
      },
      meta: {}
    };
  }

  async createNote(
    tenantId: string,
    conversationId: string,
    payload: AttendanceInternalNotePayload
  ): Promise<AttendanceInternalNoteResponse> {
    const note = this.normalizeText(payload.note, 'Nota interna');
    const createdByName = this.normalizeText(payload.createdByName || 'Atendente', 'Nome do atendente');

    const rows = await this.prismaService.$queryRawUnsafe<NoteRow[]>(
      'insert into attendance_conversation_notes (tenant_id, conversation_id, note, created_by_user_id, created_by_name, created_at) values ($1::uuid, $2::uuid, $3, $4::uuid, $5, now()) returning id, conversation_id, note, created_by_user_id, created_by_name, created_at',
      tenantId,
      conversationId,
      note,
      payload.createdByUserId || null,
      createdByName
    );

    return {
      success: true,
      data: {
        note: this.mapNote(rows[0])
      },
      meta: {}
    };
  }

  async listTags(tenantId: string): Promise<AttendanceTagsResponse> {
    await this.ensureDefaultTags(tenantId);

    const rows = await this.prismaService.$queryRawUnsafe<TagRow[]>(
      'select id, name, slug, color, is_active, created_at, updated_at from attendance_tags where tenant_id = $1::uuid and is_active = true order by name asc',
      tenantId
    );

    return {
      success: true,
      data: {
        tags: rows.map((row) => this.mapTag(row))
      },
      meta: {}
    };
  }

  async createTag(
    tenantId: string,
    payload: AttendanceTagPayload
  ): Promise<AttendanceTagResponse> {
    const name = this.normalizeText(payload.name, 'Nome da tag');
    const slug = this.slugify(name);
    const color = payload.color || '#0757c8';

    await this.prismaService.$executeRawUnsafe(
      'insert into attendance_tags (tenant_id, name, slug, color, is_active, created_at, updated_at) values ($1::uuid, $2, $3, $4, true, now(), now()) on conflict (tenant_id, slug) do update set name = excluded.name, color = excluded.color, is_active = true, updated_at = now()',
      tenantId,
      name,
      slug,
      color
    );

    const rows = await this.prismaService.$queryRawUnsafe<TagRow[]>(
      'select id, name, slug, color, is_active, created_at, updated_at from attendance_tags where tenant_id = $1::uuid and slug = $2 limit 1',
      tenantId,
      slug
    );

    return {
      success: true,
      data: {
        tag: this.mapTag(rows[0])
      },
      meta: {}
    };
  }

  async listConversationTags(
    tenantId: string,
    conversationId: string
  ): Promise<AttendanceConversationTagsResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<TagRow[]>(
      'select t.id, t.name, t.slug, t.color, t.is_active, t.created_at, t.updated_at from attendance_tags t inner join attendance_conversation_tags ct on ct.tag_id = t.id where ct.tenant_id = $1::uuid and ct.conversation_id = $2::uuid and t.is_active = true order by t.name asc',
      tenantId,
      conversationId
    );

    return {
      success: true,
      data: {
        tags: rows.map((row) => this.mapTag(row))
      },
      meta: {}
    };
  }

  async attachTag(
    tenantId: string,
    conversationId: string,
    payload: AttendanceAttachTagPayload
  ): Promise<AttendanceConversationTagsResponse> {
    if (!payload.tagId) {
      throw new BadRequestException('Tag e obrigatoria');
    }

    await this.prismaService.$executeRawUnsafe(
      'insert into attendance_conversation_tags (tenant_id, conversation_id, tag_id, created_at) values ($1::uuid, $2::uuid, $3::uuid, now()) on conflict (tenant_id, conversation_id, tag_id) do nothing',
      tenantId,
      conversationId,
      payload.tagId
    );

    return this.listConversationTags(tenantId, conversationId);
  }

  private async ensureDefaultTags(tenantId: string) {
    const tags = [
      ['lead', 'lead', '#f97316'],
      ['cliente', 'cliente', '#16a34a'],
      ['urgente', 'urgente', '#dc2626'],
      ['financeiro', 'financeiro', '#7c3aed'],
      ['suporte', 'suporte', '#2563eb'],
      ['orcamento', 'orcamento', '#0f766e'],
      ['reclamacao', 'reclamacao', '#b91c1c'],
      ['pos-venda', 'pos-venda', '#475569']
    ];

    for (const tag of tags) {
      await this.prismaService.$executeRawUnsafe(
        'insert into attendance_tags (tenant_id, name, slug, color, is_active, created_at, updated_at) values ($1::uuid, $2, $3, $4, true, now(), now()) on conflict (tenant_id, slug) do nothing',
        tenantId,
        tag[0],
        tag[1],
        tag[2]
      );
    }
  }

  private mapNote(row: NoteRow) {
    return {
      id: row.id,
      conversationId: row.conversation_id,
      note: row.note,
      createdByUserId: row.created_by_user_id,
      createdByName: row.created_by_name,
      createdAt: row.created_at.toISOString()
    };
  }

  private mapTag(row: TagRow) {
    return {
      id: row.id,
      name: row.name,
      slug: row.slug,
      color: row.color,
      isActive: row.is_active,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }

  private normalizeText(value: string | undefined | null, label: string): string {
    const textValue = (value || '').trim();

    if (!textValue) {
      throw new BadRequestException(label + ' e obrigatorio');
    }

    if (textValue.length > 1000) {
      throw new BadRequestException(label + ' muito longo');
    }

    return textValue;
  }

  private slugify(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '') || 'tag';
  }
}
