# 04-joins Confluent Cloud demo – deploy via shared flink-sql/tools (confluent-sql REST API).
# Manifest: cc/deploy_manifest.json
# Run `make sync` once before first deploy.

TOOLS := $(abspath ../tools)
DEMO  := $(abspath cc-flink)

.PHONY: sync deploy undeploy drop-tables deploy-% undeploy-%

sync:
	$(MAKE) -C $(TOOLS) sync

deploy:
	$(MAKE) -C $(TOOLS) deploy SQL_DIR=$(DEMO)

undeploy:
	$(MAKE) -C $(TOOLS) undeploy SQL_DIR=$(DEMO)

drop-tables:
	$(MAKE) -C $(TOOLS) drop-tables SQL_DIR=$(DEMO)

deploy-%:
	$(MAKE) -C $(TOOLS) deploy-$* SQL_DIR=$(DEMO)

undeploy-%:
	$(MAKE) -C $(TOOLS) undeploy-$* SQL_DIR=$(DEMO)
