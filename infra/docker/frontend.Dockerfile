FROM node:20-alpine AS deps

WORKDIR /app/apps/frontend

COPY apps/frontend/package.json apps/frontend/package-lock.json ./

RUN npm ci

FROM node:20-alpine AS build

WORKDIR /app/apps/frontend

COPY --from=deps /app/apps/frontend/node_modules ./node_modules
COPY apps/frontend ./

RUN npm run build

FROM nginx:1.27-alpine AS runtime

COPY --from=build /app/apps/frontend/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
