# Getting started

???- info "Update"
    Created 2018 Updated 08/2024
    Flink supports Java 11 so Quarkus code needs to be limited to quarkus 3.2.12_Final and maven should compile in JDK 11.
    Use jbang to install jdk 11. WSL ubuntu has OpenJDK 11 and 17.

## First app

Each Flink app is a [Java main function which defines the data flow to execute on a stream](https://ci.apache.org/projects/flink/flink-docs-release-1.19/dev/datastream_api.html#anatomy-of-a-flink-program). The structure follows the steps below:

1. Obtain an execution environment,
1. Load/create the initial data,
1. Specify transformations on the data,
1. Specify where to put the results of the computations,
1. Trigger the program execution


Once developers build the application jar file, they use Flink CLI to send the jar as a job to the Job manager server. 

### Docker compose for dev environment

During development, we can use docker-compose to start a simple `Flink session` cluster or a standalone job manager to execute one unique job, which has the application jar mounted inside the docker image.

* Start Flink session cluster using the following command: 

  ```shell
  # under this repository folder
  docker compose up -d
  ```

The docker compose looks like:

```yaml
version: "3.8"
services:
  jobmanager:
    image: flink:latest
    hostname: jobmanager
    ports:
      - "8081:8081"
    command: jobmanager
    environment:
      FLINK_PROPERTIES: "jobmanager.rpc.address: jobmanager"
    volumes:  
        - .:/home
  taskmanager:
    image: flink:latest 
    hostname: taskmanager
    depends_on:
      - jobmanager
    command: taskmanager
    scale: 2
    volumes:
        - .:/home
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        taskmanager.numberOfTaskSlots: 4
```

The docker compose mounts the local folder to `/home` in both the job manager and task manager containers so that, we can submit the job from the job manager (accessing the compiled jar) and also access the input data files in the task manager container.

### Create a java app

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

### Submit job to Flink

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

In the execution above, `flink` is a CLI available inside the job-manager container.

See [the coding practice summary](./programming.md) for other dataflow examples.

And the official [operators documentation](https://ci.apache.org/projects/flink/flink-docs-stable/dev/stream/operators/) to understand how to transform one or more DataStreams into a new DataStream. Programs can combine multiple transformations into sophisticated data flow topologies.

## SQL Client

Build the image within the sql-client folder using the dockerfile. Modify the flink version as needed.

```shell
#under sql-client folder
docker build -t jbcodeforce/flink-sql-client .
```

Then to interact with Flink using the SQL client open a bash in the running container

```sh
docker exec -ti sql-client bash
# in the shell
./sql-client.sh
```

Then use CLI commands. ([See documentation for sqlclient](https://nightlies.apache.org/flink/flink-docs-release-1.19/docs/dev/table/sqlclient/)).

See [this folder](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demo/basic-sql) to get some simple examples.

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

The test needs to check whether the operator state is updated correctly and if it is cleaned up properly,
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
