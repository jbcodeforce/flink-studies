#!/bin/bash

# Cleanup DuckDB External Lookup deployment from Kubernetes
# This script removes all resources related to the DuckDB deployment

set -e

# Configuration
NAMESPACE="duckdb"

echo "🧹 Cleaning up DuckDB External Lookup from Kubernetes..."
echo "Namespace: ${NAMESPACE}"

# Function to check if resource exists
resource_exists() {
    local resource_type=$1
    local resource_name=$2
    local namespace_flag=""
    
    if [[ "$resource_type" != "pv" && "$resource_type" != "sc" ]]; then
        namespace_flag="-n ${NAMESPACE}"
    fi
    
    kubectl get $resource_type $resource_name $namespace_flag &>/dev/null
}

# Function to delete resource if exists
delete_if_exists() {
    local resource_type=$1
    local resource_name=$2
    local namespace_flag=""
    local display_name=${3:-$resource_name}
    
    if [[ "$resource_type" != "pv" && "$resource_type" != "sc" ]]; then
        namespace_flag="-n ${NAMESPACE}"
    fi
    
    if resource_exists $resource_type $resource_name; then
        echo "🗑️  Deleting $display_name..."
        if [[ "$resource_type" == "pv" ]]; then
            kubectl delete $resource_type $resource_name --force --grace-period=0 --timeout=60s
        else
            kubectl delete $resource_type $resource_name $namespace_flag --timeout=60s
        fi
        echo "✅ Deleted $display_name"
    else
        echo "⏭️  $display_name not found, skipping"
    fi
}

# Confirm deletion
echo ""
echo "⚠️  This will delete the following resources:"
echo "   - Deployment: duckdb-external-lookup"
echo "   - Service: duckdb-external-lookup"
echo "   - Service: duckdb-external-lookup-nodeport"
echo "   - ConfigMap: duckdb-config"
echo "   - PersistentVolumeClaim: duckdb-pvc"
echo "   - PersistentVolume: duckdb-pv"
echo "   - StorageClass: hostpath (if no other resources use it)"
echo ""
echo "📊 Current resources:"
echo "Deployments:"
kubectl get deployments -l app=external-lookup-duckdb -n ${NAMESPACE} 2>/dev/null || echo "  None found"
echo ""
echo "Services:"
kubectl get services -l app=external-lookup-duckdb -n ${NAMESPACE} 2>/dev/null || echo "  None found"
echo ""
echo "PVC:"
kubectl get pvc -l app=external-lookup-duckdb -n ${NAMESPACE} 2>/dev/null || echo "  None found"
echo ""
echo "PV:"
kubectl get pv -l app=external-lookup-duckdb 2>/dev/null || echo "  None found"
echo ""

if ! [[ "${1}" == "--force" ]]; then
    read -p "Are you sure you want to delete these resources? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled"
        exit 0
    fi
fi

# Delete resources in reverse order
echo ""
echo "🚀 Starting cleanup..."

# Delete Deployment first to stop pods
delete_if_exists deployment duckdb-external-lookup "Deployment"

# Wait for pods to terminate
echo "⏳ Waiting for pods to terminate..."
kubectl wait --for=delete pods -l app=external-lookup-duckdb --timeout=120s -n ${NAMESPACE} 2>/dev/null || true

# Delete Services
delete_if_exists service duckdb-external-lookup "ClusterIP Service"
delete_if_exists service duckdb-external-lookup-nodeport "NodePort Service"

# Delete ConfigMap
delete_if_exists configmap duckdb-config "ConfigMap"

# Delete PVC (this will trigger PV cleanup if reclaim policy is Delete)
delete_if_exists pvc duckdb-pvc "PersistentVolumeClaim"

# Delete PV (if it still exists and has Retain policy)
delete_if_exists pv duckdb-pv "PersistentVolume"

# Check if any other resources use the hostpath storage class
echo ""
echo "🔍 Checking if StorageClass is still in use..."
if kubectl get pvc --all-namespaces -o jsonpath='{.items[*].spec.storageClassName}' | grep -q "hostpath"; then
    echo "⚠️  Other resources are using 'hostpath' StorageClass, keeping it"
else
    delete_if_exists sc hostpath "StorageClass"
fi

echo ""
echo "🔍 Verifying cleanup..."
echo "Remaining resources with app=external-lookup-duckdb label:"
echo ""

echo "Deployments:"
kubectl get deployments -l app=external-lookup-duckdb -n ${NAMESPACE} 2>/dev/null || echo "  ✅ None found"

echo ""
echo "Services:"
kubectl get services -l app=external-lookup-duckdb -n ${NAMESPACE} 2>/dev/null || echo "  ✅ None found"

echo ""
echo "ConfigMaps:"
kubectl get configmaps -l app=external-lookup-duckdb -n ${NAMESPACE} 2>/dev/null || echo "  ✅ None found"

echo ""
echo "PVC:"
kubectl get pvc -l app=external-lookup-duckdb -n ${NAMESPACE} 2>/dev/null || echo "  ✅ None found"

echo ""
echo "PV:"
kubectl get pv -l app=external-lookup-duckdb 2>/dev/null || echo "  ✅ None found"

echo ""
echo "✅ Cleanup completed successfully!"

echo ""
echo "📝 Note: Database files may still exist on the host system at:"
echo "   Colima: /tmp/duckdb-external-lookup"
echo "   kind: /tmp/hostpath-provisioner/duckdb-external-lookup"
echo ""
echo "To remove database files manually (optional):"
echo "   rm -rf /tmp/duckdb-external-lookup"
echo "   rm -rf /tmp/hostpath-provisioner/duckdb-external-lookup"
