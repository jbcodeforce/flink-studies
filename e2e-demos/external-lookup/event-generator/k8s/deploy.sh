#!/bin/bash

# Deploy Payment Event Generator to Kubernetes
# This script deploys all the necessary Kubernetes resources for the event generator

set -e

# Configuration
NAMESPACE="el-demo"
WAIT_TIMEOUT="300s"
APP_NAME="external-lookup-event-generator"
echo "🚀 Deploying Payment Event Generator to Kubernetes..."
echo "Namespace: ${NAMESPACE}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if we can connect to Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"

# Check if namespace exists, create if not
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    echo "🔧 Namespace '${NAMESPACE}' does not exist. Creating..."
    kubectl create namespace "${NAMESPACE}"
    echo "✅ Namespace '${NAMESPACE}' created."
else
    echo "✅ Namespace '${NAMESPACE}' already exists."
fi

# Function to display menu
show_deployment_menu() {
    echo ""
    echo "📋 Select deployment variant:"
    echo "1. Standard - Normal event generation (default)"
    echo "2. High-rate - High throughput testing"
    echo "3. Burst - Burst mode testing" 
    echo "4. Error-test - Error scenario testing"
    echo "5. All variants - Deploy all configurations"
    echo "0. Exit"
    echo ""
}

# Function to deploy specific variant
deploy_variant() {
    local variant=$1
    local replicas=${2:-1}
    
    echo ""
    echo "📦 Deploying ${variant} variant with ${replicas} replica(s)..."
    
    # Scale the specific deployment
    kubectl scale deployment "event-generator-${variant}" --replicas=${replicas} -n ${NAMESPACE}
    
    # Wait for deployment to be ready
    if [ ${replicas} -gt 0 ]; then
        echo "⏳ Waiting for deployment to be ready..."
        kubectl wait --for=condition=available --timeout=${WAIT_TIMEOUT} deployment/event-generator-${variant} -n ${NAMESPACE}
        
        echo "✅ ${variant} variant deployed successfully!"
        
        # Show pod status
        kubectl get pods -l app=${APP_NAME},variant=${variant} -n ${NAMESPACE}
        
        # Show recent logs
        echo ""
        echo "📋 Recent logs:"
        POD_NAME=$(kubectl get pods -l app=${APP_NAME},variant=${variant} -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
        if [ -n "$POD_NAME" ]; then
            kubectl logs "$POD_NAME" -n ${NAMESPACE} --tail=10
        fi
    else
        echo "✅ ${variant} variant scaled down to 0"
    fi
}

# Function to show status
show_status() {
    echo ""
    echo "🔍 Current deployment status:"
    kubectl get deployments -l app=${APP_NAME} -n ${NAMESPACE}
    
    echo ""
    echo "📊 Pod status:"
    kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE}
    
    echo ""
    echo "🌐 Service status:"
    kubectl get services -l app=${APP_NAME} -n ${NAMESPACE}
}

# Function to show metrics
show_metrics_info() {
    echo ""
    echo "📈 Metrics Access:"
    echo "1. Port forward for metrics access:"
    echo "   kubectl port-forward svc/event-generator-metrics 8090:8090 -n ${NAMESPACE}"
    echo "   Then access: http://localhost:8090/metrics"
    echo ""
    echo "2. NodePort access (if enabled):"
    echo "   http://localhost:30090/metrics"
    echo ""
    echo "3. Internal cluster access:"
    echo "   http://event-generator-metrics.${NAMESPACE}.svc.cluster.local:8090/metrics"
}

# Apply base configurations first
echo ""
echo "📦 Applying base configurations..."
kubectl apply -f configmap.yaml
kubectl apply -f service.yaml
kubectl apply -f deployment.yaml

echo "✅ Base configurations applied"

# Interactive deployment menu
if [ "$1" = "auto" ]; then
    # Auto mode - deploy standard variant only
    deploy_variant "standard" 1
    show_metrics_info
elif [ "$1" = "all" ]; then
    # Deploy all variants
    deploy_variant "standard" 1
    deploy_variant "high-rate" 0  # Start with 0 replicas
    deploy_variant "burst" 0      # Start with 0 replicas  
    deploy_variant "error-test" 0 # Start with 0 replicas
    echo "✅ All variants deployed (only standard is active)"
    show_metrics_info
else
    # Interactive mode
    while true; do
        show_status
        show_deployment_menu
        read -p "Select option (1-5, 0 to exit): " choice
        
        case $choice in
            1)
                deploy_variant "standard" 1
                ;;
            2)
                deploy_variant "high-rate" 1
                ;;
            3)
                deploy_variant "burst" 1
                ;;
            4)
                deploy_variant "error-test" 1
                ;;
            5)
                deploy_variant "standard" 1
                deploy_variant "high-rate" 1
                deploy_variant "burst" 1
                deploy_variant "error-test" 1
                echo "✅ All variants deployed"
                ;;
            0)
                echo "👋 Goodbye!"
                break
                ;;
            *)
                echo "❌ Invalid option. Please select 0-5."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
fi

show_metrics_info

echo ""
echo "🎯 Useful Commands:"
echo "View logs: kubectl logs -l app=${APP_NAME} -f -n ${NAMESPACE}"
echo "Scale deployment: kubectl scale deployment event-generator-standard --replicas=2 -n ${NAMESPACE}"
echo "Delete all: kubectl delete -f . -n ${NAMESPACE}"
echo ""
echo "🧪 Test Commands:"
echo "Test scenarios: kubectl exec -it deployment/event-generator-standard -- payment-generator scenarios"
echo "Validate claims: kubectl exec -it deployment/event-generator-standard -- payment-generator validate-claims"
