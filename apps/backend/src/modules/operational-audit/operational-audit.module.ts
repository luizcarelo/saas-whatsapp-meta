import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { OperationalAuditController } from './operational-audit.controller';
import { OperationalAuditService } from './operational-audit.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    OperationalAuditController
  ],
  providers: [
    OperationalAuditService
  ]
})
export class OperationalAuditModule {}
