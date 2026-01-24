#!/bin/bash
# Troubleshooting script for Docker pull issues

set -e

IMAGE="confluentinc/cp-flink-kubernetes-operator:1.13.0-cp2"

echo "=== Docker Pull Troubleshooting ==="
echo "Image: $IMAGE"
echo ""

# 1. Check Docker daemon
echo "1. Checking Docker daemon status..."
if ! docker info > /dev/null 2>&1; then
    echo "   ❌ Docker daemon is not running!"
    echo "   Please start Docker/OrbStack and try again."
    exit 1
fi
echo "   ✅ Docker daemon is running"

# 2. Check disk space
echo ""
echo "2. Checking disk space..."
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "   ⚠️  Disk usage is ${DISK_USAGE}% - consider freeing space"
else
    echo "   ✅ Disk space available (${DISK_USAGE}% used)"
fi

# 3. Test network connectivity
echo ""
echo "3. Testing Docker Hub connectivity..."
if curl -s -I https://registry-1.docker.io/v2/ | grep -q "401\|200"; then
    echo "   ✅ Can reach Docker Hub"
else
    echo "   ❌ Cannot reach Docker Hub - check your network"
    exit 1
fi

# 4. Clear any stuck downloads
echo ""
echo "4. Cleaning up Docker system..."
docker system prune -f > /dev/null 2>&1
echo "   ✅ Cleanup complete"

# 5. Try pulling with different options
echo ""
echo "5. Attempting to pull image with verbose output..."
echo "   This may take several minutes for large images..."
echo ""

# Try with platform specification and progress
if docker pull "$IMAGE" --platform linux/amd64 --progress=plain; then
    echo ""
    echo "✅ Successfully pulled $IMAGE"
    docker images | grep cp-flink-kubernetes-operator
else
    echo ""
    echo "❌ Pull failed. Trying alternative approaches..."
    echo ""
    echo "Alternative solutions:"
    echo "  a) Restart OrbStack/Docker Desktop completely"
    echo "  b) Try pulling without platform specification:"
    echo "     docker pull $IMAGE"
    echo "  c) Check if the tag exists:"
    echo "     Visit: https://hub.docker.com/r/confluentinc/cp-flink-kubernetes-operator/tags"
    echo "  d) Try a different version/tag"
    echo "  e) Increase Docker timeout in settings"
    exit 1
fi
