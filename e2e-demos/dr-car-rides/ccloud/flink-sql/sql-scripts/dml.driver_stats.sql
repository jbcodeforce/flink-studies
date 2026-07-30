-- Stage 2: event-time tumble by driver → driver_stats
INSERT INTO driver_stats
SELECT
    driver_id,
    window_start,
    window_end,
    COUNT(*) AS ride_count,
    SUM(fare_usd) AS fare_sum,
    MAX(seq) AS max_seq
FROM TABLE(
    TUMBLE(TABLE rides_clean, DESCRIPTOR(pickup_ts), INTERVAL '1' MINUTE)
)
GROUP BY driver_id, window_start, window_end;
