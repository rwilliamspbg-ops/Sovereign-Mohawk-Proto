# build stage
FROM golang:1.27.4-alpine AS build
# Force the exact toolchain go.mod requires; see root Dockerfile's comment
# for the observed CI failure (missed Go-version bump in this file) this
# defends against.
ENV GOTOOLCHAIN=go1.27.4+auto
ENV GODEBUG=http2client=0
WORKDIR /src
COPY ../../ ./
RUN (go mod tidy \
      || (sleep 10 && go mod tidy) \
      || (sleep 20 && go mod tidy)) && \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /bin/app ./cmd/orchestrator
RUN go build -o main ./cmd/fl-aggregator/main.go
# runtime stage
FROM gcr.io/distroless/base-debian12
COPY --from=build /bin/app /bin/app
EXPOSE 8090
WORKDIR /app
ENTRYPOINT ["/bin/app"]
