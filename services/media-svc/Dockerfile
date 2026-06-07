# media-svc Dockerfile — based on infra/ci/Dockerfile.template
ARG GO_VERSION=1.24
FROM golang:${GO_VERSION}-alpine AS builder

ARG SERVICE_NAME=media-svc
ARG CGO_ENABLED=0

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=${CGO_ENABLED} GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/${SERVICE_NAME} ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot

ARG SERVICE_NAME=media-svc
ARG HTTP_PORT=8003

COPY --from=builder /out/${SERVICE_NAME} /app/service

USER nonroot:nonroot
EXPOSE ${HTTP_PORT}

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/service", "healthcheck"]

ENTRYPOINT ["/app/service"]
