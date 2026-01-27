# Model Serving with Feast Integration

A production-ready model serving application that fetches features from Feast online store and provides REST API endpoints for driver risk prediction.

## Overview

This model serving application:
- Fetches features from Feast online store using FeatureService
- Runs a simple rule-based model for driver risk prediction
- Exposes REST API endpoints for inference
- Includes health checks and metrics
- Ready for Kubernetes deployment

## Architecture

```
Client Request → FastAPI Service → Feast FeatureStore → Online Store (SQLite/Redis)
                                    ↓
                              Model Inference → Prediction Response
```

## Prerequisites

- Python 3.12+
- Feast feature repository configured
- Feast online store populated (by Kafka consumer)
- Access to Feast feature repository

## Installation

### Local Development

1. Install dependencies using uv:
```bash
uv sync
```

2. Set up environment variables (see Configuration section)

3. Run the model serving application:
```bash
uv run python -m model_serving.main
```

The API will be available at `http://localhost:8000`

### Docker

Build the Docker image:
```bash
docker build -f Dockerfile.model-serving -t jbcodeforce/model-serving:latest .
```

Run the container:
```bash
docker run -p 8000:8000 \
           -e FEAST_REPO_PATH=/app/feature_repo \
           -e FEAST_FEATURE_SERVICE=driver_activity_v3 \
           -v $(pwd)/feature_repo:/app/feature_repo \
           jbcodeforce/model-serving:latest
```

## Configuration

Configuration is managed through environment variables. All settings have sensible defaults.

### Required Configuration

- `FEAST_REPO_PATH`: Path to Feast feature repository (default: `./feature_repo`)
- `FEAST_FEATURE_SERVICE`: FeatureService name to use (default: `driver_activity_v3`)

### Optional Configuration

- `MODEL_TYPE`: Type of model (default: `rule_based`)
- `MODEL_PATH`: Path to pre-trained model file (if using pre-trained model)
- `MODEL_VERSION`: Model version identifier (default: `1.0.0`)
- `SERVER_HOST`: Server host (default: `0.0.0.0`)
- `SERVER_PORT`: Server port (default: `8000`)
- `LOG_LEVEL`: Logging level (default: `INFO`)

## API Endpoints

### POST /predict

Get a risk prediction for a driver.

**Request:**
```json
{
  "driver_id": 1001,
  "val_to_add": 1000,
  "val_to_add_2": 2000
}
```

**Response:**
```json
{
  "prediction": {
    "risk_score": 0.35,
    "risk_level": "low"
  },
  "features_used": {
    "conv_rate": 0.8,
    "acc_rate": 0.9,
    "avg_daily_trips": 500.0,
    "conv_rate_plus_val1": 1800.0,
    "conv_rate_plus_val2": 2800.0
  },
  "model_version": "1.0.0"
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "feast_connected": true,
  "model_loaded": true
}
```

### GET /metrics

Get service metrics.

**Response:**
```json
{
  "requests_processed": 150,
  "requests_failed": 2,
  "average_response_time_ms": 45.23
}
```

### GET /

Root endpoint with API information.

### GET /docs

Interactive API documentation (Swagger UI).

## Model Details

The current implementation uses a simple rule-based model that predicts driver risk based on:

- **conv_rate** (conversion rate): Higher is better (lower risk)
- **acc_rate** (acceptance rate): Higher is better (lower risk)
- **avg_daily_trips** (average daily trips): More trips can indicate higher activity but also potential fatigue

**Risk Score Calculation:**
```
risk_score = (1 - conv_rate) * 0.4 + (1 - acc_rate) * 0.4 + (trips / 2000) * 0.2
```

**Risk Levels:**
- `low`: risk_score < 0.4
- `medium`: 0.4 ≤ risk_score < 0.7
- `high`: risk_score ≥ 0.7

## Kubernetes Deployment

### 1. Create ConfigMap

Update `k8s/model-serving-configmap.yaml` with your configuration values, then apply:

```bash
kubectl apply -f k8s/model-serving-configmap.yaml
```

### 2. Create Feast Feature Repository ConfigMap

The Feast feature repository needs to be available as a ConfigMap:

```bash
kubectl create configmap feast-feature-repo \
  --from-file=feature_repo/ \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 3. Deploy the Model Serving Service

```bash
kubectl apply -f k8s/model-serving-deployment.yaml
kubectl apply -f k8s/model-serving-service.yaml
```

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -l app=model-serving

# Check logs
kubectl logs -f deployment/model-serving

# Port forward to test
kubectl port-forward svc/model-serving 8000:8000

# Test prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"driver_id": 1001, "val_to_add": 1000, "val_to_add_2": 2000}'
```

## Example Usage

### Using curl

```bash
# Health check
curl http://localhost:8000/health

# Get prediction
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "driver_id": 1001,
    "val_to_add": 1000,
    "val_to_add_2": 2000
  }'

# Get metrics
curl http://localhost:8000/metrics
```

### Using Python

```python
import requests

# Health check
response = requests.get("http://localhost:8000/health")
print(response.json())

# Get prediction
response = requests.post(
    "http://localhost:8000/predict",
    json={
        "driver_id": 1001,
        "val_to_add": 1000,
        "val_to_add_2": 2000
    }
)
print(response.json())
```

## Integration with Kafka Consumer

This model serving application works seamlessly with the Kafka consumer:

1. **Kafka Consumer** pushes driver stats to Feast online store
2. **Model Serving** fetches features from Feast online store
3. **Model** makes predictions based on the latest features

The model serving application does not wait for Kafka - it always uses the latest features available in the Feast online store, ensuring low-latency predictions even if Kafka is lagging.

## Monitoring

### Health Checks

The `/health` endpoint checks:
- Feast connectivity
- Model availability

### Metrics

The `/metrics` endpoint provides:
- Total requests processed
- Total requests failed
- Average response time

### Logging

The application uses structured logging with configurable log levels. Logs include:
- Request details
- Feature fetching status
- Prediction results
- Error details with stack traces

## Troubleshooting

### No features found for driver_id

**Problem:** Getting 404 error when requesting prediction.

**Solution:**
1. Ensure the Kafka consumer has pushed data for this driver_id
2. Check that features are materialized in Feast online store
3. Verify the driver_id exists in the online store:
```bash
kubectl exec -it <pod-name> -- python -c "
from feast import FeatureStore
store = FeatureStore(repo_path='/app/feature_repo')
features = store.get_online_features(
    features=['driver_hourly_stats_fresh:conv_rate'],
    entity_rows=[{'driver_id': 1001}]
)
print(features.to_dict())
"
```

### Feast connection errors

**Problem:** Health check shows `feast_connected: false`

**Solution:**
1. Verify Feast repository path is correct
2. Check that feature repository is accessible
3. Verify FeatureService name is correct
4. Check Feast store logs

### Model prediction errors

**Problem:** Getting 500 errors on prediction endpoint

**Solution:**
1. Check application logs for detailed error messages
2. Verify all required features are available in Feast
3. Check feature values are valid (not None, within expected ranges)

## Development

### Code Structure

```
model_serving/
├── __init__.py
├── main.py              # Entry point
├── app.py               # FastAPI application
├── config.py            # Configuration management
├── schemas.py           # Request/response models
├── feast_client.py      # Feast integration
├── model.py             # Model implementation
└── utils.py             # Utility functions
```

### Running Tests

```bash
# Install test dependencies
uv sync --dev

# Run tests
uv run pytest tests/
```

### Adding a New Model

1. Implement model class in `model.py` or create new model file
2. Update `load_model()` function to support new model type
3. Update configuration to allow selecting new model type
4. Update documentation

## License

See main project LICENSE file.
