# Build stage
FROM golang:1.27.4-alpine AS builder

# Force the exact toolchain go.mod requires; see root Dockerfile's comment
# for the observed CI failure (missed Go-version bump in this file) this
# defends against.
ENV GOTOOLCHAIN=go1.27.4+auto
ENV GODEBUG=http2client=0

WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download \
      || (sleep 10 && go mod download) \
      || (sleep 20 && go mod download) \
      || (sleep 40 && go mod download)

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o accelerator-detect ./cmd/accelerator-detect

# Runtime stage
FROM alpine:3.23

RUN apk add --no-cache ca-certificates

WORKDIR /root

COPY --from=builder /app/accelerator-detect .

ENTRYPOINT ["./accelerator-detect"]