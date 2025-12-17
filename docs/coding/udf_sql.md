# User Defined Functions

[User-defined functions (UDFs)](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/functions/udfs/) are extension to Flink SQL and Table API for frequently used logic and custom integration. It can be written in Java or PyFlink.

If an operation cannot be expressed directly using Flink's standard SQL syntax or [built-in](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/table/functions/systemfunctions/) functions (e.g., integrating a third-party library, implementing a proprietary business logic, or performing a complex machine learning inference), a UDF provides the necessary capability to execute that custom code within the stream or batch job.

Developers can leverage ny existing libraries like Geospatial calculation, Math computation, to implement the UDF.

## Four Types of UDF

| UDF Type | Description |Input to Output Mapping| Example Use Case|
|----------|-------------|-----------------------|-----------------|
| Scalar Function| Maps a set of scalar input values to a single, new scalar output value. | 1 row -> 1 row | Formatting a string, calculating an encryption key.|
| Table Function  | Maps a set of scalar input values to one or more rows (a new table). | 1 row -> N rows | Splitting a single column into multiple rows.|
| Aggregate Function| Maps the values of multiple input rows to a single scalar aggregate value.| N rows -> 1 row | Calculating a custom weighted average or variance.|
| Table Aggregate Function | Maps the values of multiple input rows to multiple output rows. | N rows -> M rows | Calculating a running "top-N" list for each group. |

## Implementation approach

For developer the steps are:

1. Develop a Class to extends a `org.apache.flink.table.functions.ScalarFunction` or `org.apache.flink.table.functions.TableFunction`
1. Implement one of the eval function
1. Add constructor with empty parameters and more constructors if needed
1. Prefer specifying the parameter types and function return type, specially for TableFunction
1. Build a uber jar
1. Deploy to Confluent Cloud or into the lib folder of CP Flink Application or into the lib folder of the OSS Flink distribution.

On Confluent Cloud, be sure to use log4j to get function logs and wrap code into try .. .catch. [See log debug messages documentation.](https://docs.confluent.io/cloud/current/flink/how-to-guides/enable-udf-logging.html)

### Iterate on UDF development

In some case we need to iterate on the deployment of new UDF version. It is possible to deploy UDF with different version.

* Need to drop the function:
    ```sh
    drop function USERS_IN_GROUPS
    ```
* Delete the artifacts
* Upload the new jar as new artifact
* Then recreate it with the new artifact id

### Examples 

* [See this repository to get a set of reusable UDFs](https://github.com/jbcodeforce/flink-udfs-catalog) implemented as solution for generic problems asked by our customers.
* See also the [Confluent documentation on UDF](https://docs.confluent.io/cloud/current/flink/how-to-guides/create-udf.html#flink-sql-create-udf) and a [Confluent git repo](https://github.com/confluentinc/flink-udf-java-examples) with some sample UDFs.


### Table API examples

* [Confluent Flink table api example with UDF.](https://github.com/confluentinc/flink-table-api-java-examples/blob/master/src/main/java/io/confluent/flink/examples/table/Example_09_Functions.java)

### Extending base APIs

#### Scalar function

Scalar function generates a unique value.

[The product documentation](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/functions/udfs/#scalar-functions) has all the details.

Use AsyncScalarFunction when interacting with external systems. Use thread pools, initialized in constructor, to manage connection multiplexing.


#### Table function

Table function returns an arbitrary number of rows (or structured types) as output. Single scalar value can be emitted and will be implicitly wrapped into a row by the runtime.

```java
import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.annotation.FunctionHint;

@FunctionHint(output = @DataTypeHint("ROW<word STRING, length INT>"))
public static class SplitFunction extends TableFunction<Row> {

    public void eval(String str) {...
```

[See details in the product documentation](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/functions/udfs/#table-functions).

AsyncTableFunction should be used to generate n rows when integrating with external systems.

The function is used with SQL,using the `LATERAL TABLE(<TableFunction>) with JOIN or LEFT JOIN` with an ON TRUE join condition.

#### Aggregate Function

Aggregate user defined function, maps scalar values of multiple rows to a new scalar value, using accumulator. The accumulator is an intermediate data structure that stores the aggregated values until a final aggregation result is computed. 

The `accumulate()` method is called for each input row to update the accumulator.

[For more detail, see the product documentation](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/functions/udfs/#aggregate-functions).


#### Deeper considerations

* Scalar UDFs in the Table API/SQL are generally expected to be stateless


### Deploying to Confluent Cloud

* Get FlinkDeveloper RBAC to be able to manage workspaces and artifacts
* Use the Confluent CLI to upload the jar file. Example from GEO_DISTANCE:
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

* UDFs are registered inside a Flink database. It may take some time.
    ```sql
    CREATE FUNCTION GEO_DISTANCE
    AS
    'io.confluent.udf.GeoDistanceFunction'
    USING JAR 'confluent-artifact://cfa-...';
    ```


* Use the function to compute distance between Paris and London:
    ![](./images/udf_in_sql.png)

### Runtime explanation

* UDF invocations are batched (may wait up to 500ms), the runtime tries to accumulate several records before it calls them. 
* In Confluent Cloud the UDFs actually run in a separate pod for security isolation, which increases the consumption.
