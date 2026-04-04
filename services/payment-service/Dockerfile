FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/payment-service/package*.json ./services/payment-service/
RUN npm ci

COPY shared ./shared
COPY services/payment-service ./services/payment-service

RUN npm run build -w @lessgo/shared
RUN npm run build -w payment-service

FROM node:22-alpine AS runner

WORKDIR /app

COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/payment-service/package*.json ./services/payment-service/
RUN npm ci --omit=dev --workspace @lessgo/shared --workspace payment-service --include-workspace-root=false

COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/payment-service/dist ./services/payment-service/dist

WORKDIR /app/services/payment-service

EXPOSE 3005

CMD ["npm", "start"]
