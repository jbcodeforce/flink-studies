# Deploying a set of services to Kubernetes

This folder contains Kubernetes deployment configurations for various components used in Flink development and operations with Open Source Flink or Confluent Plaform:

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