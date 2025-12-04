# Flink Getting Started Guide

???- info "Updates"
    * Created 2018 
    * Updated 2/14/2025 - improve note, on k8s deployment and get simple demo reference, review done. 
    * 03/30/25: converged the notes and update referenced links
    * 09/25: Review - simplications.

There are four different approaches to deploy and run Apache Flink / Confluent Flink:

1. [Local Binary Installation](#1-open-source-apache-Flink-local-binary-installation)
2. [Docker-based local deployment](#2-docker-based-deployment)
3. [Kubernetes Deployment](#3-kubernetes-deployment) Colima, AKS, EKS, GKS, King or minicube
4. [Confluent Cloud Managed Service](#4-confluent-cloud-deployment)

## Pre-requisites

Before getting started, ensure you have some of the following dependant components:

1. [Java 11 or higher installed (OpenJDK)](https://openjdk.org/) for developing Java based solution.
2. Docker Engine and Docker CLI (for Docker and Kubernetes deployments)
3. [kubectl](https://kubernetes.io/docs/tasks/tools/) and [Helm](https://jbcodeforce.github.io/coding/helm) (for Kubernetes deployment)
4. [Confluent Cloud](https://login.confluent.io/) account (for Confluent Cloud deployment, and Flink SQL development)
6. [Confluent cli installed](https://docs.confluent.io/confluent-cli/current/install.html) for both Confluent Cloud and Confluent Platform
1. Git clone this repository, to access code and deployment manifests and scripts

## 1. Open Source Apache Flink Local Binary Installation

This approach is ideal for development and testing on a single machine.

### Installation Steps

1. Download and extract Flink binary. See in the release page -> [downloads](https://flink.apache.org/downloads/) the last version.
   ```sh
   # Using the provided script, and change the version
   ./deployment/product-tar/install-local.sh
   
   # Or manually
   curl https://dlcdn.apache.org/flink/flink-2.1.1/flink-2.1.1-bin-scala_2.12.tgz --output Flink-2.1.1-bin-scala_2.12.tgz
   tar -xzf Flink-2.1.1-bin-scala_2.12.tgz
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
   export Flink_HOME=$(pwd)/flink-2.1.1
   export KAFKA_HOME=$(pwd)/kafka_2.13-3.9.0
   export PATH=$PATH:$Flink_HOME/bin:$KAFKA_HOME/bin

   ```

3. Start the Flink cluster:
   ```sh
   $Flink_HOME/bin/start-cluster.sh
   ```

1. Access the Web UI at [http://localhost:8081](http://localhost:8081)

1. Submit a job (Java application)
   ```sh
   ./bin/flink run ./examples/streaming/TopSpeedWindowing.jar
   ./bin/flink list
   ./bin/flink cancel <id> 
   ```
1. Download needed SQL connector for Kafka
   ```sh
   cd Flink-2.1.1
   mkdir sql-lib
   cd sql-lib
   curl https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.4.0-1.20/flink-sql-connector-kafka-3.4.0-1.20.jar --output Flink-sql-connector-kafka-3.4.0-1.20.jar
   ```

1. Stop the cluster:
    ```sh
    $Flink_HOME/bin/stop-cluster.sh
    ```

* [See this deployement readme in this repo](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/product-tar/README.md).

### Running simple SQL application

* [See this sql programming lab 0 in this repo](https://github.com/jbcodeforce/flink-studies/blob/master/code/flink-sql/00-basic-sql/README.md)
* [And the lab with Kafka integration](https://github.com/jbcodeforce/flink-studies/blob/master/code/flink-sql/01-confluent-kafka-local-Flink)

### Troubleshooting

- If port 8081 is already in use, modify `$Flink_HOME/conf/flink-conf.yaml`
- Check logs in `$Flink_HOME/log` directory
- Ensure Java 11+ is installed and JAVA_HOME is set correctly

## 2. Docker-based Deployment

This approach provides containerized deployment using Docker Compose.

### Quick Start

1. Build a custom Apache Flink image with your own connectors. Verify current [docker image tag](https://hub.docker.com/_/flink/tags) then use [the Dockerfile](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/custom-Flink-image/Dockerfile):
   ```sh
   cd deployment/custom-Flink-image
   docker build -t jbcodeforce/myFlink .
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

As Task manager will execute the job, it is important that the container running the Flink code has access to the jars needed to connect to external sources like Kafka or other tools like FlinkFaker. Therefore, in `deployment/custom-Flink-image`, there is a [Dockerfile](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/custom-Flink-image/Dockerfile) to get the needed jars to build a custom Flink image that may be used for Taskmanager 
and SQL client. Always update the jar version with new [Flink version](https://hub.docker.com/_/flink).

???- Warning "Docker hub and maven links"
    * [Docker Hub Flink link](https://hub.docker.com/_/flink)
    * [Maven Flink links](https://repo.maven.apache.org/maven2/org/apache/flink/)
    

## 3. Kubernetes Deployment

This approach provides scalable, production-ready deployment using Kubernetes. 

### Apache Flink

See the K8S deployment [deeper dive chapter](./k8s-deploy.md) and the [lab readme](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s/flink-oss) for Apache Flink OSS details.


### Confluent Platform Manager for Flink on Kubernetes

See [Kubernetes deployment chapter](./k8s-deploy.md) for detailed instructions, and the [deployment folder and readme](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s/cmf). See also the [Confluent operator documentation](https://docs.confluent.io/operator/current/co-prepare.html), [submit Flink SQL Statement with Confluent Manager for Apache Flink](https://docs.confluent.io/platform/current/flink/get-started/get-started-statement.html):


## 4. Confluent Cloud Deployment

This approach provides a fully managed Flink service and very easy to get started quickly without managing Flink clusters or Kafka Clusters. It uses the confluent cli

1. Upgrade the cli
   ```sh
   confluent update
   ```
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

See [Confluent Cloud Flink documentation](../techno/ccloud-Flink.md) for more details.

Explore the [Shift Left project](https://jbcodeforce.github.io/shift_left_utils/), your dedicated CLI for scaling and organizing Confluent Cloud Flink projects with an opinionated, streamlined approach.

## Choosing the Right Deployment Approach

| Approach | Use Case | Pros | Cons |
|----------|----------|------|------|
| Local Binary | Development, Testing | Simple setup, Fast iteration | Limited scalability, or manual configuration and maintenance on distributed computers.|
| Docker | Development, Testing | Containerized, Reproducible | Manual orchestration |
| Kubernetes | Production | Scalable, Production-ready | Complex setup |
| Confluent Cloud | Production | Fully managed, No ops | Vendor Control Plane |


## Additional Resources

- [Apache Flink Documentation](https://nightlies.apache.org/flink/flink-docs-release-1.20/)
- [Confluent Cloud Documentation](https://docs.confluent.io/cloud/current/get-started/index.html)
- [Flink Kubernetes Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/)
- [Docker Hub Flink Images](https://hub.docker.com/_/flink)
- [Shift Left project](https://jbcodeforce.github.io/shift_left_utils/) to manage Flink project at scale.


<div class="nav-links" style="display: flex; justify-content: space-between;">
  <a href="/flink-studies/concepts/" class="nav-link nav-prev">&lt;&lt; PREVIOUS: Key Concepts</a>
  <a href="/flink-studies/coding/flink-sql/" class="nav-link nav-next">&gt;&gt; NEXT: Flink SQL &gt;&gt;</a>
</div>
