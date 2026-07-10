---
title: "Data Build Tool Summary"
source: flink-studies/docs/coding/dbt.md
ingested:
tags: [flink, coding, dbt]
type: article
compiled: false
---
# Data Build Tool Summary

* [Dbt core](https://github.com/dbt-labs/dbt-core) is an open source ELT CLI and database agnostic used to allow data analysts and engineers building reliable, modular data pipelines, creating "models" (SELECT statements) that are version-controlled, automatically documented, and tested for quality before consumption by analytics tools.  Learn more about `dbt` [in the docs](https://docs.getdbt.com/docs/introduction).
* [dbt Cloud](https://www.getdbt.com/product/dbt): is the managed service with a web-based IDE, scheduler, job orchestration, and monitoring...

Supported by ISVs in lake house market. 

## Relation with Flink

Confluent has also developed a [dbt adapter](https://pypi.org/project/dbt-confluent/) to deploy Flink SQL statements into Confluent Cloud for Flink. It aims to support standard `dbt` commands (init, debug, run, test, docs generate, etc.) against Confluent Cloud for Flink, so teams can manage pipelines end-to-end from `dbt` rather than using Terraform or confluent cli.

We will first work on one concrete [example for a database](#a-data-warehouse-example), and then work on a [Confluent Cloud Flink project](#a-confluent-cloud-flink-example).

[See Confluent cloud product documentation on dbt.](https://docs.confluent.io/cloud/current/flink/operate-and-deploy/deploy-flink-dbt.html)

## Use Cases

The classical dbt use cases are:

* Modelling changes are easy to follow and revert
* Explicit dependencies between models
* Data quality tests
* Incremental load of fact tables
* Track history of dimension tables
* Support automated testing, document generation, and data lineage visualization

## dbt cli install

* We need Python, as `dbt` should be installed in a virtual environment. [See installation instructions](https://docs.getdbt.com/docs/core/installation-overview). See the [supported Python database](https://docs.getdbt.com/faqs/Core/install-python-compatibility)
* Create a `$HOME/.dbt` folder to let `dbt` persists the `profile.yaml` file to keep user and Database credentials. 
1. Start a new python session under your working folder (e.g. dbt)
  ```sh
  uv venv
  source .venv/bin/activate
  ```
1. Install `dbt`, and dbt adapter for duckdb
  ```sh
  uv add dbt-duckdb
  ```

  and dbt adapter for Confluent Cloud for Flink
  ```sh
  uv add dbt-confluent
  ```

## Getting started

We will go over the getting the foundations of a project, and then go over the main concepts while implementing the examples.

A `dbt` project is a directory on the data engineer's machine containing a lot of .sql files (called models) and YAML files for configurations. This can be pushed to a git repository, and `dbt` used as part of a ci/cd workflow.

### A data warehouse example

This example is in [code/dbt/airbnb](https://github.com/jbcodeforce/flink-studies/tree/master/code/dbt/airbnb) and use `duckdb` as data base engine.

1. Create the `dbt` project
    ```sh
    dbt init airbnb
    ```

    while running this command, it will ask to set the `dbt` profile for this project (I selected duckdb). A project profile is a YAML file containing the connection details for your chosen data platform.  When there is an existing `~/.dbt/profiles.yml`, the previous command will add a new stanza to it like:

    ```yaml
    airbnb:
      outputs:
        dev:
          type: duckdb
          path: dev.duckdb
          threads: 1

        prod:
          type: duckdb
          path: prod.duckdb
          threads: 4

      target: dev
    ```

    It specifies two configurations, `dev` and `prod`, with different data warehouse connection specifications. The path specifies where in the working directory (e.g. airbnd) the database will be created.

    This will also create a set of folders to manage all the needed elements of data pipelines:
      
      ```sh
      models
      analyses
      tests
      seeds
      macros
      snapshots
      ```

      and the `dbt_project.yml`file to define the `dbt` settings. 

1. Understand the `dbt_project.yml`
    * It refences the profile to use:
      ```yaml
      profile: 'airbnb'
      ```
    *  and the models may have many resources configured at once:
      ```yaml
      models:
        models:
          # namespace for model configs matching the project name
          airbnb:
            +materialized: view
      ```

Next we will cover the `dbt` [main concepts](#major-concepts) with concrete examples.

### A Confluent Cloud Flink example

* [See documentation of Confluent dbt adapter](https://docs.confluent.io/cloud/current/flink/operate-and-deploy/deploy-flink-dbt.html) for installation.
  ```sh
  pip install dbt-confluent
  # or
  uv add  dbt-confluent
  ```

  Flink SQLs are defined in Models and `dbt` processes them for the deployment to Confluent Cloud using the statement REST API. When adopting a 'shift left' strategy of moving part of the star model to real time processing, it makes sense to manage real-time streaming project as data engineers manages data warehouse or lakehouse projects.

* Create the project
  ```sh
  dbt init flink_workshop
  ```
  
  The dbt profile under `~/.dbt/profile.yaml` may include references to environment variables like API KEY and SECRET.
    ```yaml
    flink_workshop:
      outputs:
        dev:
          cloud_provider: aws
          cloud_region: us-west-2
          compute_pool_id: lfcp-
          dbname: j9r-kafka
          environment_id: env-
          execution_mode: streaming_query
          flink_api_key: "{{ env_var('CONFLUENT_FLINK_API_KEY') }}"
          flink_api_secret: "{{ env_var('CONFLUENT_FLINK_API_SECRET') }}"
          organization_id: 49......44
          statement_label: dbt-confluent
          statement_name_prefix: dbt-
          threads: 1
          type: confluent
    ```

    It is a reusable connection that can be referenced by any dbt project:
    ```yaml
    name: 'flink_workshop'
    version: '1.0.0'
    profile: 'cc_flink'
    ```
    
    So it makes sense to rename the `flink_workshop` to ``cc_flink`.


* [profile.yaml](https://docs.getdbt.com/docs/local/profiles.yml?version=1.12) defines information to connect to database.

## Major dbt Concepts

* Batching in `dbt` with a data warehouse, like DuckDB or Snowflake, is primarily managed through different materialization strategies: 
    * *Table*: Replaces the entire target table with each run. Ideal for smaller datasets or full-refresh batches.
    * *Incremental*: Updates only new or changed data using append, merge, or delete+insert.
    * *Microbatch*: Breaks massive datasets into smaller, time-based segments (e.g., daily) that process independently.
    * *External*: Reads from and exports results directly to files (Parquet, CSV, JSON) on local storage or S3.

* `dbt` encourages building complex transformations in smaller, reusable SQL steps, reducing repetitive code.
* `dbt` uses a template mechanism (jinja), functions and a set of features to organize SQL and cross reference them. 
* The mandatory file for a project is the `dbt_project.yml` file as it contains information that tells `dbt` how to operate the project. `dbt` demarcates between a folder name and a configuration by using a + prefix before the configuration name.
* **Models**: are the basic building blocks of the business logic. They includes materialized tables and views, and SQL files. Models can reference each others and use templates and macros. 
* **Resources types** includes models, seeds, snapshots, tests, sources
* **Properties** describe resources
* **Configurations** control how `dbt` builds resources in the warehouse. Could be set cross resources in `dbt_project.yml`, in a `properties.yml` under a folder, `config()` in a sql or resource file.

### Models

Models are built in logical layers to keep the pipeline clean and scalable. They are dependent on each other, forming a Direct Acyclic Graph.

* Staging (stg_): Clean and rename the raw data (e.g., lowercase names, fix boolean types).
* Intermediate (int_): Perform complex joins, aggregations, and business logic here.
* Marts (fct_ or dim_): The final, analytics-ready models

The table below lists when to use View vs Table:

|  | View | Table|
| --- | --- | --- |
| **Purpose** | Use for minor transformation | For intensive transformation |
| **Execution** | At runtime and when referenced | Pre-executed, with the results saved in tables |
| **Storage** | None | Need Storage space for materialized tables |
| **Performance** | Lot of steps leads to slower performance | Chained processes get improved perf. | 

* `dbt` provides built-in testing (e.g., uniqueness, non-null checks) to catch broken logic 
* **schema** is the data contract of elements of the model, and defined in a separate yaml file.
* There are two macros to cross reference tables: `{{ ref() }}` used to reference a table within a model and `{{source() }}` to reference external data sources. 

???+ handson "Create the first model"
    [See the duckdb example](https://github.com/jbcodeforce/flink-studies/tree/master/code/dbt) to review the detailed steps to build an analytic data warehouse. The principle is to get ETL to move data to a landing zone, in the datawarehouse `raw` schema.

    ![](./diagrams/arch.drawio.png)

    Once created, the second step, is to add `dbt` sources, then dimensions and facts for the analytics data products.

    For a Flink project the ETL may load data to Kafka Topics, then the same logic to process raw records to silver and analytical data products is done using Flink SQLs.


#### Create silver layer

Sources are defined using a YAML file [`sources.yml`](https://docs.getdbt.com/reference/source-properties) inside your `models/` directory.

```yaml
sources:
  - name: airbnb  # This is the internal dbt name for the source
    schema: raw   # The actual schema name in your warehouse
    tables:
      - name: listings # This is the name of the raw table in the data warehouse
        identifier: raw_listings
```

Table defined in sources, will be referenced in other SQL model using: `{{ source('airbnb', 'listings') }}`. 

From there, one of the first development step is to process those raw tables to create src tables, which include filtered records, deduplicated, and even with some data transformation like flattening hierarchical columns. The models to do so can be saved in a `models/src` folder:

The following SQL is a classical deduplication:

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

So running the following command will create the new table for cleaned records:

```sh
dbt run --target dev
# returns
Found 1 seed, 3 sources, 474 macros
```

which can be validated by opening the duckdb database:

```sql
duckdb data/airbnb.duckdb
# in the shell
select * from main.src_hosts;
```

Same may be done for `raw_reviews`, `raw_listings`

For source freshness, it is recommended to define refreshness condition on raw tables using a timestamp or date column. 

### Project structure

`dbt` recursively scans everything under model-paths (by default models/). `dbt run`, `dbt build`, and `dbt seed` will all find those `.sql` files and deploy/run them.

The folder structure under the models folder can be a hierarchy based on the kimball architecture or star schema [See PM methodology](../cookbook/pm.md#flink-project-management):
```sh
models/
  sources/
    hosts/
      src_hosts.sql
    listings/
      src_listings.sql
  dimensions/
    hosts/
      dim_hosts_cleansed.sql
  facts/
    reviews/
      fct_reviews.sql
```

`dbt` names a model from the file name, not from the folder path.

* For `models/sources/src_hosts.sql` the model name is `src_hosts`
* Use `ref('src_hosts')`, not `ref('sources.hosts.src_hosts')`

So if two subfolders both contain model.sql, you get a name collision, therefore it is recommended to use distinct filenames (dim_hosts.sql, fct_reviews.sql), or set an explicit alias in config.

For incremental deployment it should be possible to run `dbt` as:
```sh
uv run dbt run --select dimensions.hosts 
# or --select dimensions.*

# Select a unique model
uv run dbt  run --project-dir . --select withdrawals_by_account.sql --target dev --profiles-dir ~/.dbt --full-refresh
```

### Materializations

There are four possible materializations for a model:

* **View:** this is a lightweight representation of the data,  not reused. no recreation of the table at each execution.
* **Table:** reusable data in external table, recreated at each run
* **Incremental:** fact tables appends to tables - more like event data - table is not recreated each time.
* **Ephemeral (CTEs):** aliasing of the data and filtering data. Not advertized in the data warehouse. For example all the sql under the `src` may become CTEs

Materialization can be set globally in the `dbt_profile.yaml`: all models are views, except in the `dimensions` folder where there are tables:

```yaml
models:
  airbnb:
    +materialized: view
    dimensions:
      +materialized: table 
    src:
      +materialized: ephemeral
```

Also it is possible to define at the model level the materialization using the `config()` function:

* Create dimensions folder, add sql with config:
  ```sql 
  {{
    config(
      materialized = 'view'
      )
  }}
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
  FROM    {{ ref('src_listings') }}
  ```

### Incremental

Each time dbt runs, the tables will be recreated in the data warehouse. But Fact tables may be kept and the dml can run to continue processing only new records. To do so we need to specify the materialization to be `incremental`. We also want to stop the dml if schema is changed, for that we add conditions: `on_schema_change='fail'`.
  ```sql
  {{
    config(
      materialized = 'incremental',
      on_schema_change='fail'
      )
  }}
  WITH src_reviews AS (
    SELECT * FROM {{ ref('src_reviews') }}
  )
  SELECT * FROM src_reviews
  WHERE review_text is not null

  {% if is_incremental() %}
    AND review_date > (select max(review_date) from {{ this }})
  {% endif %}
  ```

  Finally we need to specify how dbt should increment records in this fact table: this is done by adding jinja template condition to test if dbt run in incremental mode. Therefore condition could be added on one of the column like the `review_date`. It needs to be after the last record in the `fct_reviews` table () '{{ this }}'.

* Executing `dbt run` with the fct_reviews in incremental view will take care of new records added to the `raw_reviews` like:
    ```sql
    INSERT INTO raw_reviews VALUES(3176, CURRENT_TIMESTANP(), 'j9r', 'Excellent sejour', 'positive');
    ```

    then rerun dbt, the new records will be added as last record in the fct_reviews.

* To rebuild everything, make a full-refresh:
  ```
  dbt run --full-refresh
  ```

* With the src as ephemeral the output of `dbt run` becomes:
  ```sh
  23:16:16  1 of 4 START sql table model DEV.dim_hosts_cleansed ............................ [RUN]
  23:16:18  1 of 4 OK created sql table model DEV.dim_hosts_cleansed ....................... [SUCCESS 14111 in 1.93s]
  23:16:18  2 of 4 START sql table model DEV.dim_listings_cleansed ......................... [RUN]
  23:16:20  2 of 4 OK created sql table model DEV.dim_listings_cleansed .................... [SUCCESS 17499 in 2.47s]
  23:16:20  3 of 4 START sql incremental model DEV.fct_reviews ............................. [RUN]
  23:16:23  3 of 4 OK created sql incremental model DEV.fct_reviews ........................ [SUCCESS 0 in 2.37s]
  23:16:23  4 of 4 START sql table model DEV.dim_listings_with_hosts ....................... [RUN]
  23:16:24  4 of 4 OK created sql table model DEV.dim_listings_with_hosts .................. [SUCCESS 17499 in 1.58s]
  23:16:24  
  23:16:24  Finished running 1 incremental model, 3 table models in 0 hours 0 minutes and 9.83 seconds (9.83s).
  ```

* `dbt compile` does not deploy to the target data warehouse
    ```sh
    23:39:49  Running with dbt=1.11.6
    23:39:50  Registered adapter: snowflake=1.11.2
    23:39:50  Found 8 models, 1 seed, 3 sources, 522 macros
    23:39:50  
    23:39:50  Concurrency: 1 threads (target='dev')
    ```

#### Incremental strategies

| mode             | pros | cons |
| ---------------- | ---- | ---- |
| **append**           | simplest. fully transparent logic | no duplicate checks |
| **merge**            | idempotent. updates existing records | slower, require unique key |
| **delete+insert**    | works for data warehouse without merge. | two operations. require unique key |
| **insert+overwrite** | fast for partitioned tables | requires partitioned table. Replaces the whole partitions|

This is set in the config() element.

```
  {{
    config(
      materialized = 'incremental',
      on_schema_change='fail',
      incremental_strategy='merge',
      
      )
  }}
```

### Type-2 slowly changing dimensions

The goal is to keep history of changes to the records over time and not just the last record per key. `dbt` adds `dbt_valid_from` and `dbt_valid_to` columns to mark each records to be valid for a from and to times. A current correct records have `dbt_valid_to` sets to null.

There are two strategies for assessing data changes:
* *Timestamp*: a unique key and updated_at fields is defined at the source model. These columns are used for determining changes
* *Check*: any changes in a set of columns (or all columns) will be picked up as an update.

* **snapshots** live in the `snapshot` folder and are used for tracking changes. To create snapshots we need a yaml file under the `snapshot` folder:
    ```yaml
    snapshots:
    - name: scd_raw_listings
        relation: source('airbnb', 'listings')
        config:
          unique_key: id
          strategy: timestamp
          updated_at: updated_at
          hard_deletes: invalidate
    ```

* the `dbt snapshot` will create a new table with the columns added for the referenced table.
    ```sh
    00:04:36  1 of 1 START snapshot DEV scd_raw_listings ..................................... [RUN] 
    00:04:40  1 of 1 OK snapshotted DEV.scd_raw_listings ..................................... [SUCCESS 17499 in 3.44s]
    ```

    ![](./images/scd_raw_listings.png)

* An update to an existing record and a new `dbt snapshot` will create historical record.

---

## Tests

* Two types of tests:
    * Unit Tests
    * Data Tests: run on actual data

* There are two types of data tests: singular (SQL queries stored in tests) and generic

* Defining test is by adding a `schema.yaml` with `data_tests` conditions on table. [See example in models folder](https://github.com/jbcodeforce/flink-studies/blob/master/code/dbt/airbnb/models/schema.yaml)
  ```yaml
  models:
  - name: dim_listings_cleansed
    description: "Listings dimension"
    columns:
      - name: listing_id
        description: "Listing ID"
        data_tests:
          - not_null
          - unique
  ```

* To run the tests
  ```sh
  dbt text --target duckdb -x
  # -x it to continue even if one test fails
  ```

* For unit test, we can define a yaml file at the same level as the SQL under validation. See [unit_test.yaml](https://github.com/jbcodeforce/flink-studies/blob/master/code/dbt/airbnb/models/mart/unit_test.yaml), then run:
  ```sh
  dbt test -s mart_fullmoon_reviews
  ```

## Confluent Cloud Flink Specifics

In Confluent Cloud for Flink context, the `dbt run` does not process data; it deploys or updates the definition of a continuous dataflow to the streaming engine. User runs `dbt run` only when the SQL queries changes. Important chapter from [Confluent cloud product documentation on dbt.](https://docs.confluent.io/cloud/current/flink/operate-and-deploy/deploy-flink-dbt.html)

* A `dbt` schema is a Flink database, while a `dbt` database is a Flink Catalog, and finally a `dbt` identifier is a Flink Table. The `dbname` field in `profiles.yml` actually refers to a Kafka cluster name. 
  ```yaml
  cc_flink:
    outputs:
      dev:
        dbname: j9r-kafka
        environment_id: env-yk3jm6
        execution_mode: streaming_query
        statement_label: dbt-confluent
        statement_name_prefix: dbt-
        threads: 1
        type: confluent
    target: dev
  ```

Some error messages reference "schema" when they mean "Kafka cluster/database". It is confusing to set the environment_id where is Confluent Cloud the environment name is used.

* The `dbt` mapping for dbt Confluent:

| Dbt construct | CC Flink | dbt confluent materialization |
| --------- | -------- | ------- |
| view     | create view .. as select | view |
| table     | snapshot query | streaming_table  |
| incremental | not-supported | | 
| ephemeral | not supported | | 
| materialized_view | create table ... as select | streaming_table |
| seeds | CREATE TABLE + INSERT VALUES (point-in-time) | seed (default) |

### How to

???+ handson "Seed reference data on Confluent Cloud for Flink"
    The [airbnb_streaming](https://github.com/jbcodeforce/flink-studies/tree/master/code/dbt/airbnb_streaming) project loads small reference CSVs into Flink tables with `dbt seed`. The dbt-confluent adapter infers column types from the CSV (via agate) and issues `CREATE TABLE` followed by `INSERT INTO ... VALUES`. Override types in `seeds/seeds.yml` when inference is too coarse (e.g. map date strings to `DATE`).

    ```yaml
    # seeds/seeds.yml (dbt properties format)
    version: 2
    seeds:
      - name: seed_full_moon_dates
        config:
          alias: raw_full_moon_dates
          column_types:
            full_moon_date: DATE
    ```

    Set `+execution_mode: snapshot` on seeds in `dbt_project.yml` so DDL and INSERT run as point-in-time statements (not streaming queries). Seeds are limited to 10,000 rows per file.

    ```bash
    cd code/dbt/airbnb_streaming
    dbt seed --target dev
    ```

    Optionally run `make seed` to regenerate `seeds.yml` column types from CSV headers before seeding.


???+ question "How to specify table properties?"
    Use the config function, and the `with` as json.

    ```sql
    {{ config(
        materialized = 'streaming_table',
        with         = {
            'changelog.mode: 'upsert'
        }
       ) 
    }}
    ```

???+ question "How to define primary key for non source tables?"
    This is done in the schema.yml file. For a column: 
    ```yaml
    columns:
      - name: account_number
        data_type: varchar(2147483647)
        constraints:
          - type: not_null
          - type: primary_key
            expression: "not enforced"
    ``` 
    or as combined keys set with external contraints:
    ```yaml
    columns:
      - name: account_number
        data_type: varchar(255)
      - name: transaction_type
        data_type: varchar(50)
      - name: total_withdrawn
        data_type: decimal(38, 2)
    constraints:
      - type: primary_key
        columns: [account_number, transaction_type]
        expression: "NOT ENFORCED"
    ```

???+ question "How to define materialized table"
    Add the config element in the model file
      ```sql
      {{ config(
          materialized       = 'materialized_table',
          freshness_interval = "INTERVAL '1' MINUTE",
          distributed_by     = "order_id",
          start_mode         = 'RESUME_OR_FROM_BEGINNING'
          with               = {
              'key.format: 'avro-registry',
              'value.format: 'avro-registry'
          }
        ) 
      }}
      ```

### Flink Demos using dbt

* [Jan's flink workshop ported to dbt](https://github.com/jbcodeforce/flink-studies/tree/main/code/dbt/flink_workshop)    
* [Research on PTF](https://github.com/jbcodeforce/research/tree/main/flink-ptf-multitenant-debezium-spanout/sql/order_pipeline)
* [wd-flink-demo](https://github.com/jbcodeforce/wd-flink-demo)
* [Airbnb streaming](https://github.com/jbcodeforce/flink-studies/tree/main/code/dbt/airbnb)
* [Tool to help migrate Flink ddl and dmls to dbt model](https://github.com/jbcodeforce/flink-studies/tree/main/code/flink-sql/tools/flink_dbt_migrate)

## Sources of Information

* [Udemy training from Zoltan C. Toth](https://www.udemy.com/course/complete-dbt-data-build-tool-bootcamp-zero-to-hero-learn-dbt) with [Git Repo](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero). Example of data [from Inside AirBnB](https://insideairbnb.com/berlin/).
* [Dbt core](https://github.com/dbt-labs/dbt-core)
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
* [Preset](https://preset.io/product/) is a SaaS for [Apache Superset](https://superset.apache.org/) to develop BI dashboard, on cloud with dbt integration. It also includes a SQL Editor.
* [Snowflake](https://app.snowflake.com)  username: jbcodeforce. Using key-pair authentication. Public [key in Snowlflake](https://docs.snowflake.com/en/user-guide/opencatalog/key-pair-auth-configure#generate-a-private-and-public-key)
* [Youtube tutorial](https://www.youtube.com/watch?v=cW7KFaos2cw)
* [Patrick Neff's git repo: Stream Processing in Confluent Cloud Flink with data build tool (dbt)](https://github.com/pneff93/dbt-cc-stream-processing)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices