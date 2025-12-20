 CREATE TABLE IF NOT EXISTS transactions (
            transaction_id VARCHAR(255) PRIMARY KEY NOT ENFORCED,
            customer_id VARCHAR(255),
            transaction_date VARCHAR(30),
            transaction_type VARCHAR(255),
            transaction_amount FLOAT,
            merchant_category VARCHAR(255),
            merchant_name VARCHAR(255),
            transaction_location VARCHAR(255),
            account_balance_after_transaction FLOAT,
            is_international_transaction BOOLEAN,
            device_used VARCHAR(255),
            ip_address VARCHAR(255),
            transaction_status VARCHAR(255),
            transaction_source_destination VARCHAR(255),
            transaction_notes VARCHAR(3000),
            fraud_flag BOOLEAN
       ) with (
          'connector' = 'filesystem',
          'path' = '../../e2e-demos/cdc-demo/datasets/transactions.csv',
          'format' = 'csv'
       );