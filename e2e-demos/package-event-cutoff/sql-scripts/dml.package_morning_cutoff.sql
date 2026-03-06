insert into  enhanced_package_events 
with proactive_events as (
  SELECT
    e.package_id,
    c.cutoff_ts as event_ts,
    e.status,
    e.expected_ts,
    'proactive_no_event' as event_type,
    e.payload
  FROM package_events e
  left JOIN cutoff_triggers c
    ON  e.event_ts BETWEEN c.cutoff_ts - INTERVAL '24' HOUR AND c.cutoff_ts - INTERVAL '2' hour
),
dedup_proactive_events as (
 SELECT package_id, event_ts, status, expected_ts, event_type, payload
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY package_id
        ORDER BY event_ts DESC
      ) AS row_num
    FROM proactive_events
  )
  where row_num = 1
 )
select * from dedup_proactive_events
union all
select * from last_expected_ts_package_events

