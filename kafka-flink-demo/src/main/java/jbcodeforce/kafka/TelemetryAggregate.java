package jbcodeforce.kafka;

import java.util.Properties;

import javax.inject.Inject;
import javax.inject.Singleton;

import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.windowing.WindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingEventTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.Window;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;
import org.apache.flink.util.Collector;
import org.eclipse.microprofile.config.inject.ConfigProperty;

import io.quarkus.runtime.QuarkusApplication;
import jbcodeforce.domain.TelemetryCount;

/**
 * A simple app to count the number of telemetries received in a time window per refrigerator ID
 */
@Singleton
public class TelemetryAggregate implements QuarkusApplication {

  @Inject
  @ConfigProperty(name = "app.time.window.size.s")
  public static int timeWindowSize = 15;

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
    TelemetryAggregate.definingTheDataFlow(telemetryStream);
    try {
      env.execute("Process Telemetries");
    } catch (Exception e) {
      e.printStackTrace();
    }
    return 1;
  }  

  public class NumberOfTelemetryWindowFunction implements WindowFunction {

    @Override
    public void apply(Object key, Window window, Iterable<TelemetryEvent> input, Collector<TelemetryCount> out) throws Exception {
      while (input.hasNext()) {
        TelemetryEvent te = input.next();
        TelemetryCount tc = new TelemetryCount(te.containerID,1);
        out.collect(tc);
      }
    }
  }

  public static DataStream<TelemetryCount> definingTheDataFlow(DataStream<TelemetryEvent> telemetryStream ){
    telemetryStream.print();
    
    return telemetryStream.keyBy(value -> value.containerID)
      .window(TumblingEventTimeWindows.of(Time.seconds(timeWindowSize)))
      .apply(new NumberOfTelemetryWindowFunction());
    
  }
}
