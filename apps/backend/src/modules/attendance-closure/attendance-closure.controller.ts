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
import { AttendanceClosureService } from './attendance-closure.service';
import type {
  AttendanceClosurePayload,
  AttendanceRatingPayload
} from './attendance-closure.types';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceClosureController {
  constructor(private readonly closureService: AttendanceClosureService) {}

  @Post('conversations/:conversationId/close')
  closeConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceClosurePayload
  ) {
    return this.closureService.closeConversation(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/closures')
  listClosures(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.closureService.listClosures(user.tenantId, conversationId);
  }

  @Post('conversations/:conversationId/rating')
  createRating(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceRatingPayload
  ) {
    return this.closureService.createRating(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/ratings')
  listRatings(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.closureService.listRatings(user.tenantId, conversationId);
  }
}
