# Nested objects and arrays

## Pre-requisites

* Create a Confluent cloud environment using quickstart

```sh
confluent flink quickstart --name jb-demo --max-cfu 10 --region us-west-2 --cloud aws
```

* Start the SQL client

```sh
confluent flink shell --compute-pool --environment
```

## Access user information from nested schema

1. Create a mockup of nested schema with the `vw.nested_user.sql` file

    ```sql
    create view nested_user_clicks as
    select
        click_id,
        view_time,
        url,
        CAST(user_id, user_agent) AS ROW<user_id BIGINT, user_agent STRING>) AS user_data,
        `$rowtime`
    FROM `examples`.`marketplace`.`clicks`;
    ```

    Recall to create those statement using CLI:
    
    ```sh
    confluent flink statement create $statement_name --sql "$sql_statement" --database $DB_NAME --compute-pool $CPOOL_ID --wait 
    ```

1. Access the nested schema in the SELECT (see `dml.nested_user.sql`)

For array iteration and aggregation for example see the `vw.arrray_of_rows.sql` and a unnesting of the array with

    ```sql
    SELECT window_time, url, T.*
    FROM page_views_1m
    CROSS JOIN UNNEST(page_views_1m.page_views) AS T(user_id, view_time, viewed_at)
    ```

## Another examples

How to get REST API service ingested into topic and processed by Flink using nested json object and array:

* [Confluent- HTTP source as stream demo](https://github.com/confluentinc/demo-scene/tree/master/http-streaming) with [video run throw](https://www.youtube.com/watch?v=HB_TbqCKny4). The source is opensky-network.org which delivers every 10s flight information for a specified geography. A Kafka HTTP Connector is configured to get the data from the REST API. The [API response is described here.](https://openskynetwork.github.io/opensky-api/rest.html#response) The approach is to define a table with a new schema using Flink CTAS statements and add data cleaning and filterning DMLs.

Example of output:

```json
{
    "time": 1735065278,
    "states": [
        [
            "4b1800",
            "SWR112E ",
            "Switzerland",
            1735065278,
            1735065278,
            9.0268,
            47.4177,
            5478.78,
            false,
            163.93,
            82.61,
            11.38,
            null,
            5615.94,
            "1000",
            false,
            0
        ],
        # more records in states
}
```

The SQL expands the states array in each row of the all_flights table into new rows, one per array element, by performing a cross join against the UNNEST'ing of the states array.

```sql
INSERT INTO all_flights_cleansed
    SELECT TO_TIMESTAMP_LTZ(`time`, 0) AS poll_timestamp,
      RTRIM(StatesTable.states[1]) AS icao24,
      RTRIM(StatesTable.states[2]) AS callsign,
      RTRIM(StatesTable.states[3]) AS origin_country,
      TO_TIMESTAMP_LTZ(CAST(StatesTable.states[4] AS NUMERIC), 0) AS event_timestamp,
      CAST(StatesTable.states[6] AS DECIMAL(10, 4)) AS longitude,
      CAST(StatesTable.states[7] AS DECIMAL(10, 4)) AS latitude,
      CAST(StatesTable.states[8] AS DECIMAL(10, 2)) AS barometric_altitude,
      CAST(StatesTable.states[9] AS BOOLEAN) AS on_ground,
      CAST(StatesTable.states[10] AS DECIMAL(10, 2)) AS velocity_m_per_s
    FROM all_flights CROSS JOIN UNNEST(all_flights.states) as StatesTable (states);
```