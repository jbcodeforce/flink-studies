# Apache Flink on k8s with the Flink operator

This folder includes different deployment manifests for Apache Flink OSS. The approach is to encapsulate some of the kubectl commands using `make` targets. 

See the [Flink kubernetes operator - open source](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-main/) for details.

## Pre-requisites

* [See the pre-requisites note for CLIs installation and other general dependencies](https://github.com/jbcodeforce/flink-studies/coding/k8-deploy/#pre-requisites)

* Access to a Kubernetes cluster: `make start_colima`
* Update the CERT_MGR_VERSION=v1.18.2 and FLINK_OPERATOR_VERSION=1.18.2 in the Makefile. See [Certification Release version here](https://github.com/cert-manager/cert-manager/) (1.18.2 as of 09/2025) and [K9s operator tags](https://github.com/apache/flink-kubernetes-operator/tags)
* Install certification manager (only one time per k8s cluster):

```sh
make deploy_cert_manager
# verify
kubeclt get pods -n cert-manager
```

* Create `flink-oss` namespace: `make create_ns`
* To avoid operator conflict, when Confluent for Flink is not installed, install the Apache Flink Kubernetes operator.
    ```sh
    make update_helm_flink_repo
    make prepare
    make verify_flink
    ```
* In case Confluent Platform for flink is installed, we may want to use the different deployments to deploy Apache flink:

  * Session deployment:
    ```sh
    kubectl apply -f  flink-configuration-configmap.yaml 
    kubectl get cm
    kubectl apply -f jobmanager-service.yaml 
    kubectl apply -f jobmanager-rest-service.yaml 
    kubectl apply -f jobmanager-session-deployment-non-ha.yaml
    kubectl get pods
    kubectl apply -f taskmanager-session-deployment.yaml
    ```

  * Previous steps are done with:
    ```sh
    make deploy_jobmanager
    make deploy_taskmanager 
    make flink_console
    ```

* Do port forwarding
  ```sh
  kubectl port-forward ${flink-jobmanager-pod} 8081:8081
  # or
  make flink_console
  ```

* [Access Flink UI](http://localhost:8081)

(See also the [Flink pre-requisites documentation.](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/docs/try-flink-kubernetes-operator/quick-start/))

* (Optional add Kafbat-ui helm repo):

```sh
helm repo add kafbat-ui https://kafbat.github.io/helm-charts
```

* Install Minio to persist jar or expose object storage in the K8S cluster. [See Minio quickstart](https://min.io/docs/minio/linux/reference/minio-mc.html#quickstart) and [the minio section in k8s deployment chapter.](https://jbcodeforce.github.io/flink-studies/coding/k8s-deploy/#using-minio)


## Deploy Apache Flink Applications

* A basic predefined Flink app

    ```sh
    make deploy_basic_flink_deployment  
    ```
* [Access Flink UI](http://localhost:8081)


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

