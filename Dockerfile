# Stage 1: Build the Go binary
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

WORKDIR /app

# Copy dependency manifests first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o aggregator ./cmd/aggregator/main.go

# Stage 2: Final lightweight image
FROM alpine:latest

RUN apk add --no-cache ca-certificates

WORKDIR /root/

# Copy the binary from the builder stage
COPY --from=builder /app/aggregator .

# Expose the API port for hierarchical communication (Theorem 3)
EXPOSE 8080

# Command to run the global aggregator
CMD ["./aggregator"]
