# Confluent Platform for Flink

[The official product documentation after 12/2024 release is here.](https://docs.confluent.io/platform/current/flink/get-started.html) 

The main features are:

* Fully compatible with open-source Flink. 
* Deploy on Kubernetes using Helm
* Define environment, which groups applications
* Deploy application with user interface and task manager cluster
* Exposes custom kubernetes operator for specific CRD

The figure below presents the Confluent Flink components deployed on Kubernetes:

<figure markdown="span">
![1](./diagrams/cp-flink-deployment.drawio.png)
<figcaption>Confluent Platform for Flink</figcaption>
</figure>

* CFK supports the management of custom CRD, based on the Flink for Kubernetes Operator. (CFK 3.0.0 supports CP 8.0.0)
* CMF (Confluent Manager for Apache Flink) adds security control, and a REST API server for the cli or a HTTP client
* FKO is the open source Flink for Kubernetes Operator
* Flink cluster are created from command and CRDs and run Flink applications within an environment

Be sure to have [confluent cli.](https://docs.confluent.io/confluent-cli/current/install.html#install-confluent-cli)

[See dedicated chapter for Kubernetes deployment](../coding/k8s-deploy.md#deploy-confluent-platform-for-flink).

## Important source of information for deployment

* [Confluent Platform deployment using kubernetes operator](https://docs.confluent.io/operator/current/co-deploy-cp.html#co-deploy-cp)
* [Deployment overview](https://docs.confluent.io/platform/current/flink/installation/overview.html) and [for Apache Flink.](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/overview/) 
* [CP Flink supports K8s HA only.](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/ha/kubernetes_ha/)
* [Flink fine-grained resource management documentation.](https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/finegrained_resource/)
* [CP v8 announcement](https://www.confluent.io/blog/introducing-confluent-platform-8-0/): builds on Kafka 4.0, next-gen Confluent Control Center (integrating with the open telemetry protocol (OTLP),  Confluent Manager for Apache Flink® (CMF)), Kraft native (support significantly larger clusters with millions of partitions), Client-Side field level encryption. CP for Flink support SQL, Queues for Kafka is now in Early Access, 

## Metadata management service for RBAC

* [Metadata Service Overview](https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#configure-mds-long-in-cp)
* Single broker [Kafka+MDS Deployment](https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#configure-a-primary-ak-cluster-to-host-the-mds-and-role-binding)
* [Git repo with working CP on K8s deployment using RBAC via SASL/Plain and LDAP](https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/security/production-secure-deploy)
* [Configure CP Flink to use MDS for Auth](https://docs.confluent.io/platform/current/flink/installation/authorization.html)
* [Additional Flink RBAC Docs](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.8/docs/operations/rbac/)
* [How to secure a Flink job with RBAC](https://docs.confluent.io/platform/current/flink/flink-jobs/security.html#how-to-secure-a-af-job-with-cmf-long)
* Best Practices for [K8s + RBAC](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)


## Monitoring and Troubleshouting