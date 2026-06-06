# protobuf 工具链（委托 contracts/protobuf）

契约源文件已迁移至 [`contracts/protobuf/`](../../contracts/protobuf/)。本目录保留 Makefile 以兼容 `services/*/Makefile` 中的 `PROTO_DIR`。

## 用法

```bash
cd tools/protobuf
make proto    # 生成 Go 代码到 contracts/protobuf/gen/
make lint     # buf lint
make breaking # breaking change 检查
```

## 安装 buf

```bash
brew install bufbuild/buf/buf
```

完整说明见 [contracts/README.md](../../contracts/README.md)。
