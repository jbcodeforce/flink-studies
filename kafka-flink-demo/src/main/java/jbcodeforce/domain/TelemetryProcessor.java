package jbcodeforce.domain;

import org.apache.flink.api.common.functions.AggregateFunction;

public class TelemetryProcessor implements AggregateFunction<TelemetryEvent,TelemetrySummary,TelemetrySummary> {

    /**
     *
     */
    private static final long serialVersionUID = -5233837073216204026L;

    @Override
    public TelemetrySummary createAccumulator(){
      return new TelemetrySummary();
    }

    @Override
    public TelemetrySummary add(TelemetryEvent inEvent, TelemetrySummary out)  {
        if (inEvent.payload == null) return out;
      out.containerID = inEvent.containerID;
      out.count+=1;
      if (inEvent.payload.temperature <= out.Tmin) {
        out.Tmin = inEvent.payload.temperature;
      }
      if (inEvent.payload.temperature >= out.Tmax) {
        out.Tmax = inEvent.payload.temperature;
      }
      if (out.count == 1) {
        out.Taverage = (out.Taverage + inEvent.payload.temperature);
        out.CO2average = (out.CO2average + inEvent.payload.carbon_dioxide_level);
      } else {
        out.Taverage = (out.Taverage + inEvent.payload.temperature)/2;
        out.CO2average = (out.CO2average + inEvent.payload.carbon_dioxide_level) / 2;
      }
      
      
      if (inEvent.payload.carbon_dioxide_level <= out.CO2min) {
        out.CO2min= inEvent.payload.carbon_dioxide_level;
      }
      if (inEvent.payload.carbon_dioxide_level >= out.CO2max) {
        out.CO2max = inEvent.payload.carbon_dioxide_level;
      }
      return out;
    }

    @Override
    public TelemetrySummary getResult(TelemetrySummary out){
      return out;
    }

    @Override
    public TelemetrySummary merge(TelemetrySummary count1,TelemetrySummary count2){
      TelemetrySummary out = new TelemetrySummary();
      out.containerID = count1.containerID;
      out.count = count1.count + count2.count;
      out.CO2average = (count1.CO2average + count2.CO2average) / 2;
      out.CO2max = Math.max(count1.CO2max, count2.CO2max);
      out.CO2min = Math.min(count1.CO2min, count2.CO2min);
      out.Taverage = (count1.Taverage + count2.Taverage) / 2;
      out.Tmax = Math.max(count1.Tmax, count2.Tmax);
      out.Tmin = Math.min(count1.Tmin, count2.Tmin);
      return out;
    }
    
}
