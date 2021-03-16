package jbcodeforce.domain;

public class TelemetrySummary {
    public String containerID;
    public int count = 0;
    public double Tmin = 20000;
    public double Tmax = 0;
    public double Taverage;
    public double CO2min = 20000;
    public double CO2max = 0;
    public double CO2average;

    public TelemetrySummary() {
        super();
    }
}
