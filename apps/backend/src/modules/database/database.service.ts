import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma.service';

type DatabaseStatus = {
  configured: boolean;
  connected: boolean;
  provider: string;
  connectionName: string;
  error: string | null;
};

@Injectable()
export class DatabaseService {
  constructor(private readonly prismaService: PrismaService) {}

  async getStatus(): Promise<DatabaseStatus> {
    try {
      await this.prismaService.$queryRawUnsafe('SELECT 1');

      return {
        configured: true,
        connected: true,
        provider: 'postgresql',
        connectionName: 'primary',
        error: null
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'database_error';

      return {
        configured: true,
        connected: false,
        provider: 'postgresql',
        connectionName: 'primary',
        error: message
      };
    }
  }
}
