# Flink Kubernetes Deployment

Flink consists of Job Manager and Task Manager. The Job Manager coordinates the stream processing job, manages job submission and its lifecycle and allocates work to Task Managers. Task Managers execute the actual stream processing logic. Only one active Job Manager and there can be n Task Managers (n replicas).
Failures of Job Manager pods are handled by the Deployment Controller which will take care of spawning a new Job Manager.

Flink uses Checkpointing to periodically store the state of the various stream processing operators on durable storage. When recovering from a failure, the stream processing job can resume from the latest checkpoint. Checkpointing is coordinated by the Job Manager - notably, the Job Manager knows the location of the latest completed checkpoint which will get important later on.

A flow is a packaged as a jar, so need to be in a docker image with the Flink executable.

The setup is describe in [the product doc](https://ci.apache.org/projects/flink/flink-docs-stable/ops/deployment/kubernetes.html#deploy-flink-cluster-on-kubernetes) and can be summarized as:

* Select the execution mode, session or job. For application, just build a dockerfile for your application with Flink jars will make it.
* Deploy a config map to define the `log4j-console.properties` and `flink-conf.yaml`
* Define the job manager service.

The diagram below illustrates the standard deployment of a job on k8s with session mode:

 ![1](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/FlinkOnK8s.svg)
 *src: apache flink site*
 
## Flink application deployment

Here is an example of dockerfile
```
FROM flink
RUN mkdir -p $FLINK_HOME/usrlib
COPY /path/of/my-flink-job-*.jar $FLINK_HOME/usrlib/my-flink-job.jar
```

There is a new way using [native kubernetes](https://ci.apache.org/projects/flink/flink-docs-release-1.11/ops/deployment/native_kubernetes.html) to deploy an application.