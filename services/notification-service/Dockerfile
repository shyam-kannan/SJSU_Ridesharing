FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/notification-service/package*.json ./services/notification-service/
RUN npm ci

COPY shared ./shared
COPY services/notification-service ./services/notification-service

RUN npm run build -w @lessgo/shared
RUN npm run build -w notification-service

FROM node:22-alpine AS runner

WORKDIR /app

COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/notification-service/package*.json ./services/notification-service/
RUN npm ci --omit=dev --workspace @lessgo/shared --workspace notification-service --include-workspace-root=false

COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/notification-service/dist ./services/notification-service/dist

WORKDIR /app/services/notification-service

EXPOSE 3006

CMD ["npm", "start"]
