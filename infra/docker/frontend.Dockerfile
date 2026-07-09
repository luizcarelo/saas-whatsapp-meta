FROM node:20-alpine AS build

WORKDIR /app/apps/frontend

COPY apps/frontend/package.json ./
RUN npm install

COPY apps/frontend ./
RUN npm run build

FROM nginx:1.27-alpine AS runtime

COPY --from=build /app/apps/frontend/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
