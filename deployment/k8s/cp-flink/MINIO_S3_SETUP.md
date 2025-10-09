# MinIO S3 Setup for Flink Checkpointing

This document describes the secure MinIO S3 configuration for Apache Flink checkpointing and savepointing in Kubernetes.

## Overview

This setup provides:
- **MinIO** as S3-compatible object storage
- **Kubernetes Service** for DNS resolution
- **Kubernetes Secrets** for secure credential management
- **FlinkEnvironment** configured for S3 checkpointing

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flink Pods                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Environment Variables (from Secret)                    │ │
│  │  - S3_ENDPOINT                                          │ │
│  │  - S3_ACCESS_KEY                                        │ │
│  │  - S3_SECRET_KEY                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                           │                                  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Flink Configuration                                    │ │
│  │  - state.checkpoints.dir: s3a://flink/checkpoints      │ │
│  │  - state.savepoints.dir: s3a://flink/savepoints        │ │
│  │  - s3.endpoint: ${S3_ENDPOINT}                         │ │
│  │  - s3.access-key: ${S3_ACCESS_KEY}                     │ │
│  │  - s3.secret-key: ${S3_SECRET_KEY}                     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ HTTP
                           ▼
        ┌────────────────────────────────────┐
        │  Kubernetes Service                 │
        │  minio.minio-dev.svc.cluster.local  │
        │  Port: 9000 (API)                   │
        │  Port: 9090 (Console)               │
        └────────────────────────────────────┘
                           │
                           ▼
        ┌────────────────────────────────────┐
        │  MinIO Pod (minio-dev namespace)   │
        │  - Bucket: flink                    │
        │    - checkpoints/                   │
        │    - savepoints/                    │
        └────────────────────────────────────┘
```

## Components

### 1. MinIO Deployment

**File:** `../MinIO/minio-dev.yaml`

- **Namespace:** `minio-dev`
- **Pod:** Single MinIO instance
- **Ports:**
  - `9000`: S3 API endpoint
  - `9090`: Web console
- **Storage:** HostPath volume at `/mnt/disk1/data`
- **Service:** ClusterIP for internal cluster access

**DNS Names:**
- Full: `minio.minio-dev.svc.cluster.local`
- Short (cross-namespace): `minio.minio-dev`
- Within namespace: `minio`

### 2. Kubernetes Secret

**File:** `minio-credentials-secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-s3-credentials
  namespace: el-demo
type: Opaque
stringData:
  s3.access-key: minioadmin
  s3.secret-key: minioadmin
  s3.endpoint: http://minio.minio-dev.svc.cluster.local:9000
```

### 3. FlinkEnvironment Configuration

**File:** `flink-dev-env.yaml`

The FlinkEnvironment uses a **Pod Template** to inject secret values as environment variables:

```yaml
spec:
  flinkApplicationDefaults:
    spec:
      flinkConfiguration:
        state.checkpoints.dir: 's3a://flink/checkpoints'
        state.savepoints.dir: 's3a://flink/savepoints'
        s3.endpoint: '${S3_ENDPOINT}'
        s3.path.style.access: 'true'
        s3.access-key: '${S3_ACCESS_KEY}'
        s3.secret-key: '${S3_SECRET_KEY}'
      
      podTemplate:
        spec:
          containers:
          - name: flink-main-container
            env:
            - name: S3_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: minio-s3-credentials
                  key: s3.endpoint
            - name: S3_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-s3-credentials
                  key: s3.access-key
            - name: S3_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: minio-s3-credentials
                  key: s3.secret-key
```

## Deployment Steps

### 1. Deploy MinIO

```bash
make deploy_minio
make verify_minio
```

This deploys:
- MinIO namespace
- MinIO pod
- MinIO service

### 2. Deploy Credentials Secret

```bash
make deploy_minio_secret
make verify_minio_secret
```

### 3. Create Flink Bucket

Before running Flink jobs, create the `flink` bucket:

**Option A: Using MinIO Console**
```bash
make port_forward_minio_console
# Access http://localhost:9090
# Login: minioadmin / minioadmin
# Create bucket: "flink"
```

**Option B: Using mc CLI**
```bash
kubectl run -it --rm mc --image=minio/mc --restart=Never -- \
  sh -c "mc alias set minio http://minio.minio-dev:9000 minioadmin minioadmin && mc mb minio/flink"
```

### 4. Deploy FlinkEnvironment

```bash
make deploy_flink_env
make verify_flink_env
```

## Security Best Practices

### Development Environment

The current setup uses default MinIO credentials (`minioadmin/minioadmin`) which is acceptable for local development.

### Production Environment

For production, follow these security practices:

#### 1. Use Dedicated MinIO Credentials

Create a dedicated user with limited permissions:

```bash
# Port-forward to MinIO
kubectl port-forward -n minio-dev pod/minio 9000:9000

# Using mc CLI
mc alias set prod-minio http://localhost:9000 minioadmin minioadmin
mc admin user add prod-minio flink-user <secure-password>
mc admin policy attach prod-minio readwrite --user flink-user
```

#### 2. Create Secret Imperatively

Don't commit secrets to git. Create them using kubectl:

```bash
kubectl create secret generic minio-s3-credentials \
  --from-literal=s3.access-key=flink-user \
  --from-literal=s3.secret-key=<secure-password> \
  --from-literal=s3.endpoint=http://minio.minio-dev.svc.cluster.local:9000 \
  -n el-demo
```

#### 3. Use External Secrets Operator

For production Kubernetes clusters, consider using:
- **External Secrets Operator** to sync from AWS Secrets Manager, HashiCorp Vault, etc.
- **Sealed Secrets** for encrypted secrets in git
- **SOPS** for encrypted configuration files

Example with External Secrets Operator:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: minio-s3-credentials
  namespace: el-demo
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: minio-s3-credentials
  data:
  - secretKey: s3.access-key
    remoteRef:
      key: prod/flink/minio
      property: accessKey
  - secretKey: s3.secret-key
    remoteRef:
      key: prod/flink/minio
      property: secretKey
  - secretKey: s3.endpoint
    remoteRef:
      key: prod/flink/minio
      property: endpoint
```

#### 4. Use TLS

For production, enable TLS on MinIO:

```bash
# Generate certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout private.key -out public.crt \
  -subj "/CN=minio.minio-dev.svc.cluster.local"

# Create TLS secret
kubectl create secret tls minio-tls \
  --cert=public.crt \
  --key=private.key \
  -n minio-dev

# Update MinIO deployment to mount certificates
# Update s3.endpoint to use https://
```

#### 5. Network Policies

Restrict access to MinIO using Network Policies:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: minio-access
  namespace: minio-dev
spec:
  podSelector:
    matchLabels:
      app: minio
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: el-demo
    ports:
    - protocol: TCP
      port: 9000
```

## Configuration Options

### Flink S3 Configuration

Key configuration properties for S3/MinIO:

| Property | Value | Description |
|----------|-------|-------------|
| `s3.endpoint` | `http://minio.minio-dev.svc.cluster.local:9000` | MinIO API endpoint |
| `s3.path.style.access` | `true` | Required for MinIO (uses path-style URLs) |
| `s3.access-key` | From secret | S3 access key |
| `s3.secret-key` | From secret | S3 secret key |
| `state.checkpoints.dir` | `s3a://flink/checkpoints` | Checkpoint storage location |
| `state.savepoints.dir` | `s3a://flink/savepoints` | Savepoint storage location |
| `state.backend.incremental` | `true` | Enable incremental checkpoints |
| `state.checkpoints.num-retained` | `3` | Number of checkpoints to retain |

### Additional S3 Options

For performance tuning, consider these additional properties:

```yaml
s3.upload.max.concurrent.uploads: '10'
s3.connection.timeout: '300000'
s3.socket.timeout: '50000'
s3.connection.maximum: '100'
s3.multipart.upload.enabled: 'true'
s3.multipart.upload.min.file.size: '5242880'  # 5MB
s3.multipart.upload.part.size: '5242880'  # 5MB
```

## Verification

### Check Secret Injection

```bash
# Get a Flink pod name
FLINK_POD=$(kubectl get pods -n el-demo -l app=<your-app> -o name | head -1)

# Check environment variables
kubectl exec -n el-demo $FLINK_POD -- env | grep S3_
```

Expected output:
```
S3_ENDPOINT=http://minio.minio-dev.svc.cluster.local:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
```

### Check Checkpoint Location

```bash
# Access Flink Dashboard
# Check Configuration tab for:
state.checkpoints.dir: s3a://flink/checkpoints
state.savepoints.dir: s3a://flink/savepoints
```

### Verify S3 Connectivity

```bash
# Deploy a test pod
kubectl run -it --rm test-s3 --image=amazon/aws-cli --restart=Never -- \
  s3 --endpoint-url=http://minio.minio-dev:9000 \
     --region=us-east-1 \
     ls s3://flink/
```

### Check MinIO Bucket Contents

```bash
# Port-forward to MinIO Console
make port_forward_minio_console

# Access http://localhost:9090
# Navigate to: Buckets > flink > checkpoints/
# You should see checkpoint directories after Flink jobs run
```

## Troubleshooting

### Issue: Flink Cannot Connect to MinIO

**Symptoms:**
```
Could not connect to S3 endpoint: Connection refused
```

**Solutions:**
1. Verify MinIO service is running:
   ```bash
   kubectl get svc -n minio-dev minio
   ```

2. Check DNS resolution from Flink namespace:
   ```bash
   kubectl run -it --rm dns-test --image=busybox --restart=Never -n el-demo -- \
     nslookup minio.minio-dev.svc.cluster.local
   ```

3. Verify network connectivity:
   ```bash
   kubectl run -it --rm curl-test --image=curlimages/curl --restart=Never -n el-demo -- \
     curl -v http://minio.minio-dev.svc.cluster.local:9000
   ```

### Issue: Authentication Failed

**Symptoms:**
```
S3Exception: Access Denied (Status Code: 403)
```

**Solutions:**
1. Verify secret exists and has correct keys:
   ```bash
   kubectl get secret minio-s3-credentials -n el-demo -o yaml
   ```

2. Decode and check secret values:
   ```bash
   kubectl get secret minio-s3-credentials -n el-demo -o jsonpath='{.data.s3\.access-key}' | base64 -d
   ```

3. Check environment variables in Flink pod:
   ```bash
   kubectl exec -n el-demo <flink-pod> -- env | grep S3_
   ```

### Issue: Bucket Not Found

**Symptoms:**
```
S3Exception: The specified bucket does not exist (Status Code: 404)
```

**Solution:**
Create the bucket as described in the deployment steps above.

### Issue: Path Style Access

**Symptoms:**
```
S3Exception: Inaccessible host: 'flink.minio.minio-dev'
```

**Solution:**
Ensure `s3.path.style.access: 'true'` is set in Flink configuration. This is required for MinIO.

## Makefile Targets

Convenient make targets for MinIO operations:

```bash
# Deploy MinIO and service
make deploy_minio

# Deploy credentials secret
make deploy_minio_secret

# Verify deployments
make verify_minio
make verify_minio_secret

# Access MinIO console
make port_forward_minio_console

# Full installation (includes secret deployment)
make install_cmf
```

## References

- [Apache Flink S3 Configuration](https://nightlies.apache.org/flink/flink-docs-stable/docs/deployment/filesystems/s3/)
- [MinIO Kubernetes Deployment](https://min.io/docs/minio/kubernetes/upstream/index.html)
- [Confluent Flink Operator](https://docs.confluent.io/platform/current/flink/index.html)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [External Secrets Operator](https://external-secrets.io/)

## Migration from Local File System

If you're migrating from local file system checkpointing:

1. **Backup existing checkpoints:**
   ```bash
   kubectl exec -n el-demo <jobmanager-pod> -- \
     tar czf /tmp/checkpoints-backup.tar.gz /opt/flink/volume/flink-cp
   ```

2. **Update FlinkEnvironment** to use S3 (already done in this setup)

3. **Deploy updated configuration:**
   ```bash
   kubectl apply -f flink-dev-env.yaml
   ```

4. **Restart Flink jobs** (they will start fresh with S3 checkpointing)

Note: You cannot directly restore from local file system checkpoints to S3. Jobs must be restarted.

## Cost Considerations

For production MinIO deployments:

1. **Use Persistent Volumes** instead of HostPath
2. **Enable erasure coding** for data redundancy
3. **Configure lifecycle policies** to expire old checkpoints
4. **Monitor storage usage** with MinIO metrics

Example lifecycle policy:
```bash
mc ilm add --expiry-days 7 minio/flink/checkpoints
```

## Conclusion

This setup provides a production-ready foundation for Flink checkpointing with MinIO. The key benefits are:

✅ Secure credential management with Kubernetes Secrets  
✅ DNS-based service discovery  
✅ Environment variable injection for configuration  
✅ Easy to migrate to external S3 providers (AWS, GCS, Azure)  
✅ Scalable and resilient checkpoint storage  

For production use, follow the security best practices section to enhance the security posture.

