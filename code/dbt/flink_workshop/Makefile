.PHONY: debug run run-full compile run-crm run-crm-full

TARGET ?= dev
DBT := cd .. && uv run dbt

debug:
	$(DBT) debug --project-dir flink_workshop --target $(TARGET) --profiles-dir $(HOME)/.dbt

# Deploy full CRM data product (sources, dimensions, joins, metrics).
run:
	$(DBT) run --project-dir flink_workshop --select tag:crm --target $(TARGET) --profiles-dir $(HOME)/.dbt

run-full:
	$(DBT) run --project-dir flink_workshop --select tag:crm --full-refresh --target $(TARGET) --profiles-dir $(HOME)/.dbt

# Alias targets
run-crm: run
run-crm-full: run-full

compile:
	$(DBT) compile --project-dir flink_workshop --target $(TARGET) --profiles-dir $(HOME)/.dbt
