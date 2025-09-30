#!/bin/bash

# Event Generator - Kubernetes Cleanup Script
# This script removes all Kubernetes resources for the Event Generator application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="external-lookup-event-generator"
NAMESPACE="el-demo"
FORCE_DELETE=false
KEEP_NAMESPACE=false

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
        echo "This will delete the following Event Generator resources in namespace '$NAMESPACE':"
        echo "  - Deployments: event-generator-*"
        echo "  - Services: event-generator-metrics, event-generator-metrics-nodeport"
        echo "  - ConfigMaps: event-generator-config, event-generator-*-config"
        echo "  - Secrets: event-generator-secrets"
        if [ "$KEEP_NAMESPACE" = "false" ]; then
            echo "  - Namespace: $NAMESPACE"
        fi
        echo ""
        
        # Show current resources
        print_status "Current Event Generator resources:"
        echo ""
        echo "Deployments:"
        kubectl get deployments -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  None found"
        echo ""
        echo "Services:"
        kubectl get services -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  None found"
        echo ""
        echo "ConfigMaps:"
        kubectl get configmaps -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  None found"
        echo ""
        
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Cleanup cancelled"
            exit 0
        fi
    fi
}

# Delete deployments
delete_deployments() {
    print_status "Deleting Event Generator deployments..."
    
    # Delete all deployments with the app label
    kubectl delete deployments -l app="$APP_NAME" -n "$NAMESPACE" --timeout=60s || true
    
    # Delete specific deployments if they exist (fallback)
    local deployments=("event-generator-standard" "event-generator-high-rate" "event-generator-burst" "event-generator-error-test")
    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" -n "$NAMESPACE" >/dev/null 2>&1; then
            kubectl delete deployment "$deployment" -n "$NAMESPACE" --timeout=60s || true
        fi
    done
    
    # Force delete pods if necessary
    if [ "$FORCE_DELETE" = "true" ]; then
        kubectl delete pods -l app="$APP_NAME" -n "$NAMESPACE" --force --grace-period=0 || true
    else
        kubectl delete pods -l app="$APP_NAME" -n "$NAMESPACE" --timeout=60s || true
    fi
    
    # Wait for pods to terminate
    print_status "Waiting for pods to terminate..."
    kubectl wait --for=delete pods -l app="$APP_NAME" --timeout=120s -n "$NAMESPACE" 2>/dev/null || true
    
    print_success "Deleted deployments and pods"
}

# Delete services
delete_services() {
    print_status "Deleting Event Generator services..."
    
    # Delete all services with the app label
    kubectl delete services -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete specific services if they exist (fallback)
    local services=("event-generator-metrics" "event-generator-metrics-nodeport")
    for service in "${services[@]}"; do
        if kubectl get service "$service" -n "$NAMESPACE" >/dev/null 2>&1; then
            kubectl delete service "$service" -n "$NAMESPACE" || true
        fi
    done
    
    print_success "Deleted services"
}

# Delete configuration
delete_configuration() {
    print_status "Deleting Event Generator configuration..."
    
    # Delete all ConfigMaps with the app label
    kubectl delete configmaps -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete specific ConfigMaps if they exist (fallback)
    local configmaps=("event-generator-config" "event-generator-high-rate-config" "event-generator-burst-config" "event-generator-error-test-config")
    for configmap in "${configmaps[@]}"; do
        if kubectl get configmap "$configmap" -n "$NAMESPACE" >/dev/null 2>&1; then
            kubectl delete configmap "$configmap" -n "$NAMESPACE" || true
        fi
    done
    
    # Delete Secrets
    kubectl delete secrets -l app="$APP_NAME" -n "$NAMESPACE" || true
    if kubectl get secret event-generator-secrets -n "$NAMESPACE" >/dev/null 2>&1; then
        kubectl delete secret event-generator-secrets -n "$NAMESPACE" || true
    fi
    
    print_success "Deleted configuration resources"
}

# Delete monitoring resources (if any)
delete_monitoring() {
    print_status "Deleting monitoring resources..."
    
    # Delete ServiceMonitors (if using Prometheus Operator)
    kubectl delete servicemonitors -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    # Delete any PodMonitors
    kubectl delete podmonitors -l app="$APP_NAME" -n "$NAMESPACE" || true
    
    print_success "Deleted monitoring resources"
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
    rm -f /tmp/event-generator-port-forward.pid
    rm -f /tmp/kubectl-proxy.pid
    
    print_success "Local cleanup completed"
}

# Show remaining resources
show_remaining_resources() {
    print_status "Checking for remaining resources..."
    
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        echo "Remaining Event Generator resources in namespace $NAMESPACE:"
        
        echo ""
        echo "Deployments:"
        kubectl get deployments -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  ✅ None found"
        
        echo ""
        echo "Services:"
        kubectl get services -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  ✅ None found"
        
        echo ""
        echo "ConfigMaps:"
        kubectl get configmaps -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  ✅ None found"
        
        echo ""
        echo "Pods:"
        kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || echo "  ✅ None found"
        
        # Show any stuck resources
        STUCK_PODS=$(kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | tail -n +2 | wc -l)
        if [ "$STUCK_PODS" -gt 0 ]; then
            print_warning "$STUCK_PODS pods may be stuck in terminating state"
            kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded
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
    echo "  -n, --namespace NS      Kubernetes namespace (default: el-demo)"
    echo "  -f, --force             Force deletion without confirmation"
    echo "  --keep-namespace        Don't delete the namespace"
    echo
    echo "Examples:"
    echo "  $0                      # Interactive cleanup with confirmation"
    echo "  $0 --force              # Force cleanup without confirmation"
    echo "  $0 --keep-namespace     # Cleanup but keep namespace"
}

# Parse command line arguments
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
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main cleanup process
main() {
    print_status "Starting cleanup of Event Generator in namespace: $NAMESPACE"
    
    check_prerequisites
    confirm_deletion
    delete_deployments
    delete_services
    delete_configuration
    delete_monitoring
    delete_namespace
    cleanup_local
    show_remaining_resources
    
    print_success "Event Generator cleanup completed!"
    
    echo ""
    print_status "Next steps (if needed):"
    print_status "  1. Verify cleanup: kubectl get all -l app=$APP_NAME -n $NAMESPACE"
    print_status "  2. Check other namespaces: kubectl get all --all-namespaces -l app=$APP_NAME"
    print_status "  3. Remove Docker images: docker rmi external-lookup-event-generator:latest"
}

# Run main function
main "$@"