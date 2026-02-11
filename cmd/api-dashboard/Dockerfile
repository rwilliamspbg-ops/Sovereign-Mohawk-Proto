# Build stage: Use Go 1.22-alpine for a lightweight build environment
FROM golang:1.22-alpine AS builder

# Set the working directory to the root of the project
WORKDIR /app

# Install necessary build tools
RUN apk add --no-cache git

# Copy go.mod and go.sum from the root to leverage Docker cache
COPY go.mod go.sum ./
RUN go mod download

# Copy the entire project source
COPY . .

# Build the specific API Dashboard binary
# We target the main.go file in the api-dashboard directory
RUN go build -o api-dashboard-bin ./cmd/api-dashboard/main.go

# Final stage: Use a minimal alpine image for the runner
FROM alpine:latest
WORKDIR /root/

# Install CA certificates for secure communication
RUN apk --no-cache add ca-certificates

# Copy the binary from the builder stage
COPY --from=builder /app/api-dashboard-bin .

# Expose the dashboard port defined in your docker-compose
EXPOSE 8081

# Run the binary
CMD ["./api-dashboard-bin"]
