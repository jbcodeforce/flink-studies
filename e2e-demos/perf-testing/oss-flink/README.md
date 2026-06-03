# Perf testing — OSS Flink (Kubernetes)

## Goal

Run the perf passthrough job on Apache Flink **2.2.0** via the Flink Kubernetes Operator (FKO).

## Prerequisites

- FKO installed; namespace `flink` and `ServiceAccount` `flink` (see [deployment/k8s/flink-oss](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s/flink-oss))
- Kafka reachable from the cluster (e.g. [deployment/k8s/cfk](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s/cfk))
- Docker, Maven, `kubectl`

## Build and deploy

```bash
cd e2e-demos/perf-testing
./scripts/build-all.sh
./oss-flink/flink-sql-executor/build.sh
# load image into kind/minikube if needed
./scripts/deploy-k8s-oss.sh
```

Adjust `BOOTSTRAP_SERVERS` in [k8s/flink-deployment.yaml](k8s/flink-deployment.yaml) if your Kafka service DNS differs.

## Observe

```bash
kubectl get flinkdeployment -n flink
kubectl port-forward svc/perf-sql-executor-rest 8081:8081 -n flink
```

Then run the shared producer and validate from the demo root ([../README.md](../README.md) Phase 2).

## Datastream variant

Build a second image with `perf-datastream-job-0.1.0.jar` and set `entryClass` to `io.github.flinkstudies.perf.datastream.PerfDataStreamJob` (same env vars).
