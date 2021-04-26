# Getting started


## First app

Each Flink app goal is to develop a [Java main function which defined the data flow to execute on a stream](https://ci.apache.org/projects/flink/flink-docs-release-1.12/dev/datastream_api.html#anatomy-of-a-flink-program). Build a jar and then send the jar as a job to the Job manager. For development we can use docker-compose to start a simple Flink session cluster or use a docker compose that starts a standalone job manager to execute one unique job, which has the application jar mounted inside the docker image.

* Start Flink session cluster using the following command: 

  ```shell
  docker-compose up -d
  ```

  The docker compose mounts the local folder to `/home` in both the job manager and task manager containers so we can submit the job from the job manager (accessing the compiled jar) and access the data files in the task manager container.

* Create a Quarkus app: `mvn io.quarkus:quarkus-maven-plugin:1.13.2.Final:create -DprojectGroupId=jbcodeforce -DprojectArtifactId=my-flink`

* Add the following [maven dependencies](https://mvnrepository.com/artifact/org.apache.flink) into pom.xml

```xml
<!-- https://mvnrepository.com/artifact/org.apache.flink/flink-java -->
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-java</artifactId>
    <version>1.12.0</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-streaming-java_2.12</artifactId>
    <version>1.12.0</version>
    <scope>provided</scope>
</dependency>
```

* Build the main function with the following code structure:

    * get Flink execution context
    * defined process flow to apply to the stream
    * start the execution

```java
// Get execution context
  ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();
  ParameterTool params = ParameterTool.fromArgs(args);
  env.getConfig().setGlobalJobParameters(params);
  // Define data flow processing...

  env.execute();
```

The code above uses the [ParameterTool  class](https://ci.apache.org/projects/flink/flink-docs-stable/api/java/org/apache/flink/api/java/utils/ParameterTool.html) to process the program arguments. So most of the basic examples use `--input filename` and `--output filename` as java arguments. So `params` will have those arguments in a Map. 

* Be sure to set uber-jar generation (`quarkus.package.type=uber-jar`) in the `application.properties` to get all the dependencies in the jar sent to Flink.
* package the jar with `mvn package`
* Every Flink application needs an execution environment, `env` in previous example. To submit a job to a Session cluste,r use the following commands:

```shell
# One way with mounted files to task manager and job manager containers.
CNAME="jbcodeforce.p1.WordCountMain"
JMC=$(docker ps --filter name=jobmanager --format={{.ID}})
docker exec -ti $JMC flink run -d -c $CNAME /home/my-flink/target/my-flink-1.0.0-runner.jar --input file://home/my-flink/data/wc.text --output file://home/data/out.csv 
```

In previous execution, `flink` is a CLI available inside the job-manager container.

The file needs to be accessible from the Task manager container: so mounting the same filesystem to both containers, helps to access the jar for the java class and the potential files to be used to process the data.

See [this coding note](#programming.md) for other dataflow examples.

And the official [Operators documentation](https://ci.apache.org/projects/flink/flink-docs-stable/dev/stream/operators/) to understand how to transform one or more DataStreams into a new DataStream. Programs can combine multiple transformations into sophisticated data flow topologies.

## Unit testing

The data flow can be isolated in a static method within the main class, and then we can use elements on the data streams to populate with expected test data.

```java
```

## Example of standalone job docker-compose file

Change the `--job-classname` parameter of the standalone-job command within the docker-compose file:

```yaml
version: "2.2"
services:
  jobmanager:
    image: flink:1.12.2-scala_2.11
    ports:
      - "8081:8081"
    command: standalone-job --job-classname com.job.ClassName [--job-id <job id>] [--fromSavepoint /path/to/savepoint [--allowNonRestoredState]] [job arguments]
    volumes:
      - /host/path/to/job/artifacts:/opt/flink/usrlib
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        parallelism.default: 2

  taskmanager:
    image: flink:1.12.2-scala_2.11
    depends_on:
      - jobmanager
    command: taskmanager
    scale: 1
    volumes:
      - /host/path/to/job/artifacts:/opt/flink/usrlib
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        taskmanager.numberOfTaskSlots: 2
        parallelism.default: 2
```
