import { Injectable } from '@nestjs/common';
import { ConfigurationService } from '../configuration/configuration.service';

type DatabaseStatus = {
  configured: boolean;
  provider: string;
  connectionName: string;
};

@Injectable()
export class DatabaseService {
  constructor(private readonly configurationService: ConfigurationService) {}

  getStatus(): DatabaseStatus {
    const configured = this.configurationService.hasDatabaseUrl();

    return {
      configured,
      provider: 'postgresql',
      connectionName: configured ? 'primary' : 'not_configured'
    };
  }
}
