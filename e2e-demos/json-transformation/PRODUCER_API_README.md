# Kafka Producer REST API & Web Interface

This FastAPI-based application provides both a web interface and REST API endpoints to control the production of JSON records to Kafka topics. It supports predefined record types (jobs, orders) and custom JSON payloads.

## 🌐 **NEW: Web Interface**

The application now includes a beautiful, modern web interface for easy record production!

### **Features:**
- 🎨 **Modern UI**: Clean, responsive design with real-time status updates
- 📝 **Smart Forms**: Dynamic forms that adapt based on message type selection
- 🔄 **Real-time Status**: Live job progress monitoring with automatic polling
- 📊 **Job Management**: View job history and status directly in the browser
- ⚡ **Fast Feedback**: Instant validation and user-friendly error messages

## 🚀 Quick Start

### Deploy & Access the Web Interface

```bash
# Option 1: Direct localhost access (NodePort - RECOMMENDED)
make demo_web_direct               # Complete setup + direct access

# Option 2: Port-forwarding access
make demo_web                      # Complete setup + port-forward

# Or step by step:
make setup_demo                    # Deploy all components
# Then choose access method:
make open_web_ui_nodeport         # Direct access (no port-forward needed)
# OR
make port_forward_producer_api    # Setup port forwarding
make open_web_ui                  # Port-forward access
```

### 🌐 Access Points

**Direct Access (NodePort - No port-forward needed):**
- 🌐 **Web Interface**: `http://localhost:30080/` 
- 📚 **Swagger UI**: `http://localhost:30080/docs`
- 📖 **ReDoc**: `http://localhost:30080/redoc` 
- 🔍 **Health Check**: `http://localhost:30080/health`
- 📋 **API Info**: `http://localhost:30080/api`

**Port-Forward Access (Alternative method):**
- 🌐 **Web Interface**: `http://localhost:8080/` (requires `make port_forward_producer_api`)
- 📚 **Swagger UI**: `http://localhost:8080/docs`
- 📖 **ReDoc**: `http://localhost:8080/redoc` 
- 🔍 **Health Check**: `http://localhost:8080/health`

## 📡 API Endpoints

### Health & Status

#### `GET /`
Basic health check
```bash
curl http://localhost:8080/
```

#### `GET /health`
Detailed health check with dependency status
```bash
curl http://localhost:8080/health
```

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

## 🌐 Using the Web Interface

### **Step 1: Select Message Type**
Choose from:
- 📦 **Order Records**: E-commerce order data 
- 💼 **Job Records**: Job posting data
- 🛠️ **Custom JSON**: Your own JSON payload

### **Step 2: Configure Production**
- **Topic**: Kafka topic name (auto-suggestions provided)
- **Count**: Number of records (1-1000 for predefined types)
- **Custom Data**: JSON editor for custom payloads

### **Step 3: Monitor Progress**  
- Real-time job status updates
- Completion notifications
- Error handling with detailed messages

## 🛠️ Development & Testing

### Run Locally

```bash
# Install dependencies
pip install fastapi uvicorn confluent-kafka pydantic jinja2 python-multipart

# Set environment variables (same as CLI producer)
export KAFKA_BOOTSTRAP_SERVERS="localhost:9094"
export KAFKA_TOPIC="raw-orders"

# Run the API server
python api_server.py

# Or with uvicorn directly
uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
```

### **Access Locally**
- **Web Interface**: `http://localhost:8000/`
- **API Docs**: `http://localhost:8000/docs`

### Test with curl

```bash
# Health check
curl http://localhost:8000/health

# Produce records
curl -X POST http://localhost:8000/produce \
  -H "Content-Type: application/json" \
  -d '{"type": "job", "topic": "raw-jobs", "count": 3}'

# Check job status (use job_id from response)
curl http://localhost:8000/jobs/job_1705749600_a1b2c3d4

# List all jobs
curl http://localhost:8000/jobs
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

## 🔧 Deployment Options

### **Option 1: Web Interface Only**
Deploy just the web interface for interactive control:
```bash
make deploy_producer_api
make port_forward_producer_api 
make open_web_ui
```

### **Option 2: Full Demo Setup**  
Deploy web interface + CLI producers:
```bash
make demo_web  # Complete setup with web access
```

### **Option 3: Manual Deployment**
Deploy components separately:
```bash
kubectl apply -f cp-flink/orders_producer_pod.yaml
kubectl apply -f cp-flink/jobs_producer_pod.yaml  
kubectl apply -f cp-flink/producer_api_pod.yaml
```

### Option 3: Docker Compose (Local)
```yaml
version: '3.8'
services:
  producer-api:
    build: ./producer
    command: ["python", "api_server.py"]
    ports:
      - "8000:8000"
    environment:
      - KAFKA_BOOTSTRAP_SERVERS=kafka:9092
      - KAFKA_TOPIC=raw-orders
```

## 🚨 Production Considerations

1. **Authentication**: Add authentication/authorization middleware
2. **Rate Limiting**: Implement request rate limiting  
3. **Monitoring**: Add metrics and logging integration
4. **Persistence**: Use Redis/Database instead of in-memory job tracking
5. **Scaling**: Deploy multiple API instances behind a load balancer
6. **Security**: Add input validation and sanitization
7. **Async Processing**: Consider using Celery for long-running jobs

## 🐛 Troubleshooting

### API Server Won't Start
- Check if port 8000 is available
- Verify all dependencies are installed
- Check Kafka connection settings

### Jobs Stuck in "running"
- Check Kafka broker connectivity
- Verify topic exists and is accessible
- Check producer logs for errors

### High Memory Usage
- Clean up completed jobs regularly: `POST /jobs/cleanup`
- Reduce job history retention
- Monitor background task queue

### Connection Errors
```bash
# Test Kafka connectivity from within the pod
kubectl exec -it producer-api -n confluent -- python -c "
import os
from kafka_json_producer import KafkaJSONProducer
producer = KafkaJSONProducer('test-topic')
print('Kafka connection successful!')
"
```

## 📚 Documentation & Resources

### **Interactive Documentation**
- 🌐 **Web Interface**: `http://localhost:8080/` - User-friendly form interface
- 📚 **Swagger UI**: `http://localhost:8080/docs` - Interactive API testing
- 📖 **ReDoc**: `http://localhost:8080/redoc` - Beautiful API documentation  

### **Quick Make Commands**
```bash
# Web Interface - Direct Access (RECOMMENDED)
make demo_web_direct        # Complete setup + direct localhost access
make open_web_ui_nodeport   # Open web interface (NodePort)
make open_swagger_nodeport  # Open Swagger UI (NodePort)  
make open_redoc_nodeport    # Open ReDoc (NodePort)

# Web Interface - Port Forward Access
make demo_web               # Complete setup + port-forward access
make open_web_ui           # Open web interface (port-forward)
make open_swagger          # Open Swagger UI (port-forward)
make open_redoc            # Open ReDoc (port-forward)

# Deployment & Status
make deploy_producer_api   # Deploy API pod
make status_producers      # Check all producer status (shows access URLs)

# Testing - Direct Access
make test_api_health_nodeport       # Test API health (NodePort)
make test_api_produce_orders_nodeport  # Test order production (NodePort)
make test_api_produce_jobs_nodeport    # Test job production (NodePort)

# Testing - Port Forward Access  
make test_api_health       # Test API health (port-forward)
make test_api_produce_orders  # Test order production (port-forward)
make test_api_produce_jobs    # Test job production (port-forward)

# Management
make cleanup_demo          # Remove all components
```

### **Why Use the Web Interface?**
- ✅ **User-Friendly**: No need to remember API endpoints or JSON formats
- ✅ **Visual Feedback**: Real-time status updates and progress monitoring  
- ✅ **Form Validation**: Automatic validation prevents common mistakes
- ✅ **Quick Testing**: Perfect for demos, development, and testing
- ✅ **No CLI Required**: Accessible to non-technical team members

The FastAPI framework automatically generates comprehensive API documentation, while the web interface provides an intuitive way to interact with the system.
