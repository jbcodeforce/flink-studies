package jbcodeforce.domain;

import javax.inject.Inject;
import javax.inject.Singleton;

import org.apache.flink.api.java.utils.ParameterTool;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.assigners.TumblingEventTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.eclipse.microprofile.config.inject.ConfigProperty;

@Singleton
public abstract class ReeferTelemetryJob {
    @Inject
    @ConfigProperty(name = "app.time.window.size.m")
    public static long timeWindowSize = 5;

    public final StreamExecutionEnvironment createApplicationPipeline(ParameterTool params) throws Exception {
        // Create and configure the StreamExecutionEnvironment
		StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.getConfig().setGlobalJobParameters(params);
        DataStream<TelemetryEvent> telemetryStream = readTelemetryStream(params,env);
        
        telemetryStream.keyBy((TelemetryEvent value) -> value.containerID)
            .window(TumblingEventTimeWindows.of(Time.minutes(timeWindowSize)))
            .aggregate(new TelemetryProcessor());
        return env;
    } 

    
    
	protected abstract DataStream<TelemetryEvent> readTelemetryStream(ParameterTool params, StreamExecutionEnvironment env);
    protected abstract void writeTelemetrySummaries(ParameterTool params, DataStream<TelemetrySummary>  outStream);
}
