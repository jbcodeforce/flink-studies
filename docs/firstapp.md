# Getting started

## First app

Each Flink app is a [Java main function which defines the data flow to execute on a stream](https://ci.apache.org/projects/flink/flink-docs-release-1.13/dev/datastream_api.html#anatomy-of-a-flink-program). 

Once we build the application jar file, we use Flink CLI to send the jar as a job to the Job manager server. 
During development, we can use docker-compose to start a simple `Flink session` cluster or use a docker compose which
 starts a standalone job manager to execute one unique job, which has the application jar mounted inside the docker image.

* Start Flink session cluster using the following command: 

  ```shell
  # under this repository folder
  docker-compose up -d
  ```

  The docker compose mounts the local folder to `/home` in both the job manager and task manager containers 
so that, we can submit the job from the job manager (accessing the compiled jar) and also access the input data files in the task manager container.

* Create a Quarkus app: `mvn io.quarkus:quarkus-maven-plugin:1.13.3.Final:create -DprojectGroupId=jbcodeforce -DprojectArtifactId=my-flink`

* Add the following [maven dependencies](https://mvnrepository.com/artifact/org.apache.flink) into pom.xml

```xml
<!-- https://mvnrepository.com/artifact/org.apache.flink/flink-java -->
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-java</artifactId>
    <version>1.14.4</version>
</dependency>
<dependency>
    <groupId>org.apache.flink</groupId>
    <artifactId>flink-streaming-java_2.12</artifactId>
    <version>1.14.4</version>
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

The code above uses the [ParameterTool  class](https://ci.apache.org/projects/flink/flink-docs-stable/api/java/org/apache/flink/api/java/utils/ParameterTool.html) to process the program arguments. 
So most of the basic examples use `--input filename` and `--output filename` as java arguments. So `params` will have those arguments in a Map. 

* Be sure to set quarkus uber-jar generation (`quarkus.package.type=uber-jar`) in the `application.properties` to get all the dependencies in a unique jar: Flink needs all dependencies in classpath.
* Package the jar with `mvn package`
* Every Flink application needs a reference to the execution environment (variable `env` in previous example). 
* To submit a job to a Session cluster, use the following commands which use the `flink` cli inside the running container:

```shell
# One way with mounted files to task manager and job manager containers.
CNAME="jbcodeforce.p1.WordCountMain"
JMC=$(docker ps --filter name=jobmanager --format={{.ID}})
docker exec -ti $JMC flink run -d -c $CNAME /home/my-flink/target/my-flink-1.0.0-runner.jar --input file://home/my-flink/data/wc.text --output file://home/data/out.csv 
```

In the execution above, `flink` is a CLI available inside the job-manager container.

See [this coding practice summary](#programming.md) for other dataflow examples.

And the official [operators documentation](https://ci.apache.org/projects/flink/flink-docs-stable/dev/stream/operators/) to understand 
how to transform one or more DataStreams into a new DataStream. Programs can combine multiple transformations into sophisticated 
data flow topologies.

## Unit testing

There are three type of function to test:

* Stateless
* Stateful
* Timed process

### Stateless

For stateless, the data flow can be isolated in static method within the main class, 
or defined within a separate class. The test instantiates the class and provides the data.

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

The test needs to check whether the operator state is updated correctly and if it is cleaned up properly
 along with the output of the operator.
Flink provides TestHarness classes so that we don’t have to create the mock objects.

```java
```

## Example of standalone job docker-compose file

Change the `--job-classname` parameter of the standalone-job command within the docker-compose file:

```yaml
version: "2.2"
services:
  jobmanager:
    image: flink:1.14.4-scala_2.11
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
    image: flink:1.14.4-scala_2.11
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
