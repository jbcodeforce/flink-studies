create view nested_user_clicks as
select
    click_id,
    view_time,
    url,
    CAST((user_id, user_agent) AS ROW<user_id BIGINT, user_agent STRING>) AS user_data,
    `$rowtime`
FROM `examples`.`marketplace`.`clicks`;


-- Example of user_data content: 
-- 3463,Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36