import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceDashboardController } from './attendance-dashboard.controller';
import { AttendanceDashboardService } from './attendance-dashboard.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceDashboardController
  ],
  providers: [
    AttendanceDashboardService
  ]
})
export class AttendanceDashboardModule {}
