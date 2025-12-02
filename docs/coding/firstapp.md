# First Java Applications




## An example of Batch processing

The goals is to read a csv file and compute aggregates in Java DataStream, and then TableAPI. The code is in [code/table-api/loan-batch-processing]()



See [the coding practice summary](./datastream.md) for more datastream examples.

And the official [operators documentation](https://ci.apache.org/projects/flink/flink-docs-stable/dev/stream/operators/) to understand how to transform one or more DataStreams into a new DataStream. Programs can combine multiple transformations into sophisticated data flow topologies.

---

TO REWORK

## Unit testing

There are three type of function to test:

* Stateless
* Stateful
* Timed process

### Stateless

For stateless, the data flow can be isolated in static method within the main class, or defined within a separate class. The test instantiates the class and provides the data.

For example testing a string to a tuple mapping (MapTrip() is a MapFunction(...) extension):

```java
 public void testMapToTuple() throws Exception {
        MapTrip mapFunction = new MapTrip();
        Tuple5<String,String,String, Boolean, Integer> t = mapFunction.map("id_4214,PB7526,Sedan,Wanda,yes,Sector 19,Sector 10,5");
        assertEquals("Wanda",t.f0);
        assertEquals("Sector 19",t.f1);
        assertEquals("Sector 10",t.f2);
        assertTrue(t.f3);
        assertEquals(5,t.f4);
    }
```

### Stateful

The test needs to check whether the operator state is updated correctly and if it is cleaned up properly, along with the output of the operator. Flink provides TestHarness classes so that we don’t have to create the mock objects.

```java
```
