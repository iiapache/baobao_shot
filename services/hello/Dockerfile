# hello 演示服务 — Go 实现，供 CI / 网关 / 本地验证
ARG GO_VERSION=1.22
FROM golang:${GO_VERSION}-alpine AS builder

ARG SERVICE_NAME=server
ARG CGO_ENABLED=0

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=${CGO_ENABLED} GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/${SERVICE_NAME} ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot

ARG HTTP_PORT=8080

COPY --from=builder /out/server /app/service

USER nonroot:nonroot
EXPOSE ${HTTP_PORT}

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/service", "healthcheck"]

ENTRYPOINT ["/app/service"]
