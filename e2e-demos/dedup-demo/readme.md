# Deduplication Demo

This demo showcases how to handle duplicate events in a streaming data pipeline using Apache Flink. The demo includes a Python producer that intentionally generates duplicate product events to demonstrate Flink's deduplication capabilities.

## Overview

The demo consists of:
- **Python Producer** (`product_producer.py`): Generates product events with intentional duplicates
- **Kafka Topic**: Stores the streaming product events
- **Flink SQL Deduplication** (`flink-deduplication.sql`): Interactive SQL-based deduplication
- **Flink Table API Application** (`flink-table-api/`): Production-ready Java application for Kubernetes deployment
- **Output**: `src_products` table/topic with deduplicated data

## Product Event Schema

The producer uses Pydantic models that align with the PostgreSQL schema. Events are structured as follows:

### Product Model (matches SQL schema)
```sql
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT NOT NULL DEFAULT 0,
    discount DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### ProductEvent JSON Structure
```json
{
  "event_id": "evt_1_1640995200_1234",
  "action": "updated",
  "timestamp": "2023-12-01T10:30:00.123456+00:00",
  "processed": false,
  "product": {
    "product_id": 1,
    "product_name": "Laptop Pro",
    "description": "High-performance laptop for professionals",
    "price": "1299.99",
    "stock_quantity": 25,
    "discount": "0.00",
    "created_at": "2023-12-01T09:00:00.000000+00:00",
    "updated_at": "2023-12-01T10:30:00.123456+00:00"
  },
  "old_price": "1199.99"
}
```

**Note:** Decimal values are serialized as strings to maintain precision, and timestamps are in ISO format with timezone information.

### Benefits of Using Pydantic Models

1. **Type Safety**: Ensures data integrity with compile-time type checking
2. **Validation**: Automatic validation of field constraints (e.g., non-negative prices)
3. **Schema Alignment**: Models directly match the PostgreSQL schema
4. **Serialization**: Built-in JSON serialization with proper handling of Decimal and datetime types
5. **Documentation**: Self-documenting code with field descriptions and constraints

## Running the Producer

### Prerequisites

1. Install [uv](https://docs.astral.sh/uv/getting-started/installation/) Python package manager
2. Create and activate a virtual environment (if needed):
```bash
uv venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

3. Install Python dependencies:
```bash
uv sync
```

4. Ensure Kafka is running (default: `localhost:9092`)

Alternatively, you can use the setup script to handle dependencies and initial setup:
```bash
./setup.sh
```

### Configuration

The producer uses environment variables for configuration:

- `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker address (default: `localhost:9092`)
- `KAFKA_PRODUCT_TOPIC`: Topic name for product events (default: `products`)
- `KAFKA_USER`: Username for SASL authentication (optional)
- `KAFKA_PASSWORD`: Password for SASL authentication (optional)
- `KAFKA_SECURITY_PROTOCOL`: Security protocol (default: `PLAINTEXT`)
- `KAFKA_SASL_MECHANISM`: SASL mechanism (default: `PLAIN`)
- `KAFKA_CERT`: Path to SSL certificate (optional)

### Start the Producer

```bash
uv run product_producer.py
```

The producer will:
- Generate new product events (70% probability)
- Create duplicates of recent events (30% probability)
- Use `product_id` as the message key for consistent partitioning
- Display when duplicate events are being generated with a 🔄 indicator

### Sample Output

```
📦 Sent event: updated for product Coffee Maker (ID: 3)
📦 Sent event: price_changed for product Smartphone (ID: 5)
   💰 Price changed: $699.99 → $756.23
🔄 Generating DUPLICATE event!
📦 Sent event: stock_updated for product Running Shoes (ID: 4)
   📦 Stock updated to: 89
📦 Sent event: created for product Laptop Pro (ID: 1)
```

## Flink SQL Deduplication

This demo includes a complete Flink SQL script (`flink-deduplication.sql`) that implements deduplication and creates the `src_products` table.

### Deduplication Strategy

The SQL script implements **content-based deduplication**:
- Partitions events by `product_id` and product state (name, price, stock, discount)
- Uses `ROW_NUMBER()` to keep only the most recent event for each unique product state
- Creates a `src_products` table with deduplicated data

### Running the Flink SQL Deduplication

#### Option 1: Using the Helper Script (Recommended)

```bash
./run-flink-dedup.sh
```

The script will:
1. Detect your deployment environment (local or Kubernetes)
2. For Kubernetes: Copy the SQL file to a Flink pod and execute it
3. For local: Run the SQL file using your local Flink installation

#### Option 2: Manual Kubernetes Execution

```bash
# Find Flink pods
kubectl get pods -n confluent -l app=flink

# Copy SQL file to Flink pod
kubectl cp flink-deduplication.sql confluent/your-flink-pod:/tmp/flink-deduplication.sql

# Execute the SQL script
kubectl exec -it your-flink-pod -n confluent -- /opt/flink/bin/sql-client.sh -f /tmp/flink-deduplication.sql
```

#### Option 3: Interactive SQL CLI

```bash
# Connect to Flink SQL CLI
kubectl exec -it your-flink-pod -n confluent -- /opt/flink/bin/sql-client.sh

# Then paste the SQL commands from flink-deduplication.sql
```

### Key SQL Components

The deduplication script creates several components:

1. **`product_events_raw`**: Source table reading from Kafka `products` topic
2. **`product_events_flattened`**: View that flattens the nested product structure
3. **`product_events_deduplicated`**: View implementing deduplication logic
4. **`src_products`**: Final table with deduplicated product data (upsert-kafka connector)
5. **Monitoring views**: `deduplication_stats` and `current_product_state`

### Monitoring Deduplication

Once the Flink SQL script is running, you can monitor the deduplication process:

```sql
-- Check deduplication statistics
SELECT * FROM deduplication_stats;

-- View current product states
SELECT * FROM current_product_state;

-- Monitor incoming events
SELECT product_id, action, event_timestamp 
FROM product_events_flattened 
ORDER BY event_timestamp DESC LIMIT 10;

-- Compare raw vs deduplicated counts
SELECT 'Raw Events' as source, COUNT(*) as count FROM product_events_flattened
UNION ALL
SELECT 'Deduplicated' as source, COUNT(*) as count FROM product_events_deduplicated;
```

### SQL Script Structure

The complete `flink-deduplication.sql` script includes:

```sql
-- 1. Source table reading from Kafka
CREATE TABLE product_events_raw (...) WITH ('connector' = 'kafka', ...);

-- 2. Flattened view for easier processing  
CREATE VIEW product_events_flattened AS SELECT ...;

-- 3. Deduplication logic using ROW_NUMBER()
CREATE VIEW product_events_deduplicated AS
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY product_id, product_name, price, stock_quantity
        ORDER BY event_timestamp DESC
    ) as row_num
    FROM product_events_flattened
) WHERE row_num = 1;

-- 4. Final output table with upsert-kafka connector
CREATE TABLE src_products (...) WITH ('connector' = 'upsert-kafka', ...);

-- 5. Insert deduplicated data
INSERT INTO src_products SELECT ... FROM product_events_deduplicated;
```

See the complete script in [`flink-deduplication.sql`](flink-deduplication.sql) for all details.

## Flink Implementation Options

This demo provides **two different Flink implementations** for different use cases:

### 1. Flink SQL (`flink-deduplication.sql`)
- **Use Case**: Development, testing, and interactive exploration
- **Deployment**: Run via Flink SQL CLI (`./run-flink-dedup.sh`)
- **Best For**: Quick prototyping, learning, and ad-hoc analysis

### 2. Flink Table API (`flink-table-api/`)
- **Use Case**: Production deployments and automated pipelines
- **Deployment**: Kubernetes application with proper resource management
- **Best For**: Production workloads, CI/CD integration, and enterprise deployment

| Feature | Flink SQL | Flink Table API |
|---------|-----------|-----------------|
| **Development Speed** | ⚡ Fast | 🔧 Moderate |
| **Production Ready** | 🧪 Testing | ✅ Yes |
| **Resource Management** | 📝 Manual | 🚀 Automated |
| **Monitoring** | 📊 Basic | 📈 Full Observability |
| **Deployment** | 🖥️ Interactive | 🎯 Kubernetes |
| **Configuration** | 🔧 Static | ⚙️ Runtime |

Choose the approach that best fits your needs:
- **Start with SQL** for development and proof-of-concept
- **Move to Table API** for production deployment

## Deployment Options

### Local Development

For local development with an existing Kafka cluster:

1. Start the producer: `uv run product_producer.py`
2. Monitor the Kafka topic to see events and duplicates

### Kubernetes with Confluent Platform

For deployment on Kubernetes with Confluent Platform:

1. **Build the Docker image:**
   ```bash
   ./build-image.sh
   
   # For local k8s clusters, load the image
   minikube image load dedup-demo-producer:latest
   # OR: kind load docker-image dedup-demo-producer:latest
   ```

2. **Deploy the Kafka Topic and Producer:**
   ```bash
   kubectl apply -f k8s/products-topic.yaml
   kubectl apply -f k8s/producer-pod.yaml
   ```

3. **Monitor the producer:**
   ```bash
   kubectl logs -f dedup-demo-producer -n confluent
   ```

See the [k8s/README.md](k8s/README.md) for detailed Kubernetes deployment instructions.

## Testing the Complete Demo

### Step 1: Start the Producer

Choose your deployment option:

**Local Development:**
```bash
uv run product_producer.py
```

**Kubernetes:**
```bash
kubectl apply -f k8s/products-topic.yaml
kubectl apply -f k8s/producer-pod.yaml
kubectl logs -f dedup-demo-producer -n confluent
```

### Step 2: Monitor Incoming Events

Monitor the raw Kafka topic to see events and duplicates:

```bash
# For local Kafka
kafka-console-consumer --topic products --bootstrap-server localhost:9092 --from-beginning

# For Kubernetes deployment  
kubectl exec -it kafka-0 -n confluent -- kafka-console-consumer --topic products --bootstrap-server kafka:9092 --from-beginning
```

### Step 3: Run Flink Deduplication

Choose your Flink implementation:

#### Option A: Flink SQL (Development/Testing)
```bash
./run-flink-dedup.sh
```

Or manually for Kubernetes:
```bash
kubectl cp flink-deduplication.sql confluent/flink-pod:/tmp/flink-deduplication.sql
kubectl exec -it flink-pod -n confluent -- /opt/flink/bin/sql-client.sh -f /tmp/flink-deduplication.sql
```

#### Option B: Flink Table API (Production)
```bash
# Build and deploy the Table API application
cd flink-table-api
./build-flink-app.sh

# Load image to local Kubernetes
minikube image load flink-dedup-app:1.0.0

# Deploy to Kubernetes
kubectl apply -f k8s/flink-application.yaml

# Monitor the job
kubectl get flinkapplication -n flink
kubectl logs -f deployment/product-dedup-job-jobmanager -n flink
```

### Step 4: Verify Deduplication

Check the deduplication results:

```sql
-- In Flink SQL CLI:
SELECT * FROM deduplication_stats;
SELECT * FROM current_product_state;
```

Monitor the output topic:
```bash
# Check the deduplicated results in src_products topic
kubectl exec -it kafka-0 -n confluent -- kafka-console-consumer --topic src_products --bootstrap-server kafka:9092 --from-beginning
```

### Expected Results

You should observe:
- **Raw events**: ~30% duplicates from the producer
- **Deduplication stats**: Shows total events, unique products, and duplicate percentage
- **src_products table**: Contains only unique product states
- **Processing**: Real-time deduplication as new events arrive

## Troubleshooting

### DNS Resolution Errors

If you encounter errors like:
```
Failed to resolve 'kafka-X.kafka.confluent.svc.cluster.local'
```

This means you're running the producer outside the cluster but Kafka is returning internal hostnames. **Recommended solution**: Use the Kubernetes producer pod instead:

```bash
kubectl apply -f k8s/producer-pod.yaml
kubectl logs -f dedup-demo-producer -n confluent
```

For detailed troubleshooting steps, see [k8s/README.md](k8s/README.md#troubleshooting).

## Next Steps

- **✅ Completed**: Flink SQL deduplication with `src_products` table
- **✅ Completed**: Flink Table API production application 
- **✅ Completed**: Kubernetes deployment with Confluent Platform
- **✅ Completed**: Docker containerization and build automation
- Add advanced monitoring and alerting (Prometheus/Grafana integration)
- Implement CI/CD pipeline for the Table API application
- Add unit and integration tests for the Java application
- Experiment with different deduplication time windows and strategies
- Add more complex duplicate scenarios (partial updates, out-of-order events)
- Implement downstream consumers of the `src_products` table
- Add data quality checks and validation rules
- Performance testing and optimization for high-volume scenarios
- Add schema evolution and backward compatibility support

