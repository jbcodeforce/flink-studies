# Rule Match on Sensors

Apply per-tenant business rules to real-time sensor readings using a **temporal join** on a static rules table (`sensor_rules`). When a sensor reading arrives, Flink looks up the active rule for that tenant and device type as of the reading's timestamp and enriches the record with the applicable thresholds.

> **Status**: SQL stubs defined in the README — add `ddl.sensors.sql`, `ddl.sensor_rules.sql`, `dml.insert_sensor_rules.sql`, and `dml.rule_match.sql` to `cc-flink/` to make the demo deployable.

## Business Problem

For each device type there is a set of permitted threshold values defined per tenant. When a sensor reading arrives, determine whether it violates the applicable low or high threshold — looking up the rule that was active at the time of the reading.

## Key Concepts

| Concept | Description |
|---------|-------------|
| Temporal join on static table | `LEFT JOIN sensor_rules FOR SYSTEM TIME AS OF s.created_at` — looks up the rule version that was current at the sensor reading's event time |
| Versioned reference table | `sensor_rules` is an upsert/changelog table; Flink uses its event-time history for the point-in-time lookup |
| `PRIMARY KEY(tenant_id, rule_id, parameter_id)` | Uniquely identifies a rule; enables the versioned temporal-join semantics |

## Layout

```
cc-flink/   Confluent Cloud Flink SQL (DDL stubs, deploy manifest)
```

## Prerequisites

1. Confluent Cloud environment with a Flink compute pool
2. Deployment credentials in `../../../tools/`
3. Add the SQL files listed below before deploying

## Run (Confluent Cloud)

```sh
cd cc-flink

make sync
make deploy-ddl       # create sensors and sensor_rules tables
make deploy-data      # seed sensor_rules with threshold values
make deploy-pipeline  # start the rule-matching join

make undeploy
make drop-tables
```

## Key SQL

### Rules table

```sql
CREATE TABLE sensor_rules (
  tenant_id       STRING,
  rule_id         BIGINT NOT NULL,
  parameter_id    BIGINT NOT NULL,   -- acts as device type
  low_threshold   BIGINT,
  high_threshold  BIGINT,
  creation_date   TIMESTAMP(3),
  PRIMARY KEY(tenant_id, rule_id, parameter_id) NOT ENFORCED
) WITH (
  'changelog.mode' = 'upsert',
  ...
);
```

### Sensors source (Faker connector for local testing)

```sql
CREATE TABLE sensors (
  tenant_id      STRING NOT NULL,
  sensor_id      BIGINT NOT NULL,
  parameter_id   INT    NOT NULL,
  measured_value BIGINT,
  created_at     TIMESTAMP(3),
  PRIMARY KEY(tenant_id, sensor_id, parameter_id) NOT ENFORCED
) WITH (
  'connector'                        = 'faker',
  'rows-per-second'                  = '10',
  'fields.tenant_id.expression'      = '#{Options.option ''tenant_a'', ''tenant_b'', ''tenant_c''}',
  'fields.sensor_id.expression'      = '#{Number.numberBetween ''1'', ''100''}',
  'fields.parameter_id.expression'   = '#{Number.numberBetween ''1'', ''10''}',
  'fields.measured_value.expression' = '#{Number.numberBetween ''400'', ''3500''}',
  'changelog.mode'                   = 'append'
);
```

### Temporal join

```sql
SELECT
  s.tenant_id,
  s.sensor_id,
  s.measured_value,
  rule.low_threshold,
  rule.high_threshold,
  CASE
    WHEN s.measured_value < rule.low_threshold  THEN 'BELOW'
    WHEN s.measured_value > rule.high_threshold THEN 'ABOVE'
    ELSE 'OK'
  END AS status
FROM sensors s
LEFT JOIN sensor_rules FOR SYSTEM TIME AS OF s.created_at AS rule
  ON  s.tenant_id    = rule.tenant_id
  AND s.parameter_id = rule.parameter_id;
```
