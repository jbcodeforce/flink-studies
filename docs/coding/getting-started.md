# Flink Getting started

???- info "Updates"
    * Created 2018 
    * Updated 2/14/2025 - improve note, on k8s deployment and get simple demo reference, review done. 
    * 03/30/25: coverged notes and update referenced links

This chapter reviews the different environments for deploying Flink, and Flink jobs on a developer's workstation. Options include  downloading product tar file, using Docker Compose, or local Kubernetes Colima-k3s, or adopting an hybrid approach that combines a Confluent Cloud Kafka cluster with a local Flink instance. This last option is not supported for production but is helpful for development purpose. To get started with Confluent Cloud for Flink [see this summary chapter](../techno/ccloud-flink.md).

The section includes Open Source product, Confluent Platform for Flink or Confluent Cloud for Flink.

## Pre-requisites

1. Clone this repository.

## Install Apache Flink locally

The Apache Flink Open Source tar file can be downloaded. The `install-local.sh` script in 'deployment/product-tar` folder does the download and untar operations.

* Set env variable: `export FLINK_HOME=$(pwd)/flink-1.20.1`

* Once done, start Flink using the `start-cluster.sh` script in `flink-1.20.1/bin`. See [Flink OSS product documentation](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/try-flink/local_installation/).

    ```sh
    $FLINK_HOME/bin/start-cluster.sh
    ```

* Access [Web UI](http://localhost:8081/#/overview) and submit one of the available examples using the flink client cli: `./bin/flink run examples/streaming/WordCount.jar`.
* Once Apache Flink java datastream or table api programs are packaged as uber-jar, use the `flink` cli to submit the application.

    ```sh
    $FLINK_HOME/bin/flink run  examples/streaming/WordCount.jar
    ```

* As an option, start the SQL client:

    ```sh
    $FLINK_HOME/bin/sql-client.sh
    ```

* [Optional] Start SQL Gateway to be able to have multiple client apps submitting SQL queries in concurrency.

    ```sh
    $FLINK_HOME/bin/sql-gateway.sh start -Dsql-gateway.endpoint.rest.address=localhost
    # stop it
    $FLINK_HOME/bin/sql-gateway.sh stop-all -Dsql-gateway.endpoint.rest.address=localhost
    ```

* Stop the Flink job and the Task manager cluster:

    ```sh
    $FLINK_HOME/bin/stop-cluster.sh
    ```

See [product documentation for different examples](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/try-flink/datastream/).

## With docker images

* For docker container execution, you need a docker engine, with docker client CLIs. 
* There are multiple way to run docker container: 

    1. Docker desktop, RangerDesktop or any other docker engine
    1. Kubernetes using Colima or Minikube
    1. Docker compose to orchestrate multiple containers

For each of those environments, see the [deployment folder](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/) and read the [dedicated k8s deployment chapter](./k8s-deploy.md).

### Docker Desktop and Compose

During development, we can use docker-compose to start a simple `Flink session` cluster or a standalone job manager to execute one unique job, which has the application jar mounted inside the docker image. We can use this same environment to do SQL based Flink apps. 

As Task manager will execute the job, it is important that the container running the flink code has access to jars needed to connect to external sources like Kafka or other tools like FlinkFaker. Therefore, in `deployment/custom-flink-image`, there is a [Dockerfile](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/custom-flink-image/Dockerfile) to get the needed jars to build a custom Flink image that may be used for Taskmanager and SQL client. Always update the jar version with new [Flink version](https://hub.docker.com/_/flink).

???- Warning "Docker hub and maven links"
    * [Docker Hub Flink link](https://hub.docker.com/_/flink)
    * [Maven Flink links](https://repo.maven.apache.org/maven2/org/apache/flink/)

* If specific integrations are needed, get the needed jars, update the dockerfile and then build the Custom Flink image, under `deployment/custom-flink-image` folder

    ```sh
    docker build -t jbcodeforce/myflink .
    ```

* Start Flink session cluster using the following command: 

    ```shell
    # under this repository and deployment/docker folder
    docker compose up -d
    ```

???- info "Docker compose for Flink OSS"
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

In the `deployment/docker` folder the docker compose starts one OSS kafka broker, one zookeeper, one OSS Flink job manager and one Flink Task manager.

```sh
docker compose -f kafka-docker-compose.yaml up -d
```

[See Confluent operator documentation.](https://docs.confluent.io/operator/current/co-prepare.html)

### Kubernetes Deployment

As an alternative to Docker Desktop, [Colima](https://github.com/abiosoft/colima) is an open source to run container on Linux or Mac.  See the [deployment/k8s folder.](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s). Below are the generic steps to follow:

* Get helm, and kubectl
* Add flink-operator-repo helm repo

For Confluent Platform for Flink add the following steps:
* Install Confluent plugin for kubectl
* Deploy Confluent Platform Flink operator, `make deploy_cp_flink_operator`  (see Makefile in [deployment/k8s and its readme](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/k8s)) with  makefile to simplify the deployment.
* Deploy Confluent Platform operator to get Kafka brokers deployed: `make deploy_cp_operator`
* Deploy Confluent Kafka Broker using one Kraft controller, one broker, with REST api and schema registry: `make deploy_cp_cluster`


* Finally deploy Flink applications.

[See Kubernetes deployment dedicated chapter](./k8s-deploy.md).

## Confluent Cloud

As a managed service, Confluent Cloud offers Flink deployment, read [the getting started product documentation](https://docs.confluent.io/cloud/current/get-started/index.html) and [this summary](../techno/ccloud-flink.md).

To use the Confluent Cloud Flink sql client [see this note.](https://docs.confluent.io/confluent-cli/current/command-reference/flink/confluent_flink_shell.html)

