#!/bin/bash
# Get the direct ECS access URL for the ML inference service
# This script retrieves the public IP of the running ECS task

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get cluster and service names from Terraform
CLUSTER_NAME=$(terraform -chdir="${SCRIPT_DIR}" output -raw ecs_cluster_name 2>/dev/null || echo "")
SERVICE_NAME=$(terraform -chdir="${SCRIPT_DIR}" output -raw ml_inference_service_name 2>/dev/null || echo "")

# Try to get region from Terraform output, then from tfvars, then default
REGION=$(terraform -chdir="${SCRIPT_DIR}" output -raw cloud_region 2>/dev/null || echo "")
if [ -z "$REGION" ]; then
    # Try to extract from terraform.tfvars
    REGION=$(grep -E '^\s*cloud_region\s*=' "${SCRIPT_DIR}/terraform.tfvars" 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' | head -1)
fi
if [ -z "$REGION" ]; then
    # Try AWS CLI default region
    REGION=$(aws configure get region 2>/dev/null || echo "")
fi
if [ -z "$REGION" ]; then
    # Last resort: try to detect from cluster ARN by querying common regions
    echo "Warning: Could not determine region. Trying to detect from cluster..."
    for test_region in us-west-2 us-east-1 us-east-2 eu-west-1; do
        if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$test_region" --query 'clusters[0].clusterName' --output text 2>/dev/null | grep -q "$CLUSTER_NAME"; then
            REGION="$test_region"
            echo "Detected region: $REGION"
            break
        fi
    done
fi
if [ -z "$REGION" ]; then
    echo "Error: Could not determine AWS region. Please set cloud_region in terraform.tfvars or configure AWS CLI default region."
    exit 1
fi

if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ]; then
    echo "Error: Could not get cluster or service name from Terraform outputs"
    echo "Make sure Terraform has been applied and the ECS service exists."
    exit 1
fi

# Check if ALB is enabled
ALB_ENABLED=$(terraform -chdir="${SCRIPT_DIR}" output -raw enable_ml_inference_alb 2>/dev/null || echo "false")
if [ "$ALB_ENABLED" = "true" ]; then
    ALB_URL=$(terraform -chdir="${SCRIPT_DIR}" output -raw ml_inference_service_url 2>/dev/null || echo "")
    if [ -n "$ALB_URL" ]; then
        echo "ALB is enabled. Service URL: $ALB_URL"
        exit 0
    fi
fi

# Verify cluster exists in the region
echo "Checking cluster: $CLUSTER_NAME in region: $REGION"
if ! aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$REGION" --query 'clusters[0].clusterName' --output text 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    echo "Error: Cluster '$CLUSTER_NAME' not found in region '$REGION'"
    echo ""
    echo "Trying to find cluster in other regions..."
    FOUND_REGION=""
    for test_region in us-west-2 us-east-1 us-east-2 eu-west-1 eu-central-1 ap-southeast-1; do
        if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$test_region" --query 'clusters[0].clusterName' --output text 2>/dev/null | grep -q "$CLUSTER_NAME"; then
            FOUND_REGION="$test_region"
            echo "Found cluster in region: $FOUND_REGION"
            REGION="$FOUND_REGION"
            break
        fi
    done
    if [ -z "$FOUND_REGION" ]; then
        echo "Error: Could not find cluster '$CLUSTER_NAME' in any common region."
        echo "Please verify:"
        echo "  1. The cluster name is correct: $CLUSTER_NAME"
        echo "  2. You have AWS CLI configured with correct credentials"
        echo "  3. The cluster exists in your AWS account"
        exit 1
    fi
fi

# Get the task ARN
echo "Getting task information for cluster: $CLUSTER_NAME, service: $SERVICE_NAME in region: $REGION"
TASK_ARN=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --region "$REGION" \
    --query 'taskArns[0]' \
    --output text 2>/dev/null || echo "")

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo "Error: No running tasks found for service $SERVICE_NAME"
    echo "Make sure the ECS service has at least one running task."
    exit 1
fi

# Get the network interface ID from the task
ENI_ID=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --region "$REGION" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)

if [ -z "$ENI_ID" ] || [ "$ENI_ID" = "None" ]; then
    echo "Error: Could not get network interface ID from task"
    exit 1
fi

# Get the public IP from the network interface
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids "$ENI_ID" \
    --region "$REGION" \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
    echo "Error: Task does not have a public IP address"
    echo "Make sure the ECS service is configured with assign_public_ip = true"
    exit 1
fi

# Output the service URL
SERVICE_URL="http://${PUBLIC_IP}:8080"
echo ""
echo "=========================================="
echo "ML Inference Service Direct Access URL:"
echo "  $SERVICE_URL"
echo ""
echo "Health Check:"
echo "  curl $SERVICE_URL/health"
echo ""
echo "API Docs:"
echo "  $SERVICE_URL/docs"
echo "=========================================="
