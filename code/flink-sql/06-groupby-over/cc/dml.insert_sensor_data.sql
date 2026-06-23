insert into d06_sensor_data values (
    1,  -- device_id
    TIMESTAMP '2024-06-01 10:00:00.000',
    10,  -- X
    10,  -- Y
    100,  -- val
    180  -- angle
), (
    2,
    TIMESTAMP '2024-06-01 10:00:01.000',
    10,
    10,
    100,
    170
), (
    1,
    TIMESTAMP '2024-06-01 10:00:02.000',
    12,
    20,
    110,  -- val
    160  -- angle
), (
    1,
    TIMESTAMP '2024-06-01 10:00:03.000',
    CAST(NULL AS INT)   ,
    CAST(NULL AS INT),
    CAST(NULL AS DOUBLE),
    CAST(NULL AS INT)
);