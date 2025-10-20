# Quick Start: Flink with MinIO S3 Checkpointing

This is a quick reference guide for setting up Apache Flink with MinIO S3 checkpointing on Kubernetes. For detailed documentation, see the linked docs.

## Prerequisites

- Kubernetes cluster (Colima, Minikube, or production cluster)
- kubectl configured
- Docker (for building custom image)
- Make (optional, for convenience commands)

## 5-Minute Setup

### Step 1: Build Custom Flink Image with S3 Support

The base Confluent Flink image **does not include S3 support**. You must build a custom image:

```bash
cd /Users/jerome/Documents/Code/flink-studies/deployment/k8s/cp-flink

# Build image with S3 plugin
make build_flink_s3_image

# Push to your registry (update DOCKER_REGISTRY variable)
export DOCKER_REGISTRY=your-dockerhub-username
make build_and_push_flink_s3_image
```

This adds the `flink-s3-fs-hadoop-1.20.2.jar` (~130MB) to `/opt/flink/plugins/s3-fs-hadoop/`.

### Step 2: Deploy MinIO

```bash
# Deploy MinIO pod and service
make deploy_minio

# Verify
make verify_minio
```

### Step 3: Deploy S3 Credentials Secret

```bash
# Deploy secret with MinIO credentials
make deploy_minio_secret

# Verify
make verify_minio_secret
```

### Step 4: Create Flink Bucket in MinIO

```bash
# Port-forward to MinIO console
make port_forward_minio_console

# In browser: http://localhost:9090
# Login: minioadmin / minioadmin
# Create bucket: "flink"
```

### Step 5: Update FlinkEnvironment

Edit `flink-dev-env.yaml` and add the custom image:

```yaml
spec:
  flinkApplicationDefaults:
    spec:
      # Add this line - use your registry
      image: your-registry/cp-flink-s3:1.20.2-s3
      
      flinkConfiguration:
        state.checkpoints.dir: 's3a://flink/checkpoints'
        state.savepoints.dir: 's3a://flink/savepoints'
        s3.endpoint: '${S3_ENDPOINT}'
        s3.path.style.access: 'true'
        s3.access-key: '${S3_ACCESS_KEY}'
        s3.secret-key: '${S3_SECRET_KEY}'
      
      podTemplate:
        # ... environment variables from secret
```

### Step 6: Deploy FlinkEnvironment

```bash
make deploy_flink_env
make verify_flink_env
```

## Verification Checklist

### ✅ Check S3 Plugin Loaded

```bash
# Get a Flink pod name
kubectl get pods -n el-demo

# Check for S3 plugin
kubectl exec -n el-demo <flink-pod> -- ls -la /opt/flink/plugins/s3-fs-hadoop/
# Should show: flink-s3-fs-hadoop-1.20.2.jar

# Check logs
kubectl logs -n el-demo <flink-pod> | grep -i "s3"
# Should see: "Loaded plugin flink-s3-fs-hadoop"
```

### ✅ Check Credentials Injected

```bash
kubectl exec -n el-demo <flink-pod> -- env | grep S3_
# Should show:
# S3_ENDPOINT=http://minio.minio-dev.svc.cluster.local:9000
# S3_ACCESS_KEY=minioadmin
# S3_SECRET_KEY=minioadmin
```

### ✅ Check MinIO Connectivity

```bash
# From within cluster
kubectl run -it --rm curl-test --image=curlimages/curl --restart=Never -n el-demo -- \
  curl -v http://minio.minio-dev.svc.cluster.local:9000

# Should get HTTP 200 response from MinIO
```

### ✅ Run Test Job with Checkpointing

Deploy a Flink job with checkpointing enabled, then check MinIO:

```bash
# Port-forward MinIO console
make port_forward_minio_console

# Browser: http://localhost:9090
# Navigate to: Buckets > flink > checkpoints/
# Should see checkpoint directories after job runs
```

## Common Issues

### Issue: "Could not find a file system implementation for scheme 's3a'"

**Cause:** S3 plugin JAR not installed or not loaded.

**Fix:**
```bash
# Verify custom image is being used
kubectl describe pod -n el-demo <flink-pod> | grep Image:
# Should show your custom image, not base confluentinc/cp-flink

# Rebuild and redeploy if needed
make build_flink_s3_image
```

### Issue: "Connection refused" to MinIO

**Cause:** MinIO service not accessible or wrong DNS name.

**Fix:**
```bash
# Check MinIO service
kubectl get svc -n minio-dev minio

# Test DNS resolution
kubectl run -it --rm dns-test --image=busybox --restart=Never -n el-demo -- \
  nslookup minio.minio-dev.svc.cluster.local
```

### Issue: "Access Denied" from MinIO

**Cause:** Credentials not injected or incorrect.

**Fix:**
```bash
# Check secret exists
kubectl get secret minio-s3-credentials -n el-demo

# Check environment variables in pod
kubectl exec -n el-demo <flink-pod> -- env | grep S3_
```

## File Structure

```
/Users/jerome/Documents/Code/flink-studies/deployment/k8s/cp-flink/
├── Dockerfile.s3-enabled           # Full-featured Dockerfile
├── Dockerfile.s3-enabled-alpine    # Lightweight Dockerfile (recommended)
├── flink-dev-env.yaml             # FlinkEnvironment with S3 config
├── minio-credentials-secret.yaml   # Kubernetes Secret for credentials
├── Makefile                        # Build and deploy commands
├── README.md                       # Main documentation
├── MINIO_S3_SETUP.md              # Complete S3/MinIO setup guide
├── S3_JAR_REQUIREMENTS.md         # JAR requirements and troubleshooting
└── QUICK_START_S3_MINIO.md        # This file
```

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│ FlinkEnvironment (flink-dev-env.yaml)      │
│ - Custom Image: cp-flink-s3:1.20.2-s3      │
│ - S3 Config: s3a://flink/checkpoints       │
└─────────────────────────────────────────────┘
              │
              │ Creates
              ▼
┌─────────────────────────────────────────────┐
│ Flink Pods (el-demo namespace)             │
│ ┌─────────────────────────────────────────┐│
│ │ /opt/flink/plugins/s3-fs-hadoop/        ││
│ │   └── flink-s3-fs-hadoop-1.20.2.jar     ││
│ └─────────────────────────────────────────┘│
│ ┌─────────────────────────────────────────┐│
│ │ Environment Variables (from Secret):    ││
│ │ - S3_ENDPOINT=http://minio...           ││
│ │ - S3_ACCESS_KEY=minioadmin              ││
│ │ - S3_SECRET_KEY=minioadmin              ││
│ └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
              │
              │ S3A Protocol
              │ (via flink-s3-fs-hadoop)
              ▼
┌─────────────────────────────────────────────┐
│ MinIO Service                               │
│ minio.minio-dev.svc.cluster.local:9000     │
│ ┌─────────────────────────────────────────┐│
│ │ Bucket: flink                           ││
│ │   ├── checkpoints/                      ││
│ │   │   ├── <job-id>/                     ││
│ │   │   │   ├── chk-1/                    ││
│ │   │   │   ├── chk-2/                    ││
│ │   │   │   └── ...                       ││
│ │   └── savepoints/                       ││
│ │       └── <savepoint-dirs>/             ││
│ └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

## Key Configuration Values

| Component | Value | Description |
|-----------|-------|-------------|
| **Custom Image** | `jbcodeforce/cp-flink-s3:1.20.2-s3` | Flink with S3 plugin |
| **S3 Plugin JAR** | `flink-s3-fs-hadoop-1.20.2.jar` | ~130MB, in plugins directory |
| **MinIO Service** | `minio.minio-dev.svc.cluster.local:9000` | Internal DNS name |
| **MinIO Console** | Port 9090 | Access via port-forward |
| **S3 Bucket** | `flink` | Must be created manually |
| **Checkpoint URI** | `s3a://flink/checkpoints` | Uses S3A protocol |
| **Savepoint URI** | `s3a://flink/savepoints` | Uses S3A protocol |
| **Secret Name** | `minio-s3-credentials` | In `el-demo` namespace |
| **Path Style** | `true` | Required for MinIO |

## Makefile Commands

```bash
# MinIO
make deploy_minio                  # Deploy MinIO
make verify_minio                  # Check MinIO status
make deploy_minio_secret           # Deploy credentials
make port_forward_minio_console    # Access console

# Custom Flink Image
make build_flink_s3_image          # Build image
make build_and_push_flink_s3_image # Build and push

# FlinkEnvironment
make deploy_flink_env              # Deploy environment
make verify_flink_env              # Check status

# Complete setup
make install_cmf                   # Includes all steps
```

## Production Considerations

### Security

For production, **never commit credentials to git**:

```bash
# Create secret imperatively
kubectl create secret generic minio-s3-credentials \
  --from-literal=s3.access-key=<production-key> \
  --from-literal=s3.secret-key=<production-secret> \
  --from-literal=s3.endpoint=https://s3.production.com \
  -n production-namespace

# Or use External Secrets Operator
# Or use Sealed Secrets
```

### High Availability

For production MinIO:
- Deploy MinIO in distributed mode (4+ nodes)
- Use PersistentVolumes (not HostPath)
- Enable TLS/SSL
- Configure lifecycle policies for old checkpoints
- Monitor storage capacity

### Image Registry

Push custom image to private registry:

```bash
# AWS ECR
aws ecr get-login-password | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
docker tag cp-flink-s3:1.20.2-s3 <account>.dkr.ecr.<region>.amazonaws.com/cp-flink-s3:1.20.2-s3
docker push <account>.dkr.ecr.<region>.amazonaws.com/cp-flink-s3:1.20.2-s3

# Or Docker Hub private repo
docker tag cp-flink-s3:1.20.2-s3 username/cp-flink-s3:1.20.2-s3
docker push username/cp-flink-s3:1.20.2-s3
```

## Next Steps

1. ✅ Complete this quick start
2. 📖 Read [`MINIO_S3_SETUP.md`](./MINIO_S3_SETUP.md) for detailed architecture
3. 📖 Review [`S3_JAR_REQUIREMENTS.md`](./S3_JAR_REQUIREMENTS.md) for troubleshooting
4. 🔧 Configure performance tuning (connection pooling, multipart uploads)
5. 🔒 Implement production security (External Secrets, TLS, IAM)
6. 📊 Set up monitoring for checkpoint metrics
7. 🧪 Test job recovery from checkpoints

## Resources

- **Main README:** [`README.md`](./README.md)
- **S3 Setup Guide:** [`MINIO_S3_SETUP.md`](./MINIO_S3_SETUP.md)
- **JAR Requirements:** [`S3_JAR_REQUIREMENTS.md`](./S3_JAR_REQUIREMENTS.md)
- **Flink S3 Docs:** https://nightlies.apache.org/flink/flink-docs-stable/docs/deployment/filesystems/s3/
- **MinIO Docs:** https://min.io/docs/minio/kubernetes/upstream/

## Summary

**Essential Steps:**
1. Build custom image with S3 plugin → `make build_flink_s3_image`
2. Deploy MinIO → `make deploy_minio`
3. Deploy credentials → `make deploy_minio_secret`
4. Create bucket → `flink`
5. Update FlinkEnvironment → Add custom image
6. Deploy → `make deploy_flink_env`

**Key Requirement:** The `flink-s3-fs-hadoop-1.20.2.jar` must be in `/opt/flink/plugins/s3-fs-hadoop/` directory.

**Without this JAR, S3A protocol will not work!**

