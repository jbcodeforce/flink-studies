-- Bootstrap raw schema and tables for local DuckDB (Option A).
-- Run once before dbt run --target duckdb. Requires CSVs in data/ (see README).
--
-- Usage (from repo root or with DUCKDB_PATH set):
--   duckdb "${DBT_DUCKDB_PATH:-./airbnb.duckdb}" < scripts/bootstrap_duckdb_raw.sql
-- Or from dbt project dir (code/dbt/airbnb):
--   duckdb "${DBT_DUCKDB_PATH:-./airbnb.duckdb}" < scripts/bootstrap_duckdb_raw.sql

CREATE SCHEMA IF NOT EXISTS raw;

CREATE OR REPLACE TABLE raw.raw_listings AS
SELECT * FROM read_csv_auto('data/listings.csv', header=true);

CREATE OR REPLACE TABLE raw.raw_hosts AS
SELECT * FROM read_csv_auto('data/hosts.csv', header=true);

CREATE OR REPLACE TABLE raw.raw_reviews AS
SELECT * FROM read_csv_auto('data/reviews.csv', header=true);
