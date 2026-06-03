.PHONY: seed infer-seeds debug

DBT := cd .. && uv run dbt --project-dir airbnb_streaming --profiles-dir $(HOME)/.dbt

infer-seeds:
	cd .. && uv run python airbnb_streaming/scripts/infer_seed_schema.py --write

seed: infer-seeds
	$(DBT) seed --target dev

debug:
	$(DBT) debug --target dev
