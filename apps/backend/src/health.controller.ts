import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  getHealth() {
    return {
      success: true,
      data: {
        status: 'ok',
        service: 'backend',
        timestamp: new Date().toISOString()
      },
      meta: {}
    };
  }
}
