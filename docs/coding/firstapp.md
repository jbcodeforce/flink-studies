# First Java Applications

???- info "Update"
    Created 2018 Updated 10/2024
    Flink supports Java 11 so Quarkus code needs to be limited to quarkus 3.2.12_Final and maven should compile in JDK 11.
    Use jbang to install jdk 11. WSL ubuntu has OpenJDK 11 and 17.

Each Flink app is a [Java main function which defines the data flow to execute on a stream](https://ci.apache.org/projects/flink/flink-docs-release-1.19/dev/datastream_api.html#anatomy-of-a-flink-program). The structure follows the steps below:

1. Obtain an execution environment,
1. Load/create the initial data,
1. Specify transformations on the data,
1. Specify where to put the results of the computations,
1. Trigger the program execution

Once developers build the application jar file, they use Flink CLI to send the jar as a job to the Job manager server. 

## Create a Java quickstart with maven

[See product documentation which can be summarized as:](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/dev/configuration/overview/)

1. Create squeleton

    ```sh
    curl https://flink.apache.org/q/quickstart.sh | bash -s 1.20.0
    ```

1. Add kafka connector dependencies in pom.xml

    ```xml
        <dependency>
          <groupId>org.apache.flink</groupId>
          <artifactId>flink-connector-kafka</artifactId>
          <version>3.0.0-1.17</version>
        </dependency>
  ```

1. Implement the process logic and the event mapping, filtering logic... We will see more example later.

## Create a Quarkus java app

* Create a Quarkus app: `quarkus create app -DprojectGroupId=jbcodeforce -DprojectArtifactId=my-flink`. See code examples under `my-flink` folder and `jbcodeforce.p1` package.

* Add the following [maven dependencies](https://mvnrepository.com/artifact/org.apache.flink) into the `pom.xml`

```xml
<!-- https://mvnrepository.com/artifact/org.apache.flink/flink-java -->
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-java</artifactId>
    <version>${flink-version}</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-streaming-java</artifactId>
    <version>${flink-version}</version>
    <scope>provided</scope>
</dependency>
```

* Create a Java Class with a main function and the following code structure:

    * get Flink execution context
    * defined process flow to apply to the data stream
    * start the execution

```java
// Get execution context
  ExecutionEnvironment env = ExecutionEnvironment.getExecutionEnvironment();
  // use file as input so use program arguments to get file name
  ParameterTool params = ParameterTool.fromArgs(args);
  env.getConfig().setGlobalJobParameters(params);
  // Define data flow processing...

  env.execute();
```

The code above uses the [ParameterTool  class](https://ci.apache.org/projects/flink/flink-docs-stable/api/java/org/apache/flink/api/java/utils/ParameterTool.html) to process the program arguments. 
So most of the basic examples use `--input filename` and `--output filename` as java arguments. So `params` will have those arguments in a Map. 

* Be sure to set quarkus uber-jar generation (`quarkus.package.type=uber-jar`) in the `application.properties` to get all the dependencies in a unique jar: Flink needs all dependencies in the classpath.
* Package the jar with `mvn package`
* Every Flink application needs a reference to the execution environment (variable `env` in previous example). 

## Submit job to Flink

* Start a job manager and task manager with the docker compose under `deployment/local` folder.
* To submit a job to a Session cluster, use the following command which uses the `flink` cli inside the running `JobManager` container:

```shell
# One way with mounted files to task manager and job manager containers.
CNAME="jbcodeforce.p1.WordCountMain"
JMC=$(docker ps --filter name=jobmanager --format={{.ID}})
docker exec -ti $JMC flink run -d -c $CNAME /home/my-flink/target/my-flink-1.0.0-runner.jar --input file:///home/my-flink/data/wc.txt --output file:///home/my-flink/data/out.csv 

# inside the jobmanager
flink run -d -c jbcodeforce.p1.WordCountMain /home/my-flink/target/my-flink-
1.0.0-runner.jar --input file:///home/my-flink/data/wc.txt --output file:///home/my-flink/data/out.csv
```

See [the coding practice summary](./programming.md) for other dataflow examples.

And the official [operators documentation](https://ci.apache.org/projects/flink/flink-docs-stable/dev/stream/operators/) to understand how to transform one or more DataStreams into a new DataStream. Programs can combine multiple transformations into sophisticated data flow topologies.

## Unit testing

There are three type of function to test:

* Stateless
* Stateful
* Timed process

### Stateless

For stateless, the data flow can be isolated in static method within the main class, or defined within a separate class. The test instantiates the class and provides the data.

For example testing a string to a tuple mapping (MapTrip() is a MapFunction(...) extension):

```java
 public void testMapToTuple() throws Exception {
        MapTrip mapFunction = new MapTrip();
        Tuple5<String,String,String, Boolean, Integer> t = mapFunction.map("id_4214,PB7526,Sedan,Wanda,yes,Sector 19,Sector 10,5");
        assertEquals("Wanda",t.f0);
        assertEquals("Sector 19",t.f1);
        assertEquals("Sector 10",t.f2);
        assertTrue(t.f3);
        assertEquals(5,t.f4);
    }
```

### Stateful

The test needs to check whether the operator state is updated correctly and if it is cleaned up properly, along with the output of the operator. Flink provides TestHarness classes so that we don’t have to create the mock objects.

```java
```

## Example of standalone job docker-compose file

Change the `--job-classname` parameter of the standalone-job command within the docker-compose file:

```yaml
version: "2.2"
services:
  jobmanager:
    image: flink:latest
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
    image: flink:latest
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
