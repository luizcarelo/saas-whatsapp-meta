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
import { ContactsService } from './contacts.service';
import type { ContactPayload } from './contacts.types';

type ListContactsQuery = {
  search?: string;
  limit?: string;
  offset?: string;
};

@Controller('contacts')
@UseGuards(JwtAuthGuard)
export class ContactsController {
  constructor(private readonly contactsService: ContactsService) {}

  @Get()
  listContacts(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: ListContactsQuery
  ) {
    return this.contactsService.listContacts(user.tenantId, query);
  }

  @Post()
  createContact(
    @CurrentUser() user: AuthenticatedUser,
    @Body() body: ContactPayload
  ) {
    return this.contactsService.createContact(user.tenantId, body);
  }

  @Get(':id')
  getContact(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.contactsService.getContact(user.tenantId, id);
  }

  @Patch(':id')
  updateContact(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: ContactPayload
  ) {
    return this.contactsService.updateContact(user.tenantId, id, body);
  }

  @Delete(':id')
  deleteContact(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id') id: string
  ) {
    return this.contactsService.deleteContact(user.tenantId, id);
  }
}
