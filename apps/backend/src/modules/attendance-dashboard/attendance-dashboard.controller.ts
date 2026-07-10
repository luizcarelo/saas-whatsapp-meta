import {
  Controller,
  Get,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceDashboardService } from './attendance-dashboard.service';

@Controller('attendance-dashboard')
@UseGuards(JwtAuthGuard)
export class AttendanceDashboardController {
  constructor(private readonly dashboardService: AttendanceDashboardService) {}

  @Get('summary')
  getSummary(@CurrentUser() user: AuthenticatedUser) {
    return this.dashboardService.getSummary(user.tenantId);
  }
}
