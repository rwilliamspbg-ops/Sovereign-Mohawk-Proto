# Stage 1: Build the Go binary
# Pinning to a specific version instead of :latest (DL3007)
FROM golang:1.27.4-alpine AS builder

# Force the exact toolchain go.mod requires regardless of what the base
# image's own `go` binary reports -- observed CI failure (2026-08-15):
# `go mod download` ran against a stale go1.26.5 inside a freshly-tagged
# golang:1.27.4-alpine image (base-image/layer-cache mismatch, not a
# missing tag -- the 1.26.6-alpine tag is real and published). GOTOOLCHAIN
# auto-download sidesteps relying on the base image's baked-in version at
# all, matching the same GOTOOLCHAIN=X+auto pattern already hardcoded
# throughout this repo's .github/workflows/*.yml files.
ENV GOTOOLCHAIN=go1.27.4+auto
ENV GODEBUG=http2client=0

# Install build dependencies without pinning obsolete Alpine package revisions
RUN apk add --no-cache git make

WORKDIR /app

# Copy dependency manifests first for better caching
COPY go.mod go.sum ./
RUN go mod download \
      || (sleep 10 && go mod download) \
      || (sleep 20 && go mod download) \
      || (sleep 40 && go mod download)

# Copy source code and build with optimizations
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o aggregator ./cmd/aggregator/main.go

# Stage 2: Final lightweight image
# Pinned to the newest 3.24 point release for a reproducible base.
# `openssl>=3.5.9-r1` is a security floor: every 3.24.x point release currently
# bakes in 3.5.9-r0, which is affected by CVE-2026-95691, CVE-2026-95692,
# CVE-2026-107496, CVE-2026-88822 and CVE-2026-88823. The fix ships only in
# the rolling v3.24 package repository, so it must be pulled in explicitly.
FROM alpine:3.24.4

# Install runtime dependencies; --upgrade pulls the fixed OpenSSL revision
RUN apk add --no-cache --upgrade ca-certificates tini 'zlib>=1.4-r0' 'openssl>=3.5.9-r1'

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
