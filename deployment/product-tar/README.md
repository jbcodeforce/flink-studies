# Apache Flink OSS Update

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



