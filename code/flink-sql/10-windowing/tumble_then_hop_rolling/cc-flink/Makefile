# dbt project for Confluent Cloud Flink (profile: cc_flink in ~/.dbt/profiles.yml).
# Uses code/flink-sql/.venv (dbt-confluent) via uv — not the global dbt CLI.

TARGET ?= dev

.PHONY: dbt-debug dbt-seed dbt-run dbt-compile

dbt-debug:
	uv run dbt debug --target $(TARGET)

dbt-seed:
	uv run dbt seed --target $(TARGET)

dbt-run:
	uv run dbt run --target $(TARGET)

dbt-compile:
	uv run dbt compile --target $(TARGET)
