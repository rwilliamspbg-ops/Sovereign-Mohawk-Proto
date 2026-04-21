# Stage 1: Build the Go binary
# Pinning to a specific version instead of :latest (DL3007)
FROM golang:1.26-alpine3.21 AS builder

# Pin versions in apk add (DL3018)
RUN apk add --no-cache git=2.45.2-r0 make=4.4.1-r2

WORKDIR /app

# Copy dependency manifests first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and build with optimizations
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o aggregator ./cmd/aggregator/main.go

# Stage 2: Final lightweight image
# Using explicit alpine version (3.21) - latest stable
FROM alpine:3.21

# Pin versions for final image runtime dependencies
RUN apk add --no-cache ca-certificates=20240705-r0 tini=0.19.0-r2

# Create non-root user for enhanced security
RUN addgroup -S appgroup && adduser -S -G appgroup appuser

WORKDIR /app

# Copy the binary from the builder stage with proper ownership
COPY --from=builder --chown=appuser:appgroup /app/aggregator .

# Drop unnecessary Linux capabilities
RUN setcap -r ./aggregator 2>/dev/null || true

# Switch to non-root user for runtime security
USER appuser

# Expose the API port for hierarchical communication (Theorem 3)
EXPOSE 8080

# Use tini as PID 1 for proper signal handling and zombie reaping
ENTRYPOINT ["/sbin/tini", "--"]

# Health check to verify aggregator is running and responsive
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O - http://localhost:8080/health || exit 1

# Command to run the global aggregator
CMD ["./aggregator"]
