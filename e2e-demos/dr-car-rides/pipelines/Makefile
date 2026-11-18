# DR Car Rides — dbt-confluent deploy for one site at a time.
#
#   make debug   SITE=primary      # connection check
#   make compile SITE=dr           # render SQL, no cloud call
#   make deploy  SITE=primary      # dbt run (creates tables, starts INSERT statements)
#   make undeploy SITE=dr          # stop + delete the Flink statements (not done by dbt)
#   make drop-tables SITE=dr       # drop rides_clean / driver_stats (after undeploy)
#
# SITE selects the env vars exported by ../scripts/export-env.sh. Only one site is
# exported per make invocation, so primary and DR values are never mixed.
# rides_raw is NOT built here: Terraform owns it (IaC/00-primary-flink), dbt only reads it.
#
# Requires ../scripts/iac-outputs.json (scripts/generate-outputs.sh) and the dbt
# profile `j9r` in ~/.dbt/profiles.yml reading ORGANIZATION_ID, ENVIRONMENT_ID,
# FLINK_API_KEY/SECRET, FLINK_COMPUTE_POOL_ID, FLINK_DATABASE_NAME, CLOUD_REGION.

SHELL := /bin/bash
SITE ?= primary
# Project-local profile (profiles.yml, no secrets): targets primary and dr = $(SITE).
# SITE=dr needs the private Flink endpoint, so it only works ON THE BASTION (see failover-hard.sh).
DBT_ARGS := --profiles-dir $(CURDIR) --target $(SITE)
EXPORT_ENV := $(abspath ../scripts/export-env.sh)
TOOLS := $(abspath ../../../code/flink-sql/tools)
TEARDOWN_DIR := $(abspath teardown)

.PHONY: sync debug compile deploy deploy-full undeploy drop-tables teardown check-site

check-site:
	@if [[ "$(SITE)" != "primary" && "$(SITE)" != "dr" ]]; then \
	  echo "SITE must be primary or dr (got: $(SITE))" >&2; exit 1; fi

# Run a command with ONLY this site's variables exported. For SITE=dr, first check that the
# private Flink endpoint resolves (it does only on the bastion, not on the laptop).
# $(1) = command
CHECK_DNS := $(abspath ../scripts/require-private-dns.sh)
define with_site
	@source "$(EXPORT_ENV)" "$(SITE)" >/dev/null && $(if $(filter dr,$(SITE)),"$(CHECK_DNS)" &&) $(1)
endef

sync:
	uv sync

debug: check-site
	$(call with_site,uv run dbt debug $(DBT_ARGS))

compile: check-site
	$(call with_site,uv run dbt compile $(DBT_ARGS))

# dbt does not recreate an existing relation; re-running is safe for DDL, but a changed
# query needs undeploy + drop-tables (or deploy-full) first. See docs/design-decisions.md.
deploy: check-site
	$(call with_site,uv run dbt run $(DBT_ARGS))

deploy-full: check-site
	$(call with_site,uv run dbt run --full-refresh $(DBT_ARGS))

# dbt cannot stop statements: use the shared tools with the teardown manifest.
undeploy: check-site
	$(call with_site,$(MAKE) -C "$(TOOLS)" undeploy SQL_DIR="$(TEARDOWN_DIR)")

drop-tables: check-site
	$(call with_site,$(MAKE) -C "$(TOOLS)" drop-tables SQL_DIR="$(TEARDOWN_DIR)")

teardown: undeploy drop-tables
