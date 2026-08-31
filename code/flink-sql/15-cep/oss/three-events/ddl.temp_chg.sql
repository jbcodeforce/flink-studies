CREATE TABLE temperature_readings (
  sensor_id INT,
  temperature DOUBLE,
  ts TIMESTAMP(3),
  WATERMARK FOR ts AS ts
) WITH (
       'changelog.mode': 'append',
        'kafka.cleanup-policy': 'delete',
        'scan.bounded.mode': 'unbounded',
        'scan.startup.mode': 'earliest-offset'
)