# Build stage
FROM golang:1.26.3-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o accelerator-detect ./cmd/accelerator-detect

# Runtime stage
FROM alpine:3.23

RUN apk add --no-cache ca-certificates

WORKDIR /root

COPY --from=builder /app/accelerator-detect .

ENTRYPOINT ["./accelerator-detect"]