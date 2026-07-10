import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceStatusController } from './attendance-status.controller';
import { AttendanceStatusService } from './attendance-status.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceStatusController
  ],
  providers: [
    AttendanceStatusService
  ]
})
export class AttendanceStatusModule {}
