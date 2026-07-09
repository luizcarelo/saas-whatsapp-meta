import { Module } from '@nestjs/common';
import { MetaWhatsappService } from './meta-whatsapp.service';

@Module({
  providers: [
    MetaWhatsappService
  ],
  exports: [
    MetaWhatsappService
  ]
})
export class MetaWhatsappModule {}
