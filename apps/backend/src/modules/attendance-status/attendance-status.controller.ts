import {
  Controller,
  Get,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceStatusService } from './attendance-status.service';

@Controller('attendance-status')
@UseGuards(JwtAuthGuard)
export class AttendanceStatusController {
  constructor(private readonly attendanceStatusService: AttendanceStatusService) {}

  @Get('model')
  getModel(@CurrentUser() user: AuthenticatedUser) {
    return this.attendanceStatusService.getModel(user.tenantId);
  }

  @Get('options')
  getOptions(
    @CurrentUser() user: AuthenticatedUser,
    @Query('group') group: string
  ) {
    return this.attendanceStatusService.getOptions(user.tenantId, group || 'attendance');
  }

  @Get('compatibility-map')
  getCompatibilityMap(@CurrentUser() user: AuthenticatedUser) {
    return this.attendanceStatusService.getCompatibilityMap(user.tenantId);
  }
}
