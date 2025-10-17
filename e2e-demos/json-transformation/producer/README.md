## Producers Kubernetes Deployment

This FastAPI-based application provides both a web interface and REST API endpoints to control the production of JSON records to Kafka topics. It supports predefined record types (jobs, orders) and custom JSON payloads.

This folder includes Kubernetes job manifests to start the producer API and Web App to produce records for `jobs` and `orders` to the `raw-orders` and `raw-jobs` topics.

### **Features:**
- 🎨 **Modern UI**: Clean, responsive design with real-time status updates
- 📝 **Smart Forms**: Dynamic forms that adapt based on message type selection
- 🔄 **Real-time Status**: Live job progress monitoring with automatic polling
- 📊 **Job Management**: View job history and status directly in the browser



## Run Locally

```bash
# Install dependencies
uv sync

# Set environment variables (same as CLI producer)
export KAFKA_BOOTSTRAP_SERVERS="localhost:9094"
export KAFKA_TOPIC="raw-orders"

# Run the API server
uv run api_server.py

# Or with uvicorn directly
uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
```

## 🚀 Quick Start on Kubernetes

To test in standalone mode, you may need to verify namespace and config map are created

```sh
kubectl get ns
kubectl get cm -n rental
```

if not do:
```
kubectl -f ../k8s/rental.yaml
kubectl -f ../k8s/kafka_client_cm.yaml
```


### WebApp

* Deploy the WebApp
  ```sh
  # Deploy the API
  make deploy_producer_api
  # Setup port forwarding  
  make port_forward_producer_api
  # Test the API
  make test_api_health
  ```

### 🌐 Access Points

**Direct Access (NodePort - No port-forward needed):**
- 🌐 **Web Interface**: `http://localhost:30080/` 
- 📚 **Swagger UI**: `http://localhost:30080/docs`
- 📖 **ReDoc**: `http://localhost:30080/redoc` 
- 🔍 **Health Check**: `http://localhost:30080/health`
- 📋 **API Info**: `http://localhost:30080/api`

### Job based
It is also possible to run the python code as job.

* Deploy config map and orders as kubernetes job to create 10 orders
  ```sh
  make deploy_order_producer
  ```

* Deploy job producer for 10 jobs
  ```sh
  make deploy_job_producer
  ```


## Code explanations

### Producer Endpoints

#### `POST /produce`
Produce predefined record types (job, order)

**Request Body:**
```json
{
  "type": "order",          // "job" or "order"
  "topic": "raw-orders",    // Kafka topic name
  "count": 5               // Number of records (1-1000)
}
```

**Example:**
```bash
curl -X POST http://localhost:8080/produce \
  -H "Content-Type: application/json" \
  -d '{
    "type": "order",
    "topic": "raw-orders", 
    "count": 10
  }'
```

**Response:**
```json
{
  "job_id": "job_1705749600_a1b2c3d4",
  "status": "queued",
  "message": "Started producing 10 order records to raw-orders",
  "request_details": {
    "type": "order",
    "topic": "raw-orders",
    "count": 10
  }
}
```

#### `POST /produce/custom`
Produce custom JSON data

**Request Body:**
```json
{
  "topic": "custom-topic",     // Kafka topic name
  "data": {                   // Your custom JSON data
    "id": "custom-123",
    "type": "custom_event",
    "payload": { ... }
  },
  "key": "optional-key"       // Optional message key
}
```

**Example:**
```bash
curl -X POST http://localhost:8080/produce/custom \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "events",
    "data": {
      "id": "evt-001",
      "user_id": "user-123", 
      "action": "login",
      "timestamp": "2024-01-20T10:00:00Z"
    },
    "key": "evt-001"
  }'
```

### Job Management

#### `GET /jobs/{job_id}`
Get status of a specific job

```bash
curl http://localhost:8080/jobs/job_1705749600_a1b2c3d4
```

**Response:**
```json
{
  "job_id": "job_1705749600_a1b2c3d4",
  "status": "completed",        // "queued", "running", "completed", "failed"
  "message": "Successfully produced 10 order records to raw-orders",
  "started_at": 1705749600.123,
  "completed_at": 1705749605.456,
  "records_produced": 10,
  "request_details": {
    "type": "order",
    "topic": "raw-orders", 
    "count": 10
  }
}
```

#### `GET /jobs`
List all recent jobs (last 50)

```bash
curl http://localhost:8080/jobs
```

#### `DELETE /jobs/{job_id}`
Delete a completed/failed job from tracking

```bash
curl -X DELETE http://localhost:8080/jobs/job_1705749600_a1b2c3d4
```

#### `POST /jobs/cleanup`
Clean up completed jobs older than 1 hour

```bash
curl -X POST http://localhost:8080/jobs/cleanup
```

## 🐍 Python Client

Use the provided `api_client_example.py` for Python integration:

```python
from api_client_example import ProducerAPIClient

client = ProducerAPIClient("http://localhost:8080")

# Health check
health = client.health_check()
print(f"API Status: {health['status']}")

# Produce order records
response = client.produce_records("order", "raw-orders", 5)
job_id = response["job_id"]

# Wait for completion
final_status = client.wait_for_job(job_id)
print(f"Job completed: {final_status['message']}")

# Produce custom JSON
custom_data = {"id": "test-123", "type": "api_test"}
response = client.produce_custom_json("test-topic", custom_data)
```


## ⚙️ Configuration

The API uses the same environment variables as the CLI producer:

| Variable | Description | Default |
|----------|-------------|---------|
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka broker addresses | `localhost:9094` |
| `KAFKA_TOPIC` | Default topic name | `raw-orders` |
| `KAFKA_USER` | SASL username | - |
| `KAFKA_PASSWORD` | SASL password | - |
| `KAFKA_SASL_MECHANISM` | SASL mechanism | `PLAIN` |
| `KAFKA_SECURITY_PROTOCOL` | Security protocol | `PLAINTEXT` |
| `KAFKA_CERT` | SSL certificate path | - |
| `PORT` | API server port | `8000` |
