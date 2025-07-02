# Docker Image for Dedup Demo Producer

This directory contains the Docker configuration for building a containerized version of the dedup-demo producer.

## File Structure

```
dedup-demo/
├── Dockerfile              # Multi-stage Docker build
├── .dockerignore           # Files to exclude from build context
├── build-image.sh          # Build and tag script
├── product_producer.py     # Main application code
├── pyproject.toml          # Python dependencies
└── k8s/
    ├── producer-pod.yaml   # Kubernetes pod using the image
    └── products-topic.yaml # Kafka topic configuration
```

## Docker Image Features

### Base Image
- **Python 3.11 slim** - Lightweight official Python image
- **Non-root user** - Runs as `appuser` for security
- **Multi-arch support** - Compatible with AMD64 and ARM64

### Dependencies
- **System packages**: gcc, libc6-dev, librdkafka-dev, pkg-config
- **Python packages**: confluent-kafka, pydantic
- **Optimized layers** - Separate dependency and code layers for better caching

### Security & Best Practices
- Non-root user execution
- Minimal system packages
- Health check included
- No cache for pip packages
- Environment variables for configuration

## Building the Image

### Quick Build

```bash
# Build with default settings (latest tag)
./build-image.sh

# Build with specific tag
./build-image.sh v1.0.0
```

### Manual Build

```bash
# Build locally
docker build -t dedup-demo-producer:latest .

# Build for specific platform
docker build --platform linux/amd64 -t dedup-demo-producer:latest .
```

### Registry Build

```bash
# For remote registry
export REGISTRY=your-registry.com
./build-image.sh v1.0.0

# Push to registry
docker push your-registry.com/dedup-demo-producer:v1.0.0
```

## Local Kubernetes Usage

### Colima

Colima is integrated with the container runtime you've chosen (Docker or containerd) on your local machine

### Minikube

```bash
# Build and load into minikube
./build-image.sh
minikube image load dedup-demo-producer:latest

# Update pod to use local image
# In k8s/producer-pod.yaml, set:
#   imagePullPolicy: Never
```

### Kind (Kubernetes in Docker)

```bash
# Build and load into kind
./build-image.sh
kind load docker-image dedup-demo-producer:latest
```

### Docker Desktop Kubernetes

```bash
# Build locally (image automatically available)
./build-image.sh

# No additional loading required
```

## Environment Variables

The Docker image accepts the same environment variables as the Python script:

| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka.confluent.svc.cluster.local:9071` | Kafka brokers |
| `KAFKA_PRODUCT_TOPIC` | `products` | Topic name |
| `KAFKA_SECURITY_PROTOCOL` | `PLAINTEXT` | Security protocol |
| `KAFKA_SASL_MECHANISM` | `PLAIN` | SASL mechanism |
| `KAFKA_USER` | `` | Username (if auth required) |
| `KAFKA_PASSWORD` | `` | Password (if auth required) |
| `KAFKA_CERT` | `` | SSL certificate path |

## Health Checks

The image includes a health check that verifies Python dependencies:

```bash
# Manual health check
docker run --rm dedup-demo-producer:latest python -c "import confluent_kafka, pydantic; print('Dependencies OK')"
```

## Debugging

### Run Interactive Shell

```bash
docker run -it --entrypoint /bin/bash dedup-demo-producer:latest
```

### Check Logs

```bash
# When running as Kubernetes pod
kubectl logs dedup-demo-producer -n confluent -f

# When running as Docker container
docker logs <container-id> -f
```

### Test Locally

```bash
# Run with local Kafka
docker run --rm \
  -e KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
  --network host \
  dedup-demo-producer:latest
```

## Troubleshooting

### Build Issues

1. **Docker not running**:
   ```bash
   # Check Docker status
   docker info
   ```

2. **Permission denied**:
   ```bash
   # Make build script executable
   chmod +x build-image.sh
   ```

3. **Platform issues** (M1 Mac):
   ```bash
   # Build for specific platform
   docker build --platform linux/amd64 -t dedup-demo-producer:latest .
   ```

### Runtime Issues

1. **Connection refused**:
   - Check Kafka service is running
   - Verify bootstrap servers configuration
   - Ensure network connectivity

2. **Image not found**:
   - For local clusters: ensure image is loaded
   - For remote clusters: verify image is pushed and accessible

3. **Permission errors**:
   - Image runs as non-root user `appuser`
   - Ensure mounted volumes have correct permissions

## Production Considerations

### Registry Strategy

```bash
# Tag with version and latest
docker tag dedup-demo-producer:latest your-registry.com/dedup-demo-producer:v1.0.0
docker tag dedup-demo-producer:latest your-registry.com/dedup-demo-producer:latest

# Push both tags
docker push your-registry.com/dedup-demo-producer:v1.0.0
docker push your-registry.com/dedup-demo-producer:latest
```

### Security Scanning

```bash
# Scan image for vulnerabilities
docker scout cves dedup-demo-producer:latest

# Or use other tools like Trivy
trivy image dedup-demo-producer:latest
```

### Resource Limits

The Kubernetes pod is configured with:
- **Requests**: 64Mi memory, 50m CPU
- **Limits**: 128Mi memory, 100m CPU

Adjust these in `k8s/producer-pod.yaml` based on your requirements. 