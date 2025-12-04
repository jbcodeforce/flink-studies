
# Sizing

Sizing a Flink cluster is a complex process influenced by many factors, including workload demands, application logic, data characteristics, expected state size, required throughput and latency, concurrency, and hardware. 

Because of those variables, every Flink deployment needs a unique sizing approach. The most effective method is to run a real job, on real hardware and tune Flink to that specific workload.

For architects seeking sizing guidance, it's helpful to consider:

* the workload semantic complexity, with the usage of aggregations, joins, windows, processing type, 
* the input throughput (MB/s or records/second), 
* the expected state size (GB), 
* the expected latency.

While Kafka sizing estimates are based on throughput and latency, this is a very crude method for Flink, as it overlooks many critical details. 

For new Flink deployments, a preliminary estimate can be provided, but it's important to stress its inexact nature. 
A simple Flink job can process approximately **10,000 records per second per CPU**. However, a more substantial job, based on benchmarks, might process closer to 5,000 records per second per CPU. Sizing may use record size, throughput, and Flink statement complexity to estimate CPU load.

### CP Flink Estimation


I tentatively built a [flink-estimator webapp](https://github.com/jbcodeforce/flink-estimator) with backend estimator for Apache Flink or Confluent Platform Cluster sizing.

The tool needs to be simple, so it persists the estimation as json on the local disk. 

To access this web app there is a docker image at [dockerhub - flink-estimator](https://hub.docker.com/repository/docker/jbcodeforce/flink-estimator/general). 

The approach is to clone the repository: [https://github.com/jbcodeforce/flink-estimator](https://github.com/jbcodeforce/flink-estimator) 

* use `docker-compose up -d` 
* deploy it to a local kubernetes cluster: 
    ```sh
    kubectl apply -k k8s
    ``` 

* Access via web browser [http://localhost:8002/](http://localhost:8002/)

![](./images/flink-estimator.png)

### CC Flink Estimation

The focus on Confluent Cloud Flink is to assess the number of CFU per statements.