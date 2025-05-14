# Flink Getting Started Guide

???- info "Updates"
    * Created 2018 
    * Updated 2/14/2025 - improve note, on k8s deployment and get simple demo reference, review done. 
    * 03/30/25: converged the notes and update referenced links

This guide covers four different approaches to deploy and run Apache Flink:

1. Local Binary Installation
2. Docker-based Deployment
3. Kubernetes Deployment: Colima or minicube
4. Confluent Cloud Managed Service

## Prerequisites

Before getting started, ensure you have:

1. [Java 11 or higher installed (OpenJDK)](https://openjdk.org/)
2. Docker Engine and Docker CLI (for Docker and Kubernetes deployments)
3. [kubectl](https://kubernetes.io/docs/tasks/tools/) and [Helm](https://jbcodeforce.github.io/coding/helm) (for Kubernetes deployment)
4. [Confluent Cloud](https://login.confluent.io/) account (for Confluent Cloud deployment)
5. Git (to clone this repository)
6. [Confluent cli installed](https://docs.confluent.io/confluent-cli/current/install.html)

## 1. Local Binary Installation

This approach is ideal for development and testing on a single machine.

### Installation Steps

1. Download and extract Flink binary
   ```sh
   # Using the provided script
   ./deployment/product-tar/install-local.sh
   
   # Or manually
   curl https://dlcdn.apache.org/flink/flink-1.20.1/flink-1.20.1-bin-scala_2.12.tgz --output flink-1.20.1-bin-scala_2.12.tgz
   tar -xzf flink-1.20.1-bin-scala_2.12.tgz
   ```
1. Download and extract Kafka binary [See download versions](https://downloads.apache.org/kafka) 
   ```sh
   curl https://downloads.apache.org/kafka/3.9.0/kafka_2.13-3.9.0.tgz  --output kafka_2.13-3.9.0.tgz 
   tar -xvf kafka_2.13-3.9.0.tgz
   cd kafka_2.13-3.9.0
   KAFKA_CLUSTER_ID="$(bin/kafka-storage.sh random-uuid)"
   bin/kafka-storage.sh format -t $KAFKA_CLUSTER_ID -c config/kraft/server.properties
   ```

2. Set environment variables:
   ```sh
   export FLINK_HOME=$(pwd)/flink-1.20.1
   export KAFKA_HOME=$(pwd)/kafka_2.13-3.9.0
   export PATH=$PATH:$FLINK_HOME/bin:$KAFKA_HOME/bin

   ```

3. Start the Flink cluster:
   ```sh
   $FLINK_HOME/bin/start-cluster.sh
   ```

1. Access the Web UI at [http://localhost:8081](http://localhost:8081)

1. Submit a job
   ```sh
   ./bin/flink run ./examples/streaming/TopSpeedWindowing.jar
   ./bin/flink list
   ./bin/flink cancel <id> 
   ```
1. Download needed SQL connector for Kafka
   ```sh
   cd flink-1.20.1
   mkdir sql-lib
   cd sql-lib
   curl https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-1.20/flink-sql-connector-kafka-3.4.0-1.20.jar --output flink-sql-connector-kafka-3.4.0-1.20.jar
   ```

1. Stop th cluster:
    ```sh
    $FLINK_HOME/bin/stop-cluster.sh
    ```
### Running a simple SQL application

1. Submit a sample job:
   ```sh
   $FLINK_HOME/bin/flink run examples/streaming/WordCount.jar
   ```
1. Start Kafka cluster and create topics
   ```sh
   $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/kraft/server.properties
   $KAFKA_HOME/bin/kafka-topics.sh --create --topic flink-input --bootstrap-server localhost:9092
   $KAFKA_HOME/bin/kafka-topics.sh --create --topic message-count --bootstrap-server localhost:9092
   ```

1. Use the Flink SQL Shell:
   ```sql
   $FLINK_HOME/bin/sql-client.sh --library $FLINK_HOME/sql-lib
   ```
      * Create a table using Kafka connector:
      ```sql
      CREATE TABLE flinkInput (
         `raw` STRING,
         `ts` TIMESTAMP(3) METADATA FROM 'timestamp'
      ) WITH (
         'connector' = 'kafka',
         'topic' = 'flink-input',
         'properties.bootstrap.servers' = 'localhost:9092',
         'properties.group.id' = 'j9rGroup',
         'scan.startup.mode' = 'earliest-offset',
         'format' = 'raw'
      );
      ```
      * Create an output table in a debizium format so we can see the before and after state:
      ```sql
      CREATE TABLE msgCount (
         `count` BIGINT NOT NULL
      ) WITH (
         'connector' = 'kafka',
         'topic' = 'message-count',
         'properties.bootstrap.servers' = 'localhost:9092',
         'properties.group.id' = 'j9rGroup',
         'scan.startup.mode' = 'earliest-offset',
         'format' = 'debezium-json'
      );
      ```
      * Make the simplest flink processing by counting the messages:
      ```sql
      INSERT INTO msgCount SELECT COUNT(*) as `count` FROM flinkInput;
      ```
      The result will look like:
      ```sh
      [INFO] Submitting SQL update statement to the cluster...
      [INFO] SQL update statement has been successfully submitted to the cluster:
      Job ID: 2be58d7f7f67c5362618b607da8265d7
      ```
      * Start a producer in one terminal
      ```sh
       bin/kafka-console-producer.sh --topic flink-input --bootstrap-server localhost:9092
      ```
      * Verify result in a second terminal
      ```sh
      bin/kafka-console-consumer.sh -topic message-count  --bootstrap-server localhost:9092
      ```
      The results will be a list of debezium records like
      ```sh
      {"before":null,"after":{"count":1},"op":"c"}
      {"before":{"count":1},"after":null,"op":"d"}
      {"before":null,"after":{"count":2},"op":"c"}
      {"before":{"count":2},"after":null,"op":"d"}
      {"before":null,"after":{"count":3},"op":"c"}
      {"before":{"count":3},"after":null,"op":"d"}
      {"before":null,"after":{"count":4},"op":"c"}
      ```

3. [Optional] Start [SQL Gateway](https://nightlies.apache.org/flink/flink-docs-release-2.0/docs/dev/table/sql-gateway/overview/)  for concurrent SQL queries:
   ```sh
   $FLINK_HOME/bin/sql-gateway.sh start -Dsql-gateway.endpoint.rest.address=localhost
   ```
   
See [product documentation for different examples](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/try-flink/datastream/). To do some 
Python table API demonstrations [see this chapter](./table-api.md/#python).

### Troubleshooting

- If port 8081 is already in use, modify `$FLINK_HOME/conf/flink-conf.yaml`
- Check logs in `$FLINK_HOME/log` directory
- Ensure Java 11+ is installed and JAVA_HOME is set correctly

## 2. Docker-based Deployment

This approach provides containerized deployment using Docker Compose.

### Prerequisites

- Docker Engine
- Docker Compose

### Quick Start

1. Build custom Flink image (if needed):
   ```sh
   cd deployment/custom-flink-image
   docker build -t jbcodeforce/myflink .
   ```

2. Start Flink session cluster:
   ```sh
   cd deployment/docker
   docker compose up -d
   ```

### Docker Compose with Kafka

To run Flink with Kafka:
   ```sh
   cd deployment/docker
   docker compose -f kafka-docker-compose.yaml up -d
   ```

### Customization

- Modify `deployment/custom-flink-image/Dockerfile` to add required connectors
- Update `deployment/docker/flink-oss-docker-compose.yaml` for configuration changes

During development, we can use docker-compose to start a simple `Flink session` cluster or a standalone job manager to execute one unique job, which has 
the application jar mounted inside the docker image. We can use this same environment to do SQL based Flink apps. 

As Task manager will execute the job, it is important that the container running the flink code has access to jars needed to connect to external sources 
like Kafka or other tools like FlinkFaker. Therefore, in `deployment/custom-flink-image`, there is a [Dockerfile](https://github.com/jbcodeforce/
flink-studies/blob/master/deployment/custom-flink-image/Dockerfile) to get the needed jars to build a custom Flink image that may be used for Taskmanager 
and SQL client. Always update the jar version with new [Flink version](https://hub.docker.com/_/flink).

???- Warning "Docker hub and maven links"
    * [Docker Hub Flink link](https://hub.docker.com/_/flink)
    * [Maven Flink links](https://repo.maven.apache.org/maven2/org/apache/flink/)
    

## 3. Kubernetes Deployment

This approach provides scalable, production-ready deployment using Kubernetes. See the K8S deployment [deeper dive chapter](./k8s-deploy.md) and the [lab readme](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s) for all command details.

* Deploy a State Machine example application to validate the deployment.
   ```sh
   kubectl create -f https://raw.githubusercontent.com/apache/flink-kubernetes-operator/release-1.11/examples/basic.yaml -n flink
   ```
* Verify Flink UI access
   ```sh
   kubectl port-forward svc/basic-example-rest 8081 -n flink
   ```
* Undeploy
   ```sh
   kubectl delete -f https://raw.githubusercontent.com/apache/flink-kubernetes-operator/release-1.11/examples/basic.yaml -n flink
   ```

### Confluent Platform on Kubernetes

For Confluent Platform deployment:

1. Install Confluent Flink Operator:
   ```sh
   make deploy_cp_flink_operator
   ```

2. Deploy Confluent Platform Kafka cluster:
   ```sh
   make deploy_cp_cluster
   ```

3. Deploy Flink applications

See [Kubernetes deployment chapter](./k8s-deploy.md) for detailed instructions. And [Confluent operator documentation.](https://docs.confluent.io/operator/current/co-prepare.html)

## 4. Confluent Cloud Deployment

This approach provides a fully managed Flink service.

### Prerequisites

- Confluent Cloud account
- Confluent CLI installed
- Environment configured

### Getting Started

1. Create a Flink compute pool:
   ```sh
   confluent flink compute-pool create my-pool --cloud aws --region us-west-2
   ```

2. Start SQL client:
   ```sh
   confluent flink shell
   ```

3. Submit SQL statements:
   ```sql
   CREATE TABLE my_table (
     id INT,
     name STRING
   ) WITH (
     'connector' = 'kafka',
     'topic' = 'my-topic',
     'properties.bootstrap.servers' = 'pkc-xxxxx.region.provider.confluent.cloud:9092',
     'properties.security.protocol' = 'SASL_SSL',
     'properties.sasl.mechanism' = 'PLAIN',
     'properties.sasl.jaas.config' = 'org.apache.kafka.common.security.plain.PlainLoginModule required username="<API_KEY>" password="<API_SECRET>";',
     'format' = 'json'
   );
   ```

See [Confluent Cloud Flink documentation](../techno/ccloud-flink.md) for more details.

See the [Shift Left project](https://jbcodeforce.github.io/shift_left_utils/) to manage bigger Flink project with a dedicated CLI.

## Choosing the Right Deployment Approach

| Approach | Use Case | Pros | Cons |
|----------|----------|------|------|
| Local Binary | Development, Testing | Simple setup, Fast iteration | Limited scalability, or manual configuration and maintenance on distributed computers.|
| Docker | Development, Testing | Containerized, Reproducible | Manual orchestration |
| Kubernetes | Production | Scalable, Production-ready | Complex setup |
| Confluent Cloud | Production | Fully managed, No ops | Vendor Control Plane |

## Application deployment

For production it is recommended to deploy in application mode, so packaging SQL, python or java application in a jar. 

## Additional Resources

- [Apache Flink Documentation](https://nightlies.apache.org/flink/flink-docs-release-1.20/)
- [Confluent Cloud Documentation](https://docs.confluent.io/cloud/current/get-started/index.html)
- [Flink Kubernetes Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/)
- [Docker Hub Flink Images](https://hub.docker.com/_/flink)

