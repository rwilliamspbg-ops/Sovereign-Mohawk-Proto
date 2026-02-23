# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install build dependencies for CGO (often needed for Wasm runtimes)
RUN apk add --no-cache git gcc musl-dev

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the Node Agent binary
RUN go build -o node-agent-bin ./cmd/node-agent/main.go

# Run stage
FROM alpine:latest
WORKDIR /root/

# Install libgcc for Wasm compatibility
RUN apk --no-cache add ca-certificates libgcc

# Copy binary from builder
COPY --from=builder /app/node-agent-bin .

# Create the directory where the Wasm modules will be mounted
RUN mkdir -p /app/wasm

# The orchestrator and aggregator URLs should be passed via environment variables
# as seen in your docker-compose.yml
EXPOSE 8082

CMD ["./node-agent-bin"]
