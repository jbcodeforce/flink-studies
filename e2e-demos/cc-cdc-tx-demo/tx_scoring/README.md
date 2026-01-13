# Transaction Scoring Service

FastAPI-based ML inference service for real-time transaction fraud scoring. This service provides HTTP endpoints that can be called by Flink SQL jobs to enrich transactions with fraud risk scores.

## Overview

The Transaction Scoring Service is a containerized FastAPI application that:
- Accepts transaction data (txn_id, amount, merchant, location)
- Returns fraud scores, categories, and risk levels
- Provides health check endpoints for ECS monitoring
- Currently uses rule-based scoring (placeholder for future ML model integration)

## Architecture

- **Framework**: FastAPI (Python 3.11)
- **Container**: Docker (multi-stage build)
- **Deployment**: AWS ECS/Fargate
- **Registry**: AWS ECR
- **Port**: 8080

## API Endpoints

### Health Check
```
GET /health
```

Returns service health status. Used by ECS health checks.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": 1704067200.0
}
```

### Transaction Scoring
```
POST /predict
```

Scores a transaction for fraud risk.

**Request:**
```json
{
  "txn_id": "txn-12345",
  "amount": 150.50,
  "merchant": "AMAZON",
  "location": "ONLINE"
}
```

**Response:**
```json
{
  "txn_id": "txn-12345",
  "fraud_score": 0.25,
  "fraud_category": "NORMAL",
  "risk_level": "LOW",
  "inference_timestamp": 1704067200.0
}
```

### API Documentation
- Interactive docs: `http://localhost:8080/docs`
- OpenAPI schema: `http://localhost:8080/openapi.json`

## Local Development

### Prerequisites
- Python 3.11+
- [uv](https://github.com/astral-sh/uv) (fast Python package installer)
- Docker (for containerized builds)

### Setup

1. **Install uv** (if not already installed):
```bash
curl -LsSf https://astral.sh/uv/install | sh
```

2. **Install dependencies:**
```bash
uv pip install -e .
```

Or using uv's sync command:
```bash
uv sync
```

2. **Run locally:**
```bash
python main.py
```

Or with uvicorn directly:
```bash
uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

3. **Test the service:**
```bash
# Health check
curl http://localhost:8080/health

# Score a transaction
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{
    "txn_id": "txn-12345",
    "amount": 150.50,
    "merchant": "AMAZON",
    "location": "ONLINE"
  }'
```

## Docker Build

### Build the image:
```bash
docker build -t tx-scoring:latest .
```

### Run the container:
```bash
docker run -p 8080:8080 tx-scoring:latest
```

### Test in container:
```bash
curl http://localhost:8080/health
```

## AWS ECR/ECS Deployment

The service is deployed to AWS ECS/Fargate using Terraform. The infrastructure is defined in `../IaC/ml-inference.tf`.

### Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform** initialized in the `../IaC` directory
3. **ECR repository** created (via Terraform)

### Deployment Steps

#### 1. Get ECR Repository URL

After Terraform deployment, get the ECR repository URL:
```bash
cd ../IaC
terraform output ecr_repository_url
```

Or from AWS Console: ECR → Repositories → `card-tx-ml-inference-{id}`

#### 2. Authenticate Docker with ECR

```bash
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

Replace `<region>` and `<account-id>` with your values.

#### 3. Build and Tag Image

```bash
# Build the image
docker build -t tx-scoring:latest .

# Tag for ECR
ECR_REPO=$(cd ../IaC && terraform output -raw ecr_repository_url)
docker tag tx-scoring:latest ${ECR_REPO}:latest
docker tag tx-scoring:latest ${ECR_REPO}:$(date +%Y%m%d-%H%M%S)
```

#### 4. Push to ECR

```bash
docker push ${ECR_REPO}:latest
docker push ${ECR_REPO}:$(date +%Y%m%d-%H%M%S)
```

#### 5. Update ECS Service

The ECS service is configured to use the `latest` tag. After pushing:

```bash
# Force new deployment (if needed)
aws ecs update-service \
  --cluster <cluster-name> \
  --service <service-name> \
  --force-new-deployment \
  --region <region>
```

Get cluster and service names from Terraform:
```bash
cd ../IaC
terraform output | grep -E "ecs_cluster|ml_inference_service"
```

### Automated Deployment Script

Create a deployment script `deploy.sh`:

```bash
#!/bin/bash
set -e

# Get ECR repository URL from Terraform
cd "$(dirname "$0")/../IaC"
ECR_REPO=$(terraform output -raw ecr_repository_url)
REGION=$(terraform output -raw cloud_region 2>/dev/null || echo "us-east-1")
CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
SERVICE=$(terraform output -raw ml_inference_service_name 2>/dev/null || echo "")

cd "$(dirname "$0")"

# Authenticate with ECR
echo "Authenticating with ECR..."
aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin ${ECR_REPO}

# Build image
echo "Building Docker image..."
docker build -t tx-scoring:latest .

# Tag and push
echo "Tagging and pushing to ECR..."
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker tag tx-scoring:latest ${ECR_REPO}:latest
docker tag tx-scoring:latest ${ECR_REPO}:${TIMESTAMP}

docker push ${ECR_REPO}:latest
docker push ${ECR_REPO}:${TIMESTAMP}

echo "Image pushed successfully!"
echo "Repository: ${ECR_REPO}"
echo "Tags: latest, ${TIMESTAMP}"

# Force ECS service update if cluster/service names are available
if [ -n "$CLUSTER" ] && [ -n "$SERVICE" ]; then
  echo "Updating ECS service..."
  aws ecs update-service \
    --cluster ${CLUSTER} \
    --service ${SERVICE} \
    --force-new-deployment \
    --region ${REGION} > /dev/null
  echo "ECS service update initiated"
fi
```

Make it executable:
```bash
chmod +x deploy.sh
```

## Integration with Flink

The service is designed to be called from Flink SQL jobs. See `../cc-flink-sql/04-ml-enrichment.sql` for integration examples.

### Example Flink SQL (when HTTP_REQUEST is available):

```sql
INSERT INTO ml_results
SELECT 
    t.txn_id,
    t.account_number,
    t.`timestamp`,
    t.amount,
    t.merchant,
    t.location,
    CAST(JSON_VALUE(
        HTTP_REQUEST(
            'POST',
            'http://<ecs-service-endpoint>:8080/predict',
            JSON_OBJECT(
                'txn_id' VALUE t.txn_id,
                'amount' VALUE t.amount,
                'merchant' VALUE t.merchant,
                'location' VALUE t.location
            )
        ),
        '$.fraud_score'
    ) AS DOUBLE) AS fraud_score,
    JSON_VALUE(
        HTTP_REQUEST(...),
        '$.fraud_category'
    ) AS fraud_category,
    CURRENT_TIMESTAMP AS inference_timestamp
FROM transactions t;
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Service port | `8080` |
| `HOST` | Bind host | `0.0.0.0` |
| `LOG_LEVEL` | Logging level | `INFO` |
| `APP_ENV` | Application environment | `production` |

## Future Enhancements

- [ ] Integrate actual Random Forest ML model
- [ ] Add model versioning and A/B testing
- [ ] Implement request caching for performance
- [ ] Add metrics and observability (Prometheus, CloudWatch)
- [ ] Support batch scoring endpoint
- [ ] Add authentication/authorization
- [ ] Implement rate limiting

## Troubleshooting

### Service not responding

1. **Check ECS task logs:**
```bash
aws logs tail /ecs/card-tx-ml-inference-{id} --follow
```

2. **Verify service is running:**
```bash
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name> \
  --query 'services[0].runningCount'
```

3. **Check security group rules:**
   - Ensure port 8080 is open for inbound traffic
   - Verify outbound rules allow responses

### Health check failures

1. **Check container logs** for errors
2. **Verify port 8080** is exposed in task definition
3. **Test health endpoint** manually:
```bash
curl http://<task-ip>:8080/health
```

### Image push failures

1. **Verify ECR authentication:**
```bash
aws ecr get-login-password --region <region>
```

2. **Check IAM permissions** for ECR push
3. **Verify repository exists:**
```bash
aws ecr describe-repositories --repository-names <repo-name>
```

## License

See parent directory LICENSE file.
