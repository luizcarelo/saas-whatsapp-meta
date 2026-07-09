FROM node:20-alpine

WORKDIR /app

ENV NODE_ENV=production

CMD ["node", "-e", "setInterval(() => console.log('worker placeholder'), 60000)"]
