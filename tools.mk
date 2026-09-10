# tools.mk — shared Flink SQL deploy targets for flink-studies
#
# This file delegates all deploy/undeploy/manifest operations to the
# flink-tools-for-agents repository, which owns the Python CLI tools.
#
# Usage (include from any Makefile):
#
#   TOOLS_MK := $(abspath path/to/tools.mk)   # path to this file
#   DEMO     := $(abspath .)                   # SQL directory with deploy_manifest.json
#   include $(TOOLS_MK)
#
# Or use the TOOLS delegate pattern (no include needed):
#
#   TOOLS := $(abspath path/to/code/flink-sql/tools)
#   deploy:
#       $(MAKE) -C $(TOOLS) deploy SQL_DIR=$(DEMO)

# ── Locate flink-tools-for-agents ─────────────────────────────────────────────
# Expected at the same level as flink-studies (sibling directory).
# Override by setting FTA_DIR in the environment or on the make command line.
FTA_DIR ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../flink-tools-for-agents)
FTA_UV  := cd $(FTA_DIR) && uv run

# SQL directory containing deploy_manifest.json (override per demo).
SQL_DIR ?= .

.PHONY: sync manifest deploy undeploy drop-tables groups deploy-% undeploy-%

# ── Setup ──────────────────────────────────────────────────────────────────────
sync:
	cd $(FTA_DIR) && uv sync --extra flink

# ── Manifest ──────────────────────────────────────────────────────────────────
manifest:
	$(FTA_UV) flink-sql-manifest --sql-dir $(SQL_DIR)

manifest-dbt:
	$(FTA_UV) flink-sql-manifest --sql-dir $(SQL_DIR) --dbt

manifest-dry:
	$(FTA_UV) flink-sql-manifest --sql-dir $(SQL_DIR) --dry-run

# ── Deploy / Undeploy ─────────────────────────────────────────────────────────
groups:
	$(FTA_UV) flink-sql-deploy --sql-dir $(SQL_DIR) groups

deploy:
	$(FTA_UV) flink-sql-deploy --sql-dir $(SQL_DIR) deploy

undeploy:
	$(FTA_UV) flink-sql-deploy --sql-dir $(SQL_DIR) undeploy

drop-tables:
	$(FTA_UV) flink-sql-deploy --sql-dir $(SQL_DIR) drop-tables

# Pattern targets: make deploy-sources  make undeploy-facts  etc.
deploy-%:
	$(FTA_UV) flink-sql-deploy --sql-dir $(SQL_DIR) deploy --group $*

undeploy-%:
	$(FTA_UV) flink-sql-deploy --sql-dir $(SQL_DIR) undeploy --group $*

# ── Queries ───────────────────────────────────────────────────────────────────
# make snapshot TABLE=orders
snapshot:
	$(FTA_UV) flink-sql-snapshot --table $(TABLE) --output table

# make stream TABLE=orders MAX_ROWS=50
stream:
	$(FTA_UV) flink-sql-stream --table $(TABLE) --max-rows $(or $(MAX_ROWS),100)
