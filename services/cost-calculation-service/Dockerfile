FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/cost-calculation-service/package*.json ./services/cost-calculation-service/
RUN npm install

COPY shared ./shared
COPY services/cost-calculation-service ./services/cost-calculation-service

RUN npm run build -w @lessgo/shared
RUN npm run build -w cost-calculation-service

FROM node:22-alpine AS runner

WORKDIR /app

COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/cost-calculation-service/package*.json ./services/cost-calculation-service/
RUN npm install --omit=dev --workspace @lessgo/shared --workspace cost-calculation-service --include-workspace-root=false

COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/cost-calculation-service/dist ./services/cost-calculation-service/dist

WORKDIR /app/services/cost-calculation-service

EXPOSE 3009

CMD ["npm", "start"]
