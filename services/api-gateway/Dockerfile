FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/api-gateway/package*.json ./services/api-gateway/
RUN npm install

COPY shared ./shared
COPY services/api-gateway ./services/api-gateway

RUN npm run build -w @lessgo/shared
RUN npm run build -w api-gateway

FROM node:22-alpine AS runner

WORKDIR /app

COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/api-gateway/package*.json ./services/api-gateway/
RUN npm install --omit=dev --workspace @lessgo/shared --workspace api-gateway --include-workspace-root=false

COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/api-gateway/dist ./services/api-gateway/dist

WORKDIR /app/services/api-gateway

EXPOSE 3000

CMD ["npm", "start"]
