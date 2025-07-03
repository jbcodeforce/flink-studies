#!/bin/bash

# Build script for SQL Runner with the SQL deduplication logic Docker image

set -e

APP_NAME="flink-sql-runner"
APP_VERSION="1.0.0"
REGISTRY="${DOCKER_REGISTRY:-}"
IMAGE_NAME="${APP_NAME}:${APP_VERSION}"
SQL_RUNNER_PROJECT="../../../code/flink-java/sql-runner"
CURRENT_DIR=$(pwd)
TAG="${1:-latest}"

if [ -n "$REGISTRY" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}"
fi

echo "📦 Step 1: Building Java application with Maven..."
if ! command -v mvn &> /dev/null; then
    echo "❌ Error: Maven not found!"
    echo "   Please install Maven to build the Java application."
    echo "   macOS: brew install maven"
    echo "   Ubuntu: sudo apt-get install maven"
    echo "   CentOS: sudo yum install maven"
    exit 1
fi

echo "🏗️  Building Docker image for SQL Runner with the SQL deduplication logic..."
echo "App Name: ${APP_NAME}"
echo "Version: ${APP_VERSION}"
echo "Image: ${FULL_IMAGE_NAME}"
echo ""

cd ${SQL_RUNNER_PROJECT}
mvn clean package -DskipTests
echo "✅ Java application built successfully"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build the image
echo "📦 Building Docker image..."
cd ${CURRENT_DIR}
cp ${SQL_RUNNER_PROJECT}/target/flink-sql-quarkus-*.jar ./flink-sql-runner.jar
echo "✅ Jar file copied successfully"
echo ""

docker build -t "${FULL_IMAGE_NAME}" .
echo "✅ Docker image built successfully"
echo ""


rm -f ./flink-sql-runner.jar
echo "🧹 Cleaned up temporary jar file"
echo ""

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
echo "   # Deploy the application"
echo "   kubectl apply -f k8s/deployment.yaml"
echo ""
echo "   # Monitor logs"
echo "   kubectl logs -f dedup-demo-producer -n confluent" 