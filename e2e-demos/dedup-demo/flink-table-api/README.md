# Flink Table API Deduplication Job

This directory contains a **Flink Table API implementation** of the product deduplication logic, packaged as a deployable Flink application for Kubernetes.

## Overview

The Flink Table API version provides the same deduplication functionality as the SQL version, but with these advantages:

- **Standalone Application**: Packaged as a self-contained JAR that can be deployed independently
- **Production Ready**: Includes proper configuration, logging, and error handling
- **Kubernetes Native**: Designed for deployment on Kubernetes with Confluent Platform for Flink
- **Configurable**: Supports runtime configuration via command line arguments
- **Scalable**: Can be scaled horizontally by adjusting parallelism

## Architecture

```
Raw Events (Kafka) → Flink Table API Job → Deduplicated Events (Kafka)
      ↓                      ↓                        ↓
   products topic       Java Application         src_products topic
  (with duplicates)    (deduplication logic)    (clean data)
```

## Project Structure

```
flink-table-api/
├── src/main/java/
│   └── com/example/dedup/
│       └── ProductDeduplicationJob.java    # Main job implementation
├── src/main/resources/
│   └── log4j2.properties                   # Logging configuration
├── k8s/
│   ├── flink-application.yaml              # FlinkApplication CRD deployment
│   └── flink-deployment.yaml               # Alternative standard K8s deployment
├── pom.xml                                 # Maven build configuration
├── Dockerfile                              # Container image definition
├── build-flink-app.sh                      # Build and packaging script
└── README.md                               # This file
```

## Building the Application

### Prerequisites

- **Java 11+**: Required for Flink 1.18
- **Maven 3.6+**: For building the Java application
- **Docker**: For creating container images
- **kubectl**: For Kubernetes deployment

### Build Steps

1. **Build and package the application:**
   ```bash
   ./build-flink-app.sh
   ```

   This script will:
   - Compile the Java code with Maven
   - Create a fat JAR with all dependencies
   - Build a Docker image
   - Tag it for local Kubernetes use

2. **For custom registry deployment:**
   ```bash
   DOCKER_REGISTRY=your-registry.com ./build-flink-app.sh
   ```

3. **Load image to local Kubernetes:**
   Nothing to do for Colima.
   
   ```bash
   # For minikube
   minikube image load flink-dedup-app:1.0.0
   
   # For kind
   kind load docker-image flink-dedup-app:1.0.0
   ```

## Deployment Options

### Option 1: FlinkApplication (Recommended)

Uses the Flink Operator and FlinkApplication CRD for managed deployment:

```bash
# Deploy the FlinkApplication
kubectl apply -f k8s/flink-application.yaml

# Check the application status
kubectl get flinkapplication -n flink

# View logs
kubectl logs -f deployment/product-dedup-job-jobmanager -n flink
```

### Option 2: Standard Kubernetes Deployment

Uses standard Kubernetes resources (Deployment, Service, Job):

```bash
# Deploy using standard K8s resources
kubectl apply -f k8s/flink-deployment.yaml

# Check deployment status
kubectl get pods -n flink

# View JobManager logs
kubectl logs -f deployment/flink-jobmanager -n flink

# View TaskManager logs
kubectl logs -f deployment/flink-taskmanager -n flink
```

## Configuration

The application accepts these command line arguments:

- `--kafka.bootstrap.servers`: Kafka broker addresses (default: `localhost:9092`)
- `--input.topic`: Input topic name (default: `products`)
- `--output.topic`: Output topic name (default: `src_products`)
- `--consumer.group`: Consumer group ID (default: `flink-dedup-consumer`)

### Environment Variables

You can also configure via environment variables:

- `KAFKA_BOOTSTRAP_SERVERS`
- `INPUT_TOPIC`
- `OUTPUT_TOPIC` 
- `CONSUMER_GROUP`

## Monitoring and Management

### Flink Web UI

Access the Flink Web UI to monitor job execution:

```bash
# Port forward to the JobManager
kubectl port-forward svc/flink-jobmanager 8081:8081 -n flink

# Open in browser
open http://localhost:8081
```

### Job Status Commands

```bash
# Check job status
kubectl get pods -n flink

# View job logs
kubectl logs -f <pod-name> -n flink

# Check job metrics
kubectl exec -it <jobmanager-pod> -n flink -- /opt/flink/bin/flink list
```

### Checkpoint and Savepoint Management

```bash
# List running jobs
kubectl exec -it <jobmanager-pod> -n flink -- /opt/flink/bin/flink list

# Create a savepoint
kubectl exec -it <jobmanager-pod> -n flink -- /opt/flink/bin/flink savepoint <job-id>

# Cancel job with savepoint
kubectl exec -it <jobmanager-pod> -n flink -- /opt/flink/bin/flink cancel -s <job-id>
```

## Implementation Details

### Deduplication Logic

The Java implementation uses the same logic as the SQL version:

1. **Source Table**: Reads from Kafka `products` topic with JSON deserialization
2. **Flattening**: Unnests the product structure using Table API
3. **Deduplication**: Uses `ROW_NUMBER()` window function to keep latest events per product state
4. **Sink Table**: Writes to `src_products` topic using upsert-kafka connector

### Key Features

- **Fault Tolerance**: Configured with checkpointing every 30 seconds
- **Exactly-Once Processing**: Ensures no data loss or duplication
- **State Management**: Uses RocksDB for efficient state storage
- **Resource Management**: Configurable memory and CPU resources
- **Logging**: Comprehensive logging with log4j2

## Comparison with SQL Version

| Feature | Flink SQL | Table API |
|---------|-----------|-----------|
| **Deployment** | Interactive CLI | Standalone Application |
| **Resource Management** | Manual | Automated via K8s |
| **Monitoring** | Limited | Full Flink Web UI |
| **Configuration** | Static | Runtime configurable |
| **Production Use** | Development/Testing | Production Ready |
| **Scalability** | Manual scaling | K8s autoscaling |

## Troubleshooting

### Common Issues

1. **Image Pull Errors**
   ```bash
   # Ensure image is loaded to local cluster
   minikube image load flink-dedup-app:1.0.0
   ```

2. **Job Submission Failures**
   ```bash
   # Check JobManager logs
   kubectl logs deployment/flink-jobmanager -n flink
   
   # Verify Kafka connectivity
   kubectl exec -it <pod> -n flink -- nc -zv kafka 9092
   ```

3. **Checkpoint Failures**
   ```bash
   # Check PVC is mounted correctly
   kubectl describe pvc flink-data-pvc -n flink
   
   # Verify storage class exists
   kubectl get storageclass
   ```

### Debug Commands

```bash
# Get detailed pod information
kubectl describe pod <pod-name> -n flink

# Check resource usage
kubectl top pods -n flink

# View events
kubectl get events -n flink --sort-by='.lastTimestamp'

# Access job container shell
kubectl exec -it <pod-name> -n flink -- /bin/bash
```

## Testing the Application

1. **Start the Producer** (from parent directory):
   ```bash
   kubectl apply -f k8s/producer-pod.yaml
   ```

2. **Deploy the Flink Job**:
   ```bash
   kubectl apply -f flink-table-api/k8s/flink-application.yaml
   ```

3. **Monitor the Processing**:
   ```bash
   # Check job is running
   kubectl get flinkapplication -n flink
   
   # View processing logs
   kubectl logs -f deployment/product-dedup-job-jobmanager -n flink
   ```

4. **Verify Output**:
   ```bash
   # Check the deduplicated output topic
   kubectl exec -it kafka-0 -n confluent -- kafka-console-consumer \
     --topic src_products --bootstrap-server kafka:9092 --from-beginning
   ```

## Next Steps

- **Monitoring**: Integrate with Prometheus/Grafana for metrics
- **Alerting**: Set up alerts for job failures and performance issues
- **Scaling**: Configure horizontal pod autoscaling based on CPU/memory
- **CI/CD**: Automate build and deployment pipeline
- **Testing**: Add unit and integration tests
- **Performance**: Tune parallelism and resource allocation for production workloads 