create table src_groups 
(
    id int primary key not enforced,
    group_name string,
    created_at timestamp
) distributed by (id) into 1 buckets with (
    'changelog.mode' = 'append',
    'connector' = 'confluent',
    'kafka.compaction.time' = '0 ms',
    'kafka.max-message-size' = '2097164 bytes',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all',
    'value.format' = 'avro-registry'
) as select * from (

insert into src_groups (id, group_name, created_at) values 
(1, 'Group 1', TO_TIMESTAMP('2021-01-01 00:00:00')),
(2, 'Group 2', TO_TIMESTAMP('2021-01-01 00:00:00')),
(3, 'Group 3', TO_TIMESTAMP('2021-01-01 00:00:00')),
(4, 'Group 4', TO_TIMESTAMP('2021-01-01 00:00:00')),
(5, 'Group 5', TO_TIMESTAMP('2021-01-01 00:00:00'));