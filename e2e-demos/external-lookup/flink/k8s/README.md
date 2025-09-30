# Payment Claims Enrichment - Kubernetes Deployment

This directory contains Kubernetes manifests and deployment scripts for the Payment Claims Enrichment Flink Table API application.

## 📁 Directory Structure

```
k8s/
├── README.md                    # This documentation
├── configmap.yaml              # Application configuration
├── rbac.yaml                   # ServiceAccount and RBAC setup
├── storage.yaml                # PersistentVolumeClaims and storage
├── flink-cluster.yaml          # Standalone Flink cluster deployment
├── services.yaml               # Services and load balancers
├── networking.yaml             # Ingress, NetworkPolicies, HPA
├── flink-operator.yaml         # Flink Kubernetes Operator deployment
├── deploy.sh                   # Main deployment script
├── cleanup.sh                  # Cleanup and removal script
└── status.sh                   # Status monitoring script
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.21+)
- kubectl configured and connected
- Sufficient cluster resources (4 CPUs, 8GB RAM minimum)
- StorageClass available for PersistentVolumes

### 1. Basic Deployment

Deploy with default settings:
```bash
./deploy.sh
```

### 2. Monitor Deployment

Check deployment status:
```bash
./status.sh
```

Watch in real-time:
```bash
./status.sh --watch
```

### 3. Access Flink Web UI

Set up port forwarding:
```bash
kubectl port-forward service/flink-jobmanager 8081:8081 -n flink
```

Access at: http://localhost:8081

### 4. Cleanup

Remove all resources:
```bash
./cleanup.sh
```

## 🔧 Deployment Options

### Standalone Flink Cluster (Default)

Deploys a complete Flink cluster with JobManager and TaskManagers:

```bash
./deploy.sh --mode standalone
```

**Features:**
- Full Flink cluster control
- Persistent checkpoints and savepoints
- Direct job deployment
- Suitable for production

### Flink Kubernetes Operator

Uses the Flink Kubernetes Operator for advanced management:

```bash
# First install the operator (if not already installed)
kubectl apply -f https://github.com/apache/flink-kubernetes-operator/releases/latest/download/flink-kubernetes-operator.yaml

# Deploy with operator
./deploy.sh --mode operator
```

**Features:**
- Declarative job management
- Automatic scaling and recovery
- Advanced lifecycle management
- Recommended for production

### Session Mode

Deploy Flink session cluster first, then submit jobs:

```bash
./deploy.sh --mode session
```

**Features:**
- Shared Flink cluster
- Multiple jobs per cluster
- Resource sharing
- Good for development/testing

## 📝 Configuration

### Environment Variables

Configure the application using environment variables in `configmap.yaml`:

```yaml
# Kafka Configuration
kafka.bootstrap.servers: "kafka.confluent:9092"
kafka.payment.events.topic: "payment-events"
kafka.enriched.payments.topic: "enriched-payments"
kafka.failed.payments.topic: "failed-payments"

# DuckDB Configuration  
duckdb.url: "jdbc:duckdb:http://duckdb-external-lookup.el-demo:8080/database"

# Flink Configuration
flink.parallelism: "2"
flink.checkpoint.interval: "60s"
```

### Resource Requirements

Default resource allocation:

| Component | CPU | Memory | Storage |
|-----------|-----|---------|---------|
| JobManager | 0.5 | 1600Mi | - |
| TaskManager | 0.5 | 1728Mi | - |
| Checkpoints | - | - | 10Gi |
| Savepoints | - | - | 5Gi |

Adjust in deployment files as needed.

### Scaling

#### Manual Scaling

Scale TaskManagers:
```bash
kubectl scale deployment flink-taskmanager --replicas=4 -n flink
```

#### Auto Scaling

HorizontalPodAutoscaler is configured in `networking.yaml`:
- Min replicas: 2
- Max replicas: 10
- Target CPU: 80%
- Target Memory: 85%

## 🌐 Networking

### Internal Access

- **JobManager RPC**: `flink-jobmanager:6123`
- **JobManager Web UI**: `flink-jobmanager:8081`
- **TaskManager RPC**: `flink-taskmanager:6122`

### External Access

#### Option 1: Port Forwarding (Development)
```bash
kubectl port-forward service/flink-jobmanager 8081:8081 -n flink
```

#### Option 2: LoadBalancer (Cloud)
```bash
kubectl get service flink-jobmanager-external -n flink
```

#### Option 3: Ingress (Production)
Configure domain in `networking.yaml`:
```yaml
spec:
  rules:
  - host: flink.yourdomain.com
```

### Network Policies

NetworkPolicies are configured for:
- Flink internal communication
- Kafka access (port 9092)
- DuckDB access (port 8080)
- Ingress controller access
- Prometheus metrics collection

## 💾 Storage

### Persistent Volumes

Two PVCs are created:
- `flink-checkpoints`: 10Gi for fault tolerance
- `flink-savepoints`: 5Gi for manual snapshots

### Storage Classes

Default StorageClass is used. For specific requirements:

```bash
# List available storage classes
kubectl get storageclass

# Edit storage.yaml to specify:
storageClassName: your-storage-class
```

### Backup Strategy

Savepoints are stored in PersistentVolumes. For backup:

```bash
# Create savepoint
kubectl exec deployment/flink-jobmanager -n flink -- \
  /opt/flink/bin/flink savepoint <job-id>

# Backup savepoints directory
kubectl exec deployment/flink-jobmanager -n flink -- \
  tar -czf /tmp/savepoints-backup.tar.gz /opt/flink/savepoints
```

## 🔍 Monitoring and Troubleshooting

### Health Checks

The application includes:
- **Liveness Probes**: Restart unhealthy containers
- **Readiness Probes**: Traffic routing control
- **Startup Probes**: Handle slow initialization

### Metrics

Prometheus metrics available at:
- JobManager: `http://flink-jobmanager:9249/metrics`
- TaskManager: `http://flink-taskmanager:9249/metrics`

### Log Access

```bash
# JobManager logs
kubectl logs deployment/flink-jobmanager -n flink -f

# TaskManager logs  
kubectl logs deployment/flink-taskmanager -n flink -f

# Application logs
kubectl logs -l app=payment-claims-enrichment -n flink -f
```

### Common Issues

#### 1. Pods Stuck in Pending
```bash
# Check resource availability
kubectl describe nodes

# Check storage
kubectl get pvc -n flink
kubectl describe pvc flink-checkpoints -n flink
```

#### 2. Job Not Starting
```bash
# Check Flink cluster status
kubectl exec deployment/flink-jobmanager -n flink -- \
  /opt/flink/bin/flink list

# Check application logs
kubectl logs deployment/flink-jobmanager -n flink
```

#### 3. External Dependencies
```bash
# Test Kafka connectivity
kubectl exec deployment/flink-jobmanager -n flink -- \
  nc -zv kafka.confluent 9092

# Test DuckDB connectivity
kubectl exec deployment/flink-jobmanager -n flink -- \
  curl -f http://duckdb-external-lookup.el-demo:8080/health
```

## 🔒 Security

### RBAC Configuration

ServiceAccount with minimal required permissions:
- Pod lifecycle management
- Service discovery
- ConfigMap/Secret access

### Network Security

- NetworkPolicies restrict traffic flow
- Internal communication only on required ports
- External access through controlled ingress points

### Secrets Management

Sensitive configuration in Kubernetes Secrets:
```bash
kubectl create secret generic payment-claims-secrets \
  --from-literal=kafka.username=your-username \
  --from-literal=kafka.password=your-password \
  -n flink
```

## 📊 Production Considerations

### High Availability

For production deployment:

1. **Multiple Availability Zones**:
   ```yaml
   affinity:
     podAntiAffinity:
       requiredDuringSchedulingIgnoredDuringExecution:
       - topologyKey: topology.kubernetes.io/zone
   ```

2. **Resource Limits**:
   ```yaml
   resources:
     requests:
       memory: "1600Mi"
       cpu: "0.5"
     limits:
       memory: "2048Mi"
       cpu: "1"
   ```

3. **Persistent Volumes**:
   - Use high-performance storage (SSD)
   - Regular backup strategy
   - Cross-zone replication

### Performance Tuning

1. **Flink Configuration**:
   - Increase parallelism based on data volume
   - Tune checkpoint interval (balance performance vs. recovery time)
   - Adjust memory allocation

2. **Kubernetes Resources**:
   - Set appropriate CPU/memory requests and limits
   - Use dedicated node pools for Flink workloads
   - Configure pod disruption budgets

3. **Lookup Performance**:
   - Tune cache settings in ConfigMap
   - Monitor cache hit rates
   - Consider database connection pooling

### Monitoring Setup

Recommended monitoring stack:
- **Prometheus**: Metrics collection
- **Grafana**: Visualization
- **AlertManager**: Alerting
- **FluentD/Fluent Bit**: Log collection

## 🧪 Testing

### Smoke Tests

After deployment, run basic functionality tests:

```bash
# Check if job is running
kubectl exec deployment/flink-jobmanager -n flink -- \
  /opt/flink/bin/flink list | grep RUNNING

# Test data flow (if event generator is available)
kubectl logs deployment/event-generator -n el-demo --tail=10
```

### Load Testing

Use the event generator to simulate load:

```bash
# Scale up event generation
kubectl scale deployment event-generator --replicas=3 -n el-demo

# Monitor processing metrics
kubectl port-forward service/flink-jobmanager 8081:8081 -n flink
# Access http://localhost:8081 and check job metrics
```

## 🤝 Contributing

When contributing to the Kubernetes deployment:

1. Test changes in development environment first
2. Update documentation for any configuration changes
3. Validate YAML manifests: `kubectl apply --dry-run=client -f .`
4. Test with different Kubernetes versions
5. Update resource requirements if needed

## 📞 Support

For issues with Kubernetes deployment:

1. Check deployment status: `./status.sh --detailed`
2. Review logs: `kubectl logs -l app=payment-claims-enrichment -n flink`
3. Verify external dependencies connectivity
4. Check resource availability
5. Consult troubleshooting section above
