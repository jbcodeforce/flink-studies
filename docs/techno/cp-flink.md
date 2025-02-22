# Confluent Platform for Flink

[The official product documentation after 12/2024 release is here.](https://docs.confluent.io/platform/current/flink/get-started.html) The main points are:

* Fully compatible with open-source Flink. 
* Deploy on Kubernetes using Helm
* Define environment, which group applications
* Deploy application with user interface and task manager cluster
* Exposes custom kubernetes operator for specific CRD


The figure below presents the Confluent Flink components deployed on Kubernetes:

![](./diagrams/cp-flink-deployment.drawio.png)

* CFK supports the management of custom CRD, based as of not on the Flink for Kubernetes Operator
* CMF adds security control, and REST API server for the cli or HTTP client
* FKO is the open source Flink for Kubernetes Operator
* Flink cluster are created from command and CRDs and run Flink applications within an environment

Be sure to have [confluent cli.](https://docs.confluent.io/confluent-cli/current/install.html#install-confluent-cli)

[See dedicated session for Kubernetes deployment](../coding/k8s-deploy.md)



* Install the Flink Kubernetes Operator (FKO), to the default namespace. It can take sometime to pull the image.

    ```sh
    helm upgrade --install cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator --set watchNamespaces={flink}
    ```

* Install Confluent Manager for Flink using the `cmf` helm chart to the `cpf` namespace:

    ```sh
    helm upgrade --install cmf confluentinc/confluent-manager-for-apache-flink --namespace cpf
    kubectl get pods -n cpf
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