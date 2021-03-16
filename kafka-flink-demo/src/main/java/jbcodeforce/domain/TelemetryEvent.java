package jbcodeforce.domain;

import io.quarkus.runtime.annotations.RegisterForReflection;

@RegisterForReflection
public class TelemetryEvent {
    public String containerID;
    public Telemetry payload;
    public String timestamp;
    public String type;

    public TelemetryEvent(){}

   
    public String toString(){
        return "{" + 
            "containerID: " + this.containerID + ", " +
            "timestamp: " + this.timestamp + ", " +
            "type: " + this.type + ", " +
            "payload: " + this.payload.toString() +
            "}";
    }

}