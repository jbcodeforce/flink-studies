# Cluster & Environment Management

## 1- Provisioning and Scaling Clusters

### 1.1 Bring up new cluster/environment.
#### Context
Use this when you need a new Flink environment (e.g., dev / stage / prod or a new region) backed by one of:

* Confluent Cloud environment
* A Kubernetes cluster (new or existing).
* CP Flink components installed via Helm (Flink K8s Operator + CMF).
* An existing Kafka cluster (Confluent Platform or Confluent Cloud).

Out of scope: deep infra provisioning automation, this focuses on the Flink layer once K8s and Kafka exist.

The Components to install for each deployment approach:

=== "Confluent Platform"
    In the context of a Confluent Platform deployment, the components to install are represented in the following figure from bottom to higher layer:

    ![](../coding/diagrams/cp_comp_to_deploy.drawio.png)

=== "Open Source Approach"
    For an equivalent open source the components are:

    ![](../coding/diagrams/oss_comp_to_deploy.drawio.png)

=== "Confluent Cloud"
    Confluent Cloud is a serverless SaaS. The deployment includes the following components, deployable via infrastructure as code:

    ![](./diagrams/cc-comp.drawio.png)

#### Preconditions / Checklist

* kubectl, helm, confluent CLIs
* Sizing / T-shirt: from [Project estimator](https://github.com/jbcodeforce/flink-estimator): Rough T-shirt size for CMF, operator, JobManagers, TaskManagers (CPU, memory) based on expected jobs and throughput.
* Information about Kafka bootstrap endpoints, schema registry URL
* Durable Storage for State: Object store or filesystem accessible from all K8s nodes (e.g., S3/GCS/minio, HDFS) for checkpoints/savepoints.

#### Inputs / Parameters
The following potential parameters may be needed to externalize:

**For Private Deployment**

* K8S_NAMESPACE_CMF (e.g., cpf)
* K8S_NAMESPACE_FLINK (e.g., flink)
* CMF_HELM_VERSION (e.g., ~2.1.0)
* FKO_HELM_VERSION (e.g., ~1.130.0)
* CHECKPOINT_URI (e.g., s3://my-bucket/flink/checkpoints/)
* SAVEPOINT_URI (optional, e.g., s3://my-bucket/flink/savepoints/)
* ENV_NAME (e.g., development, staging, prod)

**For Confluent Cloud**

* CONFLUENT_CLOUD_API_KEY
* CONFLUENT_CLOUD_API_SECRET
* CONFLUENT_CLOUD_REST_ENDPOINT
* KAFKA_API_KEY
* KAFKA_API_SECRET
* KAFKA_CLUSTER_ID

#### Procedure

We list here the high level steps. For [dedicated chapter on Kubernetes deployment](../coding/k8s-deploy.md)

For **Apache Flink or Confluent Platform:**

1. Prepare Kubernetes Namespaces
* Install Flink Kubernetes Operator (FKO)
* Install Confluent Manager for Apache Flink (CMF) - Not need for pure Apache Flink
* Configure Durable Storage for State
* Expose CMF API for Environment Management
* Create a Flink Environment (Logical Environment)
* Smoke-Test with an Example Application

#### Gotchas
* Durable storage is not optional in production; losing it means losing consistent recovery 
* For multi-namespace or multi-cluster topologies, leverage CMF’s multi-cluster support
* Adopting a declarative configuration for all applications and infrastructure components deployed to Kubernetes clusters with ArgoCD: [see this repository](https://github.com/osowski/confluent-platform-gitops) to present a GitOps for Confluent Platform deployment running on Kubernetes.

### 1.2 Adjust cluster resources (more TaskManagers, more slots).

#### Context
Use this when a Flink job or compute pool is under-provisioned: sustained backpressure, growing Kafka lag, or repeated “NoRecentCheckpoints”/resource exhaustion alerts or when on Confluent Cloud the statement becomes `Degraded`. 

**Confluent Platform for Flink or Apache Flink:**

When you need to increase or decrease the cluster’s capacity by adding/removing TaskManagers, or by changing `taskmanager.numberOfTaskSlots` (slots per TM).

This recipe is primarily cluster/platform facing; job-level parallelism tuning is covered in a separate “Scale a Flink Job” recipe.

Always try to clarify the goal:

* Reduce backpressure / lag.
* Accommodate larger state (checkpoints/savepoints, RocksDB state) or Statement State becoming too big.
* Support more concurrent jobs/statements in a shared pool.

#### Preconditions / Checklist

* Have a good understanding of the performance situation with observability stack like Grafana dasboards and other metrics
* Get a clear assessment of the current number of Task managers and task slots per task manager
* Confirm current job parallelism and utilization
* Revisit current traffic pattern, versus the one used for platform sizing

#### Inputs / Parameters

* Current compute pool limits
* Current number of jobs per compute pool

#### Procedure

1. Diagnose whether you need more TMs, more Slots, or both. Check TM utilization and slot usage:
    * Are TaskManagers at or near 100% busy?
    * Are all slots occupied? Are there idle slots but backpressure at specific operators?
* Check compute-pool / CFU limits (CP Flink / CCFlink): Ensure your target TM count/size stays within declared the limit; large TMs and more slots affect costs.
* Adjust TaskManager count for horizontal scaling - (CP and OSS). 
    * Adjust max CFU per compute pool, add more compute pool in Confluent Cloud. TM count is controlled indirectly via compute pool CFU and Autopilot/DSA; horizontal scaling is typically automatic.
    * For operator-only K8s Flink, TM count commonly set via deployment/Helm values for the TaskManager deployment (e.g., replicas in K8s or CFK spec).

* Monitor - Check that:
    * Backpressure decreases.
    * Checkpoint durations stabilize or drop (CP or OSS).
    * TM CPU/memory are in a reasonable range (no massive under-utilization).

* (Optional) Scale down later (CP or OSS): Once load drops, you can scale TMs down again to save resources. In CCFlink Autopilot will handle this automatically.
* Adjust Slots Per TaskManager (Vertical Slot Scaling). Change `taskmanager.numberOfTaskSlots` to alter concurrency per TM. Get at least one core per busy slot for non-trivial jobs.

???- info "Understand slot semantics"
    Each TaskManager is a JVM process; each slot is a fixed share of that TM’s resources. More slots per TM = more tasks sharing CPU, heap, network and disk; good for many small jobs, risky for heavy jobs.

    Update slot configuration. In a FlinkApplication / K8s spec (CP Flink example):
    ```json
        "flinkConfiguration": {
        "taskmanager.numberOfTaskSlots": "2"
        }
    ```

    Changing taskmanager.numberOfTaskSlots typically requires restarting TaskManagers

    Watch for increased GC pressure and longer checkpoint times. Assess disk I/O saturation (RocksDB state, shuffle).

#### Rollback

If the change makes things worse (more instability, timeouts, cost spikes):

* Revert TM Count / Slots
* If jobs fail or degrade: Temporarily move the most critical jobs to a separate, known-good pool / cluster with conservative settings. Then investigate per-job parallelism / skew, the RocksDB / disk hot spots, the autoscaler behavior.
* Document Effective Settings

## 2- Upgrading Flink and Cluster Components

### 2.1 Upgrade Flink minor/patch versions.
#### Context
#### Preconditions / Checklist
#### Inputs / Parameters
#### Procedure
#### Rollback
#### Gotchas
### 2.2  Rolling upgrades and compatibility considerations.
#### Context
#### Preconditions / Checklist
#### Inputs / Parameters
#### Procedure
#### Rollback
#### Gotchas
## 3 Disaster Recovery & Multi-Region Strategies
### 3.1 Backup/restore of state backend.
#### Context
#### Preconditions / Checklist
#### Inputs / Parameters
#### Procedure
#### Rollback
#### Gotchas
### 3.2 Active-active / active-passive patterns.
#### Context
#### Preconditions / Checklist
#### Inputs / Parameters
#### Procedure
#### Rollback
#### Gotchas