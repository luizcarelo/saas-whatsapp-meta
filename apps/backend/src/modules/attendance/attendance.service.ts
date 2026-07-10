import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceConversationItem,
  AttendanceConversationListResponse,
  AttendanceDepartmentItem,
  AttendanceDepartmentPayload,
  AttendanceDepartmentResponse,
  AttendanceDepartmentsResponse,
  AttendanceStatusOptionsResponse,
  AttendanceUpdateStatusPayload,
  AttendanceUpdateStatusResponse
} from './attendance.types';

type OperationalStatusRow = {
  conversation_id: string;
  status: string;
  priority: string;
  department_name: string;
  assigned_user_id: string | null;
  assigned_user_name: string | null;
  updated_at: Date;
};

type DepartmentRow = {
  id: string;
  name: string;
  slug: string;
  color: string;
  is_active: boolean;
  sort_order: number;
  created_at: Date;
  updated_at: Date;
};

const statusOptions = [
  { value: 'novo', label: 'Novo' },
  { value: 'em_atendimento', label: 'Em atendimento' },
  { value: 'aguardando_cliente', label: 'Aguardando cliente' },
  { value: 'aguardando_interno', label: 'Aguardando interno' },
  { value: 'resolvido', label: 'Resolvido' },
  { value: 'encerrado', label: 'Encerrado' },
  { value: 'arquivado', label: 'Arquivado' }
];

const priorityOptions = [
  { value: 'baixa', label: 'Baixa' },
  { value: 'normal', label: 'Normal' },
  { value: 'media', label: 'Media' },
  { value: 'alta', label: 'Alta' },
  { value: 'urgente', label: 'Urgente' }
];

@Injectable()
export class AttendanceService {
  constructor(private readonly prismaService: PrismaService) {}

  getStatusOptions(): AttendanceStatusOptionsResponse {
    return {
      success: true,
      data: {
        statuses: statusOptions,
        priorities: priorityOptions
      },
      meta: {}
    };
  }

  async listDepartments(tenantId: string): Promise<AttendanceDepartmentsResponse> {
    await this.ensureDefaultDepartments(tenantId);

    const rows = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select id, name, slug, color, is_active, sort_order, created_at, updated_at from attendance_departments where tenant_id = $1::uuid order by sort_order asc, name asc',
      tenantId
    );

    return {
      success: true,
      data: {
        departments: rows.map((row) => this.mapDepartment(row))
      },
      meta: {}
    };
  }

  async createDepartment(
    tenantId: string,
    payload: AttendanceDepartmentPayload
  ): Promise<AttendanceDepartmentResponse> {
    const name = this.normalizeDepartmentName(payload.name);
    const slug = this.slugify(name);
    const color = payload.color || '#0757c8';
    const sortOrder = Number(payload.sortOrder || 50);

    await this.prismaService.$executeRawUnsafe(
      'insert into attendance_departments (tenant_id, name, slug, color, is_active, sort_order, created_at, updated_at) values ($1::uuid, $2, $3, $4, true, $5, now(), now()) on conflict (tenant_id, slug) do update set name = excluded.name, color = excluded.color, is_active = true, sort_order = excluded.sort_order, updated_at = now()',
      tenantId,
      name,
      slug,
      color,
      sortOrder
    );

    const row = await this.findDepartmentBySlug(tenantId, slug);

    if (!row) {
      throw new BadRequestException('Nao foi possivel criar departamento');
    }

    return {
      success: true,
      data: {
        department: this.mapDepartment(row)
      },
      meta: {}
    };
  }

  async updateDepartment(
    tenantId: string,
    departmentId: string,
    payload: AttendanceDepartmentPayload
  ): Promise<AttendanceDepartmentResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select id, name, slug, color, is_active, sort_order, created_at, updated_at from attendance_departments where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      departmentId
    );

    const current = rows[0];

    if (!current) {
      throw new BadRequestException('Departamento nao encontrado');
    }

    const name = payload.name ? this.normalizeDepartmentName(payload.name) : current.name;
    const slug = this.slugify(name);
    const color = payload.color || current.color;
    const isActive = typeof payload.isActive === 'boolean' ? payload.isActive : current.is_active;
    const sortOrder = typeof payload.sortOrder === 'number' ? payload.sortOrder : current.sort_order;

    await this.prismaService.$executeRawUnsafe(
      'update attendance_departments set name = $3, slug = $4, color = $5, is_active = $6, sort_order = $7, updated_at = now() where tenant_id = $1::uuid and id = $2::uuid',
      tenantId,
      departmentId,
      name,
      slug,
      color,
      isActive,
      sortOrder
    );

    const updatedRows = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select id, name, slug, color, is_active, sort_order, created_at, updated_at from attendance_departments where tenant_id = $1::uuid and id = $2::uuid limit 1',
      tenantId,
      departmentId
    );

    return {
      success: true,
      data: {
        department: this.mapDepartment(updatedRows[0])
      },
      meta: {}
    };
  }

  async listConversations(tenantId: string): Promise<AttendanceConversationListResponse> {
    await this.ensureDefaultDepartments(tenantId);

    const conversations = await this.prismaService.conversation.findMany({
      where: {
        tenantId,
        deletedAt: null
      },
      include: {
        contact: true,
        messages: {
          orderBy: {
            createdAt: 'desc'
          },
          take: 1
        }
      },
      orderBy: {
        updatedAt: 'desc'
      },
      take: 50
    });

    const ids = conversations.map((conversation) => conversation.id);
    const statusRows = ids.length > 0
      ? await this.prismaService.$queryRawUnsafe<OperationalStatusRow[]>(
          'select conversation_id, status, priority, department_name, assigned_user_id, assigned_user_name, updated_at from conversation_operational_status where tenant_id = $1::uuid and conversation_id = any($2::uuid[])',
          tenantId,
          ids
        )
      : [];

    const statusByConversation = new Map<string, OperationalStatusRow>();

    for (const row of statusRows) {
      statusByConversation.set(row.conversation_id, row);
    }

    const items: AttendanceConversationItem[] = conversations.map((conversation) => {
      const statusRow = statusByConversation.get(conversation.id);
      const lastMessage = conversation.messages[0] || null;

      return {
        id: conversation.id,
        contactName: conversation.contact?.name || null,
        contactPhone: conversation.contact?.phone || null,
        status: statusRow?.status || 'novo',
        priority: statusRow?.priority || 'normal',
        departmentName: statusRow?.department_name || 'Fila geral',
        assignedUserId: statusRow?.assigned_user_id || null,
        assignedUserName: statusRow?.assigned_user_name || null,
        lastMessage: lastMessage?.body || null,
        lastMessageAt: lastMessage?.createdAt ? lastMessage.createdAt.toISOString() : null,
        unreadCount: 0,
        updatedAt: statusRow?.updated_at ? statusRow.updated_at.toISOString() : conversation.updatedAt.toISOString()
      };
    });

    return {
      success: true,
      data: {
        conversations: items
      },
      meta: {}
    };
  }

  async updateConversationStatus(
    tenantId: string,
    conversationId: string,
    payload: AttendanceUpdateStatusPayload
  ): Promise<AttendanceUpdateStatusResponse> {
    const status = payload.status || 'novo';
    const priority = payload.priority || 'normal';
    const departmentName = payload.departmentName || 'Fila geral';

    if (!statusOptions.some((item) => item.value === status)) {
      throw new BadRequestException('Status operacional invalido');
    }

    if (!priorityOptions.some((item) => item.value === priority)) {
      throw new BadRequestException('Prioridade invalida');
    }

    await this.ensureDefaultDepartments(tenantId);
    await this.ensureDepartmentByName(tenantId, departmentName);

    await this.prismaService.$executeRawUnsafe(
      'insert into conversation_operational_status (tenant_id, conversation_id, status, priority, department_name, assigned_user_id, assigned_user_name, created_at, updated_at) values ($1::uuid, $2::uuid, $3, $4, $5, $6::uuid, $7, now(), now()) on conflict (tenant_id, conversation_id) do update set status = excluded.status, priority = excluded.priority, department_name = excluded.department_name, assigned_user_id = excluded.assigned_user_id, assigned_user_name = excluded.assigned_user_name, updated_at = now()',
      tenantId,
      conversationId,
      status,
      priority,
      departmentName,
      payload.assignedUserId || null,
      payload.assignedUserName || null
    );

    const rows = await this.prismaService.$queryRawUnsafe<OperationalStatusRow[]>(
      'select conversation_id, status, priority, department_name, assigned_user_id, assigned_user_name, updated_at from conversation_operational_status where tenant_id = $1::uuid and conversation_id = $2::uuid limit 1',
      tenantId,
      conversationId
    );

    const row = rows[0];

    return {
      success: true,
      data: {
        conversationId,
        status: row?.status || status,
        priority: row?.priority || priority,
        departmentName: row?.department_name || departmentName,
        assignedUserId: row?.assigned_user_id || null,
        assignedUserName: row?.assigned_user_name || null,
        updatedAt: row?.updated_at ? row.updated_at.toISOString() : new Date().toISOString()
      },
      meta: {}
    };
  }

  private async ensureDefaultDepartments(tenantId: string) {
    const defaults = [
      ['Fila geral', 'fila-geral', '#0757c8', 1],
      ['Comercial', 'comercial', '#f97316', 2],
      ['Suporte', 'suporte', '#16a34a', 3],
      ['Financeiro', 'financeiro', '#7c3aed', 4],
      ['Pos-venda', 'pos-venda', '#0f766e', 5],
      ['Tecnico', 'tecnico', '#2563eb', 6],
      ['Administrativo', 'administrativo', '#475569', 7]
    ];

    for (const item of defaults) {
      await this.prismaService.$executeRawUnsafe(
        'insert into attendance_departments (tenant_id, name, slug, color, sort_order, is_active, created_at, updated_at) values ($1::uuid, $2, $3, $4, $5, true, now(), now()) on conflict (tenant_id, slug) do nothing',
        tenantId,
        item[0],
        item[1],
        item[2],
        item[3]
      );
    }
  }

  private async ensureDepartmentByName(tenantId: string, name: string) {
    const normalized = this.normalizeDepartmentName(name);
    const slug = this.slugify(normalized);
    await this.prismaService.$executeRawUnsafe(
      'insert into attendance_departments (tenant_id, name, slug, color, sort_order, is_active, created_at, updated_at) values ($1::uuid, $2, $3, $4, 99, true, now(), now()) on conflict (tenant_id, slug) do nothing',
      tenantId,
      normalized,
      slug,
      '#0757c8'
    );
  }

  private async findDepartmentBySlug(tenantId: string, slug: string): Promise<DepartmentRow | null> {
    const rows = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select id, name, slug, color, is_active, sort_order, created_at, updated_at from attendance_departments where tenant_id = $1::uuid and slug = $2 limit 1',
      tenantId,
      slug
    );

    return rows[0] || null;
  }

  private mapDepartment(row: DepartmentRow): AttendanceDepartmentItem {
    return {
      id: row.id,
      name: row.name,
      slug: row.slug,
      color: row.color,
      isActive: row.is_active,
      sortOrder: row.sort_order,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }

  private normalizeDepartmentName(value?: string): string {
    const name = (value || '').trim();

    if (!name) {
      throw new BadRequestException('Nome do departamento e obrigatorio');
    }

    if (name.length > 80) {
      throw new BadRequestException('Nome do departamento muito longo');
    }

    return name;
  }

  private slugify(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '') || 'departamento';
  }
}
