# Based on the Udemy  AirBnb training

[See the dbt chapter for summary of the practice](https://jbcodeforce.github.io/flink-studies/coding/dbt/).

## Summary

Once the dbt is install with uv. The approach is to implement the pipeline and the first step is to process raw tables to build sources staging layer.

### Snowflake Airbnb Raw Tables

* Two schemas: dev and raw. [See data import sql](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero/blob/main/_course_resources/course-resources.md). [S3 AirBnB listing](s3://dbt-datasets/listings.csv), [reviews.csv](s3://dbt-datasets/reviews.csv) and [hosts](s3://dbt-datasets/hosts.csv).
* Get connection to database like snowflake using the profiles.yml which should be under ~/.dbt or .gitgnore.
* Airbnb models:
    * Listings
    * Reviews
    * Hosts



### DuckDB Raw Tables

Use the same dbt project and models as Snowflake by switching the dbt target to DuckDB. Raw data lives in a local DuckDB file; no Snowflake account required.

**Prerequisites**

* Install dependencies from the dbt folder: `cd code/dbt && uv sync` (includes `dbt-duckdb`).
* Place raw CSVs in `code/dbt/airbnb/data/`: `listings.csv`, `hosts.csv`, `reviews.csv`. Sources: [bootcamp resources](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero/blob/main/_course_resources/course-resources.md) or S3 `s3://dbt-datasets/listings.csv`, `s3://dbt-datasets/reviews.csv`, `s3://dbt-datasets/hosts.csv`.

**One-time: load raw data into DuckDB**

From the project directory `code/dbt/airbnb/`:

```bash
cd code/dbt/airbnb
duckdb "${DBT_DUCKDB_PATH:-./airbnb.duckdb}" < scripts/bootstrap_duckdb_raw.sql
```

This creates schema `raw` and tables `raw.raw_listings`, `raw.raw_hosts`, `raw.raw_reviews`. The default DB path is `./airbnb.duckdb` (same as in `profiles.yml`). Override with `export DBT_DUCKDB_PATH=/path/to/airbnb.duckdb` if needed.

**Run the pipeline with DuckDB**

From `code/dbt/airbnb/`:

```bash
dbt seed --target duckdb
dbt run --target duckdb
dbt test --target duckdb
```

Models (dimensions, facts, mart) and macros are adapter-aware; the same SQL runs on Snowflake (target `dev`) or DuckDB (target `duckdb`). Keep `profiles.yml` under `~/.dbt` or in `.gitignore` if it contains credentials.

