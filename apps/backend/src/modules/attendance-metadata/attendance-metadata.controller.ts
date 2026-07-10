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
import { AttendanceMetadataService } from './attendance-metadata.service';
import type {
  AttendanceAttachTagPayload,
  AttendanceInternalNotePayload,
  AttendanceTagPayload
} from './attendance-metadata.types';

@Controller('attendance')
@UseGuards(JwtAuthGuard)
export class AttendanceMetadataController {
  constructor(private readonly metadataService: AttendanceMetadataService) {}

  @Get('tags')
  listTags(@CurrentUser() user: AuthenticatedUser) {
    return this.metadataService.listTags(user.tenantId);
  }

  @Post('tags')
  createTag(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: AttendanceTagPayload
  ) {
    return this.metadataService.createTag(user.tenantId, body);
  }

  @Get('conversations/:conversationId/notes')
  listNotes(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.metadataService.listNotes(user.tenantId, conversationId);
  }

  @Post('conversations/:conversationId/notes')
  createNote(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceInternalNotePayload
  ) {
    return this.metadataService.createNote(user.tenantId, conversationId, body);
  }

  @Get('conversations/:conversationId/tags')
  listConversationTags(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string
  ) {
    return this.metadataService.listConversationTags(user.tenantId, conversationId);
  }

  @Post('conversations/:conversationId/tags')
  attachTag(
    @CurrentUser() user: AuthenticatedUser,
    @Param('conversationId') conversationId: string,
    @Body() body: AttendanceAttachTagPayload
  ) {
    return this.metadataService.attachTag(user.tenantId, conversationId, body);
  }
}
