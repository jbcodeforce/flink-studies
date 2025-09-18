create table user_order_quantity (
    user_id STRING NOT NULL,
    order_quantity INT
) distributed by(user_id) into 1 buckets
with (
    'changelog.mode' = 'retract',
    'value.fields-include' = 'all'
) as
select coalesce(user_id,'NULL') as user_id, sum(quantity) as order_quantity from orders group by user_id;