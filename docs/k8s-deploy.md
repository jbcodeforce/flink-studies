# Flink Kubernetes Deployment

Flink consists of Job Manager and Task Manager. The Job Manager coordinates the stream processing job, manages job submission and the job lifecycle then allocates work to Task Managers. Task Managers execute the actual stream processing logic. Only one Job Manager is active at a given point of time, and there may be n Task Managers (n replicas).
Failures of Job Manager pods are handled by the Deployment Controller which will take care of spawning a new Job Manager.

A flow is a packaged as a jar, so need to be in a docker image with the Flink executable.

The kubernetes deployment is described in [the product documentation](https://ci.apache.org/projects/flink/flink-docs-release-1.14/deployment/resource-providers/standalone/kubernetes.html) and can be summarized as:

* Select the execution mode: `application, session or job`. For production it is recommended to deploy in `application` mode for better isolation, and usinh a cloud native approach. We can just build a dockerfile for our application using the Flink jars.
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