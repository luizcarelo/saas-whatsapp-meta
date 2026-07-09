import {
  Body,
  Controller,
  Delete,
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
import { WhatsappAccountsService } from './whatsapp-accounts.service';
import type { WhatsappAccountPayload } from './whatsapp-accounts.types';

type ListAccountsQuery = {
  search?: string;
  limit?: string;
  offset?: string;
};

@Controller('whatsapp-accounts')
@UseGuards(JwtAuthGuard)
export class WhatsappAccountsController {
  constructor(private readonly whatsappAccountsService: WhatsappAccountsService) {}

  @Get()
  listAccounts(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListAccountsQuery
  ) {
    return this.whatsappAccountsService.listAccounts(user.tenantId, query);
  }

  @Post()
  createAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: WhatsappAccountPayload
  ) {
    return this.whatsappAccountsService.createAccount(user.tenantId, body);
  }

  @Get(':id/templates')
  listTemplates(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.listTemplates(user.tenantId, id);
  }

  @Get(':id/operational')
  getOperationalStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.getOperationalStatus(user.tenantId, id);
  }

  @Get(':id')
  getAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.getAccount(user.tenantId, id);
  }

  @Patch(':id')
  updateAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: WhatsappAccountPayload
  ) {
    return this.whatsappAccountsService.updateAccount(user.tenantId, id, body);
  }

  @Delete(':id')
  deleteAccount(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.whatsappAccountsService.deleteAccount(user.tenantId, id);
  }
}
