# User Defined Functions

[User-defined functions (UDFs)](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/functions/udfs/) are extension to Flink SQL and Table API for frequently used logic and custom program and integration. It can be written in Java or PyFlink.

If an operation cannot be expressed directly using Flink's standard SQL syntax or built-in functions (e.g., integrating a third-party library, implementing a proprietary business logic, or performing a complex machine learning inference), a UDF provides the necessary capability to execute that custom code within the stream or batch job

Developers can leverage existing libraries like Geospatial calculation, Math computation... 

## Four Types of UDF

| UDF Type | Description |Input to Output Mapping| Example Use Case|
|----------|-------------|-----------------------|-----------------|
| Scalar Function| Maps a set of scalar input values to a single, new scalar output value. | 1 row -> 1 row | Formatting a string, calculating an encryption key.|
| Table Function  | Maps a set of scalar input values to one or more rows (a new table). | 1 row -> N rows | Splitting a single column into multiple rows.|
| Aggregate Function| Maps the values of multiple input rows to a single scalar aggregate value.| N rows -> 1 row | Calculating a custom weighted average or variance.|
| Table Aggregate Function | Maps the values of multiple input rows to multiple output rows. | N rows -> M rows | Calculating a running "top-N" list for each group. |

For developer the steps are:

1. Develop a functin to extends a `org.apache.flink.table.functions.ScalarFunction` or `TableFunction`
1. Build a uber jar
1. Deploy to Confluent Cloud or in the lib folder of CP Flink Application or in the lib OSS Flink.


[See this repository as a set of reusable UDFs](https://github.com/jbcodeforce/flink-udfs-catalog).

See also the [Confluent documentation on UDF](https://docs.confluent.io/cloud/current/flink/how-to-guides/create-udf.html#flink-sql-create-udf) and a [Confluent git repo](https://github.com/confluentinc/flink-udf-java-examples) with a sample UDF.

## UDF Catalog

This repository includes the following UDFs:

* [Geo Distance](https://github.com/jbcodeforce/flink-udfs-catalog/tree/main/geo_distance) using the Haversine formula to compute distance between two points on earth. It requires the latitude and longitude of the two points.

## Deploying to Confluent Cloud

* Get FlinkDeveloper RBAC to be able to manage workspaces and artifacts
* Use the Confluent CLI to upload the jar file. Example from GEO_DISTANCE
    ```sh
    confluent environment list
    # then in your environment
    confluent flink artifact create geo_distance --artifact-file target/geo-distance-udf-1.0-0.jar --cloud aws --region us-west-2 --environment env-nk...
    ```

    ```sh
    +--------------------+--------------+
    | ID                 | cfa-nx6wjz   |
    | Name               | geo_distance |
    | Version            | ver-nxnnnd   |
    | Cloud              | aws          |
    | Region             | us-west-2    |
    | Environment        | env-nknqp3   |
    | Content Format     | JAR          |
    | Description        |              |
    | Documentation Link |              |
    +--------------------+--------------+
    ```

    Also visible in the Artifacts menu
    ![](./images/udf_artifacts.png)

* UDFs are registered inside a Flink database
    ```sql
    CREATE FUNCTION GEO_DISTANCE
    AS
    'io.confluent.udf.GeoDistanceFunction'
    USING JAR 'confluent-artifact://cfa-...';
    ```
* Use the function to compute distance between Paris and London:
    ![](./images/udf_in_sql.png)