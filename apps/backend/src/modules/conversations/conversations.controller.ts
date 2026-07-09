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
import { ConversationsService } from './conversations.service';
import type {
  CreateConversationMessagePayload,
  CreateConversationPayload,
  SendConversationTemplatePayload
} from './conversations.types';

type ListConversationsQuery = {
  search?: string;
  status?: string;
  limit?: string;
  offset?: string;
};

@Controller('conversations')
@UseGuards(JwtAuthGuard)
export class ConversationsController {
  constructor(private readonly conversationsService: ConversationsService) {}

  @Get()
  listConversations(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListConversationsQuery
  ) {
    return this.conversationsService.listConversations(user.tenantId, query);
  }

  @Post()
  createConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: CreateConversationPayload
  ) {
    return this.conversationsService.createConversation(user.tenantId, body);
  }

  @Get(':id')
  getConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.conversationsService.getConversation(user.tenantId, id);
  }

  @Post(':id/messages')
  createMessage(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: CreateConversationMessagePayload
  ) {
    return this.conversationsService.createConversationMessage(user.tenantId, id, body);
  }

  @Post(':id/templates')
  sendTemplate(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: SendConversationTemplatePayload
  ) {
    return this.conversationsService.sendConversationTemplate(user.tenantId, id, body);
  }

  @Patch(':id/close')
  closeConversation(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.conversationsService.closeConversation(user.tenantId, id);
  }
}
