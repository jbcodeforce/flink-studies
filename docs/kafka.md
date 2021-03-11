# Integration with Kafka

The [integration to Kafka](https://ci.apache.org/projects/flink/flink-docs-release-1.12/dev/connectors/kafka.html) has a datasource for Flink. We need a connector jar, define Kafka server properties and then define the source for the stream.


So the product documentation is wrong (03/2021) so here are some notes and read the code under kafka-flink-demo folder and the [TelemetryAggregate class](https://github.com/jbcodeforce/flink-studies/blob/master/kafka-flink-demo/src/main/java/jbcodeforce/kafka/TelemetryAggregate.java).

The major change is to implement a DeserializerSchema to process the event as java bean: ([See code])(ttps://github.com/jbcodeforce/flink-studies/blob/master/kafka-flink-demo/src/main/java/)

```java
public class TelemetryDeserializationSchema implements DeserializationSchema<TelemetryEvent> {

    private static final long serialVersionUID = -3142470930494715773L;
    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Override
	public TelemetryEvent deserialize(byte[] message) throws IOException {
		return objectMapper.readValue(message, TelemetryEvent.class);
	}

	@Override
	public boolean isEndOfStream(TelemetryEvent nextElement) {
		return false;
	}

	@Override
	public TypeInformation<TelemetryEvent> getProducedType() {
		return TypeInformation.of(TelemetryEvent.class);
	}
    
}
```

Then the creation of the kafka data source uses the traditional Kafka properties, and the following construct:

```java
// better to use a separate class for config to be injected via CDI
KafkaConfiguration configuration = new KafkaConfiguration();
    
Properties kafkaProperties = configuration.getConsumerProperties("telemetryAggregators");

FlinkKafkaConsumer<TelemetryEvent> kafkaConsumer = new FlinkKafkaConsumer<TelemetryEvent>(configuration.mainTopicName, new TelemetryDeserializationSchema(), kafkaProperties);
kafkaConsumer.setStartFromEarliest();

DataStream<TelemetryEvent> telemetryStream = env.addSource(kafkaConsumer);
```

With Flink’s checkpointing enabled, the Flink Kafka Consumer will consume records from a topic and periodically checkpoint all its Kafka offsets, together with the state of other operations. In case of a job failure, Flink will restore the streaming program to the state of the latest checkpoint and re-consume the records from Kafka, starting from the offsets that were stored in the checkpoint.