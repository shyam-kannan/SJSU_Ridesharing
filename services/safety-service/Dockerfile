FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/safety-service/package*.json ./services/safety-service/
RUN npm install

COPY shared ./shared
COPY services/safety-service ./services/safety-service

RUN npm run build -w @lessgo/shared
RUN npm run build -w safety-service

FROM node:22-alpine AS runner

WORKDIR /app

COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/safety-service/package*.json ./services/safety-service/
RUN npm install --omit=dev --workspace @lessgo/shared --workspace safety-service --include-workspace-root=false

COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/safety-service/dist ./services/safety-service/dist

WORKDIR /app/services/safety-service

EXPOSE 8005

CMD ["npm", "start"]
