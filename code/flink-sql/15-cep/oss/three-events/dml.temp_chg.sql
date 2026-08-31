SELECT
  sensor_id,
  A.temperature AS first_temp,
  A.ts AS first_ts,
  B.temperature AS middle_temp,
  B.ts AS middle_ts,
  C.temperature AS last_temp,
  C.ts AS last_ts
FROM temperature_readings
MATCH_RECOGNIZE (
  PARTITION BY sensor_id
  ORDER BY ts

  MEASURES
    A.temperature AS first_temp,
    A.ts AS first_ts,
    B.temperature AS middle_temp,
    B.ts AS middle_ts,
    C.temperature AS last_temp,
    C.ts AS last_ts

  ONE ROW PER MATCH
  AFTER MATCH SKIP PAST LAST ROW

  PATTERN (A B C)

  DEFINE
    A AS A.temperature > 51,
    B AS B.temperature < 51,
    C AS C.temperature > 51
) AS MR;