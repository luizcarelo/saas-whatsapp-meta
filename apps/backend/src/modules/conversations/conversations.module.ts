import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { MetaWhatsappModule } from '../meta-whatsapp/meta-whatsapp.module';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({}),
    MetaWhatsappModule
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
