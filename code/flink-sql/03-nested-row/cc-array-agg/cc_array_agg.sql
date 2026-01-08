-- This example shows how to aggregate an array of records into a single record with the last record of the array.
-- create table suites with one record per asset as part of a suite.
create table suites (
    suite_id STRING,
    asset_id STRING,
    suite_name STRING,
    ts_ltz timestamp_ltz(3),
    insert_ts_ltz timestamp_ltz(3),
    PRIMARY KEY(suite_id) NOT ENFORCED
) distributed by (suite_id) into 1 buckets with (
    'changelog.mode' = 'append',
    'kafka.retention.time' = '0',
    'kafka.producer.compression.type' = 'snappy',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);

insert into suites (suite_id, asset_id, suite_name, ts_ltz, insert_ts_ltz)
values 
  ('suite_1', 'asset_1', 'suite_1', TO_TIMESTAMP_LTZ('2024-01-10 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-10 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  ('suite_2', 'asset_1', 'suite_2', TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'));


-- create a sink table:
create table suites_agg (
    suite_id STRING,
    asset_ids ARRAY<STRING>,
    ts_ltz timestamp_ltz(3),
    insert_ts_ltz timestamp_ltz(3),
    PRIMARY KEY(suite_id) NOT ENFORCED
) distributed by (suite_id) into 1 buckets with (
    'changelog.mode' = 'upsert',
    'kafka.retention.time' = '0',
    'kafka.producer.compression.type' = 'snappy',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);
-- the changelog need to be upset model to support consuming update changes 
-- which is produced by node GroupAggregate(groupBy=[suite_id, ts_ltz, asset_ids], 
-- insert the aggregated data into the sink table:
insert into suites_agg (suite_id, asset_ids, ts_ltz, insert_ts_ltz)
select suite_id, ARRAY_AGG(asset_id) as asset_ids, max(ts_ltz) as ts_ltz, max(insert_ts_ltz) as insert_ts_ltz from suites group by suite_id;

-- Doing the following in Workspace
select suite_id, ARRAY_AGG(asset_id) as asset_ids from suites group by suite_id;
-- Results look like:
-- suite_id | asset_ids
-- -------- | ---------
-- suite_1  | [asset_1]
-- suite_2  | [asset_1]

-- At the sink topic
select suite_id, asset_ids,  ts_ltz, insert_ts_ltz from suites_agg;

-- Add more records.
insert into suites (suite_id, asset_id, suite_name, ts_ltz, insert_ts_ltz)
values 
  ('suite_1', 'asset_3', 'suite_1', TO_TIMESTAMP_LTZ('2024-01-12 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-12 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  ('suite_2', 'asset_2', 'suite_2', TO_TIMESTAMP_LTZ('2024-01-12 10:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-12 10:00:00', 'yyyy-MM-dd HH:mm:ss'));

-- View the results at the sink topic - See suites_agg_chlog.png
-- in the topics there are 4 records
-- 0, suite_1, [asset_1], 2024-01-11 10:00:00, 2024-01-11 10:00:00
-- 1, suite_2, [asset_1], 2024-01-10 00:00:00, 2024-01-10 00:00:00
-- 2, suite_1, [asset_1, asset_3], 2024-01-12 00:00:00, 2024-01-12 00:00:00
-- 3, suite_2, [asset_1, asset_2], 2024-01-12 10:00:00, 2024-01-12 10:00:00

-- The query 
select suite_id, ARRAY_AGG(asset_id) as asset_ids from suites group by suite_id;
-- returns the expected results because it keep Flink SQL semantic.
-- suite_id | asset_ids
-- -------- | ---------
-- suite_1  | [asset_1, asset_3]
-- suite_2  | [asset_1, asset_2]

-- clean up the tables:
drop table suites;
drop table suites_agg;