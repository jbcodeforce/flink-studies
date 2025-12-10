# Flink SQL Puzzles

This set of Flink SQLs presents some interesting puzzles.

## Test environment
To prepare the environment of the following puzzles use Flink binary or Kubernetes deployment.


```sh
# under deployment/product-tar
export FLINK_HOME=$(pwd)/flink-2.1.0
export PATH=$PATH:$FLINK_HOME/bin
$FLINK_HOME/bin/start-cluster.sh
$FLINK_HOME/bin/sql-client.sh --library $FLINK_HOME/sql-lib
```

## Find the highest transaction amount every day

Using the `e2e-demos/cdc-demo/datasets/transactions.csv`, generate the highest transaction amount per day. 

The approach: use the transaction_date as a timestamp to apply time tumble window logic.

* Create a source table for transactions: see the `create_tx_table.sql`. The important parts of the SQL, are the primary key not enforced, the date to be a string, and the loading of the csv file
    ```sql
    CREATE TABLE IF NOT EXISTS transactions (
            transaction_id VARCHAR(255) PRIMARY KEY NOT ENFORCED,
            customer_id VARCHAR(255),
            transaction_date VARCHAR(30)
            ---
    ) with (
          'connector' = 'filesystem',
          'path' = '../../e2e-demos/cdc-demo/datasets/transactions.csv',
          'format' = 'csv'
       );
    ```
* Create the loans table with `create_loans_table.sql`
* Verify data quality, like the number of different transaction type:
    ```sql
    select transaction_type, count(*) as num_tx_type from transactions group by transaction_type;
    ```

    Should get:
    ```
    transaction_type               num_tx_type
        Credit Card                 5007
            Debit Card              5088
        Bill Payment                4975
    Loan Disbursement               5056
            Deposit                 4966
                UPI                 4919
        Net Banking                 4891
        ATM Withdrawal              5042
        Fund Transfer               5025
        EMI Payment                 5031
    ```

    The number of distinct customer_id
    ```sql
    select  count(distinct customer_id) as num_cid from transactions;
    ```

* In most data pipeline there are set of data validation to be done to prepare the data to reach gold level quality, easily used for machine learning or dashboard. The transaction and loan-applications to assess fraud is part of [Kaggle dataset and with example of notebook](https://www.kaggle.com/code/prajwaldongre/fraud-detection-and-risk-assesment-model). From this notebook it is interesting to consider what could be done earler in the data pipeline, as soon as the data is created or shared within a messaging platform.

* Need to transform the date into a timestamp and use it as the record time stamp