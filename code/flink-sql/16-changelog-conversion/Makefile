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
