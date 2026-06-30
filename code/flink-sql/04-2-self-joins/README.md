# Self join and join reference table

The domain is a music streaming model, where subscriptions are done by a party with one to many account numbers. The relation party-id -> account-id is maintained in an external system but records are published to a compact topic with key: <party-id, account-id>.

The streaming includes two type of payload: It is encapsulated into eventDetails as array of json objects and contextData to reference what payload type is used. The payload is a subscription event or a deviceSwap event (user can use the same plan on another event).

The goals of the demonstration are:

1. Be able to support generic event envelop with two types of event
1. Be able to extract the account_number of the different payload and joins to get the party_id of this account number
1. extract all accounts for the party_id retrieved
1. self join from the eventStream table to get other deviceSwap information.
1. eventStream events are kept for 6 days.
1. partyInfo are kept forever, but are seen in Flink as upsert table.

## Layout

| Path | Purpose |
| --- | --- |
| [cc/](cc/) | Confluent Cloud Flink SQL (DDL, DML, deploy manifest) |
| [python/](python/) | Kafka producers for `party_info` and `event_stream` topics |

## Quick start (Confluent Cloud)

```sh
cd cc
make sync
make deploy-ddl
make deploy-pipeline
```

Seed data via SQL (`make deploy-data`) or Python producers — see [cc/README.md](cc/README.md).

## Pipeline overview

![](./docs/pipe.drawio.png)

- **event_stream** — append log with 6-day Kafka retention; `STATE_TTL` on stream aliases in the join
- **party_info** — compact upsert reference with infinite retention
- **enriched_party_events** — sink showing party expansion and sibling subscription lookup

## Generate more events with Kafka Producer

```sh
cd python
uv sync
uv run python producers/produce_party_info.py
uv run python producers/produce_event_stream.py
```