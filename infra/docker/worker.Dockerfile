FROM node:20-alpine AS runtime

WORKDIR /app

ENV NODE_ENV=production

CMD ["node", "-e", "setInterval(() => console.log('worker placeholder'), 60000)"]
