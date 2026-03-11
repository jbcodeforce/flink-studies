# Savepoint demo – Confluent Platform (cp-flink)

## Goal

Stop and restart a **stateful** Flink job using **savepoints**: trigger a savepoint, stop the job, then start it from that savepoint so the running sum continues correctly. This illustrates the same workflow used for upgrades and for [backup/restore and active-passive DR](../../docs/cookbook/cluster_mgt.md#31-backuprestore-of-state-backend).

## Status

**Ready.** Confluent Platform on Minikube; Python event generator and Avro schema at demo root. Flink SQL runs via a SQL runner image (see [Dockerfile](../Dockerfile)); ensure `sql-scripts/` exists and matches the job (source table → aggregation).

## Implementation approach

- **No Terraform.** Kubernetes manifests and config at demo root: [config.yaml](../config.yaml), [orders-topic.yaml](../orders-topic.yaml), [event_definitions.py](../event_definitions.py), [events_generator.py](../events_generator.py), [avro/](../avro/).
- **Flink:** CP Flink image + SQL runner (Dockerfile at root). Flink job is a stateful aggregation (sum of `value`); checkpoint/savepoint dir must be durable storage (e.g. S3 or PVC) for production; for Minikube, local or ephemeral storage can be used for demo.
- **Savepoint lifecycle:** Trigger and restore via [CMF Savepoint API](https://docs.confluent.io/platform/current/flink/jobs/savepoints.html) (or Confluent CLI / Flink Kubernetes operator), as in the [cookbook procedure](../../docs/cookbook/cluster_mgt.md#procedure).

## How to run

Run from **demo root** (`e2e-demos/savepoint-demo/`). Prerequisites: Minikube (or another K8s cluster), Confluent Platform operator and Flink operator installed (see [deployment/k8s/README.md](../../deployment/k8s/README.md)).

### Phase 1 – Infrastructure and topic

1. Start Minikube and install Confluent Platform operator and Flink operator (see [deployment/k8s README and Makefile](../../deployment/k8s/README.md)).
2. Create Kafka cluster and Schema Registry (same repo).
3. Create the `orders` topic:
   ```sh
   kubectl apply -f orders-topic.yaml
   ```
4. Port-forward Schema Registry and Kafka broker (separate terminals):
   ```sh
   kubectl port-forward schemaregistry-0 8081:8081
   kubectl port-forward kafka-0 9092:9092
   ```
5. Upload Avro schema to Schema Registry:
   ```sh
   python event_definitions.py
   ```

### Phase 2 – Data and Flink job

6. Run the event generator (e.g. 1000 records; each has `value=2`, so total sum = 2000):
   ```sh
   pip install -r requirements.txt
   python events_generator.py 1000
   ```
7. Deploy and start the Flink application (SQL runner or FlinkApplication CRD) so it reads from `orders` and computes the running sum. Ensure the job has checkpointing enabled and a savepoint/checkpoint directory configured.

### Phase 3 – Savepoint: trigger, stop, restore

8. **Trigger a savepoint** (CMF):
    - Applications: `POST /cmf/api/v1/environments/{env}/applications/{appName}/savepoints` with optional body `spec.path`, `spec.formatType` (e.g. `CANONICAL`).
    - Poll until `status.state` is `COMPLETED`; note `status.path`.
9. **Stop the job** (suspend or cancel via CMF/CLI/operator).
10. **Start from savepoint:** Start the same application with `startFromSavepoint` set to the savepoint path or CMF savepoint name/UID (e.g. `POST .../applications/{appName}/start?startFromSavepointUid={uid}`).
11. **Validate:** Produce more events and confirm the sum continues from the previous value (no reset).

For full API details and rollback/gotchas, see the cookbook [Backup/restore of state backend](../../docs/cookbook/cluster_mgt.md#31-backuprestore-of-state-backend).
