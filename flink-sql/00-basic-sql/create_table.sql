CREATE TABLE IF NOT EXISTS employes (
    id INT,
    name VARCHAR, 
    dept_id INT
) WITH ( 
    'connector' = 'filesystem',
    'path' = '/home/flink-sql/data/employes.csv',
    'format' = 'csv'
);