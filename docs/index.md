# Apache Flink Studies

## What 

Apache Flink is a framework and distributed processing engine for stateful computations over unbounded and bounded data streams.

[Product documentation](https://flink.apache.org/flink-architecture.html). 

Base docker image is: [https://hub.docker.com/_/flink](https://hub.docker.com/_/flink)

See [Flink docker setup](https://ci.apache.org/projects/flink/flink-docs-master/ops/deployment/docker.html)

## Stream processing concepts

In [Flink](https://ci.apache.org/projects/flink/flink-docs-release-1.11/learn-flink/#stream-processing), applications are composed of streaming dataflows that may be transformed by user-defined operators. These dataflows form directed graphs that start with one or more sources, and end in one or more sinks.

 ![1](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/program_dataflow.svg)

It can consume from kafka, kinesis, queue, and any data source. A typical high level view of flink app:

 ![2](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/flink-application-sources-sinks.png)

Programs in Flink are inherently parallel and distributed. During execution, a stream has one or more stream partitions, and each operator has one or more operator subtasks.

 ![3](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/parallel_dataflow.svg)

A Flink application, can be stateful, is run in parallel on a distributed cluster. The various parallel instances of a given operator will execute independently, in separate threads, and in general will be running on different machines. 
State is always accessed locally, which helps Flink applications achieve high throughput and low-latency. You can choose to keep state on the JVM heap, or if it is too large, in efficiently organized on-disk data structures.

 ![4](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/local-state.png)

This is the JobManager component which parallelizes the job and distributes slices of [DataStream](https://ci.apache.org/projects/flink/flink-docs-stable/dev/datastream_api.html) flow you defined, to the Task Managers for execution. Each parallel slice of your job will be executed in a **task slot**.

 ![5](https://ci.apache.org/projects/flink/flink-docs-release-1.11/fig/distributed-runtime.svg)

The Flink Dashboard figure presents the execution reporting of those components:

 ![6](./images/flink-dashboard.png)

The execution is from one of the training examples, the number of task slot was set to 4, and one job is running.

## Taxi rides examples

See [this flink-training github](https://github.com/apache/flink-training/tree/release-1.11). 

* [Lab 1- filter non NY taxi rides](https://github.com/apache/flink-training/tree/release-1.11/ride-cleansing), the process flow uses the DataStream::filter method. The NYCFilter is a class-filter-function.

```Java
DataStream<TaxiRide> filteredRides = rides
	// keep only those rides and both start and end in NYC
    .filter(new NYCFilter());
// ...

public static class NYCFilter implements FilterFunction<TaxiRide> {
    @Override
    public boolean filter(TaxiRide taxiRide) {
        return GeoUtils.isInNYC(taxiRide.startLon, taxiRide.startLat) &&
                GeoUtils.isInNYC(taxiRide.endLon, taxiRide.endLat);
    }
}
```

This exercise uses a lot of utility classes for data and tests which hide the complexity (see the common folder).

* [Process ride and fare data streams for stateful enrichment](https://github.com/apache/flink-training/tree/release-1.11/rides-and-fares). The result should be a DataStream<Tuple2<TaxiRide, TaxiFare>>, with one record for each distinct rideId. Each tuple should pair the TaxiRide START event for some rideId with its matching TaxiFare. There is no control over the order of arrival of the ride and fare records for each rideId.

```java
DataStream<TaxiRide> rides = env
        .addSource(rideSourceOrTest(new TaxiRideGenerator()))
        .filter((TaxiRide ride) -> ride.isStart)
        .keyBy((TaxiRide ride) -> ride.rideId);

DataStream<TaxiFare> fares = env
        .addSource(fareSourceOrTest(new TaxiFareGenerator()))
        .keyBy((TaxiFare fare) -> fare.rideId);

// Set a UID on the stateful flatmap operator so we can read its state using the State Processor API.
DataStream<Tuple2<TaxiRide, TaxiFare>> enrichedRides = rides
        .connect(fares)
        .flatMap(new EnrichmentFunction())
        .uid("enrichment");
```

The join and stateful implementation are done in the EnrichmentFunction as a `RichCoFlatMap`. A CoFlatMapFunction implements a flat-map transformation over two connected streams. The same instance of the transformation function is used to transform both of the connected streams. That way, the stream transformations can share state.

 [RidesAndFaresSolution.java](https://github.com/apache/flink-training/blob/ea4a66e97dd211bd8f8b8e415e3e427c30e4746b/rides-and-fares/src/solution/java/org/apache/flink/training/solutions/ridesandfares/RidesAndFaresSolution.java#L86-L116)

`ValueState<TaxiRide> rideState` is a partitioned single-value state.

 `flatMap1(TaxiRide ride, Collector<Tuple2<TaxiRide, TaxiFare>> out) ` method is called for each element in the first of the connected streams. So here on a ride event, if there is a matching fare already computed then generate the output tuple, if not update keep the ride to be used for the fare event processing.

`flatMap2(TaxiFare fare, Collector<Tuple2<TaxiRide, TaxiFare>> out)` method is called on the second connected streams. When a fare event arrives, if there is a ride with the same key, join, if not keep the fare for future ride event.
 
So one of the trick is in the ValueState class.

* [Hourly tips](https://github.com/apache/flink-training/tree/master/hourly-tips) is a [time windowed analytics](https://ci.apache.org/projects/flink/flink-docs-release-1.11/learn-flink/streaming_analytics.html) to identify, for each hour, the driver earning the most tips. The approach is to use hour-long windows that compute the total tips for each driver during the hour, and then from that stream of window results, find the driver with the maximum tip total for each hour.

The first data stream below applies a window on a keyed stream. Process is one of the function to use on the window. (reduce and aggregate are the others). 

```java
    DataStream<Tuple3<Long, Long, Float>> hourlyTips = fares
            .keyBy((TaxiFare fare) -> fare.driverId)
            .window(TumblingEventTimeWindows.of(Time.hours(1)))
            .process(new AddTips());

    DataStream<Tuple3<Long, Long, Float>> hourlyMax = hourlyTips
            .windowAll(TumblingEventTimeWindows.of(Time.hours(1)))
            .maxBy(2);
```

A process window has an iterable on the collection of events in the window to work with:

```java
public static class AddTips extends ProcessWindowFunction<
			TaxiFare, Tuple3<Long, Long, Float>, Long, TimeWindow> {

    @Override
    public void process(Long key, Context context, Iterable<TaxiFare> fares, Collector<Tuple3<Long, Long, Float>> out) {
        float sumOfTips = 0F;
        for (TaxiFare f : fares) {
            sumOfTips += f.tip;
        }
        out.collect(Tuple3.of(context.window().getEnd(), key, sumOfTips));
    }
}
```

Time windowing has limitations:

* can not correctly process historic data
* can not correctly handle out-of-order data
* results will be non-deterministic

* [Long ride alert](https://github.com/apache/flink-training/tree/release-1.11/long-ride-alerts) is an example of [Event driven application](https://ci.apache.org/projects/flink/flink-docs-release-1.11/learn-flink/event_driven.html) where alerts are created if a taxi ride started two hours ago is still ongoing. It uses event timestamp and [watermarks](https://ci.apache.org/projects/flink/flink-docs-release-1.11/learn-flink/streaming_analytics.html#watermarks).

The key is in the [MatchFunction process function](https://github.com/apache/flink-training/blob/ea4a66e97dd211bd8f8b8e415e3e427c30e4746b/long-ride-alerts/src/solution/java/org/apache/flink/training/solutions/longrides/LongRidesSolution.java#L66-L108) implementation in which START or END events are kept in a value state, but a timer is set on the context, so the method may get a timer trigger with a processing event that will trigger the onTimer() callback method.

```java
context.timerService().registerEventTimeTimer(getTimerTime(ride));
```

It generates to the output stream / sink only records from this onTimer.

## Running the Flink cluster

Different [deployment models](https://ci.apache.org/projects/flink/flink-docs-release-1.11/ops/deployment/) are supported:

* Deploy on executing cluster, this is the **session mode**. There is a trade off to run multiple concurrent jobs in session mode.
* **Per job** mode, spin up a cluster per job submission. More k8s oriented. This provides better resource isolation.
* **Application mode** creates a cluster per app with the main() executed on the JobManager. It can include multiple jobs but run inside the app. It allows for saving the CPU cycles required, but also save the bandwidth required for downloading the dependencies locally.

## Development approach

Develop a [Java main function with the process flow definition](https://ci.apache.org/projects/flink/flink-docs-release-1.11/dev/datastream_api.html#anatomy-of-a-flink-program). Build a jar and then send the jar as a job to the job manager. For development we can use docker-compose to start a simple Flink cluster to run in session mode or use a docker compose that starts a standalone job manager to execute one unique job, which is the jar mounted inside the docker image. 

Change the parameter of the sandalone-job command:

```yaml
version: "2.2"
services:
  jobmanager:
    image: flink:1.11.2-scala_2.11
    ports:
      - "8081:8081"
    command: standalone-job --job-classname com.job.ClassName [--job-id <job id>] [--fromSavepoint /path/to/savepoint [--allowNonRestoredState]] [job arguments]
    volumes:
      - /host/path/to/job/artifacts:/opt/flink/usrlib
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        parallelism.default: 2

  taskmanager:
    image: flink:1.11.2-scala_2.11
    depends_on:
      - jobmanager
    command: taskmanager
    scale: 1
    volumes:
      - /host/path/to/job/artifacts:/opt/flink/usrlib
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        taskmanager.numberOfTaskSlots: 2
        parallelism.default: 2
```