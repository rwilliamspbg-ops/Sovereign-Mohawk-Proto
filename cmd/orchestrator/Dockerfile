# Build stage
FROM golang:1.26.6-alpine AS builder
# Force the exact toolchain go.mod requires; see root Dockerfile's comment
# for the observed CI failure (missed Go-version bump in this file, the
# actual root cause of the Chaos Readiness/Mainnet Readiness/Grafana and
# Prometheus Smoke CI failures this docker-compose-built image caused)
# this defends against.
ENV GOTOOLCHAIN=go1.26.6+auto
WORKDIR /app
RUN apk add --no-cache git gcc musl-dev
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o main ./cmd/orchestrator

# Run stage
FROM alpine:latest
WORKDIR /root/
RUN apk --no-cache add ca-certificates libgcc
COPY --from=builder /app/main .
EXPOSE 8080 4101
CMD ["./main"]
