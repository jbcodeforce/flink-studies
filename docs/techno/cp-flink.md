# Confluent Platform for Flink

[The official documentation after 12/2024 release.](https://docs.confluent.io/platform/current/flink/get-started.html) The main points are:

* Fully compatible with open-source Flink. 
* Deploy on Kubernetes using 

### Metadata management service for RBAC

* [Metadata Service Overview](https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#configure-mds-long-in-cp)
* Single broker [Kafka+MDS Deployment](https://docs.confluent.io/platform/current/kafka/configure-mds/index.html#configure-a-primary-ak-cluster-to-host-the-mds-and-role-binding)
* [Git repo with working CP on K8s deployment using RBAC via SASL/Plain and LDAP](https://github.com/confluentinc/confluent-kubernetes-examples/tree/master/security/production-secure-deploy)
* [Configure CP Flink to use MDS for Auth](https://docs.confluent.io/platform/current/flink/installation/authorization.html)
* [Additional Flink RBAC Docs](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.8/docs/operations/rbac/)
* [How to secure a Flink job with RBAC](https://docs.confluent.io/platform/current/flink/flink-jobs/security.html#how-to-secure-a-af-job-with-cmf-long)
* Best Practices for [K8s + RBAC](https://kubernetes.io/docs/concepts/security/rbac-good-practices/)

### Docker local

[See the cp-all-in-one](https://github.com/confluentinc/cp-all-in-one) for local Confluent platform docker compose files with Flink too.


confluent flink  environemnt create myenv --kubernetes-namespace flink
confluent flink application list --environment myenv