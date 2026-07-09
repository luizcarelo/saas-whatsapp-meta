import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { AuthenticatedUser } from '../../modules/auth/auth.types';

type RequestWithHeadersAndUser = {
  headers: {
    authorization?: string;
  };
  user?: AuthenticatedUser;
};

type JwtPayload = AuthenticatedUser & {
  iat?: number;
  exp?: number;
};

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<RequestWithHeadersAndUser>();
    const authorization = request.headers.authorization || '';

    if (!authorization.startsWith('Bearer ')) {
      throw new UnauthorizedException('Token ausente');
    }

    const token = authorization.replace('Bearer ', '').trim();

    if (!token) {
      throw new UnauthorizedException('Token invalido');
    }

    try {
      const payload = this.jwtService.verify<JwtPayload>(token, {
        secret: process.env.JWT_SECRET || 'change_me_jwt_secret'
      });

      request.user = {
        id: payload.id,
        tenantId: payload.tenantId,
        name: payload.name,
        email: payload.email,
        roles: payload.roles,
        permissions: payload.permissions
      };

      return true;
    } catch (_error) {
      throw new UnauthorizedException('Token invalido');
    }
  }
}
