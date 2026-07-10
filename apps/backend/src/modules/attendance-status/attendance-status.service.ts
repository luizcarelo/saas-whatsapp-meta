import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  AttendanceStatusCatalogItem,
  AttendanceStatusCompatibilityItem,
  AttendanceStatusCompatibilityMapResponse,
  AttendanceStatusModelResponse,
  AttendanceStatusOptionsResponse
} from './attendance-status.types';

type StatusRow = {
  id: string;
  status_group: string;
  code: string;
  label: string;
  description: string;
  sort_order: number;
  is_active: boolean;
  is_terminal: boolean;
  created_at: Date;
  updated_at: Date;
};

type CompatibilityRow = {
  id: string;
  legacy_scope: string;
  legacy_status: string;
  target_group: string;
  target_status: string;
  notes: string;
  created_at: Date;
  updated_at: Date;
};

@Injectable()
export class AttendanceStatusService {
  constructor(private readonly prismaService: PrismaService) {}

  async getModel(tenantId: string): Promise<AttendanceStatusModelResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<StatusRow[]>(
      'select id, status_group, code, label, description, sort_order, is_active, is_terminal, created_at, updated_at from attendance_status_catalog where tenant_id = $1::uuid and is_active = true order by status_group asc, sort_order asc, code asc',
      tenantId
    );

    const mapped = rows.map((row) => this.mapStatus(row));

    return {
      success: true,
      data: {
        groups: {
          conversation: mapped.filter((item) => item.group === 'conversation'),
          attendance: mapped.filter((item) => item.group === 'attendance'),
          send: mapped.filter((item) => item.group === 'send'),
          closure: mapped.filter((item) => item.group === 'closure')
        }
      },
      meta: {}
    };
  }

  async getOptions(
    tenantId: string,
    group: string
  ): Promise<AttendanceStatusOptionsResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<StatusRow[]>(
      'select id, status_group, code, label, description, sort_order, is_active, is_terminal, created_at, updated_at from attendance_status_catalog where tenant_id = $1::uuid and status_group = $2 and is_active = true order by sort_order asc, code asc',
      tenantId,
      group
    );

    return {
      success: true,
      data: {
        options: rows.map((row) => this.mapStatus(row))
      },
      meta: {}
    };
  }

  async getCompatibilityMap(tenantId: string): Promise<AttendanceStatusCompatibilityMapResponse> {
    const rows = await this.prismaService.$queryRawUnsafe<CompatibilityRow[]>(
      'select id, legacy_scope, legacy_status, target_group, target_status, notes, created_at, updated_at from attendance_status_compatibility_map where tenant_id = $1::uuid order by legacy_scope asc, legacy_status asc',
      tenantId
    );

    return {
      success: true,
      data: {
        mappings: rows.map((row) => this.mapCompatibility(row))
      },
      meta: {}
    };
  }

  private mapStatus(row: StatusRow): AttendanceStatusCatalogItem {
    return {
      id: row.id,
      group: row.status_group,
      code: row.code,
      label: row.label,
      description: row.description,
      sortOrder: row.sort_order,
      isActive: row.is_active,
      isTerminal: row.is_terminal,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }

  private mapCompatibility(row: CompatibilityRow): AttendanceStatusCompatibilityItem {
    return {
      id: row.id,
      legacyScope: row.legacy_scope,
      legacyStatus: row.legacy_status,
      targetGroup: row.target_group,
      targetStatus: row.target_status,
      notes: row.notes,
      createdAt: row.created_at.toISOString(),
      updatedAt: row.updated_at.toISOString()
    };
  }
}
