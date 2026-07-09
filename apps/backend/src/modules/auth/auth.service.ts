import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import bcrypt from 'bcryptjs';
import { PrismaService } from '../database/prisma.service';
import type { AuthenticatedUser, LoginResponse } from './auth.types';

type LoginInput = {
  email?: string;
  password?: string;
};

@Injectable()
export class AuthService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly jwtService: JwtService
  ) {}

  async login(input: LoginInput): Promise<LoginResponse> {
    const email = input.email ? input.email.trim().toLowerCase() : '';
    const password = input.password || '';

    if (!email || !password) {
      throw new UnauthorizedException('Credenciais invalidas');
    }

    const user = await this.prismaService.user.findFirst({
      where: {
        email,
        status: 'active',
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

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Credenciais invalidas');
    }

    if (user.tenant.status !== 'active') {
      throw new UnauthorizedException('Tenant inativo');
    }

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);

    if (!passwordMatches) {
      throw new UnauthorizedException('Credenciais invalidas');
    }

    const roles = user.userRoles.map((userRole) => userRole.role.name);

    const permissions = Array.from(
      new Set(
        user.userRoles.flatMap((userRole) =>
          userRole.role.rolePermissions.map((rolePermission) => rolePermission.permission.key)
        )
      )
    ).sort();

    const authenticatedUser: AuthenticatedUser = {
      id: user.id,
      tenantId: user.tenantId,
      name: user.name,
      email: user.email,
      roles,
      permissions
    };

    const accessToken = this.jwtService.sign(authenticatedUser, {
      secret: process.env.JWT_SECRET || 'change_me_jwt_secret',
      expiresIn: '8h'
    });

    return {
      success: true,
      data: {
        access_token: accessToken,
        token_type: 'Bearer',
        user: authenticatedUser
      },
      meta: {}
    };
  }
}
