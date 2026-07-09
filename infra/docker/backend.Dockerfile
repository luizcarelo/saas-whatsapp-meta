FROM node:20-alpine AS build

WORKDIR /app/apps/backend

COPY apps/backend/package.json ./
RUN npm install

COPY apps/backend ./
RUN npm run build

FROM node:20-alpine AS runtime

WORKDIR /app/apps/backend

ENV NODE_ENV=production

COPY --from=build /app/apps/backend/package.json ./
COPY --from=build /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/dist ./dist

EXPOSE 3000

CMD ["node", "dist/main.js"]
