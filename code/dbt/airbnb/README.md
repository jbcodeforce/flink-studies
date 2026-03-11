Welcome to your new dbt project!

### Using the starter project

**Snowflake (default)**  
- `dbt run`  
- `dbt test`  

**DuckDB (local)**  
1. From the repo root, install deps and sync: `cd code/dbt && uv sync`.
2. Place raw CSVs in `code/dbt/airbnb/data/`: `listings.csv`, `hosts.csv`, `reviews.csv` (e.g. from the [bootcamp resources](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero/blob/main/_course_resources/course-resources.md) or S3: `s3://dbt-datasets/listings.csv`, etc.).
3. From `code/dbt/airbnb/`, bootstrap the DuckDB raw tables (one-time):
   ```bash
   duckdb "${DBT_DUCKDB_PATH:-./airbnb.duckdb}" < scripts/bootstrap_duckdb_raw.sql
   ```
4. Run dbt against DuckDB:
   ```bash
   dbt seed --target duckdb
   dbt run --target duckdb
   dbt test --target duckdb
   ```
   Optional: `export DBT_DUCKDB_PATH=/path/to/airbnb.duckdb` to use a different DB path (default: `./airbnb.duckdb`).

### Resources

- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
