import {
  Controller,
  Get,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { OperationalAuditService } from './operational-audit.service';
import type { OperationalAuditQuery } from './operational-audit.types';

@Controller('operational-audit')
@UseGuards(JwtAuthGuard)
export class OperationalAuditController {
  constructor(private readonly operationalAuditService: OperationalAuditService) {}

  @Get('summary')
  getSummary(@CurrentUser() user: AuthenticatedUser) {
    return this.operationalAuditService.getSummary(user.tenantId);
  }

  @Get('messages')
  listMessages(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: OperationalAuditQuery
  ) {
    return this.operationalAuditService.listMessages(user.tenantId, query);
  }

  @Get('webhooks')
  listWebhooks(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: OperationalAuditQuery
  ) {
    return this.operationalAuditService.listWebhooks(user.tenantId, query);
  }
}
