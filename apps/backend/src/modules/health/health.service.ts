import { Injectable } from '@nestjs/common';
import { ConfigurationService } from '../configuration/configuration.service';
import { DatabaseService } from '../database/database.service';

type HealthResponse = {
  success: true;
  data: {
    status: string;
    service: string;
    timestamp: string;
    environment: string;
    checks: {
      api: string;
      database: string;
      redis: string;
      meta: string;
    };
  };
  meta: Record<string, never>;
};

@Injectable()
export class HealthService {
  constructor(
    private readonly configurationService: ConfigurationService,
    private readonly databaseService: DatabaseService
  ) {}

  async getHealth(): Promise<HealthResponse> {
    const config = this.configurationService.getPublicConfig();
    const database = await this.databaseService.getStatus();

    return {
      success: true,
      data: {
        status: database.connected ? 'ok' : 'degraded',
        service: 'backend',
        timestamp: new Date().toISOString(),
        environment: config.nodeEnv,
        checks: {
          api: 'ok',
          database: database.connected ? 'ok' : 'error',
          redis: config.redisConfigured ? 'configured' : 'not_configured',
          meta: config.metaConfigured ? 'configured' : 'not_configured'
        }
      },
      meta: {}
    };
  }
}
