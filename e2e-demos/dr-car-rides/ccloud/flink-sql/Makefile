# DR Car Rides Confluent Cloud – deploy via shared flink-sql/tools (confluent-sql REST API).
# Manifest: deploy_manifest.json in this directory.
# Run `make sync` once before first deploy.
# Requires ../scripts/iac-outputs.json (terraform output -json from IaC).
#
# Site selection (default: primary):
#   make deploy
#   make deploy SITE=dr
#   make deploy SITE=secondary   # alias for dr
#   make deploy-both             # primary then dr (active/active prep)
#   make deploy-ddl SITE=dr
# Keep ORG_ID / FLINK_ORG_ID in the caller shell (not in IaC outputs).

SHELL := /bin/bash
TOOLS := $(abspath ../../../../code/flink-sql/tools)
DEMO  := $(abspath .)
EXPORT_ENV := $(abspath ../scripts/export-env.sh)

# primary | dr | secondary (secondary → dr)
SITE ?= primary

.PHONY: sync deploy undeploy drop-tables deploy-% undeploy-% deploy-both undeploy-both

# Map SITE alias to export-env.sh argument
resolve_site = $(if $(filter secondary,$(SITE)),dr,$(SITE))

define run_with_site_env
	@site="$(resolve_site)"; \
	if [[ "$$site" != "primary" && "$$site" != "dr" ]]; then \
	  echo "SITE must be primary, dr, or secondary (got: $(SITE))" >&2; exit 1; \
	fi; \
	source "$(EXPORT_ENV)" "$$site" && \
	$(MAKE) -C "$(TOOLS)" $(1) SQL_DIR="$(DEMO)"
endef

sync:
	$(MAKE) -C $(TOOLS) sync

deploy:
	$(call run_with_site_env,deploy)

undeploy:
	$(call run_with_site_env,undeploy)

drop-tables:
	$(call run_with_site_env,drop-tables)

deploy-%:
	$(call run_with_site_env,deploy-$*)

undeploy-%:
	$(call run_with_site_env,undeploy-$*)

# Active/active: deploy (or undeploy) the same statements on both sites
deploy-both:
	$(MAKE) deploy SITE=primary
	$(MAKE) deploy SITE=dr

undeploy-both:
	$(MAKE) undeploy SITE=dr
	$(MAKE) undeploy SITE=primary
