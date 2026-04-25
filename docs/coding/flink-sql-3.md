# Materialized Tables

[Materialized Tables](https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/materialized-table/overview/) helps to manage Tables in long term with easier development life cycle than traditional Flink Tables.

It uses the concept of data freshness as the maximum amount of time that the materialized table’s content should lag behind updates to the base tables. The default refreshness is 3 minutes for CONTINUOUS mode and 1 hours for FULL mode.

* With full mode, there is a scheduler that triggers a batch job to refresh the materialized table data. 
* With CONTINUOUS, data freshness is converted into the checkpoint interval of the Flink streaming job.
* Materialized Tables are defined as other Flink tables, with the MATERIALIZED keywords. [See the syntax](https://nightlies.apache.org/flink/flink-docs-release-2.2/docs/dev/table/materialized-table/statements/), and a CTAS structure
    ```sql
    CREATE MATERIALIZED TABLE orders_table
    FRESHNESS = INTERVAL '10' SECOND
    AS SELECT * FROM kafka_catalog.db1.orders;
    ```

* Use ALTER MATERIALIZED TABLE, to suspend and resume refresh pipeline of materialized tables and manually trigger data refreshes, and modify the query definition of materialized tables.
* SUSPEND needs to set the savepoint directory:
    ```sql
    SET 'execution.checkpointing.savepoint-dir' = 'file:///Users/jerome/Documents/Code/flink-studies/code/flink-sql/13-materialized-table/savepoints';

    ALTER MATERIALIZED TABLE continuous_users_shops SUSPEND;
    ```

* It is possible to trigger a refresh:
    ```sql
    ALTER MATERIALIZED TABLE my_materialized_table REFRESH;
    ```
* To modify the query definition, use ALTER... AS. This will change the table schema, and then refresh the data. In FULL mode, not partitioned, the table will be overwritten. With partioning it will refresh the latest partition. With CONTINUOUS, the new refresh job starts from the beginning and does not restore from the previous state.

## Demonstration

* [See 13-meterialized table](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/13-materialized-table)