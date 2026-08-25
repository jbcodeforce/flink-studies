.PHONY: seed infer-seeds debug produce produce-dry

# Produce the Airbnb CSVs (../airbnb/data) to Kafka.
# Expects KAFKA_BOOTSTRAP_SERVERS / CONFLUENT_API_KEY / CONFLUENT_API_SECRET.
# Topics and their Schema Registry schemas are created automatically if missing.
# Extra flags pass through, e.g.: make produce ARGS="--limit 100 --schema-registry"
produce:
	uv run python scripts/produce_to_kafka.py $(ARGS)

produce-dry:
	uv run python scripts/produce_to_kafka.py --dry-run $(ARGS)

DBT := uv run dbt

infer-seeds:
	uv run python scripts/infer_seed_schema.py --write

seed: infer-seeds
	$(DBT) seed --target dev

debug:
	$(DBT) debug --target dev

