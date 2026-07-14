# Delegates to code/flink-sql/tools/Makefile (manifest: deploy_manifest.json in this folder).

TOOLS := $(abspath ../../tools)
SQL_DIR := $(abspath .)

.PHONY: sync deploy undeploy drop-tables deploy-ddl deploy-pipeline deploy-data \
	undeploy-pipeline undeploy-data

sync deploy undeploy drop-tables deploy-ddl deploy-pipeline deploy-data \
undeploy-pipeline undeploy-data:
	$(MAKE) -C $(TOOLS) SQL_DIR=$(SQL_DIR) $@
