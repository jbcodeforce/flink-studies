# Flink S3A/MinIO JAR Requirements

## Overview

To use MinIO (or any S3-compatible storage) with Flink's S3A protocol for checkpointing and savepointing, you need to add the **flink-s3-fs-hadoop** plugin JAR to your Flink distribution.

## Required JAR

### Primary Requirement

**JAR Name:** `flink-s3-fs-hadoop-<VERSION>.jar`

**Maven Coordinates:**
```xml
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-s3-fs-hadoop</artifactId>
    <version>1.20.2</version>
</dependency>
```

**Direct Download:**
```bash
wget https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.2/flink-s3-fs-hadoop-1.20.2.jar
```

### What's Included

This single JAR contains all necessary dependencies:
- ✅ Hadoop S3A FileSystem implementation
- ✅ AWS SDK for Java (S3 client libraries)
- ✅ Apache HttpClient and dependencies
- ✅ Credential providers (Access Key, IAM Role, etc.)
- ✅ Shaded dependencies to avoid conflicts

## Why This JAR is Needed

### S3A Protocol Support

Flink uses the `s3a://` URI scheme to access S3-compatible storage. This protocol is provided by Hadoop's S3A filesystem client, which is not included in the standard Flink distribution.

**Without this JAR, you'll see errors like:**
```
org.apache.flink.core.fs.UnsupportedFileSystemSchemeException: 
  Could not find a file system implementation for scheme 's3a'
```

### MinIO Compatibility

MinIO is S3-compatible but requires:
1. **Path-style access** (e.g., `http://endpoint:9000/bucket/key` instead of `http://bucket.endpoint:9000/key`)
2. **Custom endpoint configuration** (not AWS endpoints)
3. **Credential management** (access key/secret key)

The `flink-s3-fs-hadoop` plugin handles all of these through Flink configuration.

## Alternative: Presto S3 Filesystem

Flink also provides an alternative S3 filesystem based on Presto:

**JAR Name:** `flink-s3-fs-presto-<VERSION>.jar`

```bash
wget https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-presto/1.20.2/flink-s3-fs-presto-1.20.2.jar
```

### Hadoop vs Presto - Which to Choose?

| Feature | flink-s3-fs-hadoop | flink-s3-fs-presto |
|---------|-------------------|-------------------|
| **Maturity** | More mature, widely used | Newer, less tested |
| **Dependencies** | Larger (includes Hadoop) | Smaller footprint |
| **Credential Providers** | Full AWS credential chain | Basic credential support |
| **Configuration** | Via Hadoop properties | Via Presto properties |
| **MinIO Support** | ✅ Excellent | ✅ Good |
| **Performance** | Good | Comparable |
| **Recommendation** | **Use for production** | Use for minimal footprint |

**For MinIO with Confluent Platform, use `flink-s3-fs-hadoop`** - it's more stable and better documented.

## Installation Methods

### Method 1: Plugin Directory (Recommended for Kubernetes)

Flink uses a plugin system to load filesystem implementations. Place the JAR in the plugins directory:

```bash
# Standard Flink installation
mkdir -p $FLINK_HOME/plugins/s3-fs-hadoop
cp flink-s3-fs-hadoop-1.20.2.jar $FLINK_HOME/plugins/s3-fs-hadoop/
```

**Directory structure:**
```
/opt/flink/
├── lib/              # Core Flink JARs (don't put S3 JAR here)
├── opt/              # Optional plugins (source location)
└── plugins/          # Active plugins
    └── s3-fs-hadoop/ # S3 plugin directory
        └── flink-s3-fs-hadoop-1.20.2.jar
```

### Method 2: Docker Image (Best for Confluent Platform)

Build a custom Docker image with the S3 plugin pre-installed. See the provided Dockerfiles:

**Using our Dockerfile:**
```bash
cd /Users/jerome/Documents/Code/flink-studies/deployment/k8s/cp-flink

# Build the image
docker build -f Dockerfile.s3-enabled-alpine \
  -t jbcodeforce/cp-flink-s3:1.20.2-s3 .

# Or use make
make build_flink_s3_image

# Push to registry
make build_and_push_flink_s3_image
```

**For local Kubernetes (Colima/Minikube):**
```bash
# Load directly into local cluster
make load_flink_s3_image_local
```

### Method 3: Init Container (Alternative for Kubernetes)

Use an init container to download the JAR at pod startup:

```yaml
initContainers:
- name: download-s3-plugin
  image: busybox:latest
  command:
  - sh
  - -c
  - |
    mkdir -p /opt/flink/plugins/s3-fs-hadoop
    wget -O /opt/flink/plugins/s3-fs-hadoop/flink-s3-fs-hadoop-1.20.2.jar \
      https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.2/flink-s3-fs-hadoop-1.20.2.jar
  volumeMounts:
  - name: flink-plugins
    mountPath: /opt/flink/plugins
```

**Not recommended** - slower startup, requires network access, potential failure point.

## Configuration for MinIO

Once the JAR is installed, configure Flink to use MinIO:

### Flink Configuration Properties

```yaml
# In flink-conf.yaml or FlinkEnvironment spec
s3.endpoint: http://minio.minio-dev.svc.cluster.local:9000
s3.path.style.access: true
s3.access-key: minioadmin
s3.secret-key: minioadmin

# Checkpoint/Savepoint directories
state.checkpoints.dir: s3a://flink/checkpoints
state.savepoints.dir: s3a://flink/savepoints
```

### Secure Configuration (Using Environment Variables)

See `MINIO_S3_SETUP.md` for the complete secure setup using Kubernetes Secrets.

## Verification

### 1. Check Plugin Loading

When Flink starts, you should see log entries indicating the S3 plugin loaded:

```
INFO  org.apache.flink.core.plugin.PluginManager - Loaded plugin flink-s3-fs-hadoop from /opt/flink/plugins/s3-fs-hadoop
INFO  org.apache.flink.fs.s3.common.AbstractS3FileSystemFactory - Flink S3 filesystem initialized
```

### 2. Test S3 Connectivity

Create a test Flink job that writes to S3:

```java
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
env.getCheckpointConfig().setCheckpointStorage("s3a://flink/test-checkpoint");
env.fromElements(1, 2, 3).print();
env.execute("S3 Test Job");
```

### 3. Check MinIO for Checkpoints

After running a job with checkpointing enabled:

```bash
# Access MinIO Console
kubectl port-forward -n minio-dev pod/minio 9090:9090

# Open http://localhost:9090
# Navigate to: Buckets > flink > checkpoints/
# You should see checkpoint directories
```

## Common Issues and Solutions

### Issue 1: Scheme Not Supported

**Error:**
```
org.apache.flink.core.fs.UnsupportedFileSystemSchemeException: 
  Could not find a file system implementation for scheme 's3a'
```

**Cause:** The `flink-s3-fs-hadoop` JAR is not loaded.

**Solutions:**
1. Verify JAR is in `/opt/flink/plugins/s3-fs-hadoop/`
2. Check JAR filename matches exactly: `flink-s3-fs-hadoop-<VERSION>.jar`
3. Ensure plugin directory has one JAR only (no duplicates)
4. Check file permissions (should be readable by flink user)
5. Restart Flink pods/cluster

### Issue 2: Wrong JAR Location

**Problem:** JAR placed in `/opt/flink/lib/` instead of plugins directory.

**Why it fails:** Flink's plugin classloader isolation prevents S3 filesystem from loading properly when in `lib/`.

**Solution:** Move to plugin directory:
```bash
mkdir -p /opt/flink/plugins/s3-fs-hadoop
mv /opt/flink/lib/flink-s3-fs-hadoop-*.jar /opt/flink/plugins/s3-fs-hadoop/
```

### Issue 3: Version Mismatch

**Error:**
```
java.lang.NoSuchMethodError: org.apache.flink.core.fs.FileSystem...
```

**Cause:** S3 plugin version doesn't match Flink version.

**Solution:** Ensure plugin version exactly matches Flink version:
- Flink 1.20.2 → flink-s3-fs-hadoop-1.20.2.jar
- Flink 1.19.1 → flink-s3-fs-hadoop-1.19.1.jar

### Issue 4: ClassNotFoundException

**Error:**
```
java.lang.ClassNotFoundException: org.apache.hadoop.fs.s3a.S3AFileSystem
```

**Cause:** JAR is corrupted or incomplete download.

**Solution:**
```bash
# Re-download the JAR
rm /opt/flink/plugins/s3-fs-hadoop/flink-s3-fs-hadoop-*.jar
wget -P /opt/flink/plugins/s3-fs-hadoop/ \
  https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/1.20.2/flink-s3-fs-hadoop-1.20.2.jar

# Verify JAR integrity
unzip -t /opt/flink/plugins/s3-fs-hadoop/flink-s3-fs-hadoop-1.20.2.jar
```

### Issue 5: Connection Refused to MinIO

**Error:**
```
java.net.ConnectException: Connection refused
```

**Cause:** MinIO service not accessible or wrong endpoint.

**Solution:**
1. Verify MinIO is running: `kubectl get pods -n minio-dev`
2. Check service exists: `kubectl get svc -n minio-dev minio`
3. Test DNS resolution:
   ```bash
   kubectl run -it --rm dns-test --image=busybox --restart=Never -n el-demo -- \
     nslookup minio.minio-dev.svc.cluster.local
   ```
4. Verify endpoint in configuration matches service DNS name

### Issue 6: Path Style Access Error

**Error:**
```
com.amazonaws.services.s3.model.AmazonS3Exception: 
  The specified bucket is not valid
```

**Cause:** Path-style access not enabled (required for MinIO).

**Solution:** Ensure configuration has:
```yaml
s3.path.style.access: true
```

## FlinkEnvironment Configuration

For Confluent Platform Flink, update your FlinkEnvironment to use the custom image:

```yaml
apiVersion: platform.confluent.io/v1beta1
kind: FlinkEnvironment
metadata:
  name: dev-env
  namespace: confluent
spec:
  flinkApplicationDefaults:
    spec:
      # Use custom image with S3 plugin
      image: jbcodeforce/cp-flink-s3:1.20.2-s3
      imagePullPolicy: Always
      
      flinkConfiguration:
        state.checkpoints.dir: 's3a://flink/checkpoints'
        state.savepoints.dir: 's3a://flink/savepoints'
        s3.endpoint: '${S3_ENDPOINT}'
        s3.path.style.access: 'true'
        s3.access-key: '${S3_ACCESS_KEY}'
        s3.secret-key: '${S3_SECRET_KEY}'
```

## Build Instructions

### Building Custom Image

```bash
# Navigate to directory
cd /Users/jerome/Documents/Code/flink-studies/deployment/k8s/cp-flink

# Option 1: Using Docker directly
docker build -f Dockerfile.s3-enabled-alpine \
  --build-arg FLINK_VERSION=1.20.2 \
  -t your-registry/cp-flink-s3:1.20.2-s3 .

# Option 2: Using Makefile
export DOCKER_REGISTRY=your-registry
export IMAGE_NAME=cp-flink-s3
export IMAGE_TAG=1.20.2-s3
make build_flink_s3_image

# Push to registry
docker push your-registry/cp-flink-s3:1.20.2-s3
# Or
make build_and_push_flink_s3_image
```

### For Multi-Architecture Builds

```bash
# Build for both amd64 and arm64
docker buildx build -f Dockerfile.s3-enabled-alpine \
  --platform linux/amd64,linux/arm64 \
  --build-arg FLINK_VERSION=1.20.2 \
  -t your-registry/cp-flink-s3:1.20.2-s3 \
  --push .
```

## Performance Tuning

### S3A Configuration Options

For better performance with MinIO, add these properties:

```yaml
# Connection pooling
s3.connection.maximum: 100
s3.connection.timeout: 300000
s3.socket.timeout: 50000

# Multipart uploads for large files
s3.multipart.upload.enabled: true
s3.multipart.upload.min.file.size: 5242880  # 5MB
s3.multipart.upload.part.size: 5242880       # 5MB

# Concurrent operations
s3.upload.max.concurrent.uploads: 10
```

## Size Information

**JAR Size:** ~130 MB (includes all dependencies)

**Docker Image Size Increase:** ~130-150 MB when added to base Flink image

**Why so large?** The JAR includes:
- AWS SDK for Java (~40 MB)
- Hadoop S3A libraries (~30 MB)
- Apache HttpClient and dependencies (~20 MB)
- XML processing libraries (~10 MB)
- Shaded dependencies to avoid conflicts (~30 MB)

## Security Considerations

### Do NOT Include Credentials in Image

Never bake credentials into your Docker image:

```dockerfile
# ❌ BAD - Don't do this
ENV S3_ACCESS_KEY=minioadmin
ENV S3_SECRET_KEY=minioadmin
```

Instead, use Kubernetes Secrets (see `MINIO_S3_SETUP.md`).

### Use IAM Roles When Possible

For AWS S3 (not MinIO), prefer IAM roles over access keys:

```yaml
# No credentials needed - uses IAM role
s3.endpoint: https://s3.amazonaws.com
s3.path.style.access: false
```

## Additional Resources

- [Apache Flink S3 Documentation](https://nightlies.apache.org/flink/flink-docs-stable/docs/deployment/filesystems/s3/)
- [Flink Plugin System](https://nightlies.apache.org/flink/flink-docs-stable/docs/deployment/filesystems/plugins/)
- [Hadoop S3A Configuration](https://hadoop.apache.org/docs/stable/hadoop-aws/tools/hadoop-aws/index.html)
- [MinIO S3 Compatibility](https://min.io/docs/minio/linux/developers/s3-compatibility.html)

## Quick Reference

### Essential Commands

```bash
# Build custom Flink image with S3 support
make build_flink_s3_image

# Push to registry
make build_and_push_flink_s3_image

# Verify plugin in running pod
kubectl exec -n el-demo <flink-pod> -- ls -la /opt/flink/plugins/s3-fs-hadoop/

# Check Flink logs for S3 plugin loading
kubectl logs -n el-demo <flink-pod> | grep -i s3

# Test S3 connectivity from pod
kubectl exec -n el-demo <flink-pod> -- \
  /opt/flink/bin/flink run --help
```

### Version Compatibility Matrix

| Flink Version | S3 Plugin Version | Status |
|--------------|------------------|---------|
| 1.20.x | 1.20.x | ✅ Current |
| 1.19.x | 1.19.x | ✅ Supported |
| 1.18.x | 1.18.x | ⚠️ Older |
| 1.17.x | 1.17.x | ⚠️ Older |

Always use matching versions between Flink and S3 plugin!

## Summary

**Required JAR:** `flink-s3-fs-hadoop-<VERSION>.jar`

**Installation:** Place in `/opt/flink/plugins/s3-fs-hadoop/` directory

**Best Practice:** Build custom Docker image with plugin pre-installed

**Configuration:** Use Kubernetes Secrets for credentials

**Verification:** Check logs for plugin loading, test with checkpoint to MinIO

**For our setup:** Use the provided `Dockerfile.s3-enabled-alpine` and Makefile targets.

