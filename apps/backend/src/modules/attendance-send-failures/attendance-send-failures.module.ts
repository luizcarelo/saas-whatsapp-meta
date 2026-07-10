import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AttendanceSendModule } from '../attendance-send/attendance-send.module';
import { DatabaseModule } from '../database/database.module';
import { AttendanceSendFailuresController } from './attendance-send-failures.controller';
import { AttendanceSendFailuresService } from './attendance-send-failures.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({}),
    AttendanceSendModule
  ],
  controllers: [
    AttendanceSendFailuresController
  ],
  providers: [
    AttendanceSendFailuresService
  ]
})
export class AttendanceSendFailuresModule {}
