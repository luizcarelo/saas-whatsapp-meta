import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DatabaseModule } from '../database/database.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [
    DatabaseModule,
    JwtModule.register({})
  ],
  controllers: [
    UsersController
  ],
  providers: [
    UsersService
  ],
  exports: [
    UsersService
  ]
})
export class UsersModule {}
