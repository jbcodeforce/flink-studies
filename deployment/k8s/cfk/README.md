# Confluent Platform on Kubernetes Deployment Guide

This guide provides the shell commands equivalent to the Makefile targets for deploying Confluent Platform on Kubernetes.

## Available Commands

Using the Makefile the commands can be summarized as:

```sh
make deploy
make status
make undeploy
```

### Deploy Full Platform
```bash
# Equivalent to 'make deploy'
# Creates namespace, updates helm repo, deploys CFK and CP cluster
kubectl create ns confluent  # if not exists
helm repo add confluentinc https://packages.confluent.io/helm
helm repo update
helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes \
    --set namespaced=false \
    --set kRaftEnabled=true \
    --set namespaceList="{confluent}" \
    --set enableCMFDay2Ops=true \
    -n confluent
kubectl apply -f basic-kraft-cluster.yaml -n confluent
```

### Switch to Confluent Namespace
```bash
# Equivalent to 'make use_confluent_ns'
kubectl config set-context --current --namespace=confluent
```

### Check Deployment Status
```bash
# Equivalent to 'make status'
kubectl config set-context --current --namespace=confluent
kubectl get pods -n confluent
kubectl describe KRaftController kraftcontroller -n confluent
kubectl describe Kafka kafka -n confluent
kubectl describe ControlCenter controlcenter-ng -n confluent
kubectl describe SchemaRegistry schemaregistry -n confluent
```

### Port Forward Control Center
```bash
# Equivalent to 'make port_forward_cp_console'
kubectl -n confluent port-forward svc/controlcenter-ng 9021:9021
```

### Undeploy Platform
```bash
# Equivalent to 'make undeploy'
kubectl delete -f basic-kraft-cluster.yaml -n confluent
```

### Complete Cleanup
```bash
# Equivalent to uninstalling everything
kubectl delete -f basic-kraft-cluster.yaml -n confluent
helm uninstall confluent-operator -n confluent
kubectl delete ns confluent  # Optional: only if you want to remove the namespace
```

Note: Replace `confluent` with your desired namespace if you've configured a different one.