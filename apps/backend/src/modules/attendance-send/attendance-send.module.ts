import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceSendController } from './attendance-send.controller';
import { AttendanceSendService } from './attendance-send.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceSendController
  ],
  providers: [
    AttendanceSendService
  ],
  exports: [
    AttendanceSendService
  ]
})
export class AttendanceSendModule {}
