#!/bin/bash

# Build DuckDB External Lookup Database Container
# This script builds the Docker image for the DuckDB HTTP API

set -e

# Configuration
IMAGE_NAME="duckdb-external-lookup"
IMAGE_TAG="latest"
DOCKERFILE_PATH="."

echo "🏗️  Building DuckDB External Lookup Database Image..."
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
echo "   docker run -p 8080:8080 ${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "2. For local Kubernetes (colima/minikube/kind):"
echo "   # Image is already available in local Docker daemon"
echo ""
echo "3. Deploy to Kubernetes:"
echo "   kubectl apply -f ./k8s/"
echo ""
echo "4. Test the API:"
echo "   curl http://localhost:8080/health"
echo "   curl http://localhost:8080/claims/CLM-001"
