# build stage
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY ../../ ./
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /bin/app ./cmd/orchestrator

# runtime stage
FROM gcr.io/distroless/base-debian12
COPY --from=build /bin/app /bin/app
WORKDIR /app
ENTRYPOINT ["/bin/app"]
