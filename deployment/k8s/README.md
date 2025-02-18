# Flink on k8s with the operator (Open-source or Confluent Platform)

The approach is to simplify the commands using `make`. Confluent on kubernetes is a k8s operator based, so the makefile can install the Confluent Platform operator and the open-source flink operator.

[Flink operator - open source](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/deployment/resource-providers/standalone/kubernetes/)

[Confluent platform for flink operator](https://docs.confluent.io/platform/current/flink/get-started.html)

## Pre-requisites

Any Flink on Kubernetes deployment should include the following pre-requisites:

* Be sure to have helm cli installed: ([see installation instructions](https://helm.sh/docs/intro/install/))

```sh
# for mac
brew install helm
# for WSL2 - ubuntu
sudo apt-get install helm
```

* Get the [list of Flink releases and tags here](https://downloads.apache.org/flink/) or [Confluent one](https://docs.confluent.io/platform/current/installation/versions-interoperability.html#cp-af-compat)
* Add Helm repo: 

```sh
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.9.0
# or Confluent
helm repo add confluentinc https://packages.confluent.io/helm
# Verify help repo entry exist
helm repo list
# Be sure to change the repo as the URL may not be valid anymore
helm repo remove  flink-operator-repo
# try to update repo content
helm repo update
```

* Access to a Kubernetes cluster
* Get kubectl cli
* Install [Confluent plugin for kubectl](https://docs.confluent.io/operator/current/co-deploy-cfk.html#co-install-plugin)
* Install certification manager (only one time per k8s cluster): See [Release version here.](https://github.com/cert-manager/cert-manager/)

```sh
make deploy_cert_manager
# or explicitly using:
kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.16.2/cert-manager.yaml
```

* Install the Flink Kubernetes operator (See below)

(See also the [Flink pre-requisites documentation.](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/docs/try-flink-kubernetes-operator/quick-start/))

* (Optional add Kafbat-ui helm repo):

```sh
helm repo add kafbat-ui https://kafbat.github.io/helm-charts
```

* Install Minio to persist jar or expose object storage in the K8S. [See Minio quickstart.](https://min.io/docs/minio/linux/reference/minio-mc.html#quickstart)


### Setup the environment with minikube

1. Start minikube

    ```sh
    minikube start --cpus 4 --memory 8g --driver docker
    ```

1. Start `minikube dashboard`

### Setup with Colima

1. Start colima:

```sh
colima start --cpu 4 --memory 10 --kubernetes
# or under deployment/k8s
make start_colima
```

## Deploy Flink

1. Create `flink` and `confluent` namespaces: `make create_ns`

1. Deploy Confluent Platform Flink operator:

    ```sh
    make deploy_cp_flink_operator
    ```

1. Deploy Confluent Manager for Apache Flink

    ```sh
    make deploy_cmf
    ```

1. Define a Flink environment:

    ```sh
    # in one terminal
    kubectl port-forward svc/cmf-service 8080:80 -n flink
    # in a second terminal
    make create_flink_env
    ```

1. To change the kubectl context to use Flink namespace the command is:

    ```sh
    kubectl config set-context --current --namespace=flink
    ```

1. Validate installation with simple application job

    Deploy a stateless app and validate it runs with the Flink Dashboard

    ```sh
    make deploy_flink_demo_app

    confluent flink application web-ui-forward flink-basic-example --environment env1 --port 8090 --url http://localhost:8084
    ```

1. Undeploy this application

    ```sh
    confluent flink application delete flink-basic-example --environment env1  --url http://localhost:8084
    ```

## Deploy Confluent Platform

1. Deploy Confluent Platform operator to get Kafka brokers deployed

    ```sh
    make deploy_cp_operator
    ```

1. Or use one command to do all the previous steps: `make install_operators`

1. Verify the k8s deployment for the operator

    ```sh
    k describe deployment flink-kubernetes-operator
    ```

1. Verify Confluent Platform for Kubernetes operator

    ```sh
    k describe deployment confluent-operator
    ```

1. Deploy Confluent Kafka Broker using one Kraft controller, one broker, with REST api and schema registry

    ```sh
    make deploy_cp_cluster
    # Validate endpoints
    make display_kafka_endpoints 
    ```

1. Use Kafbat UI

    ```sh
    make deploy_kafbat_ui
    ```

* To connect a local producer running on the host machine we need to add in /etc/hosts the alias to localhost as ` kafka-0.kafka.confluent.svc.cluster.local` as even if we do a port-forward from the kafka broker pod to 9092 then returned url is the dns name.

* To change the kubectl context  to use Confluent namespace the command is:

```sh
kubectl config set-context --current --namespace=confluent
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

```
The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
my-prometheus-prometheus-pushgateway.default.svc.cluster.local


Get the PushGateway URL by running these commands in the same shell:
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