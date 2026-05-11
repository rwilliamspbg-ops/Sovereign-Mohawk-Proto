# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY web/ops-assistant/package*.json ./
COPY web/ops-assistant/tsconfig.json ./
COPY web/ops-assistant/vite.config.ts ./
COPY web/ops-assistant/local-packages ./local-packages

# Install dependencies (allow local file: packages)
RUN npm install --no-audit --no-fund

# Copy source code
COPY web/ops-assistant/server ./server
COPY web/ops-assistant/client ./client
COPY web/ops-assistant/public ./public

# Build
RUN npm run build

# Runtime stage
FROM node:20-alpine

WORKDIR /app

# Install curl for healthchecks
RUN apk add --no-cache curl tini

# Copy package files
COPY web/ops-assistant/package*.json ./

# Install production dependencies only
RUN npm install --omit=dev --no-audit --no-fund

# Copy built assets from builder
COPY --from=builder /app/dist ./dist

# Environment defaults
ENV NODE_ENV=production
ENV PORT=3000
ENV PROMETHEUS_URL=http://prometheus:9090

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Use tini to handle signals properly
ENTRYPOINT ["/sbin/tini", "--"]

# Start server
CMD ["node", "dist/server/index.js"]
