# Tumble-then-hop rolling features – deploy via shared flink-sql/tools.
# Run `make sync` once under ../../tools.

TOOLS := $(abspath ../../tools)
DEMO  := $(abspath .)

.PHONY: sync deploy undeploy drop-tables deploy-ddl deploy-pipeline undeploy-pipeline

sync:
	$(MAKE) -C $(TOOLS) sync

deploy:
	$(MAKE) -C $(TOOLS) deploy SQL_DIR=$(DEMO)

undeploy:
	$(MAKE) -C $(TOOLS) undeploy SQL_DIR=$(DEMO)

drop-tables:
	$(MAKE) -C $(TOOLS) drop-tables SQL_DIR=$(DEMO)

deploy-ddl:
	$(MAKE) -C $(TOOLS) deploy-ddl SQL_DIR=$(DEMO)

deploy-pipeline:
	$(MAKE) -C $(TOOLS) deploy-pipeline SQL_DIR=$(DEMO)

undeploy-pipeline:
	$(MAKE) -C $(TOOLS) undeploy-pipeline SQL_DIR=$(DEMO)
