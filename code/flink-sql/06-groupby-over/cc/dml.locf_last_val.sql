INSERT INTO d06_locf_last_val
WITH LatestSensorData AS (
    SELECT
        device_id,
        LAST_VALUE(X) OVER w AS last_X,
        LAST_VALUE(Y) OVER w AS last_Y,
        LAST_VALUE(angle) OVER w AS last_angle,
        val,
        -- Extracts the latest val chronologically per partition group
        LAST_VALUE(val) OVER w AS last_val
    FROM d06_sensor_data
    WINDOW w AS (
    PARTITION BY device_id
    ORDER BY ts
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )
)
-- Step 2: Compute the maximum of those latest values
SELECT
    device_id,
    MAX(last_X) AS max_last_X,
    MAX(last_Y) AS max_last_Y,
    MAX(last_angle) AS max_last_angle,
    MAX(last_val) AS max_of_last_values
FROM LatestSensorData
GROUP BY device_id;