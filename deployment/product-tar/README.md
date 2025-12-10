# Flink and Apache binary

## Apache Flink OSS Update

**Updated 12/2025**

1. See in the release page -> [downloads](https://flink.apache.org/downloads/) the last version.
1. Verify java
    ```sh
    java --version
    ```
    Tested with Java 22.0.2

1. Update the VERSION variable inside the `install-flink-local.sh`
1. Run the install script. It should create a new folder with the new version. Remove old, not needed, version.
1. Start cluster and Flink SQL
    ```sh
    # under deployment/product-tar
    export FLINK_HOME=$(pwd)/flink-2.1.1
    export PATH=$PATH:$FLINK_HOME/bin
    $FLINK_HOME/bin/start-cluster.sh
    ```
1. Verify the processes:
    ```sh
    ps aux | grep flink
    ```
    
1. Update dependants libraries
1. Validate SQL Client
    ```sh
    $FLINK_HOME/bin/sql-client.sh --library $FLINK_HOME/sql-lib
    ```

## Kafka binary

1. See [download page](https://kafka.apache.org/downloads)
1. Update the VERSION variable inside the `install-kafka-local.sh`
1. Set cluster id
    ```sh
    KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
    ```
1. Format logs directory
    ```sh
    bin/kafka-storage.sh format --standalone -t $KAFKA_CLUSTER_ID -c config/server.properties
    ```
1. Start the Kafka server:
    ```sh
    bin/kafka-server-start.sh config/server.properties
    ```