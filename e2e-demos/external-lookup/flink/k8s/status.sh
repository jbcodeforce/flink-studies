#!/bin/bash

# Payment Claims Enrichment - Kubernetes Status Script
# This script checks the status of the Flink application deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="payment-claims-enrichment"
NAMESPACE="flink"
WATCH_MODE=false
DETAILED=false

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
        print_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
}

# Display header with timestamp
display_header() {
    echo "========================================="
    echo "  Payment Claims Enrichment - Status"
    echo "========================================="
    echo "Namespace: $NAMESPACE"
    echo "Timestamp: $(date)"
    echo "========================================="
}

# Check overall deployment health
check_deployment_health() {
    echo -e "\n${BLUE}=== DEPLOYMENT HEALTH ===${NC}"
    
    # Check if any resources exist
    TOTAL_PODS=$(kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null | tail -n +2 | wc -l)
    READY_PODS=$(kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" --field-selector=status.phase=Running 2>/dev/null | tail -n +2 | wc -l)
    
    echo "Total Pods: $TOTAL_PODS"
    echo "Ready Pods: $READY_PODS"
    
    if [ "$TOTAL_PODS" -eq 0 ]; then
        print_error "No pods found for application: $APP_NAME"
        return 1
    fi
    
    if [ "$READY_PODS" -eq "$TOTAL_PODS" ]; then
        print_success "All pods are running"
    else
        print_warning "Some pods are not ready ($READY_PODS/$TOTAL_PODS)"
    fi
}

# Check pods status
check_pods() {
    echo -e "\n${BLUE}=== PODS STATUS ===${NC}"
    
    if ! kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null; then
        print_error "No pods found"
        return 1
    fi
    
    # Check for problematic pods
    FAILED_PODS=$(kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" --field-selector=status.phase=Failed 2>/dev/null | tail -n +2)
    if [ -n "$FAILED_PODS" ]; then
        print_error "Failed pods detected:"
        echo "$FAILED_PODS"
    fi
    
    PENDING_PODS=$(kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" --field-selector=status.phase=Pending 2>/dev/null | tail -n +2)
    if [ -n "$PENDING_PODS" ]; then
        print_warning "Pending pods detected:"
        echo "$PENDING_PODS"
    fi
}

# Check services status
check_services() {
    echo -e "\n${BLUE}=== SERVICES STATUS ===${NC}"
    
    if ! kubectl get services -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null; then
        print_warning "No services found"
        return 0
    fi
    
    # Check if JobManager service is accessible
    if kubectl get service flink-jobmanager -n "$NAMESPACE" >/dev/null 2>&1; then
        JM_IP=$(kubectl get service flink-jobmanager -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
        JM_PORT=$(kubectl get service flink-jobmanager -n "$NAMESPACE" -o jsonpath='{.spec.ports[?(@.name=="webui")].port}')
        print_success "Flink JobManager Web UI: http://$JM_IP:$JM_PORT"
    fi
}

# Check deployments status
check_deployments() {
    echo -e "\n${BLUE}=== DEPLOYMENTS STATUS ===${NC}"
    
    if ! kubectl get deployments -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null; then
        print_warning "No deployments found"
        return 0
    fi
    
    # Check deployment readiness
    DEPLOYMENTS=$(kubectl get deployments -l app="$APP_NAME" -n "$NAMESPACE" -o name 2>/dev/null)
    for deployment in $DEPLOYMENTS; do
        READY=$(kubectl get "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
        DESIRED=$(kubectl get "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
        DEPLOYMENT_NAME=$(echo "$deployment" | cut -d'/' -f2)
        
        if [ "$READY" = "$DESIRED" ]; then
            print_success "$DEPLOYMENT_NAME: $READY/$DESIRED ready"
        else
            print_warning "$DEPLOYMENT_NAME: $READY/$DESIRED ready"
        fi
    done
}

# Check Flink Operator resources (if applicable)
check_flink_operator_resources() {
    echo -e "\n${BLUE}=== FLINK OPERATOR RESOURCES ===${NC}"
    
    # Check if Flink Operator is installed
    if ! kubectl get crd flinkdeployments.flink.apache.org >/dev/null 2>&1; then
        print_status "Flink Kubernetes Operator not installed"
        return 0
    fi
    
    # Check FlinkDeployments
    if kubectl get flinkdeployments -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "FlinkDeployments:"
        kubectl get flinkdeployments -n "$NAMESPACE"
        
        # Check FlinkDeployment status
        FD_STATUS=$(kubectl get flinkdeployments -n "$NAMESPACE" -o jsonpath='{.items[0].status.jobStatus.state}' 2>/dev/null || echo "Unknown")
        echo "Job Status: $FD_STATUS"
        
        if [ "$FD_STATUS" = "RUNNING" ]; then
            print_success "Flink job is running"
        elif [ "$FD_STATUS" = "Unknown" ]; then
            print_warning "Flink job status unknown"
        else
            print_warning "Flink job status: $FD_STATUS"
        fi
    else
        print_status "No FlinkDeployments found"
    fi
    
    # Check FlinkSessionJobs
    if kubectl get flinksessionjobs -n "$NAMESPACE" >/dev/null 2>&1; then
        echo -e "\nFlinkSessionJobs:"
        kubectl get flinksessionjobs -n "$NAMESPACE"
    fi
}

# Check storage status
check_storage() {
    echo -e "\n${BLUE}=== STORAGE STATUS ===${NC}"
    
    # Check PVCs
    kubectl get pvc -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || {
        kubectl get pvc flink-checkpoints flink-savepoints -n "$NAMESPACE" 2>/dev/null || {
            print_warning "No PersistentVolumeClaims found"
            return 0
        }
    }
    
    # Check PVC status
    BOUND_PVCS=$(kubectl get pvc -n "$NAMESPACE" --field-selector=status.phase=Bound 2>/dev/null | tail -n +2 | wc -l)
    TOTAL_PVCS=$(kubectl get pvc -n "$NAMESPACE" 2>/dev/null | tail -n +2 | wc -l)
    
    if [ "$BOUND_PVCS" -eq "$TOTAL_PVCS" ] && [ "$TOTAL_PVCS" -gt 0 ]; then
        print_success "All PVCs are bound ($BOUND_PVCS/$TOTAL_PVCS)"
    elif [ "$TOTAL_PVCS" -gt 0 ]; then
        print_warning "Some PVCs are not bound ($BOUND_PVCS/$TOTAL_PVCS)"
    fi
}

# Check networking status
check_networking() {
    echo -e "\n${BLUE}=== NETWORKING STATUS ===${NC}"
    
    # Check ingresses
    if kubectl get ingresses -n "$NAMESPACE" >/dev/null 2>&1; then
        echo "Ingresses:"
        kubectl get ingresses -n "$NAMESPACE"
        
        # Show ingress URLs
        INGRESS_HOSTS=$(kubectl get ingresses -n "$NAMESPACE" -o jsonpath='{.items[*].spec.rules[*].host}' 2>/dev/null)
        for host in $INGRESS_HOSTS; do
            print_status "Web UI available at: http://$host"
        done
    fi
    
    # Check load balancer services
    LB_SERVICES=$(kubectl get services -n "$NAMESPACE" --field-selector=spec.type=LoadBalancer -o name 2>/dev/null)
    if [ -n "$LB_SERVICES" ]; then
        echo -e "\nLoadBalancer Services:"
        for service in $LB_SERVICES; do
            kubectl get "$service" -n "$NAMESPACE"
            EXTERNAL_IP=$(kubectl get "$service" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            if [ -n "$EXTERNAL_IP" ]; then
                print_success "External access: http://$EXTERNAL_IP"
            else
                print_status "LoadBalancer external IP pending..."
            fi
        done
    fi
}

# Check recent events
check_events() {
    if [ "$DETAILED" = "true" ]; then
        echo -e "\n${BLUE}=== RECENT EVENTS ===${NC}"
        kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
    fi
}

# Show logs for problematic pods
show_problematic_logs() {
    if [ "$DETAILED" = "true" ]; then
        echo -e "\n${BLUE}=== PROBLEMATIC POD LOGS ===${NC}"
        
        # Get failed or pending pods
        PROBLEM_PODS=$(kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded -o name 2>/dev/null)
        
        for pod in $PROBLEM_PODS; do
            POD_NAME=$(echo "$pod" | cut -d'/' -f2)
            echo -e "\nLogs for $POD_NAME:"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=20 || true
        done
    fi
}

# Show resource usage (if metrics-server is available)
check_resource_usage() {
    if [ "$DETAILED" = "true" ]; then
        echo -e "\n${BLUE}=== RESOURCE USAGE ===${NC}"
        
        if kubectl top pods -n "$NAMESPACE" >/dev/null 2>&1; then
            kubectl top pods -l app="$APP_NAME" -n "$NAMESPACE" 2>/dev/null || print_status "Metrics not available"
        else
            print_status "Metrics server not available"
        fi
    fi
}

# Provide next steps and recommendations
show_recommendations() {
    echo -e "\n${BLUE}=== RECOMMENDATIONS ===${NC}"
    
    # Check if any pods are not running
    NOT_RUNNING=$(kubectl get pods -l app="$APP_NAME" -n "$NAMESPACE" --field-selector=status.phase!=Running 2>/dev/null | tail -n +2 | wc -l)
    
    if [ "$NOT_RUNNING" -gt 0 ]; then
        print_warning "Some pods are not running. Check logs:"
        echo "  kubectl logs -f deployment/flink-jobmanager -n $NAMESPACE"
        echo "  kubectl describe pods -l app=$APP_NAME -n $NAMESPACE"
    fi
    
    # Connection commands
    echo -e "\nUseful commands:"
    echo "  kubectl port-forward service/flink-jobmanager 8081:8081 -n $NAMESPACE"
    echo "  kubectl logs -f deployment/flink-jobmanager -n $NAMESPACE"
    echo "  kubectl exec -it deployment/flink-taskmanager -n $NAMESPACE -- bash"
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace NS      Kubernetes namespace (default: flink)"
    echo "  -w, --watch            Watch mode (refresh every 5 seconds)"
    echo "  -d, --detailed         Show detailed information (logs, events, metrics)"
    echo
    echo "Examples:"
    echo "  $0                      # Basic status check"
    echo "  $0 --detailed           # Detailed status with logs and events"
    echo "  $0 --watch              # Continuous monitoring"
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
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -d|--detailed)
            DETAILED=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main status check function
run_status_check() {
    display_header
    check_deployment_health
    check_pods
    check_services
    check_deployments
    check_flink_operator_resources
    check_storage
    check_networking
    check_events
    show_problematic_logs
    check_resource_usage
    show_recommendations
}

# Main function
main() {
    check_prerequisites
    
    if [ "$WATCH_MODE" = "true" ]; then
        print_status "Starting watch mode (Press Ctrl+C to exit)..."
        while true; do
            clear
            run_status_check
            sleep 5
        done
    else
        run_status_check
    fi
}

# Run main function
main "$@"
