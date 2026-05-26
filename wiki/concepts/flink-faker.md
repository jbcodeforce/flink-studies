---
title: Flink Faker Connector
created: 2026-05-23
updated: 2026-05-23
type: concept
tags: [connector, tool]
sources: [raw/articles/flink-sql-ddl-best-practices.md]
confidence: high
---

# Flink Faker Connector

## Overview
[Flink Faker](https://github.com/knaufk/flink-faker) is a specialized table source that bridges Flink SQL with the Java DataFaker library for generating synthetic test data. It acts as a [[ScanTableSource|ScanTableSource]], producing rows on-the-fly.

## Syntax
```sql
CREATE TABLE bounded_pageviews (
    url STRING,
    user_id STRING,
    browser STRING,
    ts TIMESTAMP(3)
)
WITH (
    'connector' = 'faker',
    'number-of-rows' = '500',  -- or NULL for infinite
    'rows-per-second' = '100',
    'fields.url.expression' = '/#{GreekPhilosopher.name}.html',
    'fields.user_id.expression' = '#{numerify ''user_##''}',
    'fields.browser.expression' = '#{Options.option ''chrome'', ''firefox'', ''safari''}',
    'fields.ts.expression' = '#{date.past ''5'',''1'',''SECONDS''}'
);
```

## DataFaker Expression Syntax
Uses `#{className.methodName 'parameter'}` format.

| Operation | Example |
|-----------|---------|
| Time-based | `fields.ts.expression = '#{date.past ''15'',''SECONDS''}'` |
| Categorical | `fields.status.expression = '#{Options.option ''PENDING'',''SHIPPED'',''CANCELLED''}'` |
| Regex pattern | `fields.zip_code.expression = '#{regexify ''[0-9]{5}-[0-9]{4}''}'` |
| Nested ROW | `fields.details.item_name.expression = '#{commerce.productName}'` |

## Key Features
- **Bounded mode**: `'number-of-rows'` limits output (batch testing)
- **Unbounded mode**: Omit number-of-rows for streaming (default)
- **Rate control**: `'rows-per-second'` controls generation speed
- **Built-in providers**: Commerce, person, address, finance, Lorem, etc.

## Important Notes
- On Confluent Cloud, Faker is a source connector — no Kafka topic is created automatically
- Uses platform resources while active; drop the table after testing
- DataFaker expressions can be combined for complex synthetic data patterns

## Related
- [DataGen](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/connectors/table/datagen/) as alternative Flink-native data generator
- [[test-data]] generation strategies
- [[kafka-connector]] connector for downstream processing of generated data
