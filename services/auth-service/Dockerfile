FROM node:22-alpine AS builder

WORKDIR /app

# Install full dependencies (including dev deps) for build
COPY package*.json ./
COPY tsconfig.base.json ./
COPY shared/package*.json ./shared/
COPY services/auth-service/package*.json ./services/auth-service/
RUN npm install

COPY shared ./shared
COPY services/auth-service ./services/auth-service

RUN npm run build -w @lessgo/shared
RUN npm run build -w auth-service


FROM node:22-alpine AS runner

WORKDIR /app

# Install runtime deps only for shared + target workspace
COPY package*.json ./
COPY shared/package*.json ./shared/
COPY services/auth-service/package*.json ./services/auth-service/
RUN npm install --omit=dev --workspace @lessgo/shared --workspace auth-service --include-workspace-root=false

# Copy only built artifacts
COPY --from=builder /app/shared/dist ./shared/dist
COPY --from=builder /app/services/auth-service/dist ./services/auth-service/dist

WORKDIR /app/services/auth-service

EXPOSE 3001

CMD ["npm", "start"]
