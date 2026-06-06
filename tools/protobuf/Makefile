.PHONY: proto lint breaking clean help

PROTO_DIR := $(abspath ../../contracts/protobuf)

help proto lint breaking clean:
	@$(MAKE) -C $(PROTO_DIR) $(filter-out help,$(MAKECMDGOALS))

%:
	@:
