# Some Table API using Confluent Cloud

Based on this repository: [flink-table-api-java-examples](https://github.com/confluentinc/flink-table-api-java-examples) and [this tutorial]()

## Using java and environment variables 

* configure the .env with the needed environments variables and do a `source .env`

    ```
    export CLOUD_PROVIDER="aws"
    export CLOUD_REGION="us-east-1"
    export FLINK_API_KEY="key"
    export FLINK_API_SECRET="secret"
    export ORG_ID="b0b21724-4586-4a07-b787-d0bb5aacbf87"
    export ENV_ID="env-z3y2x1"
    export COMPUTE_POOL_ID="lfcp-8m03rm"
    ```

* Compile with `mvn clean package`
* Start one of the main from the built jar

    ```sh
    java -cp target/table-api-1.0.0.jar flink.examples.table.Main_00_JoinOrderCustomer
    ```

## Using Jshell

Using the Java Shell, we can write Table API Java code to interact with Flink:

```sh
jshell --class-path ./target/table-api-1.0.0.jar  --startup ./jshell-init.jsh
```

The TableEnvironment is pre-initialized from environment variables and accessible by using `env`:

```java
env.useCatalog("examples");
env.executeSql("SHOW DATABASES").print();
```

Recall the commands of `/help` and `/exit` for JShell.