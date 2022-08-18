# Flink Kubernetes Deployment

Flink consists of Job Manager and Task Manager. The Job Manager coordinates the stream processing job, manages job submission and the job lifecycle then allocates work to Task Managers. Task Managers execute the actual stream processing logic. Only one Job Manager is active at a given point of time, and there may be n Task Managers (n replicas).
Failures of Job Manager pods are handled by the Deployment Controller which will take care of spawning a new Job Manager.

A flow is a packaged as a jar, so need to be in a docker image with the Flink executable.

Flink offers [now a k8s Operator](https://flink.apache.org/news/2022/04/03/release-kubernetes-operator-0.1.0.html) to deploy and manage applications. This note summarize how to use this operator, with basic getting started yaml files.

The operator takes care of submitting, savepointing, upgrading and generally managing Flink jobs using the built-in Flink Kubernetes integration.

## Deploy operator

* Install [helm cli](https://github.com/helm/helm/releases).

    ```sh
    helm version
    # version.BuildInfo{Version:"v3.9.0", GitCommit:"7ceeda6c585217a19a1131663d8cd1f7d641b2a7", GitTreeState:"clean", GoVersion:"go1.17.5"}
    ```
* Verify helm on the OpenShift cluster has access to repository

    ```sh
    helm repo add stable https://charts.helm.sh/stable 
    # update repo
    helm repo update
    ```
* Add Flink repository

    ```sh
    helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.0.1/
    # Verify help repo entry exist
    helm repo list
    # Be sure to change the repo as the URL may not be valid anymore
    helm repo remove  flink-operator-repo
    # try to update repo content
    helm repo update
    ```

* Install operator:

```sh
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator
# output
NAME: flink-kubernetes-operator
LAST DEPLOYED: Thu Jul 28 19:00:31 2022
NAMESPACE: flink-demo
STATUS: deployed
REVISION: 1
TEST SUITE: None
# change the user to be one supported by OpenShift

# then verify deployment with 
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

## Submit flink job

* Select the execution mode: `application, session or job`. For production it is recommended to deploy in `application` mode for better isolation, and using a cloud native approach. We can just build a dockerfile for our application using the Flink jars.
* Deploy a config map to define the `log4j-console.properties` and other parameters for Flink (`flink-conf.yaml`)
* Define the job manager service.

The diagram below illustrates the standard deployment of a job on k8s with session mode:

 ![1](https://ci.apache.org/projects/flink/flink-docs-release-1.14/fig/FlinkOnK8s.svg)
 *src: apache Flink site*
 
But there is a new way using [native kubernetes](https://ci.apache.org/projects/flink/flink-docs-release-1.14/deployment/resource-providers/native_kubernetes.html) to deploy an application. Flink is able to dynamically allocate and de-allocate TaskManagers depending on the required resources because it can directly talk to Kubernetes.

## Flink Session

A Flink Session cluster is executed as a long-running Kubernetes Deployment. You can run multiple Flink jobs on a Session cluster. Each job needs to be submitted to the cluster after the cluster has been deployed.
It needs at least three components:

* a Deployment which runs a JobManager
* a Deployment for a pool of TaskManagers
* a Service exposing the JobManager’s REST and UI ports

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