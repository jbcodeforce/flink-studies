# [Apache Iceberg](https://iceberg.apache.org/docs/latest/)

Apache Iceberg is an open table format for huge analytic datasets. It becomes a specifications and a set of libraries to standardize how to represent a table as a set of metadata and data files. The libraries support a protocol to manipulate theses file safely.

* It adds tables to compute engines such as Spark, Trino, PrestoDB, Flink, Hive and Impala.
* It works just like a SQL table on cloud object storage.
* Iceberg solves correctness problems in eventually-consistent cloud object stores.
* It supports ten of petabytes of data, with potentials schema changes: column add, drop, rename, update, reorder, and certain data types upgrades.
* It supports 'time travel' to go back to older version of the data.

    ```sql
    SELECT * FROM iceberg_taxi_parquet
    FOR SYSTEM_TIME AS OF (current_timestamp — interval ‘1’ hour)
    ```

Iceberg has several catalog back-ends that can be used to track tables, like JDBC, Hive MetaStore and Amazon Glue.

There’re 3 layers for Iceberg:

1. **Catalog** layer: Hive or Path based catalogs. Catalog runs as a service, handles CRUD operations, feeds metadata to the compute engines. It also manages transaction. 
1. **Metadata** layer: Each CRUD operation will generate a new metadata file which contains all the metadata info of table, including the schema of table, all the historical snapshots until now. Each version of snapshot has one manifest list file. Manifest file can be shared cross snapshot files and contains a collection of data files which store the table data.
1. **Data** Layer: parquet files which contain all the historical data, including newly added records, updated record and deleted records.

Catalog becomes the source of truth of th data.

When a table is created, Iceberg creates a directory with the name of the table, and then it creates a metadata folder which contains all the metadata info. 

When records are added to the table, Iceberg creates one parquet file for each record. A new version of metadata file is created with information about a manifest list file (in avro format), which itself points to one manifest file which points to the parquet files

When updating record, Iceberg creates snapshot to keep information of the new manifest file created for the update. The previous record is marked as deleted.
Developers may query the history table of the database main table to see the different snapshots.

### Interresting content

* [Getting started](https://iceberg.apache.org/docs/latest/getting-started/)
* [Icebert and Spark quickstart with local docker compose](https://iceberg.apache.org/spark-quickstart/)
* [PyIceberg](https://py.iceberg.apache.org/)
* [Medium article to use Iceberg with AWS Glue, and Athena.](https://medium.com/snowflake/creating-and-managing-apache-iceberg-tables-using-serverless-features-and-without-coding-14d2198cf5b5)

