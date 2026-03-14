# Build stage
FROM golang:1.25-alpine AS builder
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
