# dbt Studies - Samples

## Using duckdb as data warehouse

The approach is to use duckdb as target of the dbt processing. 

### Raw landing zone

It is first used as a landing zone for raw data, then dbt models process data for creating dimensions and facts.

1. From the repo root, install deps and sync: `cd code/dbt && uv sync`.
2. Place raw CSVs in `code/dbt/airbnb/data/`: `listings.csv`, `hosts.csv`, `reviews.csv` (e.g. from the [bootcamp resources](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero/blob/main/_course_resources/course-resources.md) or S3: `s3://dbt-datasets/listings.csv`, etc.).
3. From `code/dbt/airbnb/`, bootstrap the DuckDB raw tables (one-time):
    ```bash
    export DBT_DUCKDB_PATH=./data/airbnb.duckdb
    duckdb "${DBT_DUCKDB_PATH:-./data/airbnb.duckdb}" < scripts/bootstrap_duckdb_raw.sql
    ```

    ![](./docs/arch.drawio.png)

4. Review the raw tables

[See my summary on duckdb](https://jbcodeforce.github.io/db-play/duckdb/)

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

### Understand the project

* Seeds are to define reference tables, like the full moon dates from 2009 to 2030
* Models: includes the star model: sources, dimensions and facts.

### Create seeds

The following command let dbt to look inside the seeds/ folder of your project, find any .csv files, and upload them as physical tables into your database.
```sh
dbt seed --target dev
```

The target dev matches the connection profile in `profiles.yaml`

### Create Sources

* Define the yaml file under models
* Add SQL for deduplicating the raw.raw_hosts data. Create a `models/sources` folder and add:

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

So running the following command:

```sh
dbt run --target dev
# returns
Found 1 seed, 3 sources, 474 macros
Concurrency: 1 threads (target='dev')

 1 of 1 START sql view model main.src_hosts ..................................... [RUN]
 1 of 1 OK created sql view model main.src_hosts ................................ [OK in 0.03s]
```

which can be validated by opening the duckdb database:

```sql
duckdb data/airbnb.duckdb
# in the shell
select * from main.src_hosts;
```

Same can be done for listings and reviews. Those sources SQL can do schema mapping, and filtering.