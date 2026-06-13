# A sensor processing by  applying business rules defined in table

This folder includes a simple demonstration of temporal join on static table containing rules about device and threhold value.

## Business rules

For each device type there is a permitted set of thresholds that may be defined per tenant_id. The table definition looks like:

```sql
create table sensor_rules (
    tenant_id STRING,
    rule_id BIGINT NOT NULL,
    parameter_id BIGINT NOT NULL,  -- act as a device type
    low_threshold BIGINT,
    high_threshold BIGINT,
    creation_date TIMESTAMP(3),
    PRIMARY KEY(tenant_id,rule_id,parameter_id)
) WITH (

)
```

* Define some rule values
```sql
insert into sensor_rules (
    
)
```

## Source table with fake data

Source sensors
```sql
create  table sensors (
  tenant_id STRING NOT NULL,
  sensor_id BIGINT NOT NULL,
  parameter_id INT NOT NULL,
  measured_value BIGINT,
  created_at TIMESTAMP(3),
  PRIMARY KEY(tenant_id, sensor_id, parameter_id) not enforced
) WITH (
   'connector' = 'faker',
    'rows-per-second' = '10',
    'fields.tenant_id.expression' = '#{Options.option ''tenant_a'', ''tenant_b'', ''tenant_c''}',
    'fields.sensor_id.expression' = '#{Number.numberBetween ''1'', ''100''}',
    'fields.parameter_id.expression' = '#{Number.numberBetween ''1'', ''10''}',
    'fields.measured_value.expression' = '#{Number.numberBetween ''400'', ''3500''}',
    'changelog.mode' = 'append'
)
```

## Temporal Joins with rule tables

```sql
select 
 tenant_id,
 sensor_id,
 measured_value,
 
from sensors s
left join sensor_rules for system time as of  s.created_at as rule
on s.tenant_id = rule.tenant_id
and s.parameter_id = rule.parameter_id
```


