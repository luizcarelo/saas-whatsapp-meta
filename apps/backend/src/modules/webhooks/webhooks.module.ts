import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { MetaWebhooksController } from './meta-webhooks.controller';
import { MetaWebhooksService } from './meta-webhooks.service';

@Module({
  imports: [
    DatabaseModule
  ],
  controllers: [
    MetaWebhooksController
  ],
  providers: [
    MetaWebhooksService
  ],
  exports: [
    MetaWebhooksService
  ]
})
export class WebhooksModule {}
