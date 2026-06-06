SERVICE_NAME ?= auth-family-svc
HTTP_PORT ?= 8001
GRPC_PORT ?= 9001
GO ?= go
PROTO_DIR ?= ../../../tools/protobuf

.PHONY: build test run proto tidy clean docker

build:
	$(GO) build -o bin/$(SERVICE_NAME) ./cmd/server

test:
	$(GO) test ./...

run:
	SERVICE_NAME=$(SERVICE_NAME) HTTP_PORT=$(HTTP_PORT) GRPC_PORT=$(GRPC_PORT) MOCK_APPLE_VERIFY=true STORAGE_BACKEND=memory $(GO) run ./cmd/server

proto:
	$(MAKE) -C $(PROTO_DIR) proto OUT_DIR=$(CURDIR)/internal/gen

tidy:
	$(GO) mod tidy

clean:
	rm -rf bin/ internal/gen/

docker:
	docker build -t baobao/$(SERVICE_NAME):local --build-arg SERVICE_NAME=$(SERVICE_NAME) --build-arg HTTP_PORT=$(HTTP_PORT) .
