# Inner Join with Deduplication

A classical entity → entityType management pattern on Confluent Cloud Flink. Demonstrates how to deduplicate CDC events using `ROW_NUMBER() OVER (... ORDER BY ts DESC)` before performing an inner join to produce a clean, flat asset record.

## Business Problem

Two CDC topics publish `Asset → AssetType` relationship events. Because the source system re-sends the full state on every update, the topics contain duplicates. The goal is to:

1. Deduplicate each topic to keep only the latest version of each record.
2. Inner-join the deduplicated asset-type associations with the asset-type master to enrich them.
3. Further aggregate subtypes and types into arrays for a single enriched asset row.

## Key Concepts

| Concept | Description |
|---------|-------------|
| `ROW_NUMBER()` dedup | Keep the latest record per key by ranking on `ts_ltz DESC` and filtering `rn = 1` |
| CTE chaining | Multiple dedup CTEs composed in a single statement before the join |
| `ARRAY_AGG(DISTINCT ...)` | Aggregate subtype and type names into arrays per asset |
| Watermark on `ts_ltz` | Enables ORDER BY inside the window function |

## Layout

```
cc-flink/   Confluent Cloud Flink SQL (DDL, DML, deploy manifest)
docs/       results.png — example output
```

## Prerequisites

1. Confluent Cloud environment with a Flink compute pool
2. Deployment credentials in `../../../tools/`

## Run (Confluent Cloud)

```sh
cd cc-flink

make sync
make deploy-ddl       # create raw_Asset* tables
make deploy-data      # insert records including duplicates
make deploy-pipeline  # run dedup + inner join + array aggregation

make undeploy
make drop-tables
```

## Key SQL

### Deduplication pattern (as CTE)

```sql
WITH deduped_AssetTypeAsset AS (
  SELECT AssetId, TypeId, Version, ts_ltz
  FROM (
    SELECT AssetId, TypeId, Version, ts_ltz,
           ROW_NUMBER() OVER (PARTITION BY AssetId, TypeId ORDER BY ts_ltz DESC) AS rn
    FROM `raw_AssetTypeAsset`
  ) WHERE rn = 1
),
deduped_AssetType AS (
  SELECT id, name, description, ts_ltz
  FROM (
    SELECT id, name, description, ts_ltz,
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY ts_ltz DESC) AS rn
    FROM `raw_AssetType`
  ) WHERE rn = 1
)
```

### Inner join enrichment

```sql
SELECT
  deduped_AssetTypeAsset.AssetId,
  deduped_AssetTypeAsset.TypeId,
  deduped_AssetTypeAsset.Version,
  deduped_AssetType.name,
  deduped_AssetType.description
FROM deduped_AssetTypeAsset
INNER JOIN deduped_AssetType
  ON deduped_AssetTypeAsset.TypeId = deduped_AssetType.id
```

### Array aggregation across subtypes and types

```sql
SELECT
  lt.AssetId              AS asset_id,
  ARRAY_AGG(DISTINCT lst.subtype_name) AS subtypenames,
  ARRAY_AGG(DISTINCT lt.name)          AS names,
  MAX(lst.ts_ltz)                      AS type_ts
FROM latest_types lt
LEFT JOIN latest_subtypes lst ON lt.AssetId = lst.asset_id
GROUP BY lt.AssetId
```

## Expected Results

See `docs/results.png` — the left join creates rows with `NULL` subtypes for assets without a matching subtype.
