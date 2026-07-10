import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceDashboardDepartmentMetric,
  AttendanceDashboardSummaryResponse
} from './attendance-dashboard.types';

type StatusRow = {
  conversation_id: string;
  status: string;
  priority: string;
  department_name: string;
  assigned_user_name: string | null;
};

type DepartmentRow = {
  name: string;
  color: string;
};

type CountRow = {
  total: bigint | number | null;
};

type RatingRow = {
  total: bigint | number | null;
  average: number | string | null;
};

@Injectable()
export class AttendanceDashboardService {
  constructor(private readonly prismaService: PrismaService) {}

  async getSummary(tenantId: string): Promise<AttendanceDashboardSummaryResponse> {
    const conversations = await this.prismaService.conversation.findMany({
      where: {
        tenantId,
        deletedAt: null
      },
      select: {
        id: true
      },
      take: 1000
    });

    const conversationIds = conversations.map((conversation) => conversation.id);

    const statusRows = conversationIds.length > 0
      ? await this.prismaService.$queryRawUnsafe<StatusRow[]>(
          'select conversation_id, status, priority, department_name, assigned_user_name from conversation_operational_status where tenant_id = $1::uuid and conversation_id = any($2::uuid[])',
          tenantId,
          conversationIds
        )
      : [];

    const statusByConversation = new Map<string, StatusRow>();

    for (const row of statusRows) {
      statusByConversation.set(row.conversation_id, row);
    }

    const departments = await this.prismaService.$queryRawUnsafe<DepartmentRow[]>(
      'select name, color from attendance_departments where tenant_id = $1::uuid and is_active = true order by sort_order asc, name asc',
      tenantId
    );

    const departmentMetrics = new Map<string, AttendanceDashboardDepartmentMetric>();

    for (const department of departments) {
      departmentMetrics.set(department.name, {
        name: department.name,
        color: department.color,
        total: 0,
        open: 0,
        closed: 0
      });
    }

    let open = 0;
    let closed = 0;
    let unassigned = 0;
    let highPriority = 0;

    for (const conversation of conversations) {
      const statusRow = statusByConversation.get(conversation.id);
      const status = statusRow?.status || 'novo';
      const priority = statusRow?.priority || 'normal';
      const departmentName = statusRow?.department_name || 'Fila geral';
      const assignedUserName = statusRow?.assigned_user_name || null;

      if (status === 'encerrado' || status === 'arquivado') {
        closed += 1;
      } else {
        open += 1;
      }

      if (!assignedUserName) {
        unassigned += 1;
      }

      if (priority === 'alta' || priority === 'urgente') {
        highPriority += 1;
      }

      if (!departmentMetrics.has(departmentName)) {
        departmentMetrics.set(departmentName, {
          name: departmentName,
          color: '#0757c8',
          total: 0,
          open: 0,
          closed: 0
        });
      }

      const metric = departmentMetrics.get(departmentName);

      if (metric) {
        metric.total += 1;

        if (status === 'encerrado' || status === 'arquivado') {
          metric.closed += 1;
        } else {
          metric.open += 1;
        }
      }
    }

    const ratings = await this.prismaService.$queryRawUnsafe<RatingRow[]>(
      'select count(*) as total, coalesce(avg(rating), 0) as average from attendance_conversation_ratings where tenant_id = $1::uuid',
      tenantId
    );

    const notes = await this.countTable('attendance_conversation_notes', tenantId);
    const tags = await this.countTable('attendance_conversation_tags', tenantId);
    const quickReplies = await this.countTable('attendance_quick_replies', tenantId);
    const closures = await this.countTable('attendance_conversation_closures', tenantId);

    const ratingRow = ratings[0];

    return {
      success: true,
      data: {
        conversations: {
          total: conversations.length,
          open,
          closed,
          unassigned,
          highPriority
        },
        departments: Array.from(departmentMetrics.values()),
        ratings: {
          total: this.toNumber(ratingRow?.total),
          average: Number(Number(ratingRow?.average || 0).toFixed(2))
        },
        activity: {
          notes,
          tags,
          quickReplies,
          closures
        }
      },
      meta: {}
    };
  }

  private async countTable(tableName: string, tenantId: string): Promise<number> {
    const rows = await this.prismaService.$queryRawUnsafe<CountRow[]>(
      'select count(*) as total from ' + tableName + ' where tenant_id = $1::uuid',
      tenantId
    );

    return this.toNumber(rows[0]?.total);
  }

  private toNumber(value: bigint | number | null | undefined): number {
    if (typeof value === 'bigint') {
      return Number(value);
    }

    if (typeof value === 'number') {
      return value;
    }

    return 0;
  }
}
