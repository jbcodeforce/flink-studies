create table grouped_user  (
    id int,
    group_id int,
    salt_id int,
    name string,
    email string,
    group_name string,
    created_at timestamp,
    primary key (id, group_id, salt_id) not enforced
) DISTRIBUTED BY HASH(id,group_id, salt_id) INTO 3 BUCKETS WITH (
 'changelog.mode' = 'upsert',
    'connector' = 'confluent',
    'kafka.compaction.time' = '0 ms',
    'kafka.max-message-size' = '2097164 bytes',
    'scan.bounded.mode' = 'unbounded',
    'scan.startup.mode' = 'earliest-offset',
    'value.fields-include' = 'all',
    'value.format' = 'avro-registry'
)
as 
select 
    u.*,
    g.group_name
from users_salted u
join groups_salted g on u.group_id = g.id and u.salt_id = g.salt_id