# Flink Kubernetes Deployment

Flink consists of Job Manager and Task Manager. The Job Manager coordinates the stream processing job, manages job submission and the job lifecycle then allocates work to Task Managers. Task Managers execute the actual stream processing logic. Only one Job Manager is active at a given point of time, and there may be n Task Managers (n replicas).
Failures of Job Manager pods are handled by the Deployment Controller which will take care of spawning a new Job Manager.

A flow is a packaged as a jar, so need to be in a docker image with the Flink executable.

Flink offers [a k8s Operator](https://flink.apache.org/news/2022/04/03/release-kubernetes-operator-0.1.0.html) to deploy and manage applications. This note summarize how to use this operator, with basic getting started yaml files.

The operator takes care of submitting, savepointing, upgrading and generally managing Flink jobs using the built-in Flink Kubernetes integration.

## Pre-requisites

* Be sure to have helm: `brew install helm`

```sh
helm version
# version.BuildInfo{Version:"v3.9.0", GitCommit:"7ceeda6c585217a19a1131663d8cd1f7d641b2a7", GitTreeState:"clean", GoVersion:"go1.17.5"}
```

* Install certitication manager once per k8s cluster: `kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml`
* Get the [list of Flink releases here](https://downloads.apache.org/flink/)
* Add Helm repo: 

```sh
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.9.0
# Verify help repo entry exist
helm repo list
# Be sure to change the repo as the URL may not be valid anymore
helm repo remove  flink-operator-repo
# try to update repo content
helm repo update
```

## Deploy Flink operator

Flink Kubernetes Operator acts as a control plane to manage the complete deployment lifecycle of Apache Flink applications.

```sh
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator

# output
NAME: flink-kubernetes-operator
LAST DEPLOYED: Thu Jul 28 19:00:31 2022
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

* Then verify deployment with 

```sh
helm list
NAME                      NAMESPACE   REVISION  UPDATED                            STATUS  CHART APP VERSION
flink-kubernetes-operator flink-demo  1    	2022-07-28 19:00:31.459524 -0700 PDT	deployed flink-kubernetes-operator-1.0.1	1.0.1
```

* If the pod is not running verify in the deployment the condition, we may need to add

```sh
 oc adm policy add-scc-to-user privileged -z default
```

and remove runAs elements in the deployment.yaml.

To remove the operator

```sh
helm uninstall flink-kubernetes-operator
```


## Flink Session

A Flink Session cluster is executed as a long-running Kubernetes Deployment. We may run multiple Flink jobs on a Session cluster. Each job needs to be submitted to the cluster after the cluster has been deployed.
To deploy a job we need at least three components:

* a Deployment which runs a JobManager
* a Deployment for a pool of TaskManagers
* a Service exposing the JobManager’s REST and UI ports


For a deployment select the execution mode: `application, or session`. For production it is recommended to deploy in `application` mode for better isolation, and using a cloud native approach. We can just build a dockerfile for our application using the Flink jars.

### Do Session Deployment

See some [product examples](https://github.com/apache/flink-kubernetes-operator/tree/main/examples). See my manifests in `deployment/k8s` folder.

* Deploy the JobManager and TaskManager to support session management

```sh
k apply -f basic-job-task-mgrs.yaml 
```

* Submit jobs with dedicated yaml: (change with the jar of the app to deploy)

```yaml
apiVersion: flink.apache.org/v1beta1
kind: FlinkSessionJob
metadata:
  name: job-only-example
spec:
  deploymentName: job-deployment-only-example
  job:
    jarURI: https://repo1.maven.org/maven2/org/apache/flink/flink-examples-streaming_2.12/1.16.1/flink-examples-streaming_2.12-1.16.1-TopSpeedWindowing.jar
    parallelism: 4
    upgradeMode: stateless
```

* Example of deploying Java based [SQL Runner](https://github.com/apache/flink-kubernetes-operator/blob/main/examples/flink-sql-runner-example/README.md) to interprete a sql script, package it as docker images, and deploy it with a Session Job. There is a equivalent for Python using [Pyflink](https://nightlies.apache.org/flink/flink-docs-release-1.18/docs/dev/python/overview/).

    * [See the ported code for Java](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/sql-runner)
    * And for the [Python implementation](https://github.com/jbcodeforce/flink-studies/tree/master/flink-sql-demos/flink-python-sql-runner)



---

## Submit flink job

* Deploy a config map to define the `log4j-console.properties` and other parameters for Flink (`flink-conf.yaml`)


The diagram below illustrates the standard deployment of a job on k8s with session mode:

 ![1](https://ci.apache.org/projects/flink/flink-docs-release-1.14/fig/FlinkOnK8s.svg)
 *src: apache Flink site*
 
But there is a new way using [native kubernetes](https://ci.apache.org/projects/flink/flink-docs-release-1.14/deployment/resource-providers/native_kubernetes.html) to deploy an application. Flink is able to dynamically allocate and de-allocate TaskManagers depending on the required resources because it can directly talk to Kubernetes.

## Flink application deployment

The following Dockerfile is used for deploying a solution in **application mode**, which package the Flink jars with the app, and starts the main() function.

```dockerfile
FROM flink
RUN mkdir -p $FLINK_HOME/usrlib
COPY /path/of/my-flink-job-*.jar $FLINK_HOME/usrlib/my-flink-job.jar
```

As an example the `kafka-flink-demo` has such dockerfile.

We need to define following components (See yaml files in the `kafka-flink-demo`):

* an Application which runs a JobManager
* Deployment for a pool of TaskManagers
* Service exposing the JobManager’s REST and UI ports

The Application Mode makes sure that all Flink components are properly cleaned up after the termination of the application.