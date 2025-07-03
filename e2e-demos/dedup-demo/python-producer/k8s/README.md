# Kubernetes Deployment for Dedup Demo

This directory contains Kubernetes manifests for deploying the deduplication demo infrastructure on Confluent Platform.

## Prerequisites

- Kubernetes cluster with Confluent for Kubernetes (CFK) operator installed
- Confluent Platform deployed (see [main deployment guide](../../../deployment/k8s/cp-flink/README.md))

## Resources

### `products-topic.yaml`

Creates the following resources:

1. **KafkaTopic: `products`**
   - 1 partition (updated for single-broker development setup)
   - 7-day retention policy
   - Snappy compression for efficiency
   - References the standard `kafka` cluster

2. **ConfigMap: `dedup-demo-config`**
   - Contains environment variables for the Python producer
   - Uses port 9071 (internal Kafka broker port)
   - Can be mounted in pods that need Kafka configuration

### `producer-pod.yaml`

Creates a pod that runs the Python producer inside the cluster:

1. **Pod: `dedup-demo-producer`**
   - Runs Python producer inside the Kubernetes cluster using a custom Docker image
   - Uses pre-built image with dependencies (confluent-kafka, pydantic)
   - Uses the ConfigMap for Kafka configuration
   - Includes health checks and resource limits

## Deployment

### Option A: Producer Pod Inside Cluster (Recommended)

This option runs the producer inside the Kubernetes cluster, avoiding DNS resolution issues.

#### 1. Build the Docker Image

Before deploying, you need to build and make the Docker image available to your Kubernetes cluster:

```bash
# Go back to the main demo directory
cd ..

# Build the Docker image
./build-image.sh

# For local Kubernetes clusters (minikube/kind)
# Load the image into the cluster:
minikube image load dedup-demo-producer:latest
# OR for kind:
kind load docker-image dedup-demo-producer:latest
# Colima the image registry is the same as docker daemon
docker images
# For remote clusters, push to a registry:
# export REGISTRY=your-registry.com
# ./build-image.sh
# docker push your-registry.com/dedup-demo-producer:latest
# Then update k8s/producer-pod.yaml to use the registry image
```

#### 2. Deploy all resources

```bash
# Deploy topic, config, and producer pod
kubectl apply -f k8s/products-topic.yaml
kubectl apply -f k8s/producer-pod.yaml
```

#### 3. Monitor the producer

```bash
# Watch the producer logs
kubectl logs -f dedup-demo-producer -n confluent

# Check producer pod status
kubectl get pod dedup-demo-producer -n confluent
```

#### 4. Monitor topic messages

```bash
# Consume messages from the topic
kubectl exec -it kafka-0 -n confluent -- kafka-console-consumer --topic products --bootstrap-server kafka:9071 --from-beginning
```

### Option B: Local Producer with Port Forwarding (Advanced)

This option requires additional configuration to resolve DNS issues.

#### 1. Deploy the Topic and ConfigMap only

```bash
kubectl apply -f products-topic.yaml
```

#### 2. Add host entries to resolve internal Kafka hostnames

Add these entries to your `/etc/hosts` file (macOS/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
127.0.0.1 kafka-0.kafka.confluent.svc.cluster.local
127.0.0.1 kafka-1.kafka.confluent.svc.cluster.local  
127.0.0.1 kafka-2.kafka.confluent.svc.cluster.local
```

#### 3. Port forward the Kafka service

```bash
# Forward the Kafka port (use port 9071 for internal communication)
kubectl port-forward service/kafka 9071:9071 -n confluent
```

#### 4. Update environment variables and run locally

```bash
export KAFKA_BOOTSTRAP_SERVERS=localhost:9071
cd ..  # Back to dedup-demo directory
uv run product_producer.py
```

### Verification Steps

#### Check Topic Creation

```bash
# Check if the topic was created
kubectl get kafkatopic products -n confluent

# Describe the topic for detailed information  
kubectl describe kafkatopic products -n confluent
```

#### Monitor in Control Center

```bash
kubectl port-forward service/controlcenter 9021:9021 -n confluent
# Navigate to http://localhost:9021
```

## Topic Configuration

The topic is configured with the following settings:

- **Partitions**: 1 (suitable for single-broker development setup)
- **Replication Factor**: 1 (suitable for development/demo)
- **Retention**: 7 days (604800000 ms)
- **Segment Size**: 24 hours (86400000 ms)
- **Compression**: Snappy (good balance of speed/compression)
- **Min In-Sync Replicas**: 1 (matches replication factor)

## Troubleshooting

### DNS Resolution Errors

If you see errors like:
```
Failed to resolve 'kafka-X.kafka.confluent.svc.cluster.local'
```

**Cause**: Kafka returns internal cluster hostnames that aren't resolvable from outside the cluster.

**Solutions**:
1. **Use Option A (Producer Pod)** - Run the producer inside the cluster
2. **Add host entries** - Map internal hostnames to localhost (see Option B)
3. **Use external LoadBalancer/NodePort services** - For production setups

### Connection Timeouts

If the producer hangs or times out:

1. **Check Kafka pod status**:
   ```bash
   kubectl get pods -n confluent -l app=kafka
   ```

2. **Verify Kafka is ready**:
   ```bash
   kubectl logs kafka-0 -n confluent | grep "started"
   ```

3. **Test internal connectivity** (from within cluster):
   ```bash
   kubectl run kafka-test --rm -i --tty --image=confluentinc/cp-kafka:8.0.0 --restart=Never -- kafka-topics --bootstrap-server kafka:9071 --list
   ```

## Usage with Python Producer

The ConfigMap can be used to configure the Python producer environment:

```bash
# Get the configuration values
kubectl get configmap dedup-demo-config -n confluent -o yaml

# Use in a pod deployment
apiVersion: v1
kind: Pod
metadata:
  name: dedup-demo-producer
spec:
  containers:
  - name: producer
    image: your-producer-image
    envFrom:
    - configMapRef:
        name: dedup-demo-config
```

## Cleanup

To remove the resources:

```bash
# Remove Kubernetes resources
kubectl delete -f k8s/producer-pod.yaml
kubectl delete -f k8s/products-topic.yaml

# Remove Docker image (optional)
docker rmi dedup-demo-producer:latest

# For minikube/kind, you may need to clean up the loaded image
minikube image rm dedup-demo-producer:latest
# OR for kind:
docker exec -it kind-control-plane crictl rmi dedup-demo-producer:latest
``` 