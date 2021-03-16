package jbcodeforce.kafka;

import java.util.Properties;

import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.timestamps.BoundedOutOfOrdernessTimestampExtractor;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;

import jbcodeforce.domain.ReeferTelemetryJob;
import jbcodeforce.domain.TelemetryEvent;
import jbcodeforce.domain.TelemetrySummary;


public class KafkaReeferTelemetryJob extends ReeferTelemetryJob {
    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
			throw new RuntimeException("Path to the properties file is expected as the only argument.");
		}
        ParameterTool params = ParameterTool.fromArgs(args);
        new KafkaReeferTelemetryJob().createApplicationPipeline(params).execute("Kafka Reefer Telemetry Processing Job");
    }

    @Override
    protected DataStream<TelemetryEvent> readTelemetryStream(ParameterTool params, StreamExecutionEnvironment env) {
        FlinkKafkaConsumer<TelemetryEvent> telemetrySource = buildKafkaConsumer();
        

		// In case event time processing is enabled we assign trailing watermarks for each partition
		telemetrySource.assignTimestampsAndWatermarks(new BoundedOutOfOrdernessTimestampExtractor<TelemetryEvent>(Time.minutes(5)) {
			@Override
			public long extractTimestamp(TelemetryEvent event) {
				return Long.parseLong(event.timestamp);
			}
		});

		return env.addSource(telemetrySource)
				.name("Kafka Telemetry Source")
				.uid("Kafka Telemetry Source");
    }

    @Override
    protected void writeTelemetrySummaries(ParameterTool params, DataStream<TelemetrySummary> outStream) {
        // TODO Auto-generated method stub
        
    }

    public static FlinkKafkaConsumer<TelemetryEvent>  buildKafkaConsumer(){
        KafkaConfiguration configuration = new KafkaConfiguration();
        
        Properties kafkaProperties = configuration.getConsumerProperties("telemetryAggregators");
    
        FlinkKafkaConsumer<TelemetryEvent> kafkaConsumer = new FlinkKafkaConsumer<TelemetryEvent>(configuration.mainTopicName, new TelemetryDeserializationSchema(), kafkaProperties);
        kafkaConsumer.setStartFromEarliest();
        kafkaConsumer.setCommitOffsetsOnCheckpoints(true);
        return kafkaConsumer;
      }


}
