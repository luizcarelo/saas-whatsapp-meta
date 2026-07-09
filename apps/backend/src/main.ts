import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from './app.module';
import { appConfig } from './config/app.config';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter()
  );

  app.enableCors({
    origin: appConfig.frontendUrl,
    credentials: true
  });

  app.setGlobalPrefix('api/v1');

  await app.listen(appConfig.port, '0.0.0.0');
}

void bootstrap();
