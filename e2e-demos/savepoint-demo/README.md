# Savepoint demo – Backup and restore of Flink state

## Business goal

Demonstrate **savepoint-based backup and restore** of a stateful Flink application: stop the job with a savepoint, then restart from that savepoint so processing continues exactly where it left off. This is the same workflow used for planned upgrades, rescaling, and for **disaster recovery (DR)** when restarting Flink in a secondary site from a savepoint.

**Relation to DR:** The procedure (trigger savepoint → stop job → start from savepoint) aligns with the cookbook [Backup/restore of state backend](../../docs/cookbook/cluster_mgt.md#31-backuprestore-of-state-backend) and supports **active-passive** DR patterns where Flink is started in the DR region from a savepoint. See also [Active-active / active-passive patterns](../../docs/cookbook/cluster_mgt.md#32-active-active--active-passive-patterns).

## Use case

- **Planned stop/restart:** Upgrade Flink or change job graph without losing state.
- **DR failover:** Restore a stateful job in another region/site from a savepoint (with Kafka and Schema Registry DR already in place).

## High-level architecture

- A **producer** (Python) writes simple order-like records (`id`, `ts_ms`, `value=2`) to a Kafka topic (`orders`), with Avro schema in Schema Registry.
- A **Flink SQL** job reads from that topic and maintains a **running sum** of `value`. After `n` records, the sum equals `n * 2`; the job is stateful.
- You **trigger a savepoint** (via CMF API or operator), **stop** the job, then **start** the same job **from the savepoint**. Processing resumes from the saved state with no gap or duplicate semantics when using the same checkpoint/savepoint semantics.

## Supported deployments

| Deployment   | Folder        | Description                                      |
|-------------|----------------|--------------------------------------------------|
| **CP Flink**| [cp-flink/](cp-flink/) | Confluent Platform Flink on Kubernetes (CMF). Minikube, Kafka, Schema Registry, Flink SQL runner; trigger savepoint via CMF API or CLI, restart from savepoint. |

Only **cp-flink** is implemented. There is no `cccloud/` or `oss-flink/` for this demo.

## Shared assets (demo root)

Used by the cp-flink deployment:

- **Topic / schema:** `orders-topic.yaml`, `avro/orders-value.avsc`, `event_definitions.py` (registers Avro schema).
- **Producer:** `events_generator.py`, `app_config.py`, `config.yaml`, `requirements.txt`.
- **Flink image:** `Dockerfile` (CP Flink image + SQL runner; expects `sql-scripts/` for Flink SQL).

For **how to run** (prerequisites, port-forward, deploy topic, upload schema, run producer, deploy Flink job, trigger savepoint, restart from savepoint), see **[cp-flink/README.md](cp-flink/README.md)**.