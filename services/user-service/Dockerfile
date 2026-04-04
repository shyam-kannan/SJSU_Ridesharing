FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/user-service/package*.json ./services/user-service/
RUN npm ci

COPY shared ./shared
COPY services/user-service ./services/user-service

RUN npm run build -w @lessgo/shared
RUN npm run build -w user-service

FROM node:22-alpine AS runner

WORKDIR /app

COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/user-service/package*.json ./services/user-service/
RUN npm ci --omit=dev --workspace @lessgo/shared --workspace user-service --include-workspace-root=false

COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/user-service/dist ./services/user-service/dist

WORKDIR /app/services/user-service

EXPOSE 3002

CMD ["npm", "start"]
