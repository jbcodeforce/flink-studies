#!/bin/bash

# Build Script
set -e

# Configuration
IMAGE_NAME="jbcodeforce/orders-producer"
IMAGE_TAG="${1:-latest}"
REGISTRY="${REGISTRY:-}"

echo "🚀 Building Flink Resource Estimator Docker Image"
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"

# Build Docker image
echo "📦 Building Docker image..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

# Tag for registry if specified
if [ -n "$REGISTRY" ]; then
    echo "🏷️  Tagging for registry: ${REGISTRY}"
    docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
fi

echo "✅ Build completed successfully!"
echo ""
echo "🎯 Next steps:"
echo "  Push to registry:  docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Deploy to K8s:     kubectl apply -f cp-flink/producer_api_pod.yaml"
echo ""

# Show image info
echo "📊 Image information:"
docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" 