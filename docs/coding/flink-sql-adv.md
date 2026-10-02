# Flink SQL Advanced Topics


## PROCTIME

Processing Time (proctime) in Apache Flink refers to the system time of the local machine (TaskManager node) executing a specific transformation operator. It looks simpler as it does not require watermark, timestamp extraction and out-of order event handling. It operates directly at the physical execution layer of a Flink TaskManager.

TaskManager calls `System.currentTimeMillis()` at the precise instant an operator thread processes an incoming record.

For accuracy, replayability with same results requirements, Confluent Cloud does not support proctime. It is non-deterministic, because proctime relies on wall-clock time, re-processing streaming data during job recovery (from savepoints or checkpoints) evaluates against the new system time, completely altering window assignments and aggregations.

One of the classical impact is when reprocessing historical data through a 5-minute tumbling window will group all replayed records into the single 5-minute window corresponding to the recovery execution window, collapsing the historical distribution.

When downstream operators introduce backpressure, records stall inside intermediate network buffers.The arrival time at the operator execution thread is artificially delayed. Records produced at T_0 might be stamped with proctime T_0 + Delta t, causing window skew and inaccurate throughput measurements. Long Java garbage collection pauses produce identical anomalies: records buffered during a GC pause are processed immediately afterward in a dense batch, incorrectly filling downstream processing-time windows.

Clock synchronization between nodes running the task manager needs to be in place, using Network Time Protocol.

In SQL, Apache OSS the following DDL uses the function

```sql
CREATE TABLE user_clicks (
    user_id STRING,
    url STRING,
    click_time AS PROCTIME() -- Declares a processing-time attribute
) WITH (
    'connector' = 'kafka',
    'topic' = 'user-clicks',
    'properties.bootstrap.servers' = 'localhost:9092',
    'format' = 'json'
);
```

Then a tumblink window will use this time:

```sql
SELECT 
    user_id,
    COUNT(*) AS click_count,
    TUMBLE_START(click_time, INTERVAL '1' MINUTE) AS window_start,
    TUMBLE_END(click_time, INTERVAL '1' MINUTE) AS window_end
FROM user_clicks
GROUP BY 
    user_id, 
    TUMBLE(click_time, INTERVAL '1' MINUTE);
```


## State bootstraping


The Flink stateful function [State Bootstrapping](https://nightlies.apache.org/flink/flink-statefun-docs-master/docs/deployment/state-bootstrap/) helps to load data in Flink snapshot as a way to bootstrap Flink stateful statement.

## Bootstrap Queries

In Confluent Cloud load data from kafka topic or tableflow table, to load historical data then automatically switch to streaming data from Kafka. It leverages [Flink’s HybridSource](https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/datastream/hybridsource/) which is a capacity to read data from different bounded sources to a unique input stream. 

### Some constraints

* Reading historical data from Iceberg table do not guaranty the record order (using kafka offset for example). This could affect correctness of query operator like LAST_VALUE, LAG, MATCH_RECOGNIZE. Event-Time dependent operators may experience latent results.
* Reading historical data from Kafka, will keep offset ordering per partition.

## Changelog PTFs

A changelog is a stream of row-level changes, where each record says whether a row was created, updated, or deleted. Some sources use their own format to carry the change operation. Confluent Cloud for Flink has now two PTF to control how to interpret and then produce changelog streams. 

See the [Confluent Cloud documentation](https://docs.confluent.io/cloud/current/flink/reference/functions/changelog-conversion.html) and the [How-to guide](https://docs.confluent.io/cloud/current/flink/how-to-guides/read-write-custom-changelog.html). The how to guide is also implemented as a demonstration in [code/flink-sql/16-changelog-conversion](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/16-changelog-conversion). It reads `raw_orders` records (append-only, carry a user-defined 'op' STRING field) and uses the FROM_CHANGELOG Process Table Function (PTF) to translate each custom op code into the matching Flink internal row kind:


| PTF | Direction | What it does |
|---|---|---|
| `FROM_CHANGELOG` | **Inbound** | Reads an append-only stream carrying a user-defined op field and converts it into a Flink updating table by mapping each op code to a Flink row kind (`+I`, `-U`, `+U`, `-D`). |
| `TO_CHANGELOG` | **Outbound** | Converts a Flink updating table back into a plain append stream where every row (including deletes) carries an explicit op code a non-Flink consumer can act on. |

A demonstration pipeline:

![](./diagrams/d16_flow.drawio.png)



