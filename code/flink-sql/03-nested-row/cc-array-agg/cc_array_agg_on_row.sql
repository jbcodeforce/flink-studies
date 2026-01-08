-- now use row as part of the array aggregation.
-- create table suites with one record per asset as part of a suite.
create table suites (
    suite_id INTEGER,
    asset_id INTEGER,
    suite_name STRING,
    asset_name STRING,
    asset_price_min DECIMAL(24,4),
    asset_price_max DECIMAL(24,4),
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

insert into suites (suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz, insert_ts_ltz)
values 
  (1, 1, 'suite_1', 'asset_1', 100.00, 130.00, TO_TIMESTAMP_LTZ('2024-01-10 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-10 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (2, 1, 'suite_2', 'asset_1', 100.00, 130.00, TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'));

-- verify creating array of rows:
select 
    suite_id, 
    ARRAY_AGG(ROW (asset_id, asset_name, asset_price_min, asset_price_max)) as asset_data 
from suites 
group by suite_id;
-- Results look like:
-- suite_id | asset_data (type Object)
-- -------- | ---------
-- suite_1  | [(1, asset_1, 100.00, 130.00)]
-- suite_2  | [(1, asset_1, 100.00, 130.00)]

-- sink table
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

-- insert the aggregated data into the sink table:
insert into suites_agg (suite_id, asset_data, ts_ltz, insert_ts_ltz)
select 
    suite_id, 
    ARRAY_AGG(ROW (asset_id, asset_name, ROW(asset_price_min, asset_price_max))) as asset_data,
    max(ts_ltz) as ts_ltz,
    max(insert_ts_ltz) as insert_ts_ltz
from suites 
group by suite_id;
-- Validate at the Flink Workspace level
select suite_id, asset_data, ts_ltz, insert_ts_ltz from suites_agg;
-- Results look like:
-- suite_id | asset_data (type Object) | ts_ltz | insert_ts_ltz
-- -------- | --------- | -------- | --------
-- 1  | [1, asset_1] | 2024-01-10 00:00:00 | 2024-01-10 00:00:00
-- 2  | [1, asset_1] | 2024-01-11 10:00:00 | 2024-01-11 10:00:00

-- Adding more records 
insert into suites (suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz, insert_ts_ltz)
values 
  (1, 2, 'suite_1', 'asset_2', 150.00, 230.00, TO_TIMESTAMP_LTZ('2024-01-12 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-12 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (2, 2, 'suite_2', 'asset_2', 150.00, 230.00, TO_TIMESTAMP_LTZ('2024-01-12 10:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-12 10:00:00', 'yyyy-MM-dd HH:mm:ss'));

-- Validate at the Flink Workspace level
select suite_id, asset_data, ts_ltz, insert_ts_ltz from suites_agg;
-- Results look like:
-- suite_id | asset_data (type Object) | ts_ltz | insert_ts_ltz
-- -------- | --------- | -------- | --------
-- 2  | 1,asset_1,100.0000,130.0000,3,asset_3,,130.0000,2,asset_2,150.0000,230.0000
-- 1  | 1,asset_1,100.0000,130.0000,2,asset_2,150.0000,230.0000

-- Result from suites
-- 1 [1,asset_1,100,130, 2,asset_2,150,230]
-- 2 [1,asset_1,100,130, 2,asset_2,150,230]

-- same results at the sink topic

-- Adding more new assets
insert into suites (suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz, insert_ts_ltz)  
values 
  (1, 3, 'suite_1', 'asset_3', 100.00, 130.00, TO_TIMESTAMP_LTZ('2024-01-13 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-13 00:00:00', 'yyyy-MM-dd HH:mm:ss')),
  (2, 4, 'suite_2', 'asset_4', 400.00, 440.00, TO_TIMESTAMP_LTZ('2024-01-13 10:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-13 10:00:00', 'yyyy-MM-dd HH:mm:ss'));

-- Validate at the Flink Workspace level
select * from suites_agg;
-- Results look like:
-- suite_id | asset_data (type Object) | ts_ltz | insert_ts_ltz
-- -------- | --------- | -------- | --------
-- 1  | [1, asset_1, 2, asset_2, 3, asset_3] | 2024-01-13 00:00:00 | 2024-01-13 00:00:00
-- 2  | [1, asset_1, 2, asset_2, 3, asset_3] | 2024-01-13 10:00:00 | 2024-01-13 10:00:00

-- if sending the same last 2 records again the
-- array will grow:
-- 1  | [1, asset_1, 2, asset_2, 3, asset_3, 3, asset_3] 
-- 2  | [1, asset_1, 2, asset_2, 4, asset_4, 4, asset_4]

-- So we need toc combine with a deduplication CTE
with deduped_suites as (
    select suite_id, asset_id, asset_name, asset_price_min, asset_price_max, ts_ltz, insert_ts_ltz 
    from (
        select suite_id, asset_id, asset_name, asset_price_min, asset_price_max, ts_ltz, insert_ts_ltz,
        ROW_NUMBER() OVER (PARTITION BY suite_id ORDER BY ts_ltz DESC, insert_ts_ltz DESC) as rn
        from suites
    ) where rn = 1 
)
select 
    suite_id, 
    ARRAY_AGG(ROW (asset_id, asset_name,  ROW(asset_price_min, asset_price_max))) as asset_data, 
    max(ts_ltz) as ts_ltz,
    max(insert_ts_ltz) as insert_ts_ltz 
from deduped_suites group by suite_id;
-- Results look like:
-- suite_id | asset_data (type Object) | ts_ltz | insert_ts_ltz
-- -------- | --------- | -------- | --------
-- 1  | [1, asset_1, 2, asset_2, 3, asset_3] | 2024-01-13 00:00:00 | 2024-01-13 00:00:00
-- 2  | [1, asset_1, 2, asset_2, 4, asset_4] | 2024-01-13 10:00:00 | 2024-01-13 10:00:00

-- To support removing records from the array the source table should support upsert.

create table suites_retract (
    suite_id INTEGER,
    asset_id INTEGER,
    suite_name STRING,
    asset_name STRING,
    asset_price_min DECIMAL(24,4),
    asset_price_max DECIMAL(24,4),
    ts_ltz timestamp_ltz(3),
    insert_ts_ltz timestamp_ltz(3),
    PRIMARY KEY(suite_id) NOT ENFORCED
) distributed by (suite_id) into 1 buckets with (
    'changelog.mode' = 'retract',
    'kafka.retention.time' = '0',
    'kafka.producer.compression.type' = 'snappy',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);

-- add a an _op field in the suite table to simulate delete operation
create table suites (
    suite_id INTEGER,
    asset_id INTEGER,
    suite_name STRING,
    asset_name STRING,
    asset_price_min DECIMAL(24,4),
    asset_price_max DECIMAL(24,4),
    ts_ltz timestamp_ltz(3),
    insert_ts_ltz timestamp_ltz(3),
    _op STRING,
    PRIMARY KEY(suite_id) NOT ENFORCED
) distributed by (suite_id) into 1 buckets with (
    'changelog.mode' = 'append',
    'kafka.retention.time' = '0',
    'kafka.producer.compression.type' = 'snappy',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all'
);
-- insert 7 records with 2 duplicates and 1 delete.
insert into suites(suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz, insert_ts_ltz, _op) values 
  (1, 1, 'suite_1', 'asset_1', 100.00, 130.00, TO_TIMESTAMP_LTZ('2024-01-10 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-10 00:00:00', 'yyyy-MM-dd HH:mm:ss'), 'I'),
  (1, 2, 'suite_1', 'asset_2', 200.00, 230.00, TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'), 'I'),
  (2, 3, 'suite_2', 'asset_3', 300.00, 330.00, TO_TIMESTAMP_LTZ('2024-01-12 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-12 00:00:00', 'yyyy-MM-dd HH:mm:ss'), 'I'),
  --- duplicate not same time stamp.
  (2, 3, 'suite_2', 'asset_3', 300.00, 331.00, TO_TIMESTAMP_LTZ('2024-01-13 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-13 00:00:00', 'yyyy-MM-dd HH:mm:ss'), 'I'),
  (1, 5, 'suite_1', 'asset_5', 500.00, 550.00, TO_TIMESTAMP_LTZ('2024-01-14 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-14 00:00:00', 'yyyy-MM-dd HH:mm:ss'), 'I'),
  --- duplicate
  (1, 2, 'suite_1', 'asset_2', 200.00, 231.00, TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-11 10:00:00', 'yyyy-MM-dd HH:mm:ss'), 'I'),
 
  (2, 7, 'suite_2', 'asset_7', 700.00, 770.00, TO_TIMESTAMP_LTZ('2024-01-16 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-16 00:00:00', 'yyyy-MM-dd HH:mm:ss'), 'I'),
  --- delete
  (1, 2, 'suite_1', 'asset_2', 200.00, 232.00, TO_TIMESTAMP_LTZ('2024-01-17 00:00:00', 'yyyy-MM-dd HH:mm:ss'), TO_TIMESTAMP_LTZ('2024-01-17 00:00:00', 'yyyy-MM-dd HH:mm:ss'), 'D');

-- The expected results are:
-- 1,[1,asset_1,100.0000,130.0000,3,asset_3,300.0000,331.0000,5,asset_5,500.0000,550.0000,5] ...
-- 2,[3,asset_3,300.0000,330.0000,7,asset_7,700.0000,770.0000

-- add a dedup and delete operation support.
insert into suites_retract 
with deduped_suites as (
    select * from (
        select suite_id, suite_name, asset_id, asset_name, asset_price_min, asset_price_max, ts_ltz, insert_ts_ltz, _op
        ROW_NUMBER() OVER (PARTITION BY suite_id, asset_id ORDER BY ts_ltz DESC, insert_ts_ltz DESC) as rn
        from suites
    ) where rn = 1 
)
select 
    suite_id, asset_id, suite_name, asset_name, asset_price_min, asset_price_max, ts_ltz, insert_ts_ltz 
from deduped_suites
where _op <> 'D';

-- the results in select * from suites_retract are:
-- 1,1,suite_1, asset_1,100.0000,130.0000,2024-01-09 ...
-- 1,2,suite_1, asset_2,200.0000,230.0000,2024-01-11 ...
-- 2,3,suite_2, asset_3,300.0000,331.0000,2024-01-12 ...
-- 1,5,suite_1, asset_5,500.0000,550.0000,2024-01-14 ...
-- 2,7,suite_2, asset_7,700.0000,770.0000,2024-01-16 ...

-- build array of rows with the expected results
select 
    suite_id,
    suite_name,
    ARRAY_AGG(ROW (asset_id, asset_name,  ROW(asset_price_min, asset_price_max))) as asset_data, 
    max(ts_ltz) as ts_ltz,
    max(insert_ts_ltz) as insert_ts_ltz 
from suites_retract group by suite_id, suite_name;

-- expected results are:

-- 1,suite_1,[1,asset_1,100.0000,130.0000,3,asset_3,300.0000,331.0000,5,asset_5,500.0000,550.0000,5] ...
-- 2,suite_2,[3,asset_3,300.0000,331.0000,7,asset_7,700.0000,770.0000

