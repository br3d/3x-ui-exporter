# Stage 1: Build
FROM golang:alpine3.22 AS build

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

# Copy other code
COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o 3xui-exporter_linux_amd64 .

# Stage 2: Final stage
FROM alpine:3.22

RUN apk add --no-cache curl=8.14.1-r1

RUN addgroup -S 3xui_exporter && adduser -S 3xui_exporter -G 3xui_exporter

WORKDIR /app

COPY --from=build /app/3xui-exporter_linux_amd64 .

RUN chown -R 3xui_exporter:3xui_exporter /app

USER 3xui_exporter

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -sf http://localhost:9550/metrics | grep -q "go_goroutines" || exit 1

EXPOSE 9550

ENTRYPOINT ["/app/3xui-exporter_linux_amd64"]
