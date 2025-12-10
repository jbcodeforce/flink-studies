create view nested_user_clicks as
select
    click_id,
    view_time,
    url,
    CAST((user_id, user_agent) AS ROW<user_id BIGINT, user_agent STRING>) AS user_data,
    `$rowtime`
FROM `examples`.`marketplace`.`clicks`;
