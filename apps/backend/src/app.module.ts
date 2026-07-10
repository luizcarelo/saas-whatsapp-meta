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
import { AttendanceModule } from './modules/attendance/attendance.module';
import { AttendanceMetadataModule } from './modules/attendance-metadata/attendance-metadata.module';
import { AttendanceClosureModule } from './modules/attendance-closure/attendance-closure.module';
import { AttendanceDashboardModule } from './modules/attendance-dashboard/attendance-dashboard.module';
import { AttendanceSendModule } from './modules/attendance-send/attendance-send.module';
import { AttendanceAutomationsModule } from './modules/attendance-automations/attendance-automations.module';
import { AttendanceSendFailuresModule } from './modules/attendance-send-failures/attendance-send-failures.module';
import { AttendanceStatusModule } from './modules/attendance-status/attendance-status.module';

@Module({
  imports: [
    AttendanceStatusModule,
    AttendanceSendFailuresModule,
    AttendanceAutomationsModule,
    AttendanceSendModule,
    AttendanceDashboardModule,
    AttendanceClosureModule,
    AttendanceMetadataModule,
    AttendanceModule,
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
