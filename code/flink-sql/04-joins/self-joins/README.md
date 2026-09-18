# Self Join and Join Reference Table

The domain is a music streaming model where subscriptions are done by a party with one-to-many account numbers. The relation `party_id → account_id` is maintained in an external system and published to a compact topic.

The streaming includes two payload types encapsulated in `eventDetails` (array of JSON objects) with `contextData` indicating the type: a **subscription** event or a **deviceSwap** event.

## Goals

1. Support a generic event envelope with two event types.
2. Extract the `account_number` from each payload and join to resolve `party_id`.
3. Extract all accounts for the resolved `party_id`.
4. Self-join `event_stream` to attach sibling `deviceSwap` information.
5. Keep `event_stream` events for 6 days (Kafka retention + `STATE_TTL`).
6. Keep `party_info` forever as an upsert (compact) reference table.

## Layout

| Path | Purpose |
|------|---------|
| [cc-flink/](cc-flink/) | Confluent Cloud Flink SQL (DDL, DML, deploy manifest) |
| [python/](python/) | Kafka producers for `party_info` and `event_stream` topics |
| [docs/](docs/) | Architecture diagram |

## Pipeline Overview

![Pipeline](./docs/pipe.drawio.png)

- **event_stream** — append log with 6-day Kafka retention; `STATE_TTL` on stream aliases in the join
- **party_info** — compact upsert reference with infinite retention
- **enriched_party_events** — sink showing party expansion and sibling subscription lookup

## Quick Start (Confluent Cloud)

```sh
cd cc-flink

make sync
make deploy-ddl
make deploy-pipeline
```

Seed data via SQL (`make deploy-data`) or Python producers:

```sh
cd python
uv sync
uv run python producers/produce_party_info.py
uv run python producers/produce_event_stream.py
```

See [cc-flink/README.md](cc-flink/README.md) for detailed run instructions and query examples.
