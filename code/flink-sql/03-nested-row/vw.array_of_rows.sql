CREATE VIEW page_views_1m AS
SELECT 
  window_time, 
  url,
  ARRAY_AGG(CAST((user_id, view_time, $rowtime) AS ROW<user_id INT, view_time INT, viewed_at TIMESTAMP_LTZ(3)>)) AS page_views
FROM TABLE(TUMBLE(TABLE `examples`.`marketplace`.`clicks`, DESCRIPTOR(`$rowtime`), INTERVAL '1' MINUTE))
GROUP BY window_start, window_end, window_time, url;