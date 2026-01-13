-- ################################################
-- Example of aggregating with ROWs as part of the array aggregation.
-- create table suites with one record per asset as part of a suite.
create table suites (
    suite_id INTEGER,
    asset_id INTEGER,
    suite_name STRING,
    asset_name STRING,
    asset_price_min DECIMAL(24,4),
    asset_price_max DECIMAL(24,4),
    ts_ltz timestamp_ltz(3),
    PRIMARY KEY(suite_id) NOT ENFORCED
) distributed by (suite_id) into 1 buckets with (
    'changelog.mode' = 'append',
    'kafka.retention.time' = '0',
    'kafka.producer.compression.type' = 'snappy',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);

insert into suites (suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz)
values 
  (1, 1, 'suite_1', 'asset_1', 100.00, 130.00, TO_TIMESTAMP_LTZ('2024-01-10 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (1, 2, 'suite_1', 'asset_2', 200.00, 230.00, TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (2, 1, 'suite_2', 'asset_1', 100.00, 130.00, TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'));
-- verify creating array of rows:
select 
    suite_id, 
    ARRAY_AGG(ROW (asset_id, asset_name, asset_price_min, asset_price_max)) as asset_data 
from suites 
group by suite_id;
-- Results look like:
-- suite_id | asset_data (type Object)
-- -------- | ---------
-- 1  | [1, asset_1, 100.00, 130.00, 2, asset_2, 200.00, 230.00]
-- 2  | [1, asset_1, 100.00, 130.00]

-- Add a sink table to store the aggregated data:
create table suites_agg (
    suite_id INTEGER,
    asset_data ARRAY<
        ROW<
          asset_id INTEGER, 
          asset_name STRING, 
          asset_price_range ROW<
             asset_price_min DECIMAL(24,4), 
             asset_price_max DECIMAL(24,4)
          >
        >>,
    ts_ltz timestamp_ltz(3),
    PRIMARY KEY(suite_id) NOT ENFORCED
) distributed by (suite_id) into 1 buckets with (
    'changelog.mode' = 'upsert',
    'kafka.retention.time' = '0',
    'kafka.producer.compression.type' = 'snappy',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);

-- insert the aggregated data into the sink table:
insert into suites_agg (suite_id, asset_data, ts_ltz)
select 
    suite_id, 
    ARRAY_AGG(ROW (asset_id, asset_name, ROW(asset_price_min, asset_price_max))) as asset_data,
    max(ts_ltz) as ts_ltz
from suites 
group by suite_id;
-- Validate at the Flink Workspace level
select suite_id, asset_data, ts_ltz from suites_agg;
-- Results look like:
-- suite_id | asset_data (type Object) | ts_ltz
-- -------- | ------------------------ | --------
-- 1  | [1, asset_1, 100.00, 130.00, 2, asset_2, 200.00, 230.00] | 2024-01-10 00:00:00
-- 2  | [1, asset_1, 100.00, 130.00] | 2024-01-11 10:00:00

-- Adding more records 
insert into suites (suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz)
values 
  (1, 3, 'suite_1', 'asset_3', 300.00, 330.00, TO_TIMESTAMP_LTZ('2024-01-12 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (2, 2, 'suite_2', 'asset_2', 400.00, 450.00, TO_TIMESTAMP_LTZ('2024-01-12 10:00:00', 'yyyy-MM-dd HH:mm:ss'));

-- Validate at the Flink Workspace level
select suite_id, asset_data, ts_ltz from suites_agg;
-- Results look like:
-- suite_id | asset_data (type Object) | ts_ltz |   
-- -------- | ------------------------ | --------
-- 2  | 1,asset_1,100.0000,130.0000,3,asset_3,300.0000,330.0000,2,asset_2,200.0000,230.0000
-- 1  | 1,asset_1,100.0000,130.0000,2,asset_2,400.0000, 450.0000

-- ################### 2nd example: deduplication CTE ###################
-- The goal is to remove duplicates from the source table before array aggregation. 
-- So we need to combine with a deduplication CTE


create view suites_versioned as 
select  suite_id, suite_name, asset_id, asset_name, asset_price_min, asset_price_max, ts_ltz
from (
    select *,
       ROW_NUMBER() OVER (PARTITION BY suite_id, asset_id ORDER BY ts_ltz DESC) as rn
        from suites
    ) where rn = 1;
    
-- then process the array aggregation
select 
    suite_id,
    ARRAY_AGG(ROW (asset_id, asset_name,  ROW(asset_price_min, asset_price_max))) as asset_data, 
    max(ts_ltz) as ts_ltz
from suites_versioned group by suite_id;

-- ROW could not be used with DISTINCT keyword.


-- ################### 3rd example: removing records from the array ###################
-- To support removing records from the array the source table should support upsert.
-- 1. drop table suites  to start from clean dataset

-- insert 7 records with 2 duplicates and 1 delete.
insert into suites(suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz) values 
  (1, 1, 'suite_1', 'asset_1', 100.00, 130.00, TO_TIMESTAMP_LTZ('2024-01-10 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (1, 2, 'suite_1', 'asset_2', 200.00, 230.00, TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (2, 3, 'suite_2', 'asset_3', 300.00, 330.00, TO_TIMESTAMP_LTZ('2024-01-12 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (2, 3, 'suite_2', 'asset_3', 300.00, 331.00, TO_TIMESTAMP_LTZ('2024-01-13 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (1, 5, 'suite_1', 'asset_5', 500.00, 550.00, TO_TIMESTAMP_LTZ('2024-01-14 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (1, 2, 'suite_1', 'asset_2', 200.00, 231.00, TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (2, 7, 'suite_2', 'asset_7', 700.00, 770.00, TO_TIMESTAMP_LTZ('2024-01-16 00:00:00', 'yyyy-MM-dd HH:mm:ss'));
  
-- The expected results are:
-- 1,[ 1,asset_1,100.0000,130.0000,2,asset_2,200.0000,230.0000,5,asset_5,500.0000,550.0000]
-- 2,[3,asset_3,300.0000,331.0000,7,asset_7,700.0000,770.0000

-- changing the asset 1 in suite 1, will perform the retract.
insert into suites(suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz) values 
  (1, 1, 'suite_1', 'asset_1', 110.00, 135.00, TO_TIMESTAMP_LTZ('2024-01-16 00:00:00', 'yyyy-MM-dd HH:mm:ss'));
-- expected results:
-- 1, [2,asset_2,200.0000,230.0000,5,asset_5,500.0000,550.0000,1,asset_1,110.0000,135.0000]
