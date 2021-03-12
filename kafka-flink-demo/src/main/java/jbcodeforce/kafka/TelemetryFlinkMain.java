package jbcodeforce.kafka;

import io.quarkus.runtime.Quarkus;
import io.quarkus.runtime.annotations.QuarkusMain;

@QuarkusMain
public class TelemetryFlinkMain {
    public static void main(String[] args) {
        Quarkus.run(TelemetryAggregate.class, args);
    }
}
