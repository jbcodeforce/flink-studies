# Apache Flink Studies


???- info "Update"
    Created 2018 Updated 10/2024
    
## Why Flink?

In classical IT architecture, we can see two types of data processing: transactional and analytics. 
With 'monolytics' application, the database system serves multiple applications which sometimes access the same database instances and tables. This approach causes problems to support evolution and scaling. 
Microservice architecture addresses part of those problems by isolating data storage per service. 

To get insight from the data, the traditional approach is to develop data warehouse and ETL jobs to copy and transform data from the transactional systems to the warehouse. ETL processes extract data from a transactional database, transform data into a common representation that might include validation, value normalization, encoding, deduplication, and schema transformation, and finally load the new records into the target analytical database. They are batches and run periodically.

From the data warehouse, the analysts build queries, metrics, and dashboards / reports to address a specific business question. 

Massive storage is needed, which uses different protocol such as: NFS, S3, HDFS...

Today, there is a new way to think about data, by considering them, as continuous streams of events, which can be processed in real time. Those event streams serve as the foundation for stateful stream processing applications: the analytics move to the data.

We can define three classes of application implemented with stateful stream processing:

1. **Event-driven applications**: to adopt the reactive manifesto for scaling, resilience, responsive application, leveraging messaging as communication system.
1. **Data pipeline applications**: to replace ETL with low latency stream processing for data transformation, enrichment....
1. **Data analytics applications**: to compute aggregates; and to immediately act on the data and query live updated reports. 

For more real industry use cases content see the [Flink Forward web site.](https://www.flink-forward.org/)

## The What 

[Apache Flink](https://flink.apache.org) (2016) is a framework and **distributed processing** engine for stateful computations over unbounded and bounded data streams. Flink supports batch (data set) and graph (data stream) processing. Since few years it becomes standard for its performance and rich feature set. 

It is based on four important capabilities:

* Streaming
* State
* Time
* Checkpoint

Flink is very good at:

* Very low latency processing with event time semantics to get consistent and accurate results even in case of out of order events.
* Exactly once state consistency. 
* Millisecond latencies while processing millions of events per second
* Expressive and easy-to-use APIs: map, reduce, join, window, split, and connect...
* Fault tolerance, and high availability: supports worker and master failover, eliminating any single point of failure
* Support Java, Scala, Python and SQL to implement the streaming logic.
* A lot of connectors to integrate with Kafka, Cassandra, Pulsar, Elastic Search, JDBC, S3...
* Support container and deployment on Kubernetes
* Support updating the application code and migrate jobs to different Flink clusters without losing the state of the application
* Also support batch processing

The figure below illustrates those different models combined with [Zepellin](https://zeppelin.apache.org/) as a multi purpose notebook to develop data analytic projects on top of Spark, Python or Flink.


 ![Flink components](./images/arch.png)


## Stream processing concepts

* A Flink application is run as a **job** and represents a topology of nodes, which is a processing pipeline. It is also named Dataflow.
* Dataflows may be transformed by user-defined operators. Each step of the graph is executed by an operator. These dataflows form directed acyclic graphs that start with one or more sources, and end in one or more sinks.
* Sources get data from a stream, like Kafka topic/partition.

![](./diagrams/dag.drawio.png)

* The source operator forwards records to the downstream operators
* The graph can run in parellel while consuming from different partitions
* Operator can filter records out of the streams or do enrichments
* Operators can also run in parallel after data redistribution.
* Some operators, like **Group by**, need to do reshuffling or repartitioning of the data to the operator, or do a reblancing to merge streams.


### Bounded and unbounded data

A Stream is a sequence of events, bounded or unbounded:

![](./diagrams/streaming.drawio.png)

### Dataflow


In [Flink](https://ci.apache.org/projects/flink/flink-docs-release-1.12/learn-flink/#stream-processing), applications are composed of streaming dataflows. Dataflow can consume from Kafka, Kinesis, Queue, and any data sources. A typical high level view of Flink app is presented in figure below:

 ![2](https://ci.apache.org/projects/flink/flink-docs-release-1.12/fig/flink-application-sources-sinks.png)

 *src: apache Flink product doc*

The figure below, from the product documentation, summarizes the APIs used to develop a data stream processing flow:

 ![1](https://ci.apache.org/projects/flink/flink-docs-release-1.19/fig/program_dataflow.svg)
 
 *src: apache Flink product doc*


Stream processing includes a set of functions to transform data, and to produce a new output stream. Intermediate steps compute rolling aggregations like min, max, mean, or collect and buffer records in time window to compute metrics on a finite set of events. 

### Distributed platform

To improve throughput the data is partitionned so operators can run in parallel. Programs in Flink are inherently parallel and distributed. During execution, a stream has one or more stream partitions, and each operator has one or more operator subtasks.

 ![3](https://ci.apache.org/projects/flink/flink-docs-release-1.12/fig/parallel_dataflow.svg)

 *src: apache Flink site*

Some operations, such `group-by` or `count`,  may reshuffle or repartition the data. This is a costly operation, that involves serialization and sending data over the network. Finally events can be assigned to one sink via rebalancing from multiple streams to one. Here is an example of SQL streaming logic with where statement can be run in parallel; while grouping, repartition the streams and then rebalance to one sink:

```sql
INSERT INTO results
SELECT color, COUNT(*) FROM events
WHERE color <> blue
GROUP BY color;
```

To properly define window operator semantics, developers need to determine both how events are assigned to buckets and how often the window produces a result. Flink's streaming model is based on windowing and checkpointing, it uses controlled cyclic dependency graph as its execution engine.

The following figure is showing integration of stream processing runtime with an append log system, like Kafka, with internal local state persistence and continuous checkpointing to remote storage as HA support:

![](./diagrams/flink-rt-processing.drawio.png)

Using a local state persistence, improves latency, while adopting a remote backup storage increases fault tolerance.


### Checkpointing

As part of the checkpointing process, Flink saves the 'offset read commit' information of the append log, so in case of a failure, Flink recovers a stateful streaming application by restoring its state from a previous checkpoint and resetting the read position on the append log.

The evolution of microservice is to become more event-driven, which are stateful streaming applications that ingest event streams and process the events with application-specific business logic. This logic can be done in flow defined in Flink and executed in the clustered runtime.

![](./images/evt-app.png)

Transform operators can be chained. 

A Flink application, may be stateful, runs in parallel on a distributed cluster. The various parallel instances of a given operator execute independently, in separate threads, and in general run on different machines.

State is always accessed locally, which helps Flink applications achieve high throughput and low-latency. Developers can choose to keep state on the JVM heap, or if it is too large, save it on-disk.

 ![4](https://ci.apache.org/projects/flink/flink-docs-release-1.12/fig/local-state.png)

## Runtime architecture

This is the Job Manager component which parallelizes the job and distributes slices of [the Data Stream](https://ci.apache.org/projects/flink/flink-docs-stable/dev/datastream_api.html) flow, the developers have defined.Each parallel slice of the job is executed in a **task slot**.  Once the job is submitted, the **Job Manager** is scheduling the job to different task slots within the **Task Manager**. The Job manager may create resources from a computer pool, or in kubernetes deployment, it creates pods. 

 ![5](https://ci.apache.org/projects/flink/flink-docs-release-1.12/fig/distributed-runtime.svg)

Once the job is running, the Job Manager is responsible to coordinate the activities of the Flink cluster, like checkpointing, and restarting task manager that may have failed.

Tasks are loading the data from sources, do their own processing and then send data among themselves for repartitioning and rebalancing, to then push results out to the sinks.

When Flink is not able to process a real-time event, it may have to buffer it, until other necessary data has arrived. This buffer has to be persisted in longer storage, so data are not lost if a task manager fails and has to be restarted. In batch mode, the job can reload the data from the beginning. In batch the results are computed once the job is done (count the number of record like `select count(*) AS `count` from bounded_pageviews;` return one result), while in streaming, each event may be the last one recieved, so results are produced incrementally, after every events or after a certain period of time based on timers.


???- "Parameters"
    *  taskmanager.numberOfTaskSlots: 2

Once Flink is started (for example with the docker image), Flink Dashboard [http://localhost:8081/#/overview](http://localhost:8081/#/overview) presents the execution reporting:

 ![6](./images/flink-dashboard.png)

The execution is from one of the training examples, the number of task slot was set to 4, and one job is running.

Spark Streamin is using microbatching which is not a true real-time processing while Flink is. Both Flink and Spark support batch processing. 


## Stateless

Some applications support data loss and expect fast recovery times in case of failure and are always consuming the latest incoming data: Alerting applications where only low latency alerts are useful, fit into this category. As well as applications where only the last data received is relevant. 

When checkpointing is turned off Flink offers no inherent guarantees in case of failures. This means that you may either have data loss or duplicate messages combined always with a loss of application state.

## Statefulness

When using aggregates or windows operators, states need to be kept. For fault tolerance, Flink uses checkpoints and savepoints. 

**Checkpoints** represent a snapshot of where the input data stream is with each operator's state. A streaming dataflow can be resumed from a checkpoint while maintaining consistency (exactly-once processing semantics) by restoring the state of the operators and by replaying the records from the point of the checkpoint.

In case of failure of a parallel execution, Flink stops the stream flow, then restarts operators from the last checkpoints. 
When doing the reallocation of data partition for processing, states are reallocated too. 
States are saved on distributed file systems. When coupled with Kafka as data source, the committed read offset will be part of the checkpoint data.

Flink uses the concept of `Checkpoint Barriers`, which represents a separation of records, so records received since the last snapshot are part of the future snapshot. 

Barrier can be seen as a mark, a tag, in the data stream that closes a snapshot. 

 ![Checkpoints](./images/checkpoints.png)

In Kafka, it will be the last committed read offset. The barrier flows with the stream so it can be distributed. Once a sink operator (the end of a streaming DAG) has received the `barrier n` from all of its input streams, it acknowledges that `snapshot n` to the checkpoint coordinator. 
After all sinks have acknowledged a snapshot, it is considered completed. 
Once `snapshot n` has been completed, the job will never ask the source for records before such snapshot.

State snapshots are saved in a state backend (in memory, HDFS, RockDB). 

KeyedStream is a key-value store. Key matches the key in the stream, state update does not need transaction.

For DataSet (Batch processing) there is no checkpoint, so in case of failure the stream is replayed from te beginning.

When addressing exactly once processing it is very important to consider the following:

1. the read operation from the source
1. apply the processing logic like window aggregation
1. generate the results to a sink

1 and 2 can be done exactly once, using Flink source connector and checkpointing but generating one unique result to a sink is more complex and is dependant of the target technology. 

![](./images/e2e-1.png)

After reading records from Kafka, do the processing and generate results, in case of failure, Flink will reload the record from the read offset and may generate duplicates in the Sink. 

![](./images/e2e-2.png)

As duplicates will occur, we always need to assess how downstream applications support idempotence.
A lot of distributed key-value storages support consistent result even after retries.

To support end-to-end exactly one delivery, we need to have a sink that supports transaction and two-phase commit.
In case of failure we need to rollback the output generated. It is important to note transactional output impacts latency.

Flink takes checkpoints periodically, like every 10 seconds, which leads to the minimum latency, we can expect at the sink level.

For Kafka Sink connector, as kafka producer, we need to set the `transactionId`, and the delivery type:

```java
new KafkaSinkBuilder<String>()
    .setBootstrapServers(bootstrapURL)
    .setDeliverGuarantee(DeliveryGuarantee.EXACTLY_ONCE)
    .setTransactionalIdPrefix("store-sol")
```

With transaction ID, a sequence number is sent by the kafka producer API to the broker, and so
the partition leader will be able to remove duplicate retries.

![](./images/e2e-3.png)

When the checkpointing period is set, we need to also configure `transaction.max.timeout.ms`
of the Kafka broker and `transaction.timeout.ms` for the producer (sink connector) to a higher
timeout than the checkpointing interval plus the max expected Flink downtime. If not the Kafka broker
will consider the connection has fail and will remove its state management.


### Windowing

[Windows](https://ci.apache.org/projects/flink/flink-docs-release-1.12/dev/stream/operators/windows.html) are buckets within a Stream and can be defined with times, or count of elements.

* **Tumbling** window assigns events into nonoverlapping buckets of fixed size. When the window border is passed, all the events are sent to an evaluation function for processing. Count-based tumbling windows define how many events are collected before triggering evaluation. Time based tumbling windows define time interval of n seconds. Amount of the data vary in a window. `.keyBy(...).window(TumblingProcessingTimeWindows.of(Time.seconds(2)))`

![](./images/tumbling.png)

* **Sliding** window: same but windows can overlap. An event might belong to multiple buckets. There is a `window sliding time` parameter: `.keyBy(...).window(SlidingProcessingTimeWindows.of(Time.seconds(2), Time.seconds(1)))`

![](./images/sliding.png)

* **Session** window: Starts when the data stream processes records and stop when there is inactivity, so the timer set this threshold: `.keyBy(...).window(ProcessingTimeSessionWindows.withGap(Time.seconds(5)))`. The operator creates one window for each data element received.

![](./images/session.png)

* **Global** window: one window per key and never close. The processing is done with Trigger:

    ```java
    .keyBy(0)
	.window(GlobalWindows.create())
	.trigger(CountTrigger.of(5))
    ```

KeyStream can help to run in parallel, each window will have the same key.

## Event time

Time is central to the stream processing, and the time is a parameter of the flow / environment and can take different meanings:

* `ProcessingTime` = system time of the machine executing the task: best performance and low latency
* `EventTime` = the time at the event source level, embedded in the record. Deliver consistent and deterministic results regardless of order.
* `IngestionTime` = time when getting into Flink. 

In any time window, the order may not be guarantee and some events with an older timestamp may fell outside of the time window boundary. When compute aggregate, how are we sure that all events that should be in this time windows really arrived in this time window. The watermark is the heuritic used for that.


### Watermark

The goal is to limit the risjkof having events coming too late in a time window while using event-time processing, and in case of an out of order a stream may be. [Watermarks](https://ci.apache.org/projects/flink/flink-docs-release-1.20/dev/event_timestamps_watermarks.html) are generated into the data stream at a given frequency, and represent the mechanism to keep how the time has progressed. A watermark carries a timestamp, computed by substracting the out-of-orderness estimate from the largest timestamp seen so far. The out-of-orderness estimate is a guess and is defined per stream. Watermark is used to compare with other events, and will claim not earlier events will occur in the future after this time stamp.

Watermark is crucial for out of order events, and when dealing with multi sources. Kafka topic partitions can be a challenge without watermark. With IoT device and network latency, it is possible to get an event with an earlier timestamp, while the operator has already processed such event timestamp from other sources. The watermark generator runs inside the kafka consumer.

With windowing operator, event time stamp is used, but windows are defined on elapse time, for example, 10 minutes, so watermark helps to track the point of time where no more delayed events will arrive. 

Using processing time, the watermark progresses at each second. Events in the windows are emitted for processing once the watermark has passed the end of the window. 

The Flink API expects a `WatermarkStrategy` that contains both a `TimestampAssigner` and `WatermarkGenerator`. A `TimestampAssigner` is a simple function that extracts a field from an event. A number of common strategies are available out of the box as static methods on `WatermarkStrategy` class.

It is possible to configure to accept late events, with the `allowed lateness` time by which element can be late before being dropped. Flink keeps a state of Window until the allowed lateness time expires.


#### Some examples 

* Parallel watermarking is an example of getting data from 4 partitions with 2 kafka consumer and 2 windows:

    ![](./diagrams/parallel-watermark.drawio.png)

Shuffling is done as windows are computing some count or group by operations. Event A arriving at 3:13, and B[3:20] on green partitions, and are processed by Window 1 which consider 60 minutes time between 3:00 and 4:00. 

By default the connector will send a Watermark every 200ms, for each partition independently. If the out-of-orderness is set to be 5 minutes, so a watermark is created with a timestamp 3:08 (partition 0) and at 3:15 for partition 1 but it sends the minimum of both. The timestamp reflects how complete the stream is so far: it could not be no more complete than the further behind which was event at 3:13, 

In the case of a partition does not get any events, as there is no watermark generated for this parition, it may mean the watermark does no advance, and as a side effect it prevents windows from producing events. To avoid this problem, we need to balance kafka partitions so none are empty or idle, or confifure the watermarking to use idleness detection.

* See example [TumblingWindowOnSale.java](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/windows/TumblingWindowOnSale.java) in my-fink folder and to test it, do the following:

```shell
# Start the SaleDataServer that starts a server on socket 9181 and will read the avg.txt file and send each line to the socket
java -cp target/my-flink-1.0.0-SNAPSHOT.jar jbcodeforce.sale.SaleDataServer
# inside the job manager container started with 
`flink run -d -c jbcodeforce.windows.TumblingWindowOnSale /home/my-flink/target/my-flink-1.0.0-SNAPSHOT.jar`.
# The job creates the data/profitPerMonthWindowed.txt file with accumulated sale and number of record in a 2 seconds tumbling window
(June,Bat,Category5,154,6)
(August,PC,Category5,74,2)
(July,Television,Category1,50,1)
(June,Tablet,Category2,142,5)
(July,Steamer,Category5,123,6)
...
```

### Trigger

[Trigger](https://ci.apache.org/projects/flink/flink-docs-release-1.13/dev/stream/operators/windows.html#triggers) determines when a window is ready to be processed. All windows have default trigger. For example tumbling window has a 2s trigger. Global window has explicit trigger. We can implement our own triggers by implementing the Trigger interface with different methods to implement: onElement(..), onEventTime(...), onProcessingTime(...)

Default triggers:

* EventTimeTrigger: fires based upon progress of event time
* ProcessingTimeTrigger: fires based upon progress of processing time
* CountTrigger: fires when # of element in a window > parameter
* PurgingTrigger

### Eviction

Evictor is used to remove elements from a window after the trigger fires and before or after the window function is applied. The logic to remove is app specific.

The predefined evictors: CountEvictor, DeltaEvictor and TimeEvictor.


## Resources

* [Product documentation](https://flink.apache.org/flink-architecture.html). 
* [Official training](https://ci.apache.org/projects/flink/flink-docs-release-1.12/learn-flink/)
* Base docker image is: [https://hub.docker.com/_/flink](https://hub.docker.com/_/flink)
* [Flink docker setup](https://ci.apache.org/projects/flink/flink-docs-master/ops/deployment/docker.html) and the docker-compose files in this repo.
* [FAQ](https://wints.github.io/flink-web/faq.html)
* [Cloudera flink stateful tutorial](https://github.com/cloudera/flink-tutorials/tree/master/flink-stateful-tutorial): very good example for inventory transaction and queries on item considered as stream
* [Building real-time dashboard applications with Apache Flink, Elasticsearch, and Kibana](https://www.elastic.co/blog/building-real-time-dashboard-applications-with-apache-flink-elasticsearch-and-kibana)
