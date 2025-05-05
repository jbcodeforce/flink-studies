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

1. Java 11 or higher installed
2. Docker Engine and Docker CLI (for Docker and Kubernetes deployments)
3. kubectl and Helm (for Kubernetes deployment)
4. Confluent Cloud account (for Confluent Cloud deployment)
5. Git (to clone this repository)

## 1. Local Binary Installation

This approach is ideal for development and testing on a single machine.

### Installation Steps

1. Download and extract Flink binary
   ```sh
   # Using the provided script
   ./deployment/product-tar/install-local.sh
   
   # Or manually
   wget https://dlcdn.apache.org/flink/flink-1.20.1/flink-1.20.1-bin-scala_2.12.tgz
   tar -xzf flink-1.20.1-bin-scala_2.12.tgz
   ```

2. Set environment variables:
   ```sh
   export FLINK_HOME=$(pwd)/flink-1.20.1
   export PATH=$PATH:$FLINK_HOME/bin
   ```

3. Start the Flink cluster:
   ```sh
   $FLINK_HOME/bin/start-cluster.sh
   ```

4. Access the Web UI at [http://localhost:8081](http://localhost:8081)

5. Stop th cluster:
    ```sh
    $FLINK_HOME/bin/stop-cluster.sh
    ```
### Running Applications

1. Submit a sample job:
   ```sh
   $FLINK_HOME/bin/flink run examples/streaming/WordCount.jar
   ```

2. Start SQL Client:
   ```sh
   $FLINK_HOME/bin/sql-client.sh
   ```

3. [Optional] Start [SQL Gateway](https://nightlies.apache.org/flink/flink-docs-release-2.0/docs/dev/table/sql-gateway/overview/)  for concurrent SQL queries:
   ```sh
   $FLINK_HOME/bin/sql-gateway.sh start -Dsql-gateway.endpoint.rest.address=localhost
   ```

See [product documentation for different examples](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/try-flink/datastream/). To do some 
Python table API demonstrations [see this chapter](./table-api.md/#python).

### Troubleshooting

- If port 8081 is already in use, modify `conf/flink-conf.yaml`
- Check logs in `$FLINK_HOME/log` directory
- Ensure Java 11+ is installed and JAVA_HOME is set correctly

## 2. Docker-based Deployment

This approach provides containerized deployment using Docker Compose.

### Prerequisites

- Docker Engine
- Docker Compose
- Git (to clone this repository)

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

This approach provides scalable, production-ready deployment using Kubernetes.

### Prerequisites

- Kubernetes cluster (local or cloud)
- kubectl
- Helm
- [Optional Colima](https://github.com/abiosoft/colima) for local Kubernetes

### Deployment Steps

1. Install Flink Operator:
   ```sh
   helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.7.0/
   helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator
   ```

2. Deploy Flink Application:
   ```sh
   kubectl apply -f deployment/k8s/flink-application.yaml
   ```

### Confluent Platform on Kubernetes

For Confluent Platform deployment:

1. Install Confluent Operator:
   ```sh
   make deploy_cp_flink_operator
   ```

2. Deploy Kafka cluster:
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

