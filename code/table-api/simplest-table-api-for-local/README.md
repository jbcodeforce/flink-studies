# Simplest Table Api program for Local run

The simplest way to test your local Flink environment using the Table API is to execute a basic job that creates an in-memory table and prints its contents.

The approach is to

1. Creates a TableEnvironment in streaming mode.
1. Creates a simple in-memory Table from a collection of values.
1. Filters the table to demonstrate a simple transformation.
1. Prints the result using execute().print().

## Build

```sh
mvn package
```

## Execution

### Run local Session Job

* Start cluster (from `<repo>/deployment/product-tar/flink-2.1.0`)
    ```sh
    ./bin/start-cluster.sh
    ```

* Submit the JAR to Flink's JobManager in Session mode
    ```sh
    ./bin/flink run <repo>/code/table-api/simplest-table-api-for-local/target/simplest-table-api-for-local-1.0.0.jar
    ```

* Stop the cluster
    ```sh
    ./bin/stop-cluster.sh
    ```

### Application mode

* Still start the cluster to get access to the Flink UI
* Copy the application jar into the Flink `lib` folder
    ```sh
    cp <repo>/code/table-api/simplest-table-api-for-local/target/simplest-table-api-for-local-1.0.0.jar lib
    ```

* we can launch one JobManager:
    ```sh
    ./bin/standalone-job.sh start --job-classname j9r.SimpleTableTest
    ```
    
* And at least one task manager to get the job executed
    ```sh
    ./bin/taskmanager.sh start
    ```

* Stop all:
    ```sh
    ./bin/taskmanager.sh stop
    ./bin/standalone-job.sh stop
    ```