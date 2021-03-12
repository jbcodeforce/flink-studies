package jbcodeforce;

import java.util.HashSet;
import java.util.Set;

import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.junit.jupiter.api.Test;

import jbcodeforce.domain.Telemetry;
import jbcodeforce.domain.TelemetryCount;
import jbcodeforce.kafka.TelemetryAggregate;
import jbcodeforce.kafka.TelemetryEvent;

public class TestDataFlow {
    
    Set<TelemetryCount> output = new HashSet<TelemetryCoun>();
    
    @Test
    public void shouldHaveFiveTelemetries(){
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        TelemetryEvent te1 = new TelemetryEvent();
        te1.containerID = "C01";
        Telemetry t1 = new Telemetry(); 
        te1.payload = t1;
        DataStream<TelemetryEvent> telemetryStream = env.fromElements(te1);
        TelemetryAggregate.definingTheDataFlow(telemetryStream).addSink(new SinkFunction<TelemetryCount>() {
            @Override
            public void invoke(TelemetryCount value) {
                System.out.println(value.containerID);
                output.add(value)
            }
        }).setParallelism(1);
        env.execute();
    }   
}
