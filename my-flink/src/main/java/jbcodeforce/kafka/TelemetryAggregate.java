package jbcodeforce.kafka;

import java.util.Properties;

import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.java.ExecutionEnvironment;
import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;

public class TelemetryAggregate {
  public static void main(String[] args) {
    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
    ParameterTool params = ParameterTool.fromArgs(args);
    env.getConfig().setGlobalJobParameters(params);

    Properties properties = new Properties();
    properties.setProperty("bootstrap.servers", System.getenv("BOOTSTRAP_SERVERS"));
    properties.setProperty("group.id", "telemetryAggregators");
    DataStream<String> stream = env
        .addSource(new FlinkKafkaConsumer<>("telemetries", new SimpleStringSchema(), properties));
    
  }  
}
