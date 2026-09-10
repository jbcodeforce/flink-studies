# code/flink-sql/tools/Makefile
#
# Backward-compatible shim — all targets delegate to the root tools.mk,
# which calls the flink-tools-for-agents CLI tools.
#
# Existing demos that do:
#   TOOLS := $(abspath ../../tools)
#   $(MAKE) -C $(TOOLS) deploy SQL_DIR=$(DEMO)
# will continue to work unchanged.
#
# Install tools once:
#   make sync
#
# Deploy a demo:
#   make deploy SQL_DIR=../00-basic-sql/cc-flink

TOOLS_MK := $(abspath ../../../tools.mk)
SQL_DIR  ?= .

.PHONY: sync manifest manifest-dbt manifest-dry groups \
        deploy undeploy drop-tables deploy-% undeploy-% \
        snapshot stream

# Forward every target to tools.mk, passing SQL_DIR through.
sync manifest manifest-dbt manifest-dry groups deploy undeploy drop-tables:
	$(MAKE) -f $(TOOLS_MK) $@ SQL_DIR=$(SQL_DIR)

deploy-%:
	$(MAKE) -f $(TOOLS_MK) deploy-$* SQL_DIR=$(SQL_DIR)

undeploy-%:
	$(MAKE) -f $(TOOLS_MK) undeploy-$* SQL_DIR=$(SQL_DIR)

snapshot:
	$(MAKE) -f $(TOOLS_MK) snapshot TABLE=$(TABLE) SQL_DIR=$(SQL_DIR)

stream:
	$(MAKE) -f $(TOOLS_MK) stream TABLE=$(TABLE) MAX_ROWS=$(MAX_ROWS) SQL_DIR=$(SQL_DIR)
