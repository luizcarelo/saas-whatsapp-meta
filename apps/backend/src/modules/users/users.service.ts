import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type {
  UserPermissionsResponse,
  UserProfile,
  UserProfilePermission,
  UserProfileResponse,
  UserProfileRole
} from './users.types';

@Injectable()
export class UsersService {
  constructor(private readonly prismaService: PrismaService) {}

  async getCurrentUserProfile(userId: string): Promise<UserProfileResponse> {
    const user = await this.prismaService.user.findFirst({
      where: {
        id: userId,
        deletedAt: null
      },
      include: {
        tenant: true,
        userRoles: {
          include: {
            role: {
              include: {
                rolePermissions: {
                  include: {
                    permission: true
                  }
                }
              }
            }
          }
        }
      }
    });

    if (!user) {
      throw new NotFoundException('Usuario nao encontrado');
    }

    const roles: UserProfileRole[] = user.userRoles.map((userRole) => ({
      id: userRole.role.id,
      name: userRole.role.name,
      description: userRole.role.description
    }));

    const permissionMap = new Map<string, UserProfilePermission>();

    for (const userRole of user.userRoles) {
      for (const rolePermission of userRole.role.rolePermissions) {
        permissionMap.set(rolePermission.permission.key, {
          key: rolePermission.permission.key,
          module: rolePermission.permission.module,
          description: rolePermission.permission.description
        });
      }
    }

    const permissions = Array.from(permissionMap.values()).sort((left, right) =>
      left.key.localeCompare(right.key)
    );

    const profile: UserProfile = {
      id: user.id,
      tenantId: user.tenantId,
      name: user.name,
      email: user.email,
      status: user.status,
      tenant: {
        id: user.tenant.id,
        name: user.tenant.name,
        status: user.tenant.status
      },
      roles,
      permissions
    };

    return {
      success: true,
      data: {
        user: profile
      },
      meta: {}
    };
  }

  async getCurrentUserPermissions(userId: string): Promise<UserPermissionsResponse> {
    const profile = await this.getCurrentUserProfile(userId);

    return {
      success: true,
      data: {
        permissions: profile.data.user.permissions
      },
      meta: {}
    };
  }
}
