# Process Table Function


## Features

* The TableAPI or SQL most powerful function API. Stateful.
* Access to Flink’s managed state, event-time and timer services, and underlying table changelogs

## Use Cases

PTFs unlock use cases that can’t be expressed in a declarable way with either SQL or the Table API implementation. It serves a similar purposes compared to the ProcessFunction in Apache Flink’s Datastream API, giving primitives for handling the most common building blocks for stateful processing applications: events, state and timers.

* Apply transformations on each row of a table.
* Logically partition the table into distinct sets and apply transformations per set.
* Store seen events for repeated access.
* Continue the processing at a later point in time enabling waiting, synchronization, or timeouts.
* Buffer and aggregate events using complex state machines or rule-based conditional logic.

## Sources

* [Flink documentation](https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/functions/ptfs/)
* [Confluent documentation](https://docs.confluent.io/cloud/current/flink/how-to-guides/create-ptf.html)
* [Martinjn Visser](https://github.com/MartijnVisser/flink-ptf-examples/tree/main)
* [Satakshi Raj](https://github.com/sraj2023/cc-flink-example/blob/main/ptf/src/main/java/io/confluent/flink/examples/windowstate/README.md)
