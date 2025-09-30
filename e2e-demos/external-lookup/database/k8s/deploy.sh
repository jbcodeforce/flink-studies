#!/bin/bash

# Deploy DuckDB External Lookup to Kubernetes
# This script deploys all the necessary Kubernetes resources with proper persistent storage

set -e

# Configuration
NAMESPACE="duckdb"
APP_NAME="duckdb-external-lookup"
WAIT_TIMEOUT="300s"
DATABASE_DATA_PATH="/Users/jerome/Documents/Code/flink-studies/e2e-demos/external-lookup/database/data"

echo "🚀 Deploying DuckDB External Lookup to Kubernetes..."
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


# Detect Kubernetes environment
detect_k8s_environment() {
    local cluster_context=$(kubectl config current-context)
    local cluster_info=$(kubectl cluster-info)
    
    if [[ "$cluster_context" == *"colima"* ]] || [[ "$cluster_info" == *"colima"* ]]; then
        echo "colima"
    elif [[ "$cluster_context" == *"kind"* ]] || [[ "$cluster_info" == *"kind"* ]]; then
        echo "kind"
    else
        # Try to detect by checking for kind-specific nodes
        if kubectl get nodes -o wide | grep -q "kind-"; then
            echo "kind"
        else
            echo "unknown"
        fi
    fi
}

# Setup persistent storage based on environment
setup_persistent_storage() {
    local env=$(detect_k8s_environment)
    echo "🔍 Detected Kubernetes environment: $env"
    
    case "$env" in
        "colima")
            echo "🗄️  Setting up storage for direct database data folder..."
            echo "Using existing database directory: $DATABASE_DATA_PATH"
            if [ ! -d "$DATABASE_DATA_PATH" ]; then
                echo "❌ Database data directory does not exist: $DATABASE_DATA_PATH"
                echo "Please run the Docker container first to create the database file."
                exit 1
            fi
            
            # Apply PV using template file with substitution
            echo "📦 Applying PersistentVolume from template..."
            sed -e "s|__APP_NAME__|${APP_NAME}|g" \
                -e "s|__DATABASE_DATA_PATH__|${DATABASE_DATA_PATH}|g" \
                persistent-volume-template.yaml | kubectl apply -f -
            ;;
        "kind")
            echo "🗄️  Setting up storage for direct database data folder (kind)..."
            echo "Using existing database directory: $DATABASE_DATA_PATH"
            if [ ! -d "$DATABASE_DATA_PATH" ]; then
                echo "❌ Database data directory does not exist: $DATABASE_DATA_PATH"
                echo "Please run the Docker container first to create the database file."
                exit 1
            fi
            
            # Apply PV using template file with substitution
            echo "📦 Applying PersistentVolume from template..."
            sed -e "s|__APP_NAME__|${APP_NAME}|g" \
                -e "s|__DATABASE_DATA_PATH__|${DATABASE_DATA_PATH}|g" \
                persistent-volume-template.yaml | kubectl apply -f -
            ;;
        *)
            echo "⚠️  Unknown Kubernetes environment. Using direct database data folder..."
            echo "Using existing database directory: $DATABASE_DATA_PATH"
            if [ ! -d "$DATABASE_DATA_PATH" ]; then
                echo "❌ Database data directory does not exist: $DATABASE_DATA_PATH"
                echo "Please run the Docker container first to create the database file."
                exit 1
            fi
            
            # Apply PV using template file with substitution
            echo "📦 Applying PersistentVolume from template..."
            sed -e "s|__APP_NAME__|${APP_NAME}|g" \
                -e "s|__DATABASE_DATA_PATH__|${DATABASE_DATA_PATH}|g" \
                persistent-volume-template.yaml | kubectl apply -f -
            ;;
    esac
    
    # Note: Using manual PV/PVC binding (no StorageClass needed)
    echo "📦 Using manual PV/PVC binding for direct data folder access"
    
    # Wait a moment for PV to be available
    echo "⏳ Waiting for PersistentVolume to be available..."
    sleep 2
    
    # Check PV status
    kubectl get pv -l app=${APP_NAME}
}

# Verify storage setup
verify_storage() {
    echo "🔍 Verifying storage setup..."
    
    # Check if PV exists and is available
    if kubectl get pv duckdb-pv &>/dev/null; then
        local pv_status=$(kubectl get pv duckdb-pv -o jsonpath='{.status.phase}')
        echo "PersistentVolume status: $pv_status"
        
        if [[ "$pv_status" != "Available" && "$pv_status" != "Bound" ]]; then
            echo "⚠️  PersistentVolume is not ready. Status: $pv_status"
        fi
    else
        echo "❌ PersistentVolume 'duckdb-pv' not found"
        return 1
    fi
    
    # Check StorageClass
    if kubectl get storageclass hostpath &>/dev/null; then
        echo "✅ StorageClass 'hostpath' is ready"
    else
        echo "❌ StorageClass 'hostpath' not found"
        return 1
    fi
    
    return 0
}

# Setup persistent storage first
echo ""
setup_persistent_storage

# Verify storage is ready
if ! verify_storage; then
    echo "❌ Storage setup failed. Aborting deployment."
    exit 1
fi

# Apply configurations in order
echo ""
echo "📦 Deploying ConfigMap..."
kubectl apply -f duckdb-configmap.yaml

echo ""
echo "💾 Deploying PersistentVolumeClaim and Deployment..."
kubectl apply -f duckdb-deployment.yaml

echo ""
echo "🌐 Deploying Service..."
kubectl apply -f duckdb-service.yaml

# Wait for PVC to bind
echo ""
echo "⏳ Waiting for PersistentVolumeClaim to bind..."
kubectl wait --for=condition=bound pvc/duckdb-pvc --timeout=60s -n ${NAMESPACE} || {
    echo "⚠️  PVC binding timeout, checking status..."
    kubectl describe pvc duckdb-pvc -n ${NAMESPACE}
}

# Wait for deployment to be ready
echo ""
echo "⏳ Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=${WAIT_TIMEOUT} deployment/${APP_NAME} -n ${NAMESPACE}

echo ""
echo "🔍 Checking deployment status..."
kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE}

# Show service information
echo ""
echo "🌐 Service Information:"
kubectl get services -l app=${APP_NAME} -n ${NAMESPACE}

echo ""
echo "🗄️  Storage Information:"
echo "PersistentVolume:"
kubectl get pv duckdb-pv -o wide
echo ""
echo "PersistentVolumeClaim:"
kubectl get pvc duckdb-pvc -n ${NAMESPACE} -o wide

# Get pod logs
echo ""
echo "📋 Recent Pod Logs:"
POD_NAME=$(kubectl get pods -l app=external-lookup-duckdb -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD_NAME" ]; then
    kubectl logs "$POD_NAME" -n ${NAMESPACE} --tail=20
else
    echo "No pods found"
fi

echo ""
echo "✅ Deployment completed successfully!"

echo ""
echo "🎯 Access Instructions:"
echo "1. Internal cluster access:"
echo "   http://duckdb-external-lookup.${NAMESPACE}.svc.cluster.local:8080"
echo ""
echo "2. Port forward for local testing:"
echo "   kubectl port-forward svc/duckdb-external-lookup 8080:8080 -n ${NAMESPACE}"
echo "   Then access: http://localhost:8080"
echo ""
echo "3. NodePort access (if enabled):"
echo "   http://localhost:30080"
echo ""
echo "🧪 Test Commands:"
echo "   kubectl port-forward svc/duckdb-external-lookup 8080:8080 -n ${NAMESPACE} &"
echo "   curl http://localhost:8080/health"
echo "   curl http://localhost:8080/claims/CLM-001"
echo "   curl http://localhost:8080/stats"

echo ""
echo "🔧 Troubleshooting Commands:"
echo "   Check PVC status: kubectl describe pvc duckdb-pvc -n ${NAMESPACE}"
echo "   Check PV status: kubectl describe pv duckdb-pv"
echo "   Check pod events: kubectl describe pod -l app=external-lookup-duckdb -n ${NAMESPACE}"
echo "   View full logs: kubectl logs -l app=external-lookup-duckdb -f -n ${NAMESPACE}"
echo "   Check storage path: kubectl exec -it deployment/duckdb-external-lookup -n ${NAMESPACE} -- ls -la /data"
