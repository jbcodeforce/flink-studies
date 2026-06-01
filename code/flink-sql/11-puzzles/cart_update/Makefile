# Cart update puzzle – deploy via shared flink-sql/tools (confluent-sql REST API).
# Run `make sync` once under ../../tools.

TOOLS := $(abspath ../../tools)
DEMO  := $(abspath .)

.PHONY: sync deploy undeploy deploy-ddl deploy-pipeline undeploy-pipeline deploy-data deploy-scenario drop-tables

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

deploy-data:
	$(MAKE) -C $(TOOLS) deploy-data SQL_DIR=$(DEMO)

deploy-scenario:
	$(MAKE) -C $(TOOLS) deploy-scenario SQL_DIR=$(DEMO)
