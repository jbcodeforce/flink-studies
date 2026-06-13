# Delegates to 00-basic-sql/Makefile (manifest: deploy_manifest.json in this folder).

ROOT := $(abspath ..)

.PHONY: sync deploy undeploy drop-tables deploy-ddl deploy-pipeline deploy-data \
	undeploy-pipeline undeploy-data deploy-customers deploy-employees \
	undeploy-customers undeploy-employees

sync deploy undeploy drop-tables deploy-ddl deploy-pipeline deploy-data \
undeploy-pipeline undeploy-data deploy-customers deploy-employees \
undeploy-customers undeploy-employees:
	$(MAKE) -C $(ROOT) $@
