# Confluent Platform for Flink

[The official documentation after 12/2024 release.](https://docs.confluent.io/platform/current/flink/get-started.html) The main points are:

* Fully compatible with open-source Flink. 
* Deploy on Kubernetes using Helm
* Define environment, which group applications
* Deploy application with user interface and task manager cluster
* Exposes custom kubernetes operator for specific CRD
* 

The figure below presents the Confluent Flink components deployed on Kubernetes:

![](./diagrams/cp-flink-deployment.drawio.png)

* CFK supports the management of custom CRD, based as of not on the Flink for Kubernetes Operator
* CMF adds security control, and REST API server for the cli or HTTP client
* FKO is the open source Flink for Kubernetes Operator
* Flink cluster are created from command and CRDs and run Flink applications within an environment

Be sure to have [confluent cli.](https://docs.confluent.io/confluent-cli/current/install.html#install-confluent-cli)

## Local deployment using Minikube

See [product instructions](https://docs.confluent.io/platform/current/flink/get-started.html#step-1-install-cmf-long)

* Start `minikube start --cpus 4 --memory 8048` 
* Add the Confluent Platform repository:

    ```sh
    helm repo add confluentinc https://packages.confluent.io/helm
    helm repo update
    helm repo list
    ```

* Install certificate manager under the `cert-manager` namespace

    ```sh
    kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml
    kubeclt get pods -n cert-manager
    ```

* Create 3 namespaces:

    ```sh
    kubectl create namespace cpf
    kubectl create namespace confluent
    kubectl create namespace flink
    ```

* Install the Flink Kubernetes Operator (FKO), to the default namespace. It can take sometime to pull the image.

    ```sh
    helm upgrade --install cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator --set watchNamespaces={flink}
    ```

* [Install Minio operator](https://min.io/docs/minio/linux/reference/minio-mc.html#quickstart) for object storage, to be able : 

    ```sh
    brew install minio/stable/mc
    # Verify installation
    mc --help
    ``` 

* Install Confluent Manager for Flink using the `cmf` helm chart to the `cpf` namespace:

    ```sh
    helm upgrade --install cmf confluentinc/confluent-manager-for-apache-flink --namespace cpf
    kubectl get pods -n cpf
    ```

* Config minio under minio-dev namespace

    ```sh
    # under deploymenet/k8s/cpf
    kubectl apply -f minio-dev.yaml
    kubectl get pods -n minio-dev
    ```

* Install Confluent Platform (Kafka) operator for kubernetes:

    ```sh
    helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes --namespace confluent
    kubectl apply -f cp-kafka.yaml
    kubectl get pods -n  confluent
    ```

* Do a port forwarding to the CMF REST api, so the Confluent cli can interact with the operator:

    ```sh
    # 
    kubectl get svc -n cpf 
    kubectl port-forward -n cpf svc/cmf-service 8080:80
    ```

* Create a Flink environment

    ```sh
    confluent flink environment create development --kubernetes-namespace flink --url http://localhost:8080
    ```

### Deploy a sample app

* Validate installation with a sample app:

    ```sh
    confluent flink application create --environment development --url http://localhost:8080 example-deployment.json
    ```

* Access Web UI

    ```sh
    confluent flink application web-ui-forward --environment development basic-example --url http://localhost:8080
    ```

* Delete the application

    ```sh
    confluent flink application delete --environment development basic-example --url http://localhost
    ```

### Deploy a custom app using minio

* Setup minio Client, with credential saved to  $HOME/.mc/config.json`

    ```sh
    kubectl port-forward pod/minio 9000 9090 -n minio-dev
    # manage server credentials in configuration file
    mc alias set dev-minio http://localhost:9000 minioadmin minioadmin
    # make a bucket
    mc mb dev-minio/flink
    ```

* Upload application to minio bucket:

    ```sh
    mc cp ./kafka-reader-writer-1.0-SNAPSHOT.jar dev-minio/flink/kafka-reader-writer-1.0-SNAPSHOT.jar
    # list buckets and objects  
    mc ls dev-minio/flink
    ```

* Start application

    ```sh
    confluent flink application create --environment development --url http://localhost:8080 kafka-deployment.json
    # Open web UI
    confluent flink application web-ui-forward --environment development kafka-reader-writer-example --url http://localhost:8080
    ```
    
* Produce messages to kafka topic

    ```sh
    echo 'message1' | kubectl exec -i -n confluent kafka-0 -- /bin/kafka-console-producer --bootstrap-server kafka.confluent.svc.cluster.local:9092 --topic in
    ```
    
* Cleanup

    ```sh
    # the Flink app
    confluent flink application delete kafka-reader-writer-example --environment development --url http://localhost:8080
    # the Kafka cluster
    # the operators
    ```

### Some troubleshooting commands

* Get node resource capacity

    ```sh
    k describe node minikube
    ```

* Use kubectl describe pod <podid> to understand what happen for a pod, and logs on the flink operator.

## Important source of information for deployment

* [Deployment overview](https://docs.confluent.io/platform/current/flink/installation/overview.html) and [for Apache Flink.](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/overview/) 
* [CP Flink supports K8s HA only.](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/ha/kubernetes_ha/)
* [Flink fine-grained resource management documentation.](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/finegrained_resource/)

## Metadata management service for RBAC

* [Metadata Service Overview](https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#configure-mds-long-in-cp)
* Single broker [Kafka+MDS Deployment](https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#configure-a-primary-ak-cluster-to-host-the-mds-and-role-binding)
* [Git repo with working CP on K8s deployment using RBAC via SASL/Plain and LDAP](https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/security/production-secure-deploy)
* [Configure CP Flink to use MDS for Auth](https://docs.confluent.io/platform/current/flink/installation/authorization.html)
* [Additional Flink RBAC Docs](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.8/docs/operations/rbac/)
* [How to secure a Flink job with RBAC](https://docs.confluent.io/platform/current/flink/flink-jobs/security.html#how-to-secure-a-af-job-with-cmf-long)
* Best Practices for [K8s + RBAC](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)

## Docker local

[See the cp-all-in-one](https://github.com/confluentinc/cp-all-in-one) for local Confluent platform docker compose files with Flink too.

Same cli commands:

```sh
confluent flink  environment create myenv --kubernetes-namespace flink --url http://localhost:8080
confluent flink application list --environment myenv --url http://localhost:8080
```

## Monitoring and Troubleshouting