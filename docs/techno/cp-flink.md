# Confluent Platform for Flink

[The official product documentation after 07/2025 release is here.](https://docs.confluent.io/platform/current/flink/overview.html) 

The main features are:

* Fully compatible with open-source Flink. 
* Deploy on Kubernetes using Helm
* Define environment, which does a logical grouping of Flink applications with the goal to provide access isolation, and configuration sharing.
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

## Specific concepts added on top of Flink

* Environment: for access control isolation, configuration sharing
* Compute pool represents resources to run Task manager and Job manager. Each Flink SQL statement is associated with exactly one Compute Pool. [See example of pool definition](https://docs.confluent.io/platform/current/flink/configure/compute-pools.html) and in [cmf folder](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/k8s/cmf)
* For SQL catalog to group database concept for Flink SQL table queries. It references a Schema Registry instance and one or more Kafka clusters.

## Set up

* [See my dedicated chapter for Confluent Plaform Kubernetes deployment](../coding/k8s-deploy.md#deploy-confluent-platform-for-flink).
* [See the makefile to deploy CMF](https://github.com/jbcodeforce/flink-studies/blob/master/deployment/k8s/cp-flink/Makefile), and the [product documentation](https://docs.confluent.io/platform/current/flink/installation/overview.html) 

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

## Understanding Sizing

The observed core performance rule is that Flink can process ~10,000 records per second per CPU core. This baseline may decrease with larger messages, bigger state, key skew, or high number of distinct keys.

There are a set of characteristics to assess before doing sizing:

### Statement Complexity Impact

Statement complexity reflects the usage of complex operators like:

* Joins between multiple streams
* Windowed aggregations
* Complex analytics functions

*More complex operations require additional CPU and memory resources.*

### Architecture Assumptions

* Source & Sink latency: Assumed to be minimal
* Key size: Assumed to be small (few bytes)
* Minimum cluster size: 3 nodes required
* CPU limit: Maximum 8 CPU cores per Flink node

### State Management & Checkpointing

* Working State: Kept locally in RocksDB
* Backup: State backed up to distributed storage
* Recovery: Checkpoint size affects recovery time
* Frequency: Checkpoint interval determines state capture frequency
* Aggregate state size consumes bandwidth and impacts recovery latency.

### Resource Guidelines

Typical Flink node configuration includes:

* 4 CPU cores with 16GB memory
* Should process 20-50 MB/s of data
* Jobs with significant state benefit from more memory

*Scaling Strategy: Scale vertically before horizontally*

### Latency Impact on Resources
Lower latency requirements significantly increase resource needs:

* Sub-500ms latency: +50% CPU, frequent checkpoints (10s), boosted parallelism
* Sub-1s latency: +20% CPU, extra buffering memory, 30s checkpoints
* Sub-5s latency: +10% CPU, moderate buffering, 60s checkpoints
* Relaxed latency (>5s): Standard resource allocation
*Stricter latency requires more frequent checkpoints for faster recovery, additional memory for buffering, and extra CPU for low-latency optimizations.*

### Estimation Heuristics

The estimator increases task managers until there are sufficient resources for:

* Expected throughput requirements
* Latency-appropriate checkpoint intervals
* Acceptable recovery times
* Handling data skew and key distribution

???- warning "Important Notes"
    * These are estimates - always test with your actual workload
    * Start with conservative estimates and adjust based on testing
    * Monitor your cluster performance and tune as needed
    * Consider your specific data patterns and business requirements

[See this estimator project](https://github.com/jbcodeforce/flink-estimator) for a tool to help estimating cluster sizing.

## Monitoring and Troubleshouting