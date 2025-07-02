#!/bin/bash

# Build script for dedup-demo producer Docker image

set -e

# Configuration
IMAGE_NAME="dedup-demo-producer"
TAG="${1:-latest}"
REGISTRY="${REGISTRY:-localhost:5000}"  # Default to local registry
FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "🏗️  Building Docker image for dedup-demo producer..."
echo "Image: ${FULL_IMAGE_NAME}"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build the image
echo "📦 Building Docker image..."
docker build -t "${IMAGE_NAME}:${TAG}" .

# Tag for registry
if [ "${REGISTRY}" != "localhost:5000" ]; then
    echo "🏷️  Tagging image for registry: ${REGISTRY}"
    docker tag "${IMAGE_NAME}:${TAG}" "${FULL_IMAGE_NAME}"
fi

echo "✅ Build completed successfully!"
echo ""
echo "📋 Next steps:"
echo ""

if [ "${REGISTRY}" == "localhost:5000" ]; then
    echo "🚀 For local Kubernetes (minikube/kind):"
    echo "   # Load image into minikube"
    echo "   minikube image load ${IMAGE_NAME}:${TAG}"
    echo ""
    echo "   # Or for kind"
    echo "   kind load docker-image ${IMAGE_NAME}:${TAG}"
    echo ""
    echo "   # Update k8s/producer-pod.yaml to use:"
    echo "   image: ${IMAGE_NAME}:${TAG}"
    echo "   imagePullPolicy: Never"
else
    echo "🚀 For remote registry:"
    echo "   # Push to registry"
    echo "   docker push ${FULL_IMAGE_NAME}"
    echo ""
    echo "   # Update k8s/producer-pod.yaml to use:"
    echo "   image: ${FULL_IMAGE_NAME}"
fi

echo ""
echo "   # Deploy the producer"
echo "   kubectl apply -f k8s/products-topic.yaml"
echo "   kubectl apply -f k8s/producer-pod.yaml"
echo ""
echo "   # Monitor logs"
echo "   kubectl logs -f dedup-demo-producer -n confluent" 