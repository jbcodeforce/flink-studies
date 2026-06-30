# Use-case templates

Preset topic and entity patterns for common streaming demos. Pass topics to `jump-start init --topics ...`.

## Fraud detection

| Item | Value |
|------|-------|
| Topics | `transactions`, `fraud-alerts`, `customer-profiles` |
| Entities | `transaction`, `fraud_alert`, `customer_profile` |
| Pipeline intent | Velocity checks, amount thresholds, risk scoring |

## IoT sensor monitoring

| Item | Value |
|------|-------|
| Topics | `sensor-readings`, `device-status`, `alerts` |
| Entities | `sensor_reading`, `device_status`, `alert` |
| Pipeline intent | Rolling averages, threshold alerts, connectivity tracking |

## Order management

| Item | Value |
|------|-------|
| Topics | `orders`, `inventory-updates`, `shipments` |
| Entities | `order`, `inventory_update`, `shipment` |
| Pipeline intent | Inventory sync, fulfillment timing, low-stock alerts |

## Customer analytics

| Item | Value |
|------|-------|
| Topics | `user-events`, `session-analytics`, `customer-segments` |
| Entities | `user_event`, `session_analytic`, `customer_segment` |
| Pipeline intent | Session aggregation, behavior segments, engagement metrics |

## Example init commands

```bash
# Fraud detection
uv run jump-start init --name fraud-detection --domain finance \
  --topics transactions,fraud-alerts \
  --targets cccloud,oss-flink

# IoT monitoring
uv run jump-start init --name iot-monitoring --domain manufacturing \
  --topics sensor-readings,alerts \
  --targets cccloud
```

After scaffold, customize DDL columns and DML logic for the specific business rules.
