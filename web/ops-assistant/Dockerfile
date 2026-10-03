# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY web/ops-assistant/package*.json ./
COPY web/ops-assistant/tsconfig.json ./
COPY web/ops-assistant/vite.config.ts ./

# Install dependencies
RUN npm ci

# Copy source code
COPY web/ops-assistant/server ./server
COPY web/ops-assistant/client ./client
COPY web/ops-assistant/index.html ./index.html

# Vite inlines VITE_* variables at BUILD time, so they must be present here --
# they cannot be supplied later via compose `environment:`. compose passes them
# as build args sourced from the repo-root .env (see docker-compose.yml).
# Unset values become empty strings, which the client treats as "use defaults".
ARG VITE_API_BASE_URL=""
ARG VITE_WS_URL=""
ARG VITE_COPILOT_PUBLIC_API_KEY=""
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
ENV VITE_WS_URL=${VITE_WS_URL}
ENV VITE_COPILOT_PUBLIC_API_KEY=${VITE_COPILOT_PUBLIC_API_KEY}

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
RUN npm ci --omit=dev

# Copy built assets from builder
COPY --from=builder /app/dist ./dist

# Environment defaults
ENV NODE_ENV=production
ENV PORT=3000
ENV PROMETHEUS_URL=http://prometheus:9090
ENV GRAFANA_URL=http://grafana:3000

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

# Use tini to handle signals properly
ENTRYPOINT ["/sbin/tini", "--"]

# Start server
CMD ["node", "dist/server/index.js"]
