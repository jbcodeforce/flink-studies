# Deploying a set of services to Kubernetes

This folder contains Kubernetes deployment configurations for various components used in Flink development and operations using Open Source Flink or Confluent Plaform (Kafka and Flink):

The Makefile in this folder defines commands for Colima, minio, certificat manager. 

## Core Components

### Apache Flink
- **OSS Flink** (`flink-oss/`): Standard Flink deployment including JobManager, TaskManager, and operator
- **Confluent Flink** (`cp-flink/`): Confluent Cloud managed Flink with S3/MinIO support

### Storage and Data
- **MinIO** (`MinIO/`): S3-compatible object storage for state backends and checkpoints
- **Confluent Kafka** (`cfk/`): Kafka cluster deployment with Kraft, Connect, and monitoring
- **Confluent Manager for Flink** (`cmf/`): Environment, Compute pool and a sample Flink application configurations

## Supporting Services

### Security and Access
- **Keycloak** (`keycloak/`): Identity and access management
- **NGINX** (`nginx/`): Web server and ingress controller
- **K8s Dashboard** (`k8s-dashboard/`): Kubernetes web UI for cluster management

## Development Tools
- `start_colima.sh`: Local Kubernetes cluster setup using Colima
- `check_env.sh`: Environment validation script

Each component directory contains its own README or documentation with specific setup instructions.

## Starting from a brand new collima VM

Here are the getting started:
1. [Optional] Delete previous default VM: `colima delete default`
1. Start a new default VM: `make start_colima` -> The created ns are `default, kube-node-lease, kube-public, kube-system`
1. Deploy Certificat manager, minio and other: `make deploy`
1. Deploy Confluent Platform. It will take few minutes to get all pods up and running
    ```sh
    cd cfk
    make deploy
    kubectl get pods -w
    ```

1. Deploy Confluent Manager for Flink. As the deployment of the operator implies to reference namespace where applications may be deployed, modify the Makefile to change the variable: NS_LIST
    ```sh
    # Create the needed namespace
    kubectl create rental
    kubectl create el-demo
    # within cmf folder
    make deploy
    ```

## Upgrading to new version

### Open Source Flink