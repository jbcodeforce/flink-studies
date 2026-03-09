# Flink to Feast – Confluent Cloud

## Goal

Push real-time windowed aggregation features to Feast online store; use Confluent Cloud Flink and ML_PREDICT for model inference. See root [../README.md](../README.md) and [../feature_repo/](../feature_repo/).

## Status

Ready. Confluent Cloud Flink, ML_PREDICT, connections, models. Shared: feature_repo, kafka_consumer, model_serving at root.

## Implementation approach

- **No IaC in this folder.** K8s and Docker at root for consumers and model serving.
- **Application logic:** Feature definitions in [../feature_repo/](../feature_repo/); Kafka consumer and model serving at root.

## How to run

From **demo root**: configure feature store, run Kafka consumer to push to online store, deploy model serving. Use CC Flink with ML_PREDICT for inference. See root [README.md](../README.md).
