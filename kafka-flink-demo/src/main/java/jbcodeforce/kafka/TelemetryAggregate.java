package jbcodeforce.kafka;

import java.util.Properties;

import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;

import io.quarkus.runtime.QuarkusApplication;
import io.quarkus.runtime.annotations.QuarkusMain;

/**
 * A simple app to count the number of telemetries received in a time window per refrigerator ID
 */
@QuarkusMain
public class TelemetryAggregate implements QuarkusApplication {


  public static FlinkKafkaConsumer<TelemetryEvent>  buildKafkaConsumer(){
    KafkaConfiguration configuration = new KafkaConfiguration();
    
    Properties kafkaProperties = configuration.getConsumerProperties("telemetryAggregators");

    FlinkKafkaConsumer<TelemetryEvent> kafkaConsumer = new FlinkKafkaConsumer<TelemetryEvent>(configuration.mainTopicName, new TelemetryDeserializationSchema(), kafkaProperties);
    kafkaConsumer.setStartFromEarliest();
    return kafkaConsumer;
  }

  @Override
  public  int run(String... args) {
    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
    ParameterTool params = ParameterTool.fromArgs(args);
    env.getConfig().setGlobalJobParameters(params);
    

    FlinkKafkaConsumer<TelemetryEvent> kafkaConsumer = buildKafkaConsumer();
    
    DataStream<TelemetryEvent> telemetryStream = env.addSource(kafkaConsumer);
    //telemetryStream.flatMap(flatMapper);
    
    env.execute("Process Telemetries");
    return 1;
  }  
}
