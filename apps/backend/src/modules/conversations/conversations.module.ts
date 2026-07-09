import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    ConversationsController
  ],
  providers: [
    ConversationsService
  ],
  exports: [
    ConversationsService
  ]
})
export class ConversationsModule {}
