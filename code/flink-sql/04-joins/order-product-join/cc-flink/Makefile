TOOLS := $(abspath ../../../tools)
SQL_DIR := $(abspath .)

sync deploy undeploy drop-tables deploy-ddl deploy-pipeline deploy-data \
undeploy-pipeline undeploy-data deploy-ddls deploy-op_join_1 deploy-op_left_join deploy-ddls_wm:
	$(MAKE) -C $(TOOLS) SQL_DIR=$(SQL_DIR) $@
