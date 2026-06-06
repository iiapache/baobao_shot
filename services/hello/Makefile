SERVICE_NAME ?= hello
GO ?= go
PROTO_DIR ?= ../../tools/protobuf

.PHONY: build test run proto tidy clean docker

build:
	$(GO) build -o bin/$(SERVICE_NAME) ./cmd/server

test:
	$(GO) test ./...

run:
	SERVICE_NAME=$(SERVICE_NAME) $(GO) run ./cmd/server

proto:
	$(MAKE) -C $(PROTO_DIR) proto OUT_DIR=$(CURDIR)/internal/gen

tidy:
	$(GO) mod tidy

clean:
	rm -rf bin/ internal/gen/

docker:
	docker build -t baobao/$(SERVICE_NAME):local .
