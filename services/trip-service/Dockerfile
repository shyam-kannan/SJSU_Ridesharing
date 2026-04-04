FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/trip-service/package*.json ./services/trip-service/
RUN npm ci

COPY shared ./shared
COPY services/trip-service ./services/trip-service

RUN npm run build -w @lessgo/shared
RUN npm run build -w trip-service

FROM node:22-alpine AS runner

WORKDIR /app

COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/trip-service/package*.json ./services/trip-service/
RUN npm ci --omit=dev --workspace @lessgo/shared --workspace trip-service --include-workspace-root=false

COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/trip-service/dist ./services/trip-service/dist

WORKDIR /app/services/trip-service

EXPOSE 3003

CMD ["npm", "start"]
