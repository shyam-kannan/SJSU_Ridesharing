FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/booking-service/package*.json ./services/booking-service/
RUN npm install

COPY shared ./shared
COPY services/booking-service ./services/booking-service

RUN npm run build -w @lessgo/shared
RUN npm run build -w booking-service

FROM node:22-alpine AS runner

WORKDIR /app

COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/booking-service/package*.json ./services/booking-service/
RUN npm install --omit=dev --workspace @lessgo/shared --workspace booking-service --include-workspace-root=false

COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/booking-service/dist ./services/booking-service/dist

WORKDIR /app/services/booking-service

EXPOSE 3004

CMD ["npm", "start"]
