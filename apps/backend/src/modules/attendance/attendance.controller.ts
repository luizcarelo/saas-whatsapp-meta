import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { AttendanceService } from './attendance.service';
import type {
  AttendanceAssignConversationPayload,
  AttendanceDepartmentPayload,
  AttendanceQuickReplyPayload,
  AttendanceUpdateStatusPayload
} from './attendance.types';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceController {
  constructor(private readonly attendanceService: AttendanceService) {}

  @Get('quick-replies')
  listQuickReplies(
    @CurrentUser() user: AuthenticatedUser,
    @Query('departmentName') departmentName?: string
  ) {
    return this.attendanceService.listQuickReplies(user.tenantId, departmentName);
  }

  @Post('quick-replies')
  createQuickReply(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: AttendanceQuickReplyPayload
  ) {
    return this.attendanceService.createQuickReply(user.tenantId, body);
  }

  @Patch('quick-replies/:quickReplyId')
  updateQuickReply(
    @CurrentUser() user: AuthenticatedUser,
    @Param('quickReplyId') quickReplyId: string,
    @Body() body: AttendanceQuickReplyPayload
  ) {
    return this.attendanceService.updateQuickReply(user.tenantId, quickReplyId, body);
  }

  @Get('departments')
  listDepartments(@CurrentUser() user: AuthenticatedUser) {
    return this.attendanceService.listDepartments(user.tenantId);
  }

  @Post('departments')
  createDepartment(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: AttendanceDepartmentPayload
  ) {
    return this.attendanceService.createDepartment(user.tenantId, body);
  }

  @Patch('departments/:departmentId')
  updateDepartment(
    @CurrentUser() user: AuthenticatedUser,
    @Param('departmentId') departmentId: string,
    @Body() body: AttendanceDepartmentPayload
  ) {
    return this.attendanceService.updateDepartment(user.tenantId, departmentId, body);
  }

  @Get('conversations/status-options')
  getStatusOptions() {
    return this.attendanceService.getStatusOptions();
  }

  @Get('conversations')
  listConversations(@CurrentUser() user: AuthenticatedUser) {
    return this.attendanceService.listConversations(user.tenantId);
  }

  @Patch('conversations/:conversationId/assignee')
  assignConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceAssignConversationPayload
  ) {
    return this.attendanceService.assignConversation(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/assignments')
  listAssignmentHistory(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.attendanceService.listAssignmentHistory(user.tenantId, conversationId);
  }

  @Patch('conversations/:conversationId/status')
  updateConversationStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceUpdateStatusPayload
  ) {
    return this.attendanceService.updateConversationStatus(user.tenantId, conversationId, body);
  }
}
