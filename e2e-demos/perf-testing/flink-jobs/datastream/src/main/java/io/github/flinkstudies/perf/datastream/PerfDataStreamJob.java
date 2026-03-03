package io.github.flinkstudies.perf.datastream;

import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

/**
 * DataStream job: read from Kafka perf-input, pass-through (or simple map), write to Kafka perf-output.
 * Env: BOOTSTRAP_SERVERS (required), INPUT_TOPIC (default perf-input), OUTPUT_TOPIC (default perf-output).
 */
public class PerfDataStreamJob {

    public static void main(String[] args) throws Exception {
        String bootstrap = System.getenv("BOOTSTRAP_SERVERS");
        if (bootstrap == null || bootstrap.isBlank()) {
            System.err.println("BOOTSTRAP_SERVERS environment variable is required");
            System.exit(1);
        }
        String inputTopic = System.getenv().getOrDefault("INPUT_TOPIC", "perf-input");
        String outputTopic = System.getenv().getOrDefault("OUTPUT_TOPIC", "perf-output");

        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        KafkaSource<String> source = KafkaSource.<String>builder()
                .setBootstrapServers(bootstrap)
                .setTopics(inputTopic)
                .setGroupId("perf-datastream")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .build();

        DataStream<String> stream = env.fromSource(source, org.apache.flink.api.common.eventtime.WatermarkStrategy.noWatermarks(), "Kafka Source");

        KafkaSink<String> sink = KafkaSink.<String>builder()
                .setBootstrapServers(bootstrap)
                .setRecordSerializer(KafkaRecordSerializationSchema.builder()
                        .setTopic(outputTopic)
                        .setValueSerializationSchema(new SimpleStringSchema())
                        .build())
                .build();

        stream.sinkTo(sink);

        env.execute("Perf DataStream Job");
    }
}
