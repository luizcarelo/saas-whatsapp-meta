import { Module } from '@nestjs/common';
import { AuthModule } from './modules/auth/auth.module';
import { ConfigurationModule } from './modules/configuration/configuration.module';
import { ContactsModule } from './modules/contacts/contacts.module';
import { ConversationsModule } from './modules/conversations/conversations.module';
import { DatabaseModule } from './modules/database/database.module';
import { HealthModule } from './modules/health/health.module';
import { UsersModule } from './modules/users/users.module';
import { WebhooksModule } from './modules/webhooks/webhooks.module';
import { WhatsappAccountsModule } from './modules/whatsapp-accounts/whatsapp-accounts.module';
import { OperationalAuditModule } from './modules/operational-audit/operational-audit.module';

@Module({
  imports: [
    OperationalAuditModule,
    ConfigurationModule,
    DatabaseModule,
    HealthModule,
    AuthModule,
    UsersModule,
    ContactsModule,
    ConversationsModule,
    WhatsappAccountsModule,
    WebhooksModule
  ],
  controllers: [],
  providers: []
})
export class AppModule {}
