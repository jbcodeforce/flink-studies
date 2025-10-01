#!/bin/bash

# Check status of DuckDB External Lookup deployment
# This script provides a comprehensive overview of the deployment status

set -e

# Configuration
NAMESPACE="el-demo"

APP_NAME="external-lookup"
echo "DuckDB External Lookup Deployment Status"
echo "============================================="
echo "Namespace: ${NAMESPACE}"
echo ""

# Check Kubernetes connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

# Detect environment
detect_k8s_environment() {
    local cluster_context=$(kubectl config current-context)
    local cluster_info=$(kubectl cluster-info)
    
    if [[ "$cluster_context" == *"colima"* ]] || [[ "$cluster_info" == *"colima"* ]]; then
        echo "colima"
    elif [[ "$cluster_context" == *"kind"* ]] || [[ "$cluster_info" == *"kind"* ]]; then
        echo "kind"
    else
        if kubectl get nodes -o wide | grep -q "kind-"; then
            echo "kind"
        else
            echo "unknown"
        fi
    fi
}

ENV=$(detect_k8s_environment)
echo "🔍 Environment: $ENV"
echo "📍 Current context: $(kubectl config current-context)"
echo ""

# Check Storage Resources
echo "🗄️  STORAGE STATUS"
echo "==================="

echo "StorageClass 'hostpath':"
if kubectl get storageclass hostpath &>/dev/null; then
    echo "✅ StorageClass exists"
    kubectl get storageclass hostpath -o wide
else
    echo "❌ StorageClass not found"
fi

echo ""
echo "PersistentVolume 'duckdb-pv':"
if kubectl get pv duckdb-pv &>/dev/null; then
    pv_status=$(kubectl get pv duckdb-pv -o jsonpath='{.status.phase}')
    case "$pv_status" in
        "Available")
            echo "✅ PV Available"
            ;;
        "Bound")
            echo "✅ PV Bound"
            ;;
        "Released")
            echo "⚠️  PV Released (may need cleanup)"
            ;;
        "Failed")
            echo "❌ PV Failed"
            ;;
        *)
            echo "❓ PV Status: $pv_status"
            ;;
    esac
    kubectl get pv duckdb-pv -o wide
else
    echo "❌ PersistentVolume not found"
fi

echo ""
echo "PersistentVolumeClaim 'duckdb-pvc':"
if kubectl get pvc duckdb-pvc -n ${NAMESPACE} &>/dev/null; then
    pvc_status=$(kubectl get pvc duckdb-pvc -n ${NAMESPACE} -o jsonpath='{.status.phase}')
    case "$pvc_status" in
        "Bound")
            echo "✅ PVC Bound"
            ;;
        "Pending")
            echo "⚠️  PVC Pending"
            ;;
        "Lost")
            echo "❌ PVC Lost"
            ;;
        *)
            echo "❓ PVC Status: $pvc_status"
            ;;
    esac
    kubectl get pvc duckdb-pvc -n ${NAMESPACE} -o wide
else
    echo "❌ PersistentVolumeClaim not found"
fi

echo ""
echo ""

# Check Application Resources
echo "🚀 APPLICATION STATUS"
echo "======================"

echo "ConfigMap 'duckdb-config':"
if kubectl get configmap duckdb-config -n ${NAMESPACE} &>/dev/null; then
    echo "✅ ConfigMap exists"
    echo "Configuration keys:"
    kubectl get configmap duckdb-config -n ${NAMESPACE} -o jsonpath='{.data}' | jq -r 'keys[]' 2>/dev/null || kubectl get configmap duckdb-config -n ${NAMESPACE} -o jsonpath='{.data}' | sed 's/[{}"]//g' | tr ',' '\n' | cut -d':' -f1
else
    echo "❌ ConfigMap not found"
fi

echo ""
    echo "Deployment '${APP_NAME}':"
    if kubectl get deployment ${APP_NAME} -n ${NAMESPACE} &>/dev/null; then
    ready=$(kubectl get deployment ${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')
    desired=$(kubectl get deployment ${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')
    
    if [[ "$ready" == "$desired" && "$ready" != "" ]]; then
        echo "✅ Deployment Ready ($ready/$desired)"
    else
        echo "⚠️  Deployment Not Ready (${ready:-0}/$desired)"
    fi
    
    kubectl get deployment ${APP_NAME} -n ${NAMESPACE} -o wide
else
    echo "❌ Deployment not found"
fi

echo ""
echo "Pods:"
if kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE} &>/dev/null; then
    kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE} -o wide
    
    # Check pod status
    pod_names=$(kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.items[*].metadata.name}')
    for pod in $pod_names; do
        phase=$(kubectl get pod $pod -n ${NAMESPACE} -o jsonpath='{.status.phase}')
        echo ""
        echo "Pod '$pod' status: $phase"
        
        if [[ "$phase" != "Running" ]]; then
            echo "Events for $pod:"
            kubectl get events --field-selector involvedObject.name=$pod -n ${NAMESPACE} --sort-by='.firstTimestamp' | tail -5
        fi
    done
else
    echo "❌ No pods found"
fi

echo ""
echo "Services:"
if kubectl get services -l app=${APP_NAME} -n ${NAMESPACE} &>/dev/null; then
    kubectl get services -l app=${APP_NAME} -n ${NAMESPACE} -o wide
else
    echo "❌ Services not found"
fi

echo ""
echo ""

# Health Check
echo "🏥 HEALTH CHECK"
echo "==============="

# Check if we can port-forward and test the API
if kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}' &>/dev/null; then
    POD_NAME=$(kubectl get pods -l app=${APP_NAME} -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -n "$POD_NAME" ]]; then
        echo "Testing API health check..."
        # Set up port-forward in the background for health check
        LOCAL_PORT=18080
        TARGET_PORT=8080
        PF_PID=""
        kubectl port-forward $POD_NAME -n ${NAMESPACE} $LOCAL_PORT:$TARGET_PORT >/dev/null 2>&1 &
        PF_PID=$!
        # Wait briefly to ensure port-forward is established
        sleep 2
        # Try to curl the health endpoint from inside the pod
        if curl -s -f http://localhost:$LOCAL_PORT/health &>/dev/null; then
            echo "✅ API Health Check: PASSED"
            
            # Get some basic stats
            echo ""
            echo "Database Stats:"
            curl -s http://localhost:$TARGET_PORT/stats 2>/dev/null | head -10 || echo "Could not retrieve stats"
        else
            echo "❌ API Health Check: FAILED"
            
            echo ""
            echo "Recent pod logs:"
            kubectl logs $POD_NAME -n ${NAMESPACE} --tail=10
        fi
        # Clean up port-forward
        if [[ -n "$PF_PID" ]]; then
            kill $PF_PID
        fi
    else
        echo "❌ No running pods found for health check"
    fi
else
    echo "❌ No pods available for health check"
fi

echo ""
echo ""

# Summary
echo "📋 SUMMARY"
echo "=========="

# Count resources
resources_ok=0
resources_total=6

echo "Resource Status:"
kubectl get storageclass hostpath &>/dev/null && echo "✅ StorageClass" && ((resources_ok++)) || echo "  ❌ StorageClass"
kubectl get pv claimdb-pv &>/dev/null && echo "✅ PersistentVolume" && ((resources_ok++)) || echo "  ❌ PersistentVolume"
kubectl get pvc claimdb-pvc -n ${NAMESPACE} &>/dev/null && echo "✅ PersistentVolumeClaim" && ((resources_ok++)) || echo "  ❌ PersistentVolumeClaim"
kubectl get configmap claimdb-config -n ${NAMESPACE} &>/dev/null && echo "✅ ConfigMap" && ((resources_ok++)) || echo "  ❌ ConfigMap"
kubectl get deployment claimdb-external-lookup -n ${NAMESPACE} &>/dev/null && echo "✅ Deployment" && ((resources_ok++)) || echo "  ❌ Deployment"
kubectl get services -l app=${APP_NAME} -n ${NAMESPACE} &>/dev/null && echo "✅ Services" && ((resources_ok++)) || echo "  ❌ Services"

echo ""
echo "Overall Status: $resources_ok/$resources_total resources found"

if [[ $resources_ok -eq $resources_total ]]; then
    echo "🎉 All resources deployed successfully!"
elif [[ $resources_ok -gt 0 ]]; then
    echo "⚠️  Partial deployment - some resources missing"
else
    echo "❌ No resources found - deployment appears to be missing"
fi

echo ""
echo "🔧 Useful Commands:"
echo "   Deploy: ./deploy.sh"
echo "   Cleanup: ./cleanup.sh"
echo "   Port forward: kubectl port-forward svc/duckdb-external-lookup 8080:8080 -n ${NAMESPACE}"
echo "   View logs: kubectl logs -l app=${APP_NAME} -f -n ${NAMESPACE}"
echo "   Describe PVC: kubectl describe pvc duckdb-pvc -n ${NAMESPACE}"
