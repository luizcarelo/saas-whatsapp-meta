import { Injectable } from '@nestjs/common';

type PublicConfig = {
  nodeEnv: string;
  appPort: number;
  appUrl: string;
  frontendUrl: string;
  databaseConfigured: boolean;
  redisConfigured: boolean;
  metaConfigured: boolean;
};

@Injectable()
export class ConfigurationService {
  getString(key: string, fallback = ''): string {
    return process.env[key] || fallback;
  }

  getNumber(key: string, fallback: number): number {
    const value = process.env[key];

    if (!value) {
      return fallback;
    }

    const parsed = Number(value);

    if (Number.isNaN(parsed)) {
      return fallback;
    }

    return parsed;
  }

  getPublicConfig(): PublicConfig {
    return {
      nodeEnv: this.getString('NODE_ENV', 'development'),
      appPort: this.getNumber('APP_PORT', 3000),
      appUrl: this.getString('APP_URL', 'http://localhost:3300'),
      frontendUrl: this.getString('FRONTEND_URL', 'http://localhost:5573'),
      databaseConfigured: this.hasDatabaseUrl(),
      redisConfigured: this.hasRedisConfig(),
      metaConfigured: this.hasMetaConfig()
    };
  }

  hasDatabaseUrl(): boolean {
    return this.getString('DATABASE_URL').length > 0;
  }

  hasRedisConfig(): boolean {
    return this.getString('REDIS_HOST').length > 0 && this.getString('REDIS_PORT').length > 0;
  }

  hasMetaConfig(): boolean {
    return this.getString('META_GRAPH_BASE_URL').length > 0 && this.getString('META_API_VERSION').length > 0;
  }
}
