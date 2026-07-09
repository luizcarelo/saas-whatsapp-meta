import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Post,
  Query
} from '@nestjs/common';
import { MetaWebhooksService } from './meta-webhooks.service';
import type {
  MetaWebhookPayload,
  MetaWebhookQuery
} from './meta-webhooks.types';

@Controller('webhooks/meta')
export class MetaWebhooksController {
  constructor(private readonly metaWebhooksService: MetaWebhooksService) {}

  @Get()
  verifyWebhook(@Query() query: MetaWebhookQuery): string {
    const mode = query['hub.mode'];
    const token = query['hub.verify_token'];
    const challenge = query['hub.challenge'];
    const expectedToken = process.env.WHATSAPP_VERIFY_TOKEN || '';

    if (mode === 'subscribe' && token === expectedToken && challenge) {
      return challenge;
    }

    throw new ForbiddenException('Webhook verification failed');
  }

  @Post()
  receiveWebhook(@Body() body: MetaWebhookPayload) {
    return this.metaWebhooksService.receivePayload(body);
  }
}
