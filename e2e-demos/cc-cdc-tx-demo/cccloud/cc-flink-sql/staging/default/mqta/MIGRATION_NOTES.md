# Snowflake to Flink SQL Migration Notes

This document describes the migration of Snowflake SQL queries to Apache Flink SQL.

## Files Created

1. **ddl.mqta.sql** - Table definitions for all required tables
2. **dml.mqta.sql** - Main data transformation query (staging table population)
3. **merge_tranlog.sql** - Upsert logic for tranlog table (converted from MERGE statement)
4. **transaction_tracking.sql** - Transaction tracking and validation query

## Key Transformations Applied

### Data Types
- `VARCHAR` → `STRING`
- `TIMESTAMP_NTZ` → `TIMESTAMP(3)`
- `NUMBER(p,s)` → `DECIMAL(p,s)` or `INTEGER`/`BIGINT` where appropriate
- `TEXT` → `STRING`
- `DATE` → `DATE` (unchanged)

### Functions
- `TO_TIMESTAMP_NTZ()` → `TO_TIMESTAMP()` with precision
- `SYSDATE()` → `CURRENT_TIMESTAMP`
- `DATEADD()` → `TIMESTAMPADD()`
- `SPLIT_PART()` → `REGEXP_EXTRACT()` or `SPLIT()`
- `FLATTEN()` → `CROSS JOIN UNNEST()` with array operations
- `ARRAY_APPEND()` → `ARRAY_CONCAT()`
- `PARSE_JSON()` → JSON parsing handled by format
- `OBJECT_CONSTRUCT()` → Removed (not directly supported, may need UDF)

### JSON Access
- Snowflake: `RECORD_CONTENT:field` or `RECORD_CONTENT:"field"`
- Flink: `JSON_VALUE(record_content, '$.field')` or `JSON_EXTRACT()`

**Note**: If using `json-registry` format, columns may be automatically parsed. The current migration assumes raw JSON strings requiring JSON functions.

### MERGE Statement Conversion
- Snowflake `MERGE INTO ... WHEN MATCHED ... WHEN NOT MATCHED` 
- Flink: Converted to `INSERT INTO` with `LEFT JOIN` and conditional logic
- Upsert semantics handled via `changelog.mode = 'upsert'` in table definition

### Table Naming
- Removed quotes from table names (Flink convention)
- Converted to lowercase (Flink convention)
- Schema prefixes removed (handled via catalog/database)

### Window Functions
- `ROW_NUMBER() OVER()` - Preserved as-is
- `DENSE_RANK() OVER()` - Preserved as-is
- Window partitioning and ordering logic maintained

## Assumptions and Limitations

### Custom Functions
The following Snowflake functions are assumed to be user-defined functions (UDFs) that need to be implemented in Flink:
- `SERVER_UUID(string)` - Extracts server UUID from identifier string
- `TRANSACTION_ID(string)` - Extracts transaction ID from identifier string

These functions are referenced but not defined in the migration. They should be implemented as Flink UDFs or replaced with appropriate string parsing logic.

### Array Operations
The `FLATTEN` operation in the transaction tracking query has been converted to `CROSS JOIN UNNEST`, but the exact syntax may need adjustment based on:
- How arrays are stored in the JSON structure
- Flink's UNNEST capabilities with JSON arrays
- Whether the data needs preprocessing

### JSON Structure
The migration assumes:
- `record_content` and `record_metadata` are stored as JSON strings
- JSON paths use dot notation (e.g., `$.field.subfield`)
- Arrays are properly formatted JSON arrays

### Time-based Operations
- `DATEADD(day, -3, CURRENT_TIMESTAMP)` → `TIMESTAMPADD(DAY, -3, CURRENT_TIMESTAMP)`
- `DATEADD(milliseconds, ...)` → `TO_TIMESTAMP()` with millisecond precision
- `DATEADD(days, ...)` → `TO_TIMESTAMP()` then cast to `DATE`

### Conditional Updates
The MERGE statement's complex conditional update logic has been converted to a `CASE` statement in the SELECT, but the exact upsert behavior may need verification:
- The original MERGE had specific conditions for when to update vs insert
- Flink's upsert mode will handle key-based updates automatically
- Additional filtering may be needed to match the original MERGE conditions exactly

## Testing Recommendations

1. **Verify JSON parsing**: Test that JSON_VALUE/JSON_EXTRACT correctly access nested fields
2. **Test array operations**: Verify UNNEST works correctly with the JSON array structure
3. **Validate UDFs**: Implement and test SERVER_UUID and TRANSACTION_ID functions
4. **Check upsert behavior**: Verify that the converted MERGE logic produces the same results
5. **Performance testing**: Window functions and aggregations may behave differently in streaming context

## Connector Configuration

All source tables use Kafka connectors with:
- `json-registry` format for schema evolution
- `earliest-offset` startup mode
- `unbounded` mode for streaming

Sink tables use:
- `avro-registry` format
- `upsert` changelog mode for key-based updates
- Snappy compression
- Schema context `.flink-dev`

## Next Steps

1. [ ] Review and adjust JSON access patterns based on actual data format
2. [ ] Implement missing UDFs (SERVER_UUID, TRANSACTION_ID)
3. [ ] Test with sample data to verify correctness
4. [ ] Adjust array/UNNEST operations if needed
5. [ ] Fine-tune connector properties for production environment
