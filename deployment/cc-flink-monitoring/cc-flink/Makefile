# Monitoring demo – deploy via shared flink-sql/tools.
# Run `make sync` once under ../../../code/flink-sql/tools.

TOOLS := $(abspath ../../../code/flink-sql/tools)
DEMO  := $(abspath .)
PYTHON ?= python3

.PHONY: sync deploy undeploy drop-tables deploy-ddl deploy-data deploy-pipeline undeploy-pipeline produce-transactions

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

deploy-data:
	$(MAKE) -C $(TOOLS) deploy-data SQL_DIR=$(DEMO)

deploy-pipeline:
	$(MAKE) -C $(TOOLS) deploy-pipeline SQL_DIR=$(DEMO)

undeploy-pipeline:
	$(MAKE) -C $(TOOLS) undeploy-pipeline SQL_DIR=$(DEMO)

produce-transactions:
	$(PYTHON) "$(DEMO)/producer/transactions_producer.py"
