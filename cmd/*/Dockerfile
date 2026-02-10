FROM golang:1.22-alpine
WORKDIR /app
COPY .. .
RUN go build -o /bin/app .
CMD ["/bin/app"]
