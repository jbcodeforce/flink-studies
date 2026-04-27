# Replay and reprocessing (Kafka + Flink)

The [README](README.md) anomaly lab uses the Faker connector. That is ideal for a self-contained SQL workspace, but it is not a replayable log: each run generates new random data.

## Why replay matters

When a probabilistic model (or an LLM downstream) behaves unexpectedly, you want to:

* Reprocess the same input sequence and compare outputs.
* Correlate a customer report with a time range of facts you can reconstruct.

Apache Kafka (and compatible logs) keep ordered, durable records with offsets. Flink jobs read those topics as sources; checkpoints bound at-least-once or exactly-once behavior depending on your configuration.

## Minimal replay pattern

1. Replace the Faker `reefer_telemetries` table with a Kafka table definition (same schema) fed by a test producer or a CDC connector—or keep Faker for demos and use Kafka only for replay exercises.
2. Produce a fixed batch of test messages to a topic (or capture production traffic to a sandbox topic with governance approval).
3. Run the Flink job and note sink output (for example print, anomaly topic, or a file sink in a dev cluster only).
4. Stop the job.
5. Re-run with one of:
   * New Flink savepoint semantics (if you use savepoints in your deployment), or
   * New `group.id` / consumer group so the job reads from earliest offset again (dev-only; understand implications for production), or
   * offset reset policy on a dedicated dev topic (never blindly on shared production topics).

6. Compare outputs between runs for the same offset range—that is the “replay the same hour” debug loop the book chapter refers to.

## Faker vs Kafka (quick comparison)

| Source | Good for | Replay? |
| --- | --- | --- |
| Faker | Quick syntax demos in a SQL workspace | No (nondeterministic) |
| Kafka | Integration tests, reprocessing, forensics | Yes (retention bound) |

## Related reading

* [agentic_flink.md](../../../docs/architecture/agentic_flink.md) – Event-driven agents and Kafka replay in context.
* Confluent: consumer offsets and Flink Kafka connector options in the version of the docs you run in production.
