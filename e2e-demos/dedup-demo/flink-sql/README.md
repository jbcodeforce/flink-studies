# Flink SQL Deduplication Summary

## What Was Created

### 1. Complete Flink SQL Script (`flink-deduplication.sql`)
- **Source Table**: `product_events_raw` - reads from Kafka `products` topic
- **Flattened View**: `product_events_flattened` - unnests the product structure
- **Deduplication View**: `product_events_deduplicated` - removes duplicates using ROW_NUMBER()
- **Destination Table**: `src_products` - final deduplicated table with upsert-kafka connector
- **Monitoring Views**: `deduplication_stats` and `current_product_state`

### 2. Deployment Helper Script (`run-flink-dedup.sh`)
- Detects local vs Kubernetes deployment
- For Kubernetes: Copies SQL file to Flink pod and executes it
- For local: Uses local Flink installation

### 3. Updated Documentation
- Complete usage instructions for both local and Kubernetes deployments
- Step-by-step testing guide
- Monitoring queries and expected results

## Key Features

### Deduplication Logic
```sql
-- Content-based deduplication
ROW_NUMBER() OVER (
    PARTITION BY product_id, product_name, price, stock_quantity, discount
    ORDER BY event_timestamp DESC
) as row_num
-- Keep only row_num = 1 (most recent event for each unique product state)
```

### Kubernetes Integration
- Designed for Confluent Platform for Flink
- Uses `kubectl exec` to access Flink SQL CLI
- Automatically detects and uses Flink pods in `confluent` namespace

### Monitoring Capabilities
- **Deduplication Statistics**: Total events vs unique products
- **Current Product State**: Latest state of each product
- **Real-time Monitoring**: Track events as they're processed

## How to Use

### Quick Start (Kubernetes)
```bash
# 1. Start the producer
kubectl apply -f k8s/producer-pod.yaml

# 2. Run deduplication
./run-flink-dedup.sh
# Select option 1 (Kubernetes)

# 3. Monitor results
# In Flink SQL CLI:
SELECT * FROM deduplication_stats;
SELECT * FROM current_product_state;
```

### Manual Kubernetes Execution
```bash
# Copy SQL file to Flink pod
kubectl cp flink-deduplication.sql confluent/flink-pod:/tmp/flink-deduplication.sql

# Execute the script
kubectl exec -it flink-pod -n confluent -- /opt/flink/bin/sql-client.sh -f /tmp/flink-deduplication.sql
```

## Architecture Flow

```
Producer → Kafka(products) → Flink SQL → Kafka(src_products)
    ↓           ↓                ↓              ↓
Raw Events  Duplicates    Deduplication  Clean Data
(100%)      (~30%)        Logic          (~70%)
```

## Key Benefits

1. **Real-time Processing**: Events are deduplicated as they arrive
2. **Scalable**: Uses Flink's distributed processing capabilities
3. **Monitoring**: Built-in views to track deduplication effectiveness
4. **Flexible**: Easy to modify deduplication criteria
5. **Cloud-ready**: Integrated with Confluent Platform for Kubernetes

## Tables Created

- **`product_events_raw`**: Raw events from Kafka
- **`src_products`**: Final deduplicated table (primary output)
- **Views**: Intermediate processing and monitoring views

The `src_products` table is the main output that downstream applications should consume for clean, deduplicated product data. 