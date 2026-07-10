import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { AttendanceMetadataController } from './attendance-metadata.controller';
import { AttendanceMetadataService } from './attendance-metadata.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    AttendanceMetadataController
  ],
  providers: [
    AttendanceMetadataService
  ]
})
export class AttendanceMetadataModule {}
