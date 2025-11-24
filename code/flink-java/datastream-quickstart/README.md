# The simplest Datastream v2 program

## Build and submit the job

* Build the jar
    ```sh
    mvn clean package
    ```
* Start the cluster: under `$FLINK_HOME/bin/start_cluster.sh`
* Submit the job
    ```sh
    flink run -c org.myorg.quickstart.NumberMapJob $CODE/flink-studies/code/flink-java/datastream-quickstart/target/datastream-quickstart-0.1.jar
    ```
* Access the Web UI: [http://localhost:8081/#/overview](http://localhost:8081/#/overview)
* Look at the sink output:
    ```sh
    cat log/flink-jerome-taskexecutor-0-MF6D5JVQF2.out
    ```

## Approach

See [The datastream summary note](https://jbcodeforce.github.io/flink-studies/coding/datastream/)