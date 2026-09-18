TOOLS := $(abspath ../../../tools)
SQL_DIR := $(abspath .)

sync deploy undeploy drop-tables deploy-ddl deploy-pipeline deploy-data \
undeploy-pipeline undeploy-data:
	$(MAKE) -C $(TOOLS) SQL_DIR=$(SQL_DIR) $@
