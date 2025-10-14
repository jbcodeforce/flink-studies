# Payment Claims Enrichment - Flink Table API

This is a Flink Table API application that enriches payment events with claims data using lookup joins against an external DuckDB database.

## Architecture

The application implements a streaming enrichment pattern:

- **Input Stream**: Payment events from Kafka topic `payment-events`
- **Lookup Source**: Claims metadata in DuckDB database 
- **Output Streams**: 
  - `enriched-payments`: Successfully enriched events
  - `failed-payments`: Events that couldn't be enriched (claim not found, DB errors)

## Features

- **Lookup Joins**: Uses Flink's `FOR SYSTEM_TIME AS OF` clause for real-time lookups
- **Error Handling**: Separates successful and failed enrichments into different topics
- **Caching**: LRU cache for lookup results with configurable TTL
- **Fault Tolerance**: Checkpointing enabled for exactly-once processing
- **Monitoring**: Structured logging and error categorization

## Data Flow

```
Payment Events (Kafka) → Flink Table API → Lookup Join (DuckDB) → Output Topics (Kafka)
                                              ↓
                                      Success/Failure Split
                                             ↙     ↘
                                   enriched-payments  failed-payments
```

## Data Models

### Input: Payment Event
```json
{
  "payment_id": "PAY-12345",
  "claim_id": "CLM-001", 
  "payment_amount": 1500.00,
  "payment_date": "2024-01-15T10:30:00",
  "processor_id": "PROC-VISA-001",
  "payment_method": "ELECTRONIC",
  "payment_status": "COMPLETED"
}
```

### Output: Enriched Payment Event
```json
{
  "payment_id": "PAY-12345",
  "claim_id": "CLM-001",
  "payment_amount": 1500.00,
  "payment_date": "2024-01-15T10:30:00",
  "processor_id": "PROC-VISA-001",
  "member_id": "MBR-789",
  "claim_amount": 2000.00,
  "claim_status": "APPROVED",
  "enrichment_status": "SUCCESS",
  "enrichment_timestamp": "2024-01-15T10:30:01"
}
```

### Database: Claims Table
```sql
CREATE TABLE claims (
  claim_id VARCHAR PRIMARY KEY,
  member_id VARCHAR NOT NULL,
  claim_amount DECIMAL(10,2) NOT NULL,
  claim_status VARCHAR,
  created_date TIMESTAMP
);
```

## Prerequisites

- Java 11+
- Maven 3.6+
- Apache Flink 1.20.0
- DuckDB with HTTP API endpoint
- Apache Kafka

## Configuration

Environment variables can override default configurations:

```bash
# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
PAYMENT_EVENTS_TOPIC=payment-events
ENRICHED_PAYMENTS_TOPIC=enriched-payments
FAILED_PAYMENTS_TOPIC=failed-payments

# DuckDB Configuration
DUCKDB_URL=jdbc:duckdb:http://localhost:8080/database
```

## Build and Run

### 1. Build the Application

```bash
mvn clean package
```

### 2. Run Locally (Standalone)

This is to test on a Flink local runtime.

```bash
# Start Flink cluster
$FLINK_HOME/bin/start-cluster.sh

# Submit job
$FLINK_HOME/bin/flink run \
  --class com.example.PaymentClaimsEnrichment \
  target/payment-claims-enrichment-1.0-SNAPSHOT.jar
```

### 3. Deploy to Kubernetes

```bash
# Build and push image
docker build -t your-registry/payment-claims-enrichment:latest .
docker push your-registry/payment-claims-enrichment:latest

# Apply Kubernetes manifests
kubectl apply -f k8s/
```

## Key SQL Queries

### Main Enrichment Query
```sql
SELECT 
    p.payment_id, p.claim_id, p.payment_amount, p.payment_date,
    p.processor_id, p.payment_method, p.payment_status,
    c.member_id, c.claim_amount, c.claim_status,
    CASE 
        WHEN c.claim_id IS NOT NULL THEN 'SUCCESS'
        ELSE 'CLAIM_NOT_FOUND'
    END as enrichment_status,
    CURRENT_TIMESTAMP as enrichment_timestamp
FROM payment_events p
LEFT JOIN claims_lookup FOR SYSTEM_TIME AS OF p.proc_time AS c
    ON p.claim_id = c.claim_id
```

### Lookup Table Definition
```sql
CREATE TABLE claims_lookup (
    claim_id STRING,
    member_id STRING, 
    claim_amount DECIMAL(10,2),
    claim_status STRING,
    created_date TIMESTAMP(3)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:duckdb:http://localhost:8080/database',
    'table-name' = 'claims',
    'lookup.cache' = 'LRU',
    'lookup.cache.max-rows' = '10000',
    'lookup.cache.ttl' = '1min',
    'lookup.async' = 'true'
)
```

## Performance Tuning

### Lookup Configuration
- `lookup.cache.max-rows`: Adjust based on memory and claim data size
- `lookup.cache.ttl`: Balance between cache hit rate and data freshness
- `lookup.async`: Enable for better throughput
- `lookup.max-retries`: Handle transient database errors

### Parallelism
- Adjust parallelism based on throughput requirements
- Consider Kafka partition count for optimal distribution

### Checkpointing
- `execution.checkpointing.interval`: Balance between fault tolerance and performance
- `execution.checkpointing.mode`: Use EXACTLY_ONCE for critical applications

## Monitoring

### Flink Web UI
Access at `http://localhost:8081` to monitor:
- Job status and performance metrics
- Checkpoint statistics
- Backpressure indicators
- Lookup join statistics

### Logs
Application logs are written to:
- Console (Docker/K8s environments)
- `logs/payment-claims-enrichment.log` (local runs)

### Key Metrics to Monitor
- **Lookup Success Rate**: Percentage of successful claim lookups
- **Processing Latency**: P95 latency from event ingestion to output
- **Checkpoint Duration**: Time taken for checkpoints to complete
- **Backpressure**: Indicates downstream bottlenecks

## Error Handling

The application handles several error scenarios:

1. **Claim Not Found**: Payment events with invalid claim_ids
   - Action: Route to `failed-payments` topic with status `CLAIM_NOT_FOUND`
   
2. **Database Unavailable**: DuckDB connection failures
   - Action: Automatic retries with exponential backoff
   - Fallback: Route to `failed-payments` with status `DB_ERROR`

3. **Timeout**: Slow database responses
   - Action: Route to `failed-payments` with status `DB_TIMEOUT`

## Testing

### Unit Tests
```bash
mvn test
```

### Integration Tests
Requires running Kafka and DuckDB:
```bash
# Start test environment
docker-compose -f docker-compose.test.yml up -d

# Run integration tests
mvn verify -P integration-test
```

### Load Testing
Use the event generator to create test scenarios:
```bash
# Generate payment events with 90% valid claim_ids
python ../event-generator/src/event_generator/cli.py \
  --events-per-second 100 \
  --valid-claim-rate 0.9 \
  --run-duration-seconds 300
```

## Troubleshooting

### Common Issues

1. **ClassNotFoundException for DuckDB Driver**
   - Ensure DuckDB JDBC driver is included in classpath
   - Check Maven shade plugin configuration

2. **Kafka Connection Errors**
   - Verify Kafka bootstrap servers configuration
   - Check topic existence and permissions

3. **Lookup Join Not Working**
   - Verify DuckDB HTTP API endpoint is accessible
   - Check claims table schema and data
   - Review lookup table DDL configuration

4. **Poor Performance**
   - Monitor checkpoint duration and backpressure
   - Tune lookup cache parameters
   - Adjust parallelism settings

### Debug Mode
Enable debug logging:
```bash
export FLINK_LOG_LEVEL=DEBUG
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is part of the Flink Studies repository and follows the same license terms.
