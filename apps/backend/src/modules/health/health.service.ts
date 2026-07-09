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

  getHealth(): HealthResponse {
    const config = this.configurationService.getPublicConfig();
    const database = this.databaseService.getStatus();

    return {
      success: true,
      data: {
        status: 'ok',
        service: 'backend',
        timestamp: new Date().toISOString(),
        environment: config.nodeEnv,
        checks: {
          api: 'ok',
          database: database.configured ? 'configured' : 'not_configured',
          redis: config.redisConfigured ? 'configured' : 'not_configured',
          meta: config.metaConfigured ? 'configured' : 'not_configured'
        }
      },
      meta: {}
    };
  }
}
