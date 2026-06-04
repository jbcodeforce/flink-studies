# Flink workshop from Jan Svoboda

dbt project that deploys [Flink SQL workshop](https://github.com/giga20/flink-workshop/blob/main/lab1.md) statements to Confluent Cloud for Flink using the [dbt-confluent](https://pypi.org/project/dbt-confluent/) adapter.

## Prerequisites

1. From `code/dbt/`, install dependencies: `uv sync`.
2. Configure `~/.dbt/profiles.yml` with a `cc_flink` profile (see [docs/coding/dbt.md](../../docs/coding/dbt.md)).
3. Export Flink API credentials:

   ```bash
   export CONFLUENT_FLINK_API_KEY=...
   export CONFLUENT_FLINK_API_SECRET=...
   ```

## Project layout

| Model | Lab section | Materialization |
|-------|-------------|-----------------|
| `transactions_faker` | 1.1 Faker transactions | `streaming_source` |
| `customers_faker` | 1.2 Faker customers | `streaming_source` |
| `customers_pk` | 3 CTAS + 4 ALTER | `streaming_table` + post-hooks |

`analyses/explain_customers_pk_ctas.sql` mirrors Lab 2 EXPLAIN: not deployed by `dbt run` but can be copied/paste to Flink workspace cell.

## Deploy

```bash
cd code/dbt
uv sync
cd flink_workshop
make  debug
make run-full   # first deploy or recreate Faker / PK tables
```

Subsequent runs without recreating topics:

```bash
make  run
```

Or without Make:

```bash
cd code/dbt
uv run dbt run --project-dir flink_workshop --profiles-dir ~/.dbt --select tag:lab01 --full-refresh --target dev
```

### Full refresh warning

`streaming_source` and `streaming_table` require `--full-refresh` to replace existing relations. That drops and recreates underlying Kafka topics for `customers_pk` and clears Faker table definitions. Plan workshop redeploys accordingly.

## Lab mapping notes

- `DISTRIBUTED BY` / `INTO N BUCKETS` from the workshop DDL are omitted: the dbt-confluent `streaming_source` macro does not emit distribution clauses. Behavior matches the lab except hash partitioning.
- Lab 3 CTAS is implemented as `streaming_table` (CREATE TABLE from `schema.yml` + `INSERT INTO ... SELECT`).
- Lab 4 `ALTER TABLE` steps run as `post_hook` on `customers_pk` (metadata columns, then `kafka.consumer.isolation-level`). Watermark on the sink is set via `MODIFY WATERMARK` post-hook to match the lab CTAS.
- If a post-hook fails on first deploy, run the corresponding `ALTER` manually in the SQL workspace, or redeploy with `run-full` after dropping `customers_pk`.

## Manual verification (Flink SQL workspace)

After `dbt run`, validate as in the workshop (not executed by dbt):

```sql
SHOW CREATE TABLE `transactions_faker`;
DESCRIBE EXTENDED `transactions_faker`;
SELECT * FROM `transactions_faker`;  -- stop when done

SELECT * FROM `customers_faker`;     -- stop when done

SHOW CREATE TABLE `customers_pk`;
DESCRIBE EXTENDED `customers_pk`;
SELECT * FROM `customers_pk`;        -- use Changelog view for +I / +U / -U
```

For Lab 2 physical plan, prefix the CTAS from the lab (or comments in `analyses/explain_customers_pk_ctas.sql`) with `EXPLAIN` in the UI.

## Drop and recreate

```sql
DROP TABLE IF EXISTS `customers_pk`;
DROP TABLE IF EXISTS `customers_faker`;
DROP TABLE IF EXISTS `transactions_faker`;
```

Then `make -C flink_workshop run-full`.

## Related

- [code/dbt/README.md](../README.md) — parent dbt workspace
- [airbnb_streaming](../airbnb_streaming/) — seeds example on the same profile
