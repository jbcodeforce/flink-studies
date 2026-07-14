# dbt Studies - Samples

This folder includes different dbt studies. This is coupled with the [dbt chapter](https://jbcodeforce.github.io/flink-studies/coding/dbt).  The `airbnb` is to use [duckdb](#using-duckdb-as-data-warehouse) as target of the `dbt` processing for data warehouse demo. `airbnb_streaming` is the same implementation using dbt and Confluent Cloud for Flink [dbt-confluent](#with-dbt-confluent---flink_workshop-project) demonstration. Finally `flink_workshop` folder includes a pure Flink workshop ported to dbt.

## Using duckdb as data warehouse

### Prerequisites

- Install dependencies from the dbt folder: `cd code/dbt && uv sync` (includes `dbt-duckdb`).
- Create the `dbt` project
    ```sh
    dbt init airbnb
    ```
- The following step is already done: Place raw CSVs in `code/dbt/airbnb/data/`: `listings.csv`, `hosts.csv`, `reviews.csv`. Sources: [bootcamp resources](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero/blob/main/_course_resources/course-resources.md) or S3 `s3://dbt-datasets/listings.csv`, `s3://dbt-datasets/reviews.csv`, `s3://dbt-datasets/hosts.csv`.

### Raw landing zone

The landing zone is used for raw data, mostly coming from CSVs, or ETL processing. `dbt` models process raw data to create dimensions and facts.

1. From the repo root, install deps and sync: `cd code/dbt && uv sync`.
1. Place raw CSVs in `code/dbt/airbnb/data/`: `listings.csv`, `hosts.csv`, `reviews.csv` (e.g. from the [bootcamp resources](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero/blob/main/_course_resources/course-resources.md) or S3: `s3://dbt-datasets/listings.csv`, etc.).

1. From `code/dbt/airbnb/`, bootstrap the DuckDB raw tables (one-time):
  ```bash
    export DBT_DUCKDB_PATH=./data/airbnb.duckdb
    duckdb "${DBT_DUCKDB_PATH:-./data/airbnb.duckdb}" < scripts/bootstrap_duckdb_raw.sql
  ```
    
  This creates schema `raw` and tables `raw.raw_listings`, `raw.raw_hosts`, `raw.raw_reviews`. The default DB path is `./airbnb.duckdb` (same as in `profiles.yml`). Override with `export DBT_DUCKDB_PATH=/path/to/airbnb.duckdb` if needed.

4. Review the raw tables. [See my summary on duckdb](https://jbcodeforce.github.io/db-play/duckdb/)
  ```sql
    .open ./data/airbnb.duckdb
    D show databases;
    ┌───────────────┐
    │ database_name │
    │    varchar    │
    ├───────────────┤
    │ airbnb        │
    └───────────────┘
    D show tables;
    D select * from  raw.raw_reviews;
    D describe raw.raw_reviews;
  ```

  See [also the dot commands](https://duckdb.org/docs/current/clients/cli/dot_commands)
  ```sql
  .open data/airbnd.duckdb
  .databases
  .schema
  .read FILENAME  Read and execute SQL from an external file
  select * from raw.raw_hosts;
  ```

### Create seeds

The following command let `dbt` to look inside the `seeds/` folder, find any .csv files, and upload them as physical tables into the database.

```sh
dbt seed --target dev
```

The target `dev` matches the connection profile in `profiles.yaml`:

```yaml
airbnb:
  outputs:
    dev:
      path: "{{ env_var('DBT_DUCKDB_PATH', './data/airbnb.duckdb') }}"
      threads: 1
      type: duckdb
    prod:
      path: prod.duckdb
      threads: 4
      type: duckdb
  target: dev
```

Verify in duckdb with:
```sql
show tables;
select * from seed_full_moon_dates limit 10;
```

### Create silver layer

- Define the `sources.yaml` file under `models` using the raw table references:
  ```yaml
  sources:
    - name: airbnb  # This is the internal dbt name for the source
      schema: raw   # The actual schema name in your warehouse
      tables:
        - name: listings # This is the name of the raw table in the data warehouse
          identifier: raw_listings
  ```

- Add SQL for deduplicating the `raw.raw_hosts` data. Create a `models/sources` folder and add the following query named `src_hosts.sql`. 

```sql
WITH ranked_hosts AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY id
            ORDER BY updated_at DESC, created_at DESC
        ) AS row_num
    FROM
        {{ source('airbnb', 'hosts') }}
    WHERE id IS NOT NULL
)
SELECT
    id AS host_id,
    name AS host_name,
    is_superhost,
    created_at,
    updated_at
FROM
    ranked_hosts
WHERE
    row_num = 1
```

*Using SQL materialized view, we do not use `INSERT INTO`, as it will be added automatically by `dbt*

Running the following command

```sh
dbt run --target dev
# returns
Found 1 seed, 3 sources, 474 macros
Concurrency: 1 threads (target='dev')

 1 of 1 START sql view model main.src_hosts ..................................... [RUN]
 1 of 1 OK created sql view model main.src_hosts ................................ [OK in 0.03s]
```

which can be validated by opening the duckdb database (same can be done for `listings` and `reviews`.):

```sql
duckdb data/airbnb.duckdb
# in the shell
select * from main.src_hosts;

select * from src_reviews;

select * from src_listings;
```

* `dbt run` creates the sql queries under the `target` folder. A `run` command may also apply to a specific table:
  ```sh
  dbt run --select +models/facts/fct_reviews.sql
  ```

  The + in front of the name, specifies to deploy parents tables too.

* For source freshness, we need to consider one DATE column and add a config element to the raw table to define refreshness condition:
    ```yaml
    - name: reviews
      identifier: raw_reviews
      config:
        loaded_at_field: date
        freshness:
            warn_after: {count: 1, period: hour}
            error_after: {count: 24, period: hour}
    ```

* Run the command: `dbt source freshness` to validate the data freshness.

### Dimensions

* Add a dimensions folder under `models` folder. dbt can find templates in a directory tree
* Add a SQL to create a dimension about the listings, as a view. Do some type conversion and set some minimum values.

```sql
{{
  config(
    materialized = 'view'
    )
}}
WITH src_listings AS (
  SELECT
    *
  FROM
    {{ ref('src_listings') }}
)
SELECT
  listing_id,
  listing_name,
  room_type,
  CASE
    WHEN minimum_nights = 0 THEN 1
    ELSE minimum_nights
  END AS minimum_nights,
  host_id,
  CAST(
    REPLACE(price_str, '$', '') AS DECIMAL(10, 2)
  ) AS price,
  created_at,
  updated_at
FROM
  src_listings
```

### Tests

* Defining test is by adding a `schema.yaml` with conditions on table columns


* To run the tests
  ```sh
  dbt text --target duckdb -x
  # -x it to continue even if one test fails
  ```

* To debug a test, we can always look at where the `dbt` created the SQL to run (under target folder), and execute this SQL in a SQL client, like duckdb cli.

* By setting in the dbt_project.yaml
  ```yaml
  data_tests:
    _store_failures: true
  ```

  Then any test failures will be saved in a new schema with table in the datawarehouse.

  ```sh
  02:48:41  Failure in test accepted_values_dim_listings_cleansed_room_type__Private_room__Entire_home_apt__Shared_room__Hotelroom (models/schema.yaml)
  02:48:41    Got 1 result, configured to fail if != 0
  02:48:41  
  02:48:41    compiled code at target/compiled/airbnb/models/schema.yaml/accepted_values_dim_listings_c_72f6cd1e8c350657dd7c7e44ed95fd70.sql
  02:48:41  
  02:48:41    See test failures:
  ---------------------------------------------------------------------------------------------------------------
  select * from "airbnb"."main_dbt_test__audit"."accepted_values_dim_listings_c_72f6cd1e8c350657dd7c7e44ed95fd70"
  ---------------------------------------------------------------------------------------------------------------
  ```

* Example to validate consistency among the created_at fields of the listings and reviews, we may want to add a singular test under the tests folder in the form of SQL:
  ```sql
  ```

* See [elementary-data.com](https://elementary-data.com)

---

## With dbt-confluent - airbnb_streaming project

The [airbnb_streaming](airbnb_streaming/) project targets Confluent Cloud for Flink via the `cc_flink` profile. Unlike DuckDB, `dbt run` deploys streaming SQL statements to Confluent Cloud for Flink rather than batch-transforming warehouse tables.

### Prerequisites

1. From `code/dbt/`, install deps: `uv sync`.
2. Configure `~/.dbt/profiles.yml` with a `cc_flink` profile (see [docs/coding/dbt.md](https://jbcodeforce.github.io/flink-studies/coding/dbt)).
3. Export Flink API credentials:
  ```bash
   export CONFLUENT_FLINK_API_KEY=...
   export CONFLUENT_FLINK_API_SECRET=...
  ```

### Seed reference data from CSV

* Place CSV files in `airbnb_streaming/seeds/`. Column types are inferred from the CSV; override them in `seeds/seeds.yml` when needed (e.g. `DATE` instead of `STRING`).
  ```bash
  cd code/dbt/airbnb_streaming
  make debug
  make seed
  ```

  Or without Make:

  ```bash
  cd code/dbt
  uv run dbt seed --project-dir airbnb_streaming --profiles-dir ~/.dbt --target dev
  ```

* Validate in the Flink SQL workspace:

```sql
SELECT * FROM raw_full_moon_dates LIMIT 5;
```

Reference seeded tables in downstream models via `models/sources.yaml` and `{{ source('reference', 'full_moon_dates') }}`.

!!! To be continued

## With dbt-confluent - flink_workshop project

The [flink_workshop](flink_workshop/) project deploys the [Confluent Flink SQL workshop](https://github.com/confluentinc/flink-workshop) as the `crm` data product: Faker sources, customer dimension, joins, aggregations/windowing, and optional MongoDB lookup.

```bash
cd code/dbt/flink_workshop
export CONFLUENT_FLINK_API_KEY=...
export CONFLUENT_FLINK_API_SECRET=...
make debug
make run-full
```

See [flink_workshop/README.md](flink_workshop/README.md) for model catalog, dbt patterns (`statement_name`, state TTL, MongoDB vars), and verification queries.

## Some challenges

I found not user friendly to develop a Flink SQL in the Confluent Workspace, then save it to a git repository and then refactor it, completly blindly to dbt syntax. This is error prone, and more work for the Flink developers. 


I understand the data engineers, used to use dbt on a daily basis, being able to start from dbt templating/model and let the tool deploy to CC is a nice approach. But one of the strength of Confluent Cloud is to develop query on data present on any topic of one to many kafka clusters, so the new development tool for data engineer is the Workspace. 

Knowing that Terraform should not be used for deploying Flink statement, as terraform state external to the runtime environment, leads to strange behavior that consider completed statements (like DDL) to be recreated each time a `terraform apply` is done, dramatically impacting existing running dml statements. 

Therefore I see two needs:
1. having a tool that processes Flink SQL as created in the workspace, but saved in a git repository, and deploy the statements by layer or hierarchical pipeline, taking into account what is running. This is the goal of [shift_left utils](https://jbcodeforce.github.io/shift_left_utils) or the [cc_deploy/deploy_flink_statements.py](../flink-sql/tools/cc_deploy/deploy_flink_statements.py)
1. having a tool to take an existing Flink SQL and transform it for dbt with schema definition and test. This is [flink_dbt_migrate](../flink-sql/tools/flink_dbt_migrate/) tool.

### Migrate existing Flink DML to dbt models

Use `[code/flink-sql/tools/migrate_dml_to_dbt](../flink-sql/tools/migrate_dml_to_dbt)` to convert demo `dml.*.sql` files into dbt models with matching `schema.yml` column types from the paired `ddl.*.sql`. 

### Gap analysis with shift_left utils CLI

- Kimball structure under `models/` can be bootstrapped with `migrate_dml_to_dbt.py` (see above).
- No metada data for statement children relationship, but could be kept as-is with shift_left. (medium term this). 
- no undeploy statements command
- no drop table from a list of tables
- no cross cut deployment support: only sources, only a data producct
- no concept of statefulness with different approach to deployment -> the response is to transform to materialized tables. But this will not address children relationship.
- no children relationship understanding
- unit tests not isolated per table

