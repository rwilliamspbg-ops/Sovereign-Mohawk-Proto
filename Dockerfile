# Stage 1: Build the Go binary
# Pinning to a specific version instead of :latest (DL3007)
FROM golang:1.22.5-alpine3.20 AS builder

# Pin versions in apk add (DL3018)
RUN apk add --no-cache git=2.45.2-r0 make=4.4.1-r2

WORKDIR /app

# Copy dependency manifests first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o aggregator ./cmd/aggregator/main.go

# Stage 2: Final lightweight image
# Using explicit alpine version (3.20) instead of :latest
FROM alpine:3.20

# Pin versions for final image runtime dependencies
RUN apk add --no-cache ca-certificates=20240203-r0

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/aggregator .

# Expose the API port for hierarchical communication (Theorem 3)
EXPOSE 8080

# Command to run the global aggregator
CMD ["./aggregator"]
