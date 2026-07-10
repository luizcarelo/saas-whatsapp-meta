import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceSendFailuresService } from './attendance-send-failures.service';
import type { AttendanceSendRetryPayload } from './attendance-send-failures.types';

@Controller('attendance-send-failures')
@UseGuards(JwtAuthGuard)
export class AttendanceSendFailuresController {
  constructor(private readonly failuresService: AttendanceSendFailuresService) {}

  @Get()
  listFailures(@CurrentUser() user: AuthenticatedUser) {
    return this.failuresService.listFailures(user.tenantId);
  }

  @Post(':sendId/retry')
  retryFailure(
    @CurrentUser() user: AuthenticatedUser,
    @Param('sendId') sendId: string,
    @Body() body: AttendanceSendRetryPayload
  ) {
    return this.failuresService.retryFailure(user.tenantId, sendId, body);
  }

  @Get('retries')
  listRetries(@CurrentUser() user: AuthenticatedUser) {
    return this.failuresService.listRetries(user.tenantId);
  }
}
