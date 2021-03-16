package jbcodeforce;

import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.junit.jupiter.api.Test;

import jbcodeforce.domain.ReeferTelemetryJob;
import jbcodeforce.domain.Telemetry;
import jbcodeforce.domain.TelemetryEvent;
import jbcodeforce.domain.TelemetrySummary;


public class TestTelemetryJob extends ReeferTelemetryJob {
   
    @Override
    protected DataStream<TelemetryEvent> readTelemetryStream(ParameterTool params, StreamExecutionEnvironment env) {
        TelemetryEvent te = new TelemetryEvent();
        Telemetry payload = new Telemetry();
        payload.temperature=2.0;
        payload.carbon_dioxide_level=15;
        te.payload = payload;
        return env.fromElements(te);
     }

    @Override
    protected void writeTelemetrySummaries(ParameterTool params, DataStream<TelemetrySummary> outStream) {
        
    }
    
    @Test
    public void should(){
        TestTelemetryJob job = new TestTelemetryJob();
        ParameterTool.fromArgs(new String[]{});
    }
    
}
