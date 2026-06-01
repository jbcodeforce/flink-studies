# Shared Flink SQL deploy tools (confluent-sql REST API).
# Install: uv sync
# Usage: make deploy SQL_DIR=../00-basic-sql/cc-flink

PYTHON ?= python3
SQL_DIR ?= ../11-puzzles/cart_update

.PHONY: sync deploy undeploy drop-tables deploy-% undeploy-%

sync:
	uv sync

deploy:
	$(PYTHON) deploy_flink_statements.py --sql-dir $(SQL_DIR) deploy --group all

undeploy:
	$(PYTHON) deploy_flink_statements.py --sql-dir $(SQL_DIR) undeploy --group all

drop-tables:
	$(PYTHON) deploy_flink_statements.py --sql-dir $(SQL_DIR) drop-tables

deploy-%:
	$(PYTHON) deploy_flink_statements.py --sql-dir $(SQL_DIR) deploy --group $*

undeploy-%:
	$(PYTHON) deploy_flink_statements.py --sql-dir $(SQL_DIR) undeploy --group $*
