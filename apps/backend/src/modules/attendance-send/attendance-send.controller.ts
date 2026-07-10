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
import { AttendanceSendService } from './attendance-send.service';
import type { AttendanceSendManualPayload } from './attendance-send.types';

type AttendanceAuthenticatedUser = AuthenticatedUser & {
  id?: string;
  userId?: string;
  sub?: string;
  name?: string;
  fullName?: string;
  email?: string;
};

@Controller('attendance-send')
@UseGuards(JwtAuthGuard)
export class AttendanceSendController {
  constructor(private readonly attendanceSendService: AttendanceSendService) {}

  @Post('conversations/:conversationId/messages')
  sendManualMessage(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceSendManualPayload
  ) {
    const authUser = user as AttendanceAuthenticatedUser;
    const authenticatedUserId = authUser.userId || authUser.id || authUser.sub || null;
    const authenticatedName = authUser.name || authUser.fullName || authUser.email || null;

    const payload: AttendanceSendManualPayload = {
      ...body,
      sentByUserId: body.sentByUserId || authenticatedUserId,
      sentByName: body.sentByName || authenticatedName || 'Atendente autenticado',
      attendantSource: body.sentByName ? 'payload' : authenticatedName ? 'authenticated_user' : 'fallback'
    };

    return this.attendanceSendService.sendManualMessage(user.tenantId, conversationId, payload);
  }

  @Get('conversations/:conversationId/messages')
  listSendHistory(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.attendanceSendService.listSendHistory(user.tenantId, conversationId);
  }
}
