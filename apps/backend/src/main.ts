import { json, urlencoded } from 'body-parser';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { rawBodySaver } from './common/middleware/raw-body.middleware';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    bodyParser: false
  });

  app.use(
    json({
      limit: '10mb',
      verify: rawBodySaver
    })
  );

  app.use(
    urlencoded({
      extended: true,
      limit: '10mb',
      verify: rawBodySaver
    })
  );

  app.setGlobalPrefix('api/v1');

  const port = Number(process.env.APP_PORT || 3000);

  await app.listen(port, '0.0.0.0');
}

void bootstrap();
