# SQL Runner for Flink

This code comes from Flink Examples, with a single pom based on Quarkus maven template. This example can be executed as a Flink application in local Docker compose, Minikuber with the Flink Kubernetes Operator.

Created 10/2024 For Flink version 1.19 for Java 11.

## Purpose

Flink doesn't support submitting SQL scripts directly as jobs, this Java program can execute SQL scripts.

To add extension, consider one of the [connectors](https://nightlies.apache.org/flink/flink-docs-master/docs/connectors/table/overview/) and add it as compile dependency to the project `pom.xml`. This will ensure that is packaged into the sql-runner fatjar and will be available on the cluster.

To make an application, we need to make all the job artifacts available locally in all containers under `/opt/flink/usrlib`, then start a JobManager container in the Application cluster mode, and finally start the required number of TaskManager containers.

## Steps

* Build the jar with `mvn package`
* Add any specific SQL in sql-scripts folder. name it `main.sql` (see deployment.yaml)
* Build the docker image with:

```sh
# Using minikube
minikube image build -t j9r/flink-sql-runner -f src/main/docker/Dockerfile .
# using docker
docker build -t j9r/flink-sql-runner -f src/main/docker/Dockerfile .
```

* For deployment with Flink Kubernetes Operator, create FlinkDeployment Yaml and Submit it to the operator

```sh
kubectl -f apply src/main/k8s/deployment.yaml
```

* For running local: `docker compose up -d`