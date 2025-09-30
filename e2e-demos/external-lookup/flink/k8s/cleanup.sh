#!/bin/bash

# Payment Claims Enrichment - Kubernetes Cleanup Script
# This script removes all Kubernetes resources for the Flink application

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
NAMESPACE="flink"
FORCE_DELETE=false
KEEP_NAMESPACE=false
KEEP_STORAGE=false

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
    if ! command_exists kubectl; then
        print_error "kubectl not found. Please install kubectl"
        exit 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster. Check your kubeconfig"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_warning "Namespace $NAMESPACE does not exist"
        return 0
    fi
}

# Confirm deletion
confirm_deletion() {
    if [ "$FORCE_DELETE" = "false" ]; then
        echo "This will delete the following resources in namespace '$NAMESPACE':"
        echo "  - Flink Deployments and Pods"
        echo "  - Services and Ingresses"
        echo "  - ConfigMaps and Secrets"
        if [ "$KEEP_STORAGE" = "false" ]; then
            echo "  - PersistentVolumeClaims and data"
        fi
        if [ "$KEEP_NAMESPACE" = "false" ]; then
            echo "  - Namespace: $NAMESPACE"
        fi
        echo ""
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleanup cancelled"
            exit 0
        fi
    fi
}

# Stop port forwarding processes
stop_port_forwarding() {
    print_status "Stopping port forwarding processes..."
    
    if [ -f "/tmp/flink-port-forward.pid" ]; then
        PF_PID=$(cat /tmp/flink-port-forward.pid)
        if ps -p $PF_PID > /dev/null 2>&1; then
            kill $PF_PID
            print_success "Stopped port forwarding process: $PF_PID"
        fi
        rm -f /tmp/flink-port-forward.pid
    fi
    
    # Kill any remaining port forward processes
    pkill -f "kubectl.*port-forward.*flink" || true
}

# Delete Flink Operator resources
delete_operator_resources() {
    print_status "Deleting Flink Operator resources..."
    
    # Delete FlinkDeployments
    if kubectl get flinkdeployments -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl delete flinkdeployments --all -n "$NAMESPACE" --timeout=60s || true
        print_success "Deleted FlinkDeployments"
    fi
    
    # Delete FlinkSessionJobs
    if kubectl get flinksessionjobs -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl delete flinksessionjobs --all -n "$NAMESPACE" --timeout=60s || true
        print_success "Deleted FlinkSessionJobs"
    fi
}

# Delete application deployments
delete_deployments() {
    print_status "Deleting application deployments..."
    
    # Delete deployments
    kubectl delete deployments -l app="$APP_NAME" -n "$NAMESPACE" --timeout=60s || true
    
    # Delete replicasets (in case deployments don't clean them up)
    kubectl delete replicasets -l app="$APP_NAME" -n "$NAMESPACE" --timeout=60s || true
    
    # Delete pods (force if necessary)
    if [ "$FORCE_DELETE" = "true" ]; then
        kubectl delete pods -l app="$APP_NAME" -n "$NAMESPACE" --force --grace-period=0 || true
    else
        kubectl delete pods -l app="$APP_NAME" -n "$NAMESPACE" --timeout=60s || true
    fi
    
    print_success "Deleted deployments and pods"
}

# Delete services and networking
delete_services() {
    print_status "Deleting services and networking resources..."
    
    # Delete services
    kubectl delete services -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete ingresses
    kubectl delete ingresses -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete network policies
    kubectl delete networkpolicies -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete HPA
    kubectl delete hpa -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete ServiceMonitors (if using Prometheus Operator)
    kubectl delete servicemonitors -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    print_success "Deleted services and networking resources"
}

# Delete configuration
delete_configuration() {
    print_status "Deleting configuration resources..."
    
    # Delete ConfigMaps
    kubectl delete configmaps -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete Secrets
    kubectl delete secrets -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    print_success "Deleted configuration resources"
}

# Delete storage resources
delete_storage() {
    if [ "$KEEP_STORAGE" = "false" ]; then
        print_status "Deleting storage resources..."
        
        # Delete PVCs
        kubectl delete pvc -l app="$APP_NAME" -n "$NAMESPACE" || true
        kubectl delete pvc flink-checkpoints -n "$NAMESPACE" || true
        kubectl delete pvc flink-savepoints -n "$NAMESPACE" || true
        
        print_success "Deleted storage resources"
        print_warning "All checkpoint and savepoint data has been deleted"
    else
        print_status "Keeping storage resources (--keep-storage flag set)"
    fi
}

# Delete RBAC resources
delete_rbac() {
    print_status "Deleting RBAC resources..."
    
    # Delete namespace-specific RBAC
    kubectl delete rolebindings -l app="$APP_NAME" -n "$NAMESPACE" || true
    kubectl delete roles -l app="$APP_NAME" -n "$NAMESPACE" || true
    kubectl delete serviceaccounts -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete cluster-wide RBAC (be careful with these)
    kubectl delete clusterrolebindings -l app="$APP_NAME" || true
    kubectl delete clusterroles -l app="$APP_NAME" || true
    
    print_success "Deleted RBAC resources"
}

# Delete namespace
delete_namespace() {
    if [ "$KEEP_NAMESPACE" = "false" ]; then
        print_status "Deleting namespace: $NAMESPACE"
        kubectl delete namespace "$NAMESPACE" --timeout=120s || {
            print_warning "Namespace deletion timed out, it may still be terminating"
        }
        print_success "Deleted namespace: $NAMESPACE"
    else
        print_status "Keeping namespace: $NAMESPACE (--keep-namespace flag set)"
    fi
}

# Clean up local artifacts
cleanup_local() {
    print_status "Cleaning up local artifacts..."
    
    # Remove any temporary files
    rm -f /tmp/flink-port-forward.pid
    rm -f /tmp/kubectl-proxy.pid
    
    print_success "Local cleanup completed"
}

# Show remaining resources
show_remaining_resources() {
    print_status "Checking for remaining resources..."
    
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        echo "Remaining resources in namespace $NAMESPACE:"
        kubectl get all -n "$NAMESPACE" 2>/dev/null || true
        
        # Show any stuck resources
        STUCK_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | tail -n +2 | wc -l)
        if [ "$STUCK_PODS" -gt 0 ]; then
            print_warning "$STUCK_PODS pods may be stuck in terminating state"
            kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded
        fi
    else
        print_success "Namespace $NAMESPACE has been completely removed"
    fi
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace NS      Kubernetes namespace (default: flink)"
    echo "  -f, --force             Force deletion without confirmation"
    echo "  --keep-namespace        Don't delete the namespace"
    echo "  --keep-storage         Don't delete PersistentVolumeClaims"
    echo "  --keep-rbac            Don't delete RBAC resources"
    echo
    echo "Examples:"
    echo "  $0                      # Interactive cleanup with confirmation"
    echo "  $0 --force              # Force cleanup without confirmation"
    echo "  $0 --keep-storage       # Cleanup but keep storage"
    echo "  $0 --keep-namespace     # Cleanup but keep namespace"
}

# Parse command line arguments
KEEP_RBAC=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_DELETE=true
            shift
            ;;
        --keep-namespace)
            KEEP_NAMESPACE=true
            shift
            ;;
        --keep-storage)
            KEEP_STORAGE=true
            shift
            ;;
        --keep-rbac)
            KEEP_RBAC=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main cleanup process
main() {
    print_status "Starting cleanup of $APP_NAME in namespace: $NAMESPACE"
    
    check_prerequisites
    confirm_deletion
    stop_port_forwarding
    delete_operator_resources
    delete_deployments
    delete_services
    delete_configuration
    delete_storage
    
    if [ "$KEEP_RBAC" = "false" ]; then
        delete_rbac
    fi
    
    delete_namespace
    cleanup_local
    show_remaining_resources
    
    print_success "Cleanup completed!"
    
    if [ "$KEEP_STORAGE" = "true" ]; then
        print_status "Storage was preserved. To clean up storage later, run:"
        print_status "  kubectl delete pvc flink-checkpoints flink-savepoints -n $NAMESPACE"
    fi
}

# Run main function
main "$@"
