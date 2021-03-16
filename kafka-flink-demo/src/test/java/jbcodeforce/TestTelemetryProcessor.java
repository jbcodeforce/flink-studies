package jbcodeforce;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.HashSet;
import java.util.Set;

import org.junit.jupiter.api.Test;

import jbcodeforce.domain.Telemetry;
import jbcodeforce.domain.TelemetryEvent;
import jbcodeforce.domain.TelemetryProcessor;
import jbcodeforce.domain.TelemetrySummary;

public class TestTelemetryProcessor {
    
    Set<TelemetrySummary> output = new HashSet<TelemetrySummary>();
    
    public  TelemetrySummary buildSummary(){
        TelemetrySummary sum1 = new TelemetrySummary();
        sum1.CO2average=10;
        sum1.CO2max=16;
        sum1.CO2min=4;
        sum1.Taverage=18;
        sum1.Tmax=30;
        sum1.Tmin=3;
        sum1.count=10;
        return sum1;
    }
    @Test
    public void getValidMergedSummary() throws Exception {
        TelemetrySummary sum1 = buildSummary();

        TelemetrySummary sum2 = buildSummary();
        sum2.CO2average=12;
        sum2.CO2max=18;
        sum2.CO2min=5;
        sum2.Tmax=40;
        sum2.Tmin=6;
        sum2.count=1;
        
        TelemetryProcessor processor = new TelemetryProcessor();
        TelemetrySummary out = processor.merge(sum1, sum2);
        assertEquals(11, out.count, "accumulate count");
        assertEquals(11, out.CO2average, "CO2 average should now be 11");
        assertEquals(4, out.CO2min, "min CO2 should be 4");
        assertEquals(18, out.CO2max, "max of CO2 should be 18");
        assertEquals(3, out.Tmin, "min of T should be 3");
        assertEquals(40, out.Tmax, "max of T should be 40");
        assertEquals(18, out.Taverage, "Average of T should be 18");
        /**
         
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        TelemetryEvent te1 = new TelemetryEvent();
        te1.containerID = "C01";
        Telemetry t1 = new Telemetry(); 
        te1.payload = t1;
        DataStream<TelemetryEvent> telemetryStream = env.fromElements(te1);
        TelemetryAggregate.processTelemetry(telemetryStream).addSink(new SinkFunction<TelemetrySummary>() {
            @Override
            public void invoke(TelemetrySummary value) {
                System.out.println(value.containerID);
                output.add(value);
            }
        }).setParallelism(1);
        env.execute();
        * 
         */
    }   

    @Test
    public void testAddTelemetryOnFirstSummary(){
        TelemetrySummary sum1 = new TelemetrySummary();
        TelemetryProcessor processor = new TelemetryProcessor();
        TelemetryEvent inEvent = new TelemetryEvent();
        Telemetry payload = new Telemetry();
        payload.temperature=2.0;
        payload.carbon_dioxide_level=15;
        inEvent.payload = payload;
        inEvent.containerID = "C01";
        processor.add(inEvent, sum1);
        assertEquals("C01",sum1.containerID);
        assertEquals(1,sum1.count);
        assertEquals(2,sum1.Taverage);
        assertEquals(2,sum1.Tmax);
        assertEquals(2,sum1.Tmin);
        assertEquals(15,sum1.CO2min);
        assertEquals(15,sum1.CO2max);
        assertEquals(15,sum1.CO2average);
    }

    @Test
    public void testAddTelemetryToExistingSummary(){
        TelemetrySummary sum1 = buildSummary();
        TelemetryProcessor processor = new TelemetryProcessor();
        TelemetryEvent inEvent = new TelemetryEvent();
        Telemetry payload = new Telemetry();
        payload.temperature=10.0;
        payload.carbon_dioxide_level=14;
        inEvent.payload = payload;
        inEvent.containerID = "C01";
        processor.add(inEvent, sum1);
        assertEquals("C01",sum1.containerID);
        assertEquals(11,sum1.count);
        assertEquals(14,sum1.Taverage);
        assertEquals(30,sum1.Tmax);
        assertEquals(3,sum1.Tmin);
        assertEquals(4,sum1.CO2min);
        assertEquals(16,sum1.CO2max);
        assertEquals(12,sum1.CO2average);
    }
}
