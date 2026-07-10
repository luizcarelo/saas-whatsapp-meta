import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AttendanceSendModule } from '../attendance-send/attendance-send.module';
import { DatabaseModule } from '../database/database.module';
import { AttendanceAutomationsController } from './attendance-automations.controller';
import { AttendanceAutomationsService } from './attendance-automations.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({}),
    AttendanceSendModule
  ],
  controllers: [
    AttendanceAutomationsController
  ],
  providers: [
    AttendanceAutomationsService
  ]
})
export class AttendanceAutomationsModule {}
