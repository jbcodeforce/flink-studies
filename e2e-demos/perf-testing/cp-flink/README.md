# Perf testing — Confluent Platform / CMF (Kubernetes)

## Goal

Run the perf passthrough job on **Confluent Manager for Flink** using `confluentinc/cp-flink:2.2.0-cp2-java21`, aligned with [deployment/k8s/cmf](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s/cmf).

## Prerequisites

- CMF deployed (`make deploy` in `deployment/k8s/cmf`)
- Confluent Kafka (CFK) in cluster
- Docker, Maven, `kubectl`

## Build and deploy

```bash
cd e2e-demos/perf-testing
./scripts/build-all.sh
./cp-flink/build.sh
./scripts/deploy-k8s-cp.sh
```

Update Kafka bootstrap in [k8s/flink-application.yaml](k8s/flink-application.yaml) to match your namespace (default `kafka.confluent.svc.cluster.local:9092`).

## Topics and load

```bash
./scripts/create-topics.sh          # CP KafkaTopic CRs in namespace kafka
kubectl apply -f producer/k8s/      # producer Job
```

Or use [run-benchmark-k8s.sh](../scripts/run-benchmark-k8s.sh).

## Tuning lab

For TM memory / checkpoint exercises, you can still use [dedup-demo FlinkApplication](https://github.com/jbcodeforce/flink-studies/tree/master/e2e-demos/dedup-demo/cp-flink/flink-table-api/k8s/flink-application.yaml) as the stateful baseline and this demo only for load ([k8s tuning §10](https://jbcodeforce.github.io/flink-studies/cookbook/k8s_tuning/#10--lab-overview--tune-and-observe-a-flinkapplication)).
