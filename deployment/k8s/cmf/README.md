# Confluent Manager for Flink

This folder includes different deployment manifests for Confluent Manager for Flink. The approach is to encapsulate some of the kubectl commands using `make` targets. The code and/or instructions here are NOT intended for production usage.

See the [Flink operator - open source documentation](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/deployment/resource-providers/standalone/kubernetes/) and the [Confluent platform for flink operator](https://docs.confluent.io/platform/current/flink/get-started.html) for details.

Read also our analysis of Kubernetes deployment for Flink in [this chapter](https://github.com/jbcodeforce/flink-studies/coding/k8-deploy).


## Planning deployment

* Confluent Plaform deployment on k8s supports [two options](https://docs.confluent.io/operator/current/co-plan.html#co-plan): [CFK](https://docs.confluent.io/operator/current/co-deploy-cfk.html#co-deploy-operator) or [CFK Blueprints](https://docs.confluent.io/operator/current/blueprints/cob-overview.html#cob-overview). We use the CFK approach here.

* Review sizing needs: Minimum of 3 kafka brokers, for pure demonstration and development we can use one broker.

## Prerequisites

* [See the pre-requisites note for CLIs installation and other general dependencies](https://github.com/jbcodeforce/flink-studies/coding/k8-deploy/#prerequisites)

* Access to a Kubernetes cluster using Colima VM:
    ```sh
    make start_colima
    ```

* The next steps are automated with one make command:
    ```sh
    make prepare
    ```
    But are doing the following steps:

    * Install certification manager (only one time per k8s cluster): See [Release version here](https://github.com/cert-manager/cert-manager/), change in the Makefile the version number and the make commands:
        ```sh
        make deploy_cert_manager
        # verify
        make verify_cert_manager
        kubeclt get pods -n cert-manager
        ```

    * Create `flink` and `confluent` namespaces: `make create_ns` - 10/01/2025 To simplify we merged both namespace into `confluent`
    * Install Minio to persist jar or expose object storage in the K8S cluster. [See Minio quickstart](https://min.io/docs/minio/linux/reference/minio-mc.html#quickstart) and [the minio section in k8s deployment chapter.](https://jbcodeforce.github.io/flink-studies/coding/k8s-deploy/#using-minio-for-app-deployment)
        ```sh
        make deploy_minio
        make verify_minio
        ```
    
    * Deploy MinIO S3 credentials secret (for secure Flink checkpointing):
        ```sh
        make deploy_minio_secret
        make verify_minio_secret
        ```
        
        **Note:** For production, create secrets using kubectl instead of committing to git:
        ```sh
        kubectl create secret generic minio-s3-credentials \
          --from-literal=s3.access-key=<your-access-key> \
          --from-literal=s3.secret-key=<your-secret-key> \
          --from-literal=s3.endpoint=http://minio.minio-dev.svc.cluster.local:9000 \
          -n el-demo
        ```


## Flink Checkpointing with MinIO

The FlinkEnvironment is configured to use MinIO as the S3-compatible storage backend for checkpoints and savepoints. This setup uses Kubernetes Secrets for secure credential management.

### Prerequisites

**Important:** You must build a custom Flink image with the S3 filesystem plugin to enable S3A protocol support for MinIO.

#### Build Custom Flink Image with S3 Support

```bash
# Build the image with S3 plugin
make build_flink_s3_image

# Push to your registry
make build_and_push_flink_s3_image

# Or manually
docker build -f Dockerfile.s3-enabled-alpine -t jbcodeforce/cp-flink-s3:1.20.2-s3 .
docker push jbcodeforce/cp-flink-s3:1.20.2-s3
```

**📖 See [`S3_JAR_REQUIREMENTS.md`](./S3_JAR_REQUIREMENTS.md) for detailed information about:**
- Required JAR files (`flink-s3-fs-hadoop`)
- Installation methods
- Version compatibility
- Troubleshooting

### Architecture

1. **Custom Flink Image**: Includes `flink-s3-fs-hadoop` plugin for S3A support
2. **MinIO Service**: Exposed via `minio.minio-dev.svc.cluster.local:9000`
3. **Kubernetes Secret**: Stores S3 credentials (`minio-s3-credentials`)
4. **Pod Template**: Injects secret values as environment variables
5. **Flink Configuration**: References environment variables for S3 access

### Configuration Details

The following Flink properties are configured in `flink-dev-env.yaml`:

- `state.checkpoints.dir`: `s3a://flink/checkpoints`
- `state.savepoints.dir`: `s3a://flink/savepoints`
- `s3.endpoint`: Dynamically loaded from secret
- `s3.access-key`: Dynamically loaded from secret
- `s3.secret-key`: Dynamically loaded from secret
- `s3.path.style.access`: `true` (required for MinIO)

**📖 See [`MINIO_S3_SETUP.md`](./MINIO_S3_SETUP.md) for complete setup documentation.**

### Creating the Flink Bucket

Before running Flink jobs, create the `flink` bucket in MinIO:

```sh
# Option 1: Using MinIO Console
make port_forward_minio_console
# Access http://localhost:9090 (login: minioadmin/minioadmin)
# Create bucket named "flink"

# Option 2: Using mc CLI
kubectl run -it --rm mc --image=minio/mc --restart=Never -- \
  sh -c "mc alias set minio http://minio.minio-dev:9000 minioadmin minioadmin && mc mb minio/flink"
```

## Deploy Confluent Platform and Confluent Manager for Flink

See the steps as described in [Confluent Plafform product documentation](https://docs.confluent.io/operator/current/co-cfk-overview.html).

--- 
TO BE MODIFIED


1. Deploy Confluent Platform:
    ```sh
    make install_cp
    make verify_cp_cfk
    ```

1. Deploy Confluent Manager for Apache Flink
    ```sh
    make install_cmf
    make verify_cmf
    ```

1. Define a Flink environment:

    ```sh
    # in one Terminal console
    make port_forward_cmf
    # or
    kubectl port-forward svc/cmf-service 8084:80 -n flink
    # in a second terminal
    make create_flink_env
    ```

1. To change the kubectl context to use Flink namespace the command is:
    ```sh
    kubectl config set-context --current --namespace=flink
    ```

1. Validate installation with a simple Flink application, and validate with the Flink Dashboard:
    ```sh
    make deploy_flink_demo_app
    ```

1. Access Flink Console for the deployed application:
    ```sh
    make access_flink_console 
    # which maps to:
    confluent flink application web-ui-forward basic-example --environment env1 --port 8090 --url http://localhost:8084
    ```

1. Undeploy this application
    ```sh
    confluent flink application delete basic-example --environment env1  --url http://localhost:8084
    ```

1. Work with SQL client usinf confluent cli:
    ```sh
    confluent --environment env1 --compute-pool pool1 flink shell
    ```

## Monitoring with Prometheus and Grafana

* Add the helm repos:

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

* Install one Prometheus instance into the default namespace

```sh
helm upgrade --install my-prometheus prometheus-community/prometheus \
 --set alertmanager.persistentVolume.enabled=false \
 --set server.persistentVolume.enabled=false \
 --namespace default
```

The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
my-prometheus-prometheus-pushgateway.default.svc.cluster.local

Get the PushGateway URL by running these commands in the same shell:
```sh
  export POD_NAME=$(kubectl get pods --namespace default -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
  kubectl --namespace default port-forward $POD_NAME 9091
```

* Install Grafana

```sh
helm upgrade --install grafana grafana/grafana --namespace default
```

* Get admin user password with:

```sh
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

* Access to Grafana console

```sh
kubectl port-forward \
  $(kubectl get pods -n default -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana -o name) \
  3000 --namespace default
```

* Configure Prometheus data source for grafana (see [instructions](https://prometheus.io/docs/visualization/grafana/#creating-a-prometheus-data-source)) using the URL `http://my-prometheus-prometheus-server.default.svc.cluster.local`

## Some application examples

* [E-commerce demo with 3 topics and a Flink join SQL using Table API](../../e2e-demos/e-com-sale/README.md).
* [Validate savepoint processing with stop and restart job](../../e2e-demos/savepoint-demo/readme.md).
* [Older demo doe 2e2 streaming](../../e2e-demos/e2e-streaming-demo/README.md).

## Troubleshooting

* If there is an ImageInspectError while starting a pod, this is because the docker engine could not access the image registry.

    ```sh
    # look at the logs of the failing pods
    kubectl -n kube-system describe po  connect-0 -n confluent
    # ssh to the minikube vm
    minikube ssh
    # add the line: unqualified-search-registries=["docker.io"]
    sudo vi /etc/containers/registries.conf
    minikube stop
    minikube start
    ```

* Exception java.lang.ClassNotFoundException: org.apache.flink.connector.file.src.reader.StreamFormat

The `org.apache.flink.connector.file.src.reader.StreamFormat` class is part of the Flink File Source connector, which is not included in the standard Flink distribution. So we need to build a dockerfile and custom image for the application with copy of needed jars.


## Sources of information

* [Deploy Confluent Platform with Kraft.](https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/quickstart-deploy)

## Deploy on AWS EKS


This deployment is using nodePort so the following mapping applies:

| Component | nodePort | URL | 
| --- | --- | --- |
| 🌐 Console | 30200 | http://localhost:30200 |
| 🌐 Kafka bootstrap | 30000 | |
| 🌐 Schema Registry | 30500 | http://localhost:30500 |