# OrderDetails JSON to Flink Table Mapping

This document explains how to map the provided JSON document structure to a Flink SQL table for stream processing.

## JSON Document Structure

The source JSON has this nested structure:
```json
{
    "OrderDetails": {
      "EquipmentRentalDetails": [
        {
          "OrderId": 396404719,
          "Status": "Return",
          "Equipment": [
            {
              "ModelCode": "HO",
              "Rate": "34.95"
            }
          ],
          "TotalPaid": 37.4,
          "Type": "InTown",
          "Coverage": null,
          "Itinerary": {
            "PickupDate": "2020-09-21T18:14:08.000Z",
            "DropoffDate": "2020-09-21T20:47:42.000Z",
            "PickupLocation": "41260",
            "DropoffLocation": "41260"
          },
          "OrderType": "Umove",
          "AssociatedContractId": null
        }
      ]
    },
    "MovingHelpDetails": null
}
```

## Flink Table Schema

The Flink table uses ROW and ARRAY types to match the nested JSON structure:

```sql
CREATE TABLE OrderDetails (
  OrderDetails ROW<
    EquipmentRentalDetails ARRAY<ROW<
      OrderId BIGINT,
      Status STRING,
      Equipment ARRAY<ROW<
        ModelCode STRING,
        Rate STRING
      >>,
      TotalPaid DOUBLE,
      Type STRING,
      Coverage STRING,
      Itinerary ROW<
        PickupDate STRING,
        DropoffDate STRING,
        PickupLocation STRING,
        DropoffLocation STRING
      >,
      OrderType STRING,
      AssociatedContractId BIGINT
    >>
  >,
  MovingHelpDetails STRING
) WITH (
  'connector' = 'kafka',
  'topic' = 'order-details',
  'format' = 'json'
);
```

## Key Mapping Patterns

| JSON Path | Flink SQL Access | Type |
|-----------|------------------|------|
| `OrderDetails.EquipmentRentalDetails[0].OrderId` | `OrderDetails.EquipmentRentalDetails[1].OrderId` | `BIGINT` |
| `OrderDetails.EquipmentRentalDetails[0].Equipment[0].ModelCode` | `equipment_item.ModelCode` (after UNNEST) | `STRING` |
| `OrderDetails.EquipmentRentalDetails[0].Itinerary.PickupDate` | `rental_detail.Itinerary.PickupDate` | `STRING` |
| `MovingHelpDetails` | `MovingHelpDetails` | `STRING` |

## Processing Patterns

### 1. Direct Nested Access
```sql
SELECT OrderDetails.EquipmentRentalDetails[1].OrderId 
FROM OrderDetails;
```

### 2. Array Unnesting (Recommended)
```sql
SELECT rental_detail.OrderId, equipment_item.ModelCode
FROM OrderDetails
CROSS JOIN UNNEST(OrderDetails.EquipmentRentalDetails) AS t(rental_detail)
CROSS JOIN UNNEST(rental_detail.Equipment) AS e(equipment_item);
```

### 3. Flattened Output
```sql
INSERT INTO OrderDetails_Flat
SELECT 
  rental_detail.OrderId,
  rental_detail.Status,
  equipment_item.ModelCode,
  equipment_item.Rate,
  rental_detail.TotalPaid,
  rental_detail.Itinerary.PickupDate,
  rental_detail.Itinerary.DropoffDate
FROM OrderDetails
CROSS JOIN UNNEST(OrderDetails.EquipmentRentalDetails) AS t(rental_detail)
CROSS JOIN UNNEST(rental_detail.Equipment) AS e(equipment_item);
```

## File References

- `flink_orderdetails_statement.sql` - Complete DDL with Kafka connector and example queries
- `flink_orderdetails_flattened.sql` - Flattened processing approach with INSERT statement
- `OrderDetails.sql` - Original table definition
- `order_details.json` - Source JSON document structure

## Usage with Shift Left CLI

```bash
# Initialize table structure
shift_left table init order_details /path/to/pipeline

# Build and deploy pipeline
shift_left table build-inventory /path/to/pipeline
shift_left pipeline deploy /path/to/inventory.json --table-name order_details
```

## Notes

- JSON field names are case-sensitive and must match exactly
- NULL values in JSON (like `Coverage: null`) are handled gracefully
- Arrays require UNNEST operations for individual element access
- Complex nested structures may benefit from flattening for downstream processing