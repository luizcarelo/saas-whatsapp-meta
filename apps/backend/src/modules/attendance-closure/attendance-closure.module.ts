import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceClosureController } from './attendance-closure.controller';
import { AttendanceClosureService } from './attendance-closure.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceClosureController
  ],
  providers: [
    AttendanceClosureService
  ]
})
export class AttendanceClosureModule {}
