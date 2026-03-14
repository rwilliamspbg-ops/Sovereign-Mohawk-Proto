# Build stage
FROM golang:1.25-alpine AS builder

WORKDIR /app

# CGO is required for both the WASM runtime and the Python ctypes bridge.
RUN apk add --no-cache git gcc musl-dev

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build the Node Agent binary.
RUN go build -o node-agent-bin ./cmd/node-agent

# Build the Python ctypes shared library so the SDK can use the real Go bridge.
RUN CGO_ENABLED=1 go build -o libmohawk.so -buildmode=c-shared ./internal/pyapi/

# Run stage
FROM alpine:latest
WORKDIR /root/

RUN apk --no-cache add ca-certificates libgcc

COPY --from=builder /app/node-agent-bin .
COPY --from=builder /app/libmohawk.so .

# WASM module mount-point
RUN mkdir -p /app/wasm

# Tell the Python SDK where to find the compiled bridge library.
ENV MOHAWK_LIB_PATH=/root/libmohawk.so

EXPOSE 8082 4001

CMD ["./node-agent-bin"]
