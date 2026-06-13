# 00-basic-sql Confluent Cloud demo – deploy via shared flink-sql/tools (confluent-sql REST API).
# Manifest: cc-flink/deploy_manifest.json
# Run `make sync` once before first deploy.

TOOLS := $(abspath ../tools)
DEMO  := $(abspath cc-flink)

.PHONY: sync deploy undeploy drop-tables deploy-ddl deploy-pipeline deploy-data \
	undeploy-pipeline undeploy-data deploy-customers deploy-employees \
	undeploy-customers undeploy-employees

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

deploy-data:
	$(MAKE) -C $(TOOLS) deploy-data SQL_DIR=$(DEMO)

undeploy-pipeline:
	$(MAKE) -C $(TOOLS) undeploy-pipeline SQL_DIR=$(DEMO)

undeploy-data:
	$(MAKE) -C $(TOOLS) undeploy-data SQL_DIR=$(DEMO)

deploy-customers:
	$(MAKE) -C $(TOOLS) deploy-customers SQL_DIR=$(DEMO)

deploy-employees:
	$(MAKE) -C $(TOOLS) deploy-employees SQL_DIR=$(DEMO)

undeploy-customers:
	$(MAKE) -C $(TOOLS) undeploy-customers SQL_DIR=$(DEMO)

undeploy-employees:
	$(MAKE) -C $(TOOLS) undeploy-employees SQL_DIR=$(DEMO)
