function readNumber(value: string | undefined, fallback: number): number {
  if (!value) {
    return fallback;
  }

  const parsed = Number(value);

  if (Number.isNaN(parsed)) {
    return fallback;
  }

  return parsed;
}

export const appConfig = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: readNumber(process.env.APP_PORT, 3000),
  appUrl: process.env.APP_URL || 'http://localhost:3000',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:5173'
};
