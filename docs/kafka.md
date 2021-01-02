# Integration with Kafka

The [integration to kafka](https://ci.apache.org/projects/flink/flink-docs-release-1.12/dev/connectors/kafka.html) as a datasource for Flink is very easy, we need a connector jar, define Kafka server properties and then define the source.

No need to copy the product documentation, just some summary of what needs to be done, with a simple example in the [TelemetryAggregate class](https://github.com/jbcodeforce/flink-studies/blob/master/my-flink/src/main/java/jbcodeforce/kafka/TelemetryAggregate.java)