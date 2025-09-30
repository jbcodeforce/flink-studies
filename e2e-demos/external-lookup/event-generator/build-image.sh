#!/bin/bash

# Build Payment Event Generator Container
# This script builds the Docker image for the Kafka event generator

set -e

# Configuration
IMAGE_NAME="external-lookup-event-generator"
IMAGE_TAG="latest"
DOCKERFILE_PATH="."

echo "🏗️  Building Payment Event Generator Image..."
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Context: ${DOCKERFILE_PATH}"

# Build the Docker image
docker build \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile \
    "${DOCKERFILE_PATH}"

echo "✅ Successfully built ${IMAGE_NAME}:${IMAGE_TAG}"

# Show image info
echo ""
echo "📊 Image Information:"
docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

echo ""
echo "🎯 Next Steps:"
echo "1. Test the image locally:"
echo "   docker run -e PAYMENT_GEN_DRY_RUN=true ${IMAGE_NAME}:${IMAGE_TAG} generate --rate 5 --duration 10"
echo ""
echo "2. Test with Kafka (ensure Kafka is running):"
echo "   docker run -e PAYMENT_GEN_KAFKA_BOOTSTRAP_SERVERS=host.docker.internal:9092 \\"
echo "              ${IMAGE_NAME}:${IMAGE_TAG} generate --rate 2 --duration 30"
echo ""
echo "3. For local Kubernetes (colima/minikube/kind):"
echo "   # Image is already available in local Docker daemon"
echo ""
echo "4. Deploy to Kubernetes:"
echo "   kubectl apply -f k8s/"
echo ""
echo "5. Test scenarios:"
echo "   docker run ${IMAGE_NAME}:${IMAGE_TAG} scenarios"
echo ""
echo "6. Validate claims database:"
echo "   docker run ${IMAGE_NAME}:${IMAGE_TAG} validate-claims --database-url http://host.docker.internal:8080"

