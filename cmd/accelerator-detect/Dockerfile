# Build stage
FROM golang:1.26.6-alpine AS builder

# Force the exact toolchain go.mod requires; see root Dockerfile's comment
# for the observed CI failure (missed Go-version bump in this file) this
# defends against.
ENV GOTOOLCHAIN=go1.26.6+auto

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