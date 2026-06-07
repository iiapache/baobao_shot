SERVICE_NAME ?= credit-sub-ad-svc
GO ?= go
PROTO_DIR ?= ../../tools/protobuf

.PHONY: build test run proto tidy clean docker migrate-up migrate-down

build:
	$(GO) build -o bin/$(SERVICE_NAME) ./cmd/server

test:
	$(GO) test ./...

run:
	SERVICE_NAME=$(SERVICE_NAME) HTTP_PORT=$(HTTP_PORT) GRPC_PORT=$(GRPC_PORT) $(GO) run ./cmd/server

proto:
	$(MAKE) -C $(PROTO_DIR) proto OUT_DIR=$(CURDIR)/internal/gen

tidy:
	$(GO) mod tidy

clean:
	rm -rf bin/ internal/gen/

docker:
	docker build -t baobao/$(SERVICE_NAME):local .

migrate-up:
	@test -n "$(DATABASE_URL)" || (echo "DATABASE_URL required" && exit 1)
	psql "$(DATABASE_URL)" -f migrations/001_initial_schema.up.sql

migrate-down:
	@test -n "$(DATABASE_URL)" || (echo "DATABASE_URL required" && exit 1)
	psql "$(DATABASE_URL)" -f migrations/001_initial_schema.down.sql
