import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { MetaWhatsappModule } from '../meta-whatsapp/meta-whatsapp.module';
import { WhatsappAccountsController } from './whatsapp-accounts.controller';
import { WhatsappAccountsService } from './whatsapp-accounts.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({}),
    MetaWhatsappModule
  ],
  controllers: [
    WhatsappAccountsController
  ],
  providers: [
    WhatsappAccountsService
  ],
  exports: [
    WhatsappAccountsService
  ]
})
export class WhatsappAccountsModule {}
