import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { ContactsController } from './contacts.controller';
import { ContactsService } from './contacts.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    ContactsController
  ],
  providers: [
    ContactsService
  ],
  exports: [
    ContactsService
  ]
})
export class ContactsModule {}
