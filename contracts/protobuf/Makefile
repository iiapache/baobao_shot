.PHONY: proto lint breaking clean help

BUF ?= buf
OUT_DIR ?= gen

help:
	@echo "contracts/protobuf — gRPC 契约工具链"
	@echo ""
	@echo "  make proto     生成 Go gRPC 代码到 $(OUT_DIR)/"
	@echo "  make lint      buf lint"
	@echo "  make breaking  与 main 分支对比 breaking change"
	@echo "  make clean     删除生成物"

proto:
	@command -v $(BUF) >/dev/null 2>&1 || { echo "error: buf 未安装，见 https://buf.build/docs/installation/"; exit 1; }
	$(BUF) dep update 2>/dev/null || true
	$(BUF) generate
	@echo ">>> 生成完成: $(OUT_DIR)/"

lint:
	$(BUF) lint

breaking:
	$(BUF) breaking --against '../../.git#branch=main'

clean:
	rm -rf $(OUT_DIR)
