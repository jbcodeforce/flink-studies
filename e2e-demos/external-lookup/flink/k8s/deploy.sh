#!/bin/bash

# Payment Claims Enrichment - Kubernetes Deployment Script
# This script deploys the Flink Table API application to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="payment-claims-enrichment"
NAMESPACE="el-demo"
DEPLOYMENT_MODE="standalone"  # standalone, operator, session
WAIT_TIMEOUT="300s"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists kubectl; then
        print_error "kubectl not found. Please install kubectl"
        exit 1
    fi
    
    if ! command_exists docker; then
        print_warning "docker not found. Make sure Docker images are available in cluster"
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster. Check your kubeconfig"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    print_status "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_warning "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        print_success "Created namespace: $NAMESPACE"
    fi
    
    # Set current context to the namespace
    kubectl config set-context --current --namespace="$NAMESPACE"
}

# Apply RBAC configuration
apply_rbac() {
    print_status "Applying RBAC configuration..."
    kubectl apply -f "$SCRIPT_DIR/rbac.yaml"
    print_success "RBAC configuration applied"
}

# Apply storage configuration
apply_storage() {
    print_status "Applying storage configuration..."
    kubectl apply -f "$SCRIPT_DIR/storage.yaml"
    
    # Wait for PVCs to be bound
    print_status "Waiting for PersistentVolumeClaims to be bound..."
    kubectl wait --for=condition=Bound pvc/flink-checkpoints --timeout="$WAIT_TIMEOUT" || {
        print_warning "PVC flink-checkpoints not bound within timeout"
    }
    kubectl wait --for=condition=Bound pvc/flink-savepoints --timeout="$WAIT_TIMEOUT" || {
        print_warning "PVC flink-savepoints not bound within timeout"
    }
    
    print_success "Storage configuration applied"
}

# Apply ConfigMaps and Secrets
apply_config() {
    print_status "Applying configuration..."
    kubectl apply -f "$SCRIPT_DIR/configmap.yaml"
    print_success "Configuration applied"
}

# Build and push Docker image (optional)
build_and_push_image() {
    if [ "$BUILD_IMAGE" = "true" ]; then
        print_status "Building and pushing Docker image..."
        
        cd "$SCRIPT_DIR/.."
        ./build.sh --docker
        
        # Tag and push to registry if specified
        if [ -n "$DOCKER_REGISTRY" ]; then
            IMAGE_TAG="${DOCKER_REGISTRY}/${APP_NAME}:${IMAGE_VERSION:-latest}"
            docker tag "${APP_NAME}:latest" "$IMAGE_TAG"
            docker push "$IMAGE_TAG"
            print_success "Image pushed to: $IMAGE_TAG"
        fi
        
        cd "$SCRIPT_DIR"
    fi
}

# Deploy Flink application based on mode
deploy_flink() {
    case "$DEPLOYMENT_MODE" in
        "standalone")
            deploy_standalone
            ;;
        "operator")
            deploy_with_operator
            ;;
        "session")
            deploy_session_mode
            ;;
        *)
            print_error "Unknown deployment mode: $DEPLOYMENT_MODE"
            exit 1
            ;;
    esac
}

# Deploy standalone Flink cluster
deploy_standalone() {
    print_status "Deploying standalone Flink cluster..."
    
    # Apply Flink cluster deployment
    kubectl apply -f "$SCRIPT_DIR/flink-cluster.yaml"
    
    # Apply services
    kubectl apply -f "$SCRIPT_DIR/services.yaml"
    
    # Apply networking
    kubectl apply -f "$SCRIPT_DIR/networking.yaml"
    
    # Wait for JobManager to be ready
    print_status "Waiting for Flink JobManager to be ready..."
    kubectl wait --for=condition=Ready pod -l component=jobmanager --timeout="$WAIT_TIMEOUT"
    
    # Wait for TaskManagers to be ready
    print_status "Waiting for Flink TaskManagers to be ready..."
    kubectl wait --for=condition=Ready pod -l component=taskmanager --timeout="$WAIT_TIMEOUT"
    
    print_success "Standalone Flink cluster deployed successfully"
}

# Deploy with Flink Kubernetes Operator
deploy_with_operator() {
    print_status "Deploying with Flink Kubernetes Operator..."
    
    # Check if Flink Operator is installed
    if ! kubectl get crd flinkdeployments.flink.apache.org >/dev/null 2>&1; then
        print_error "Flink Kubernetes Operator not found. Please install it first:"
        print_error "kubectl apply -f https://github.com/apache/flink-kubernetes-operator/releases/latest/download/flink-kubernetes-operator.yaml"
        exit 1
    fi
    
    kubectl apply -f "$SCRIPT_DIR/flink-operator.yaml"
    
    # Wait for FlinkDeployment to be ready
    print_status "Waiting for FlinkDeployment to be ready..."
    kubectl wait --for=condition=Ready flinkdeployment/payment-claims-enrichment --timeout="$WAIT_TIMEOUT"
    
    print_success "Flink application deployed with operator"
}

# Deploy in session mode
deploy_session_mode() {
    print_status "Deploying Flink session cluster..."
    
    # First deploy session cluster
    kubectl apply -f "$SCRIPT_DIR/flink-operator.yaml"
    
    # Wait for session cluster
    kubectl wait --for=condition=Ready flinkdeployment/payment-claims-enrichment-session --timeout="$WAIT_TIMEOUT"
    
    # Then deploy session job
    kubectl apply -f "$SCRIPT_DIR/flink-operator.yaml"
    
    print_success "Flink session mode deployed"
}

# Check deployment status
check_deployment_status() {
    print_status "Checking deployment status..."
    
    echo "Pods:"
    kubectl get pods -l app="$APP_NAME"
    
    echo -e "\nServices:"
    kubectl get services -l app="$APP_NAME"
    
    echo -e "\nDeployments:"
    kubectl get deployments -l app="$APP_NAME"
    
    if [ "$DEPLOYMENT_MODE" = "operator" ]; then
        echo -e "\nFlink Deployments:"
        kubectl get flinkdeployments
    fi
    
    # Check if JobManager is accessible
    if kubectl get service flink-jobmanager >/dev/null 2>&1; then
        JOBMANAGER_URL=$(kubectl get service flink-jobmanager -o jsonpath='{.spec.clusterIP}'):8081
        print_status "Flink Web UI should be accessible at: http://$JOBMANAGER_URL"
    fi
    
    # Show ingress information
    if kubectl get ingress flink-webui-ingress >/dev/null 2>&1; then
        echo -e "\nIngress:"
        kubectl get ingress flink-webui-ingress
        INGRESS_HOST=$(kubectl get ingress flink-webui-ingress -o jsonpath='{.spec.rules[0].host}')
        print_status "Flink Web UI available at: http://$INGRESS_HOST"
    fi
}

# Setup port forwarding for local access
setup_port_forwarding() {
    if [ "$SETUP_PORT_FORWARD" = "true" ]; then
        print_status "Setting up port forwarding..."
        
        # Forward Flink Web UI
        kubectl port-forward service/flink-jobmanager 8081:8081 &
        PF_PID=$!
        
        print_success "Port forwarding setup complete:"
        print_success "  Flink Web UI: http://localhost:8081"
        print_status "To stop port forwarding, run: kill $PF_PID"
        
        # Save PID for cleanup
        echo $PF_PID > /tmp/flink-port-forward.pid
    fi
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -m, --mode MODE         Deployment mode: standalone, operator, session (default: standalone)"
    echo "  -n, --namespace NS      Kubernetes namespace (default: flink)"
    echo "  -b, --build             Build and push Docker image"
    echo "  -r, --registry REG      Docker registry for image push"
    echo "  -v, --version VER       Image version tag (default: latest)"
    echo "  -p, --port-forward      Setup port forwarding for local access"
    echo "  -w, --wait TIMEOUT      Wait timeout (default: 300s)"
    echo "  --dry-run              Show what would be deployed without applying"
    echo
    echo "Examples:"
    echo "  $0                                    # Deploy with default settings"
    echo "  $0 --mode operator                    # Deploy with Flink Operator"
    echo "  $0 --build --registry myregistry.com # Build and push image"
    echo "  $0 --port-forward                     # Deploy with port forwarding"
}

# Parse command line arguments
BUILD_IMAGE=false
SETUP_PORT_FORWARD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -m|--mode)
            DEPLOYMENT_MODE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -b|--build)
            BUILD_IMAGE=true
            shift
            ;;
        -r|--registry)
            DOCKER_REGISTRY="$2"
            shift 2
            ;;
        -v|--version)
            IMAGE_VERSION="$2"
            shift 2
            ;;
        -p|--port-forward)
            SETUP_PORT_FORWARD=true
            shift
            ;;
        -w|--wait)
            WAIT_TIMEOUT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main deployment process
main() {
    print_status "Starting deployment of $APP_NAME..."
    print_status "Mode: $DEPLOYMENT_MODE, Namespace: $NAMESPACE"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_warning "DRY RUN MODE - No changes will be applied"
        kubectl apply --dry-run=client -f "$SCRIPT_DIR/"*.yaml
        return 0
    fi
    
    check_prerequisites
    create_namespace
    apply_rbac
    apply_storage
    apply_config
    build_and_push_image
    deploy_flink
    check_deployment_status
    setup_port_forwarding
    
    print_success "Deployment completed successfully!"
    print_status "Next steps:"
    print_status "  1. Check deployment: kubectl get pods -n $NAMESPACE"
    print_status "  2. View logs: kubectl logs -f deployment/flink-jobmanager -n $NAMESPACE"
    print_status "  3. Access Web UI: kubectl port-forward service/flink-jobmanager 8081:8081 -n $NAMESPACE"
}

# Run main function
main "$@"
