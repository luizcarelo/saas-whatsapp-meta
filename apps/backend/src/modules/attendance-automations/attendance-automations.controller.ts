import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceAutomationsService } from './attendance-automations.service';
import type {
  AttendanceAutomationRuleUpdatePayload,
  AttendanceAutomationRunPayload
} from './attendance-automations.types';

@Controller('attendance-automations')
@UseGuards(JwtAuthGuard)
export class AttendanceAutomationsController {
  constructor(private readonly automationsService: AttendanceAutomationsService) {}

  @Get('rules')
  listRules(@CurrentUser() user: AuthenticatedUser) {
    return this.automationsService.listRules(user.tenantId);
  }

  @Patch('rules/:ruleId')
  updateRule(
    @CurrentUser() user: AuthenticatedUser,
    @Param('ruleId') ruleId: string,
    @Body() body: AttendanceAutomationRuleUpdatePayload
  ) {
    return this.automationsService.updateRule(user.tenantId, ruleId, body);
  }

  @Post('rules/:ruleId/run')
  runRule(
    @CurrentUser() user: AuthenticatedUser,
    @Param('ruleId') ruleId: string,
    @Body() body: AttendanceAutomationRunPayload
  ) {
    return this.automationsService.runRule(user.tenantId, ruleId, body);
  }

  @Get('executions')
  listExecutions(@CurrentUser() user: AuthenticatedUser) {
    return this.automationsService.listExecutions(user.tenantId);
  }
}
