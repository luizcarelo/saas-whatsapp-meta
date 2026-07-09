import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Res,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { OperationalAuditService } from './operational-audit.service';
import type {
  OperationalAuditExportQuery,
  OperationalAuditHygienePayload,
  OperationalAuditHygieneQuery,
  OperationalAuditQuery
} from './operational-audit.types';

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

  @Get('export')
  async exportReport(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: OperationalAuditExportQuery,
    @Res() response: any
  ) {
    const file = await this.operationalAuditService.exportReport(user.tenantId, query);

    response.setHeader('Content-Type', file.contentType);
    response.setHeader('Content-Disposition', 'attachment; filename="' + file.filename + '"');

    return response.send(file.content);
  }

  @Get('hygiene-preview')
  previewHygiene(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: OperationalAuditHygieneQuery
  ) {
    return this.operationalAuditService.previewHygiene(user.tenantId, query);
  }

  @Post('hygiene-run')
  runHygiene(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: OperationalAuditHygienePayload
  ) {
    return this.operationalAuditService.runHygiene(user.tenantId, body);
  }
}
