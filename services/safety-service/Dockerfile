FROM node:20-alpine

WORKDIR /app

# Copy root package.json and workspace configuration if it exists
# In this monorepo styled setup we copy the whole services folder or specific files
# To simplify, we copy the required local packages
COPY package*.json ./
COPY tsconfig.base.json ../

# Install dependencies for shared first
COPY shared ../shared
RUN cd ../shared && npm install && npm run build

# Copy safety service package.json
COPY services/safety-service/package*.json ./
RUN npm install

# Copy source code
COPY services/safety-service/src ./src
COPY services/safety-service/tsconfig.json ./

# Build the TypeScript code
RUN npm run build

EXPOSE 8005

CMD ["npm", "start"]
