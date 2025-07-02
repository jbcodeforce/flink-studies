#!/bin/bash

# Build script for Flink Table API Deduplication Job

set -e

APP_NAME="flink-dedup-app"
APP_VERSION="1.0.0"
REGISTRY="${DOCKER_REGISTRY:-}"
IMAGE_NAME="${APP_NAME}:${APP_VERSION}"

if [ -n "$REGISTRY" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}"
fi

echo "🚀 Building Flink Table API Deduplication Job"
echo "=============================================="
echo "App Name: ${APP_NAME}"
echo "Version: ${APP_VERSION}"
echo "Image: ${FULL_IMAGE_NAME}"
echo ""

# Step 1: Clean and compile the Java application
echo "📦 Step 1: Building Java application with Maven..."
if ! command -v mvn &> /dev/null; then
    echo "❌ Error: Maven not found!"
    echo "   Please install Maven to build the Java application."
    echo "   macOS: brew install maven"
    echo "   Ubuntu: sudo apt-get install maven"
    echo "   CentOS: sudo yum install maven"
    exit 1
fi

mvn clean package -DskipTests
echo "✅ Java application built successfully"
echo ""

# Step 2: Build Docker image
echo "🐳 Step 2: Building Docker image..."
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker not found!"
    echo "   Please install Docker to build the container image."
    exit 1
fi

docker build -t "${FULL_IMAGE_NAME}" .
echo "✅ Docker image built successfully: ${FULL_IMAGE_NAME}"
echo ""

# Step 3: Tag for local Kubernetes if no registry specified
if [ -z "$REGISTRY" ]; then
    echo "🏷️  Step 3: Tagging for local Kubernetes..."
    docker tag "${FULL_IMAGE_NAME}" "${APP_NAME}:latest"
    echo "✅ Tagged as ${APP_NAME}:latest for local use"
    echo ""
    
    echo "📋 For local Kubernetes deployment:"
    echo "   minikube: minikube image load ${IMAGE_NAME}"
    echo "   kind: kind load docker-image ${IMAGE_NAME}"
    echo ""
else
    echo "🚀 Step 3: Pushing to registry..."
    docker push "${FULL_IMAGE_NAME}"
    echo "✅ Pushed to registry: ${FULL_IMAGE_NAME}"
    echo ""
fi

# Step 4: Display next steps
echo "🎯 Next Steps:"
echo "=============="
echo ""
echo "1. Load image to local Kubernetes (if using local cluster):"
echo "   for colima:  docker images"
echo "   minikube image load ${IMAGE_NAME}"
echo "   # OR"
echo "   kind load docker-image ${IMAGE_NAME}"
echo ""
echo "2. Deploy to Kubernetes:"
echo "   kubectl apply -f k8s/"
echo ""
echo "3. Check job status:"
echo "   kubectl get pods -n flink"
echo "   kubectl logs -f <pod-name> -n flink"
echo ""
echo "4. Monitor Flink Web UI:"
echo "   kubectl port-forward svc/flink-jobmanager 8081:8081 -n flink"
echo "   Open http://localhost:8081"
echo ""

echo "✅ Build completed successfully!" 