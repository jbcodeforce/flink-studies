.PHONY: debug run run-full compile

TARGET ?= dev
DBT := cd .. && uv run dbt 

debug:
	$(DBT) debug --project-dir flink_workshop --target $(TARGET) --profiles-dir $(HOME)/.dbt

run:
	$(DBT) run  --project-dir flink_workshop --select tag:lab01 --target $(TARGET) --profiles-dir $(HOME)/.dbt

run-full:
	$(DBT) run  --project-dir flink_workshop --select tag:lab01 --full-refresh --target $(TARGET) --profiles-dir $(HOME)/.dbt

compile:
	$(DBT) compile  --project-dir flink_workshop --target $(TARGET) --profiles-dir $(HOME)/.dbt
