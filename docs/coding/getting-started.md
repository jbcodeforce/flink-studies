# Flink Getting started

???- info "Update"
    * Created 2018 
    * Updated 1/18/2025 - imporve note, review done. 

This chapter reviews the different environments for deploying Flink, Flink jobs on a developer's workstation. Options include  downloading product tar file, using Docker Compose, Minikube ot Colima -k3s, or adopting an hybrid approach that combines a Confluent Cloud Kafka cluster with a local Flink instance. This last option is not supported for production but is helpful for development purpose. To get started with Confluent Cloud for Flink [see this summary chapter](../techno/ccloud-flink.md).

The section includes Open Source product, or Confluent Platform for Flink or Confluent Cloud for Flink.

## Install locally

The Flink Open Source tar file can be downloaded. The `install-local.sh` script in 'deployment/product-tar` folder does this download and untar operations.

* Once done, start Flink using the `start-cluster.sh` script in `flink-1.19.1/bin`. See [Flink OSS product documentation](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/try-flink/local_installation/).

  ```sh
  ./bin/start-cluster.sh
  ```

* Access [Web UI](http://localhost:8081/#/overview) and submit one of the example using the flink client cli: `./bin/flink run examples/streaming/WordCount.jar`.

* As an option, start the SQL client:

  ```sh
  ./bin/sql-client.sh
  ```

* [Optional] Start SQL Gateway to be able to have multiple client apps to submit SQL queries in concurrency.

  ```sh
  ./bin/sql-gateway.sh start -Dsql-gateway.endpoint.rest.address=localhost
  # stop it
  ./bin/sql-gateway.sh stop-all -Dsql-gateway.endpoint.rest.address=localhost
  ```

* Stop the Flink job and the Task manager cluster:

  ```sh
  ./bin/stop-cluster.sh
  ```

## With docker images

### Pre-requisites


* Get docker cli, helm, and kubectl
* Clone this repository.
* For docker container execution, you need a docker engine, with docker compose CLIs. As an option, we can use Colima or Minikube with docker-ce engine.

Three options: 

1. Colima with Kubernetes
1. Minikube 
1. docker compose

For each of those environment, see the next sections and for Flink Kubernetes operator deployment and configuratuin see [the dedicated k8s deployment chapter](./k8s-deploy.md).

### Colima with Kubernetes

As an alternative to use Docker Desktop, [Colima](https://github.com/abiosoft/colima) is an open source to run container on Linux or Mac. 

* Start a k3s cluster:

  ```sh
  colima start --kubernetes
  ```

Deploy the Flink and Confluent Platform operators (see Makefile in [deployment/k8s and its readme](ttps://jbcodeforce.github.io/flink-studies/deployment/k8s)). 

Define a Flink cluster, and a Kafka Cluster if needed.

### Minikube

* Install [Minikube](https://minikube.sigs.k8s.io/), and review some [best practices](https://jbcodeforce.github.io/techno/minikube/) on how to configure and use it.
* Start with enough memory and cpu

  ```sh
  minikube start --cpus='3' --memory='4096'
  ```

* Only to newly created minikube profile, [install Flink Operator for kubernetes](./k8s-deploy.md#deploy-flink-kubernetes-operator)
* If we want integration with Kafka and Schema registry select one of the Kafka platform:

    * Install [Confluent Plaform Operator](https://docs.confluent.io/operator/current/co-quickstart.html)
    
    ```sh
    kubectl create namespace confluent
    kubectl config set-context --current --namespace confluent
    helm repo add confluentinc https://packages.confluent.io/helm
    helm repo update
    helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes
    ```

    * Or [Kafka OSS Strimzi Operator](https://strimzi.io/quickstarts/) in the `kafka` namespace:

    ```sh
    kubectl create namespace kafka
    kubectl config set-context --current --namespace kafka
    kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

    ```

    with [Apicu.io](https://www.apicur.io/registry/docs/apicurio-registry-operator/1.2.0-dev-v2.6.x/assembly-operator-quickstart.html) for Operator for schema management.


### Docker Desktop and Compose

During development, we can use docker-compose to start a simple `Flink session` cluster or a standalone job manager to execute one unique job, which has the application jar mounted inside the docker image. We can use this same environment to do SQL based Flink apps. 

As Task manager will execute the job, it is important that the container running the flink code has access to jars needed to connect to external sources like Kafka or other tools like FlinkFaker. Therefore there is a [Dockerfile](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/custom-flink-image/Dockerfile) to get some important jars to build a custom Flink image that we will use for Taskmanager and SQL client. Always update the jar version with new Flink version.

* If specific integrations are needed, get the needed jar references, update the dockerfile and then build the Custom Flink image, under `deployment/custom-flink-image` folder

  ```sh
  docker build -t jbcodeforce/myflink .
  ```

* Start Flink session cluster using the following command: 

  ```shell
  # under this repository and deployment/docker folder
  docker compose up -d
  ```

The [Flink OSS docker compose](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/docker/flink-oss-docker-compose.yaml) starts one job manager and one task manager server:

```yaml
services:
  jobmanager:
    image: flink:latest
    hostname: jobmanager
    ports:
      - "8081:8081"
    command: jobmanager
    user: "flink:flink"
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
    user: "flink:flink"
    scale: 1
    volumes:
        - .:/home
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        taskmanager.numberOfTaskSlots: 4
```

The docker compose mounts the local folder to `/home` in both the job manager and task manager containers so that, we can submit jobs from the job manager (accessing the compiled jar) and also access the input data files and connector jars in the task manager container.

[See this section to deploy an application with flink]()

### Docker compose with Kafka and Flink

In the `deployment/docker` folder the docker compose starts one node OSS kafka broker, one zookeeper, one OSS Flink job manager and one task manager.

```sh
docker compose -f kafka-docker-compose.yaml up -d
```

The SQL client can be used to compute some aggregation on the sale events created by the `E-commerce simulator`. To start the simulator using a Python virtual environment do:

```sh 
pip install -r requirements.txt
python simulator.py
```

The application sends events like the following:


```json
{'event_type': 'user_action', 
 'timestamp': '2024-09-04T15:24:59.450582', 
 'user_id': 'user5', 
 'action': 'add_to_cart', 
 'page': 'category', 
 'product': 'headphones'
}
```

* Use the [Kafdrop interface to verify the messages in the topic](http://localhost:9000/topic/ecommerce_events)
* Connect to SQL client container

  ```sh
  docker exec -ti sql-client bash
  # in the container shell, start sql cli
  ./sql-client.sh
  ```

```sql title="User page view on kafka stream"
CREATE TABLE user_page_views (
    event_type STRING,
    user_id STRING,
    action STRING,
    page STRING,
    product STRING,
    timestamp_str STRING,        # (1)
    timestamp_sec TIMESTAMP(3),  # derived field
    WATERMARK FOR timestamp_sec AS TO_TIMESTAMP(timestamp_str, 'yyyy-MM-dd HH:mm:ss') - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'ecommerce_events',
    'properties.bootstrap.servers' = 'kafka:29092',
    'properties.group.id' = 'sql-flink-grp-1',
    'properties.auto.offset.reset' = 'earliest',
    'format' = 'json'  
);
```

1. The event timestamp is a string created by the Kafka producer

**WATERMARK** statement is used to define a watermark strategy for handling event time in streaming applications. Watermarks are crucial for dealing with out-of-order events, allowing Flink to manage late arrivals and trigger processing based on event time rather than processing time. A watermark is a timestamp that indicates that no events with a timestamp earlier than the watermark will arrive. 

It is important to set the consumer properties like consumer group id, the offset reset strategy...

The next SQL statement is to count the number of page per user

```sql
SELECT 
    user_id, 
    page,
    COUNT(page) AS page_views 
FROM 
    user_page_views 
GROUP BY 
    user_id,
    page;
```

The results

![](./images/query_result.png)

## Confluent Cloud

[See getting started product documentation](https://docs.confluent.io/cloud/current/get-started/index.html) and [this summary](../techno/ccloud-flink.md).

To use the Confluent client flink sql client [see this note](https://docs.confluent.io/confluent-cli/current/command-reference/flink/confluent_flink_shell.html)

