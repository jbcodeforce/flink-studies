# Confluent Cloud — Self Joins Music Streaming

## Goal

Demonstrate generic event envelopes (subscription + deviceSwap), reference-table joins to resolve `party_id`, expansion to all accounts in a party, and a self-join on `event_stream` to attach sibling subscription details.

## Deploy order

```sh
make sync
make deploy-ddl
make deploy-data      # optional seed via INSERT statements
make deploy-pipeline  # dml.enrich_party_subscriptions.sql
```

## Produce test data (alternative to INSERT)

Avro schemas in [../python/schemas/](../python/schemas/) match the DDL (`avro-registry` key + value subjects).

```sh
cd ../python
uv sync
source ../../set_env.sh
uv run producers/produce_party_info.py
uv run producers/produce_event_stream.py
```

Keys produced:
- **party_info** — Avro key `{party_id, account_number}`; value is the full row
- **event_stream** — Avro key `{event_id}`; value includes `context_data` and `event_details` (`ARRAY<STRING>`)

## Test queries

```sql
-- Raw envelope stream
SELECT * FROM event_stream LIMIT 10;

-- Reference table (upsert, infinite retention)
SELECT * FROM party_info ORDER BY party_id, account_number;

-- Enriched output: deviceSwap on acc-002 with sibling subscription on acc-001
SELECT
   *
FROM enriched_party_events
WHERE event_type = 'deviceSwap'
ORDER BY event_time;

```

## Undeploy

```sh
make undeploy-pipeline
make drop-tables
```

See [../README.md](../README.md) for domain context and architecture notes.
