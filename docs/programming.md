# Programming guidances and examples

## More Data set basic apps

See first examples are in [my-flink project under the  p1 package](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/p1):

* [PersonFiltering.java](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/p1/PersonFiltering.java) filter a persons datastream using person's age to create a new "adult" output data stream. This example uses test data from a list of person and uses a filtering class which implements the filter method. This code can execute in VSCode or any IDE
* [InnerJoin](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/p1/InnerJoin.java) Proceed two files and do an inner join by using the same key on both files. See next section for details.
* [LeftOuterJoin](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/p1/LeftOuterJoin.java) results will include matching records from both tuples and non matching from left so persons (`personSet.leftOuterJoin(locationSet)`).
* [RightOuterJoin](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/p1/RightOuterJoin.java) matching records from both data sets are present and non matching from the right.
* [Full outer join](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/p1/FullOuterJoin.java) when matching and non matching are present. See [fulljoinout.csv output file](https://github.com/jbcodeforce/flink-studies/tree/master/my-flink/data/fulljoinout.csv).
* [Traditional word count from a text](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/p1/WordCountMain.java) uses a filter function to keep line starting by a pattern (letter 'N'), then it uses a tokenizer function to build a tuple for each word with a count of 1. The last step of the flow is to groupBy word and sum the element. Not obvious.

### Inner join

Need to read from two files and prepare them as tuples. Then process each record of the first tuple with the second one using field 0 on both tuples as join key. The with() build the new tuple with combined values. With need a join function to implement the joining logic and attributes selection.

```java
 DataSet<Tuple3<Integer,String,String>> joinedSet = 
      personSet.join(locationSet)
      .where(0) // indice of the field to be used to do join from first tuple
      .equalTo(0)  // to match the field in idx 0 of the second tuple
      .with( new JoinFunction<Tuple2<Integer, String>, 
                              Tuple2<Integer, String>, 
                              Tuple3<Integer, String, String>>() {
          
          public Tuple3<Integer, String, String> join(Tuple2<Integer, String> person,  Tuple2<Integer, String> location)  {
              return new Tuple3<Integer, String, String>(person.f0,   person.f1,  location.f1);
          }              
      });
```

Exec within the `JobManager` container.

```shell
flink run -d -c jbcodeforce.p1.InnerJoin /home/my-flink/target/my-flink-1.0.0-SNAPSHOT.jar --persons file:///home/my-flink/data/persons.txt --locations file:///home/my-flink/data/locations.txt --output file:///home/my-flink/data/joinout.csv 
```

### Left outer join

The construct is the same except the results will include matching records from both tuples and non matching from left:

```java

 DataSet<Tuple3<Integer,String,String>> joinedSet = 
            personSet.leftOuterJoin(locationSet)
            ....

      public Tuple3<Integer, String, String> join(
                        Tuple2<Integer, String> person,  
                        Tuple2<Integer, String> location)  {
          if (location == null) {
              return new Tuple3<Integer, String, String>(person.f0, person.f1, "NULL");
          }
          return new Tuple3<Integer, String, String>(person.f0,   person.f1,  location.f1);
      }  
```


## Data Stream examples

**Data stream** API is used to get real time data. It can come from file with readFile with watching folder for new file to be read, socketTextStream or any streaming source (addSource) like Twitter, Kafka...

The output can also be a stream as sink: writeAsText(),.. writeToSocket, addSink...

See example in `my-flink` project source [WordCountSocketStream](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/datastream/WordCountSocketStreaming.java), and to test it, use the `nc -l 9999` tool to open a socket on port 9999 and send text message.

When using docker we need to open a socket in the same network as the Flink task manager, so a command like:

```shell
docker run -t --rm --network  flink-studies_default --name ncs -h ncshost subfuzion/netcat -l 9999
```

### Compute average profit per product

The data set [avg.txt](https://github.com/jbcodeforce/flink-studies/tree/master/my-flink/data/avg.txt) represents transactions for a given product with its sale profit. The goal is to compute the average profit per product per month. The solution use Map - Reduce.

* Input sample:

```
01-06-2018,June,Category5,Bat,12
01-06-2108,June,Category4,Perfume,10
```

* Output:

In the class [ProfitAverageMR](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/datastream/ProfitAverageMR.java), the DataStream loads the input file as specified in  `--input` argument and then splits to get columns as tuple attributes.

```java
 DataStream<String> saleStream = env.readTextFile(params.get("input"));
 // month, product, category, profit, count
 DataStream<Tuple5<String, String, String, Integer, Integer>> mappedSale = saleStream.map(new Splitter()); 
```

The `Splitter` class implements a MapFunction which splits the csv string and select the attributes needed to generate a tuple.

A first reduce operation is used on the sale tuple where the key is a month (output from GetMonthAsKey) to accumulating profit and the number of record:

```java
DataStream<Tuple5<String, String, String, Integer, Integer>> reduced = 
  mappedSale.keyBy(new GetMonthAsKey())
  .reduce(new AccumulateProfitAndRecordCount()); 
DataStream<Tuple2<String, Double>> profitPerMonth = reduced.map(new MapOnMonth());
```

here is the main reduce function: the field f3 is the profit, and f4 the number of sale.

```java
 public static class AccumulateProfitAndRecordCount implements ReduceFunction<Tuple5<String, String, String, Integer, Integer>> {

    private static final long serialVersionUID = 1L;
    @Override
    public Tuple5<String, String, String, Integer, Integer> reduce(
            Tuple5<String, String, String, Integer, Integer> current,
            Tuple5<String, String, String, Integer, Integer> previous) throws Exception {
        
        return new Tuple5<String, String, String, Integer, Integer>(current.f0,current.f1,current.f2,current.f3 + previous.f3, current.f4 + previous.f4);
    }
}
```

To run the example once the cluster is started use:

```shell
 flink run -d -c jbcodeforce.datastream.ProfitAverageMR /home/my-flink/target/my-flink-1.0.0-SNAPSHOT.jar --input file:///home/my-flink/data/avg.txt 
```

### Aggregates

See all the operators examples in [this note](https://ci.apache.org/projects/flink/flink-docs-stable/dev/stream/operators/).

Examples of aggregate API to compute min, max... using field at index 3

```java
mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0 ).sum(3).writeAsText("/home/my-flink/data/out1");

mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0 ).min(3).writeAsText("/home/my-flink/data/out2");

mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0) .minBy(3).writeAsText("/home/my-flink/data/out3");
		
mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0 ).max(3).writeAsText("/home/my-flink/data/out4");
		
mapped.keyBy(( Tuple4<String, String, String, Integer> record) -> record.f0 ).maxBy(3).writeAsText("/home/my-flink/data/out5");
```

## Windowing

[Windows](https://ci.apache.org/projects/flink/flink-docs-release-1.12/dev/stream/operators/windows.html) are buckets within a Stream and can be defined with times, or count of elements.

* **Tumbling** window: a window every n seconds. Amount of the data vary in a window. `.keyBy(...).window(TumblingProcessingTimeWindows.of(Time.seconds(2)))`
* **Sliding** window: same but windows can overlap. So there is a `window sliding time` parameter: `.keyBy(...).window(SlidingProcessingTimeWindows.of(Time.seconds(2), Time.seconds(1)))`
* **Session** window: Starts when the data stream processes records and stop when there is inactivity, so the timer set this threshold: `.keyBy(...).window(ProcessingTimeSessionWindows.withGap(Time.seconds(5)))`. The operator creates one window for each data element received
* **Global** window: one window per key and never close. The processing is done with Trigger:

    ```java
    .keyBy(0)
	.window(GlobalWindows.create())
	.trigger(CountTrigger.of(5))
    ```

KeyStream can help to run in parallel, each window will have the same key.

The time is a parameter of the flow / environment:

* `ProcessingTime` = system time of the machine executing the task: best performance and low latency
* `EventTime` = the time at the source level, embedded in the record. Deliver consistent and deterministic results regardless of order 
* `IngestionTime` = time when getting into Flink. 

See example [TumblingWindowOnSale.java](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/windows/TumblingWindowOnSale.java) and to test it, do the following:

```shell
# Start the SaleDataServer that starts a server on socket 9181 and will read the avg.txt file and send each line to the socket
java -cp target/my-flink-1.0.0-SNAPSHOT.jar jbcodeforce.sale.SaleDataServer
# inside the job manager container start with 
`flink run -d -c jbcodeforce.windows.TumblingWindowOnSale /home/my-flink/target/my-flink-1.0.0-SNAPSHOT.jar`.
# The job creates the data/profitPerMonthWindowed.txt file with accumulated sale and number of record in a 2 seconds tumbling time window
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

### Watermark

[Watermark](https://ci.apache.org/projects/flink/flink-docs-release-1.13/dev/event_timestamps_watermarks.html) is the mechanism to keep how the event time has progressed: with windowing operator, event time stamp is used, but windows are defined on elapse time, for example, 10 minutes, so watermark helps to track where the process is in this window.
The Flink API expects a WatermarkStrategy that contains both a TimestampAssigner and WatermarkGenerator. A TimestampAssigner is a simple function that extracts a field from an event. A number of common strategies are available out of the box as static methods on WatermarkStrategy, so reference to the documentation and examples.

Watermark is crucial for out of order events, and when dealing with multi sources. Kafka topic partitions can be a challenge without watermark. With IoT device and network latency, it is possible to get an event with an earlier timestamp, while the operator has already processed such event timestamp from other source.

It is possible to configure to accept late event, with the `allowed lateness` time by which element can be late before being dropped. Flink keeps a state of Window until the allowed lateness time expires.

## Taxi rides examples

See [this flink-training github](https://github.com/apache/flink-training/tree/release-1.11) for source.

* [Lab 1- filter non NY taxi rides](https://github.com/apache/flink-training/tree/release-1.11/ride-cleansing), the process flow uses the `DataStream::filter` method. The NYCFilter is a class-filter-function.

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

This exercise uses a lot of utility classes for data and tests which hide the complexity of the data preparation (see the common folder).

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
