# Shared Flink SQL deploy tools (confluent-sql REST API).
# Install: uv sync
# Usage: make deploy SQL_DIR=../00-basic-sql/cc-flink

PYTHON ?= python3
SQL_DIR ?= ../11-puzzles/cart_update

.PHONY: sync deploy undeploy drop-tables deploy-% undeploy-%

sync:
	uv sync

deploy:
	$(PYTHON) -m cc_deploy.deploy_flink_statements --sql-dir $(SQL_DIR) deploy --group all

undeploy:
	$(PYTHON) -m cc_deploy.deploy_flink_statements --sql-dir $(SQL_DIR) undeploy --group all --no-drop-tables

drop-tables:
	$(PYTHON) -m cc_deploy.deploy_flink_statements --sql-dir $(SQL_DIR) drop-tables

deploy-%:
	$(PYTHON) -m cc_deploy.deploy_flink_statements --sql-dir $(SQL_DIR) deploy --group $*

undeploy-%:
	$(PYTHON) -m cc_deploy.deploy_flink_statements --sql-dir $(SQL_DIR) undeploy --group $*
