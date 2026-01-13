#!/bin/bash
# Deployment script for Transaction Scoring Service
# Builds Docker image and pushes to ECR, then updates ECS service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IAC_DIR="${SCRIPT_DIR}/../IaC"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Transaction Scoring Service Deployment${NC}"
echo "=========================================="

# Check if Terraform outputs are available
if [ ! -d "${IAC_DIR}" ]; then
    echo -e "${RED}Error: IaC directory not found at ${IAC_DIR}${NC}"
    exit 1
fi

# Get ECR repository URL from Terraform
echo -e "${YELLOW}Getting ECR repository URL from Terraform...${NC}"
cd "${IAC_DIR}"
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")
REGION=$(terraform output -raw cloud_region 2>/dev/null || terraform output -raw region 2>/dev/null || echo "us-east-1")

if [ -z "$ECR_REPO" ]; then
    echo -e "${RED}Error: Could not get ECR repository URL from Terraform${NC}"
    echo "Make sure Terraform has been applied and the ECR repository exists."
    exit 1
fi

echo -e "${GREEN}ECR Repository: ${ECR_REPO}${NC}"
echo -e "${GREEN}Region: ${REGION}${NC}"

# Extract account ID from ECR repo URL
ACCOUNT_ID=$(echo "${ECR_REPO}" | cut -d'.' -f1 | cut -d'/' -f1)

# Authenticate with ECR
echo -e "\n${YELLOW}Authenticating Docker with ECR...${NC}"
aws ecr get-login-password --region "${REGION}" | \
    docker login --username AWS --password-stdin "${ECR_REPO}" || {
    echo -e "${RED}Error: Failed to authenticate with ECR${NC}"
    echo "Make sure AWS CLI is configured and you have permissions to access ECR."
    exit 1
}

# Build image
echo -e "\n${YELLOW}Building Docker image...${NC}"
cd "${SCRIPT_DIR}"
docker build -t tx-scoring:latest . || {
    echo -e "${RED}Error: Docker build failed${NC}"
    exit 1
}

# Tag and push
echo -e "\n${YELLOW}Tagging and pushing to ECR...${NC}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker tag tx-scoring:latest "${ECR_REPO}:latest"
docker tag tx-scoring:latest "${ECR_REPO}:${TIMESTAMP}"

echo "Pushing latest tag..."
docker push "${ECR_REPO}:latest" || {
    echo -e "${RED}Error: Failed to push image to ECR${NC}"
    exit 1
}

echo "Pushing timestamp tag: ${TIMESTAMP}"
docker push "${ECR_REPO}:${TIMESTAMP}" || {
    echo -e "${YELLOW}Warning: Failed to push timestamp tag, but latest was pushed${NC}"
}

echo -e "\n${GREEN}✓ Image pushed successfully!${NC}"
echo -e "Repository: ${ECR_REPO}"
echo -e "Tags: latest, ${TIMESTAMP}"

# Try to update ECS service if cluster/service names are available
echo -e "\n${YELLOW}Checking for ECS service to update...${NC}"
CLUSTER_NAME=$(terraform -chdir="${IAC_DIR}" output -raw ecs_cluster_name 2>/dev/null || echo "")
SERVICE_NAME=$(terraform -chdir="${IAC_DIR}" output -raw ml_inference_service_name 2>/dev/null || echo "")

if [ -n "$CLUSTER_NAME" ] && [ -n "$SERVICE_NAME" ]; then
    echo -e "${YELLOW}Updating ECS service...${NC}"
    echo "Cluster: ${CLUSTER_NAME}"
    echo "Service: ${SERVICE_NAME}"
    
    aws ecs update-service \
        --cluster "${CLUSTER_NAME}" \
        --service "${SERVICE_NAME}" \
        --force-new-deployment \
        --region "${REGION}" > /dev/null 2>&1 && {
        echo -e "${GREEN}✓ ECS service update initiated${NC}"
        echo "The service will pull the new image and restart tasks."
    } || {
        echo -e "${YELLOW}Warning: Could not update ECS service automatically${NC}"
        echo "You may need to update it manually or wait for automatic deployment."
    }
else
    echo -e "${YELLOW}ECS cluster/service names not found in Terraform outputs${NC}"
    echo "You may need to update the ECS service manually:"
    echo "  aws ecs update-service --cluster <cluster-name> --service <service-name> --force-new-deployment"
fi

echo -e "\n${GREEN}Deployment complete!${NC}"
