package jbcodeforce.domain;

import io.quarkus.runtime.annotations.RegisterForReflection;

@RegisterForReflection
public class Telemetry {
    public String container_id;
    public String measurement_time;
    public String product_id;
    public double temperature;
    public double target_temperature;
    public double ambiant_temperature;
    public double kilowatts;
    public double time_door_open;
    public int content_type;
    public int defrost_cycle;
    public double oxygen_level;
    public double nitrogen_level;
    public double humidity_level;
    public double target_humidity_level;
    public double carbon_dioxide_level;
    public boolean fan_1;
    public boolean fan_2;
    public boolean fan_3;
    public double latitude;
    public double longitude;
    public int maintenance_required;

    public Telemetry(){

    }

    public Telemetry(String payload){
        String [] arrayValues = payload.replace("(", "").replace(")", "").replace("'", "").split(",");
        if (arrayValues.length == 20){
            this.container_id = arrayValues[0].trim();
            this.measurement_time = arrayValues[1].trim();
            this.product_id = arrayValues[2].trim();
            this.temperature = Double.parseDouble(arrayValues[3].trim());
            this.target_temperature = Double.parseDouble(arrayValues[4].trim());
            this.ambiant_temperature = Double.parseDouble(arrayValues[5].trim());
            this.kilowatts = Double.parseDouble(arrayValues[6].trim());
            this.time_door_open = Double.parseDouble(arrayValues[7].trim());
            this.content_type = Integer.parseInt(arrayValues[8].trim());
            this.defrost_cycle = Integer.parseInt(arrayValues[9].trim());
            this.oxygen_level = Double.parseDouble(arrayValues[10].trim());
            this.nitrogen_level = Double.parseDouble(arrayValues[11].trim());
            this.humidity_level = Double.parseDouble(arrayValues[12].trim());
            this.target_humidity_level = Double.parseDouble(arrayValues[12].trim());
            this.carbon_dioxide_level = Double.parseDouble(arrayValues[13].trim()) + 4;
            this.fan_1 = Boolean.valueOf(arrayValues[14].trim());
            this.fan_2 = Boolean.valueOf(arrayValues[15].trim());
            this.fan_3 = Boolean.valueOf(arrayValues[16].trim());
            this.latitude = Double.parseDouble(arrayValues[17].trim());
            this.longitude = Double.parseDouble(arrayValues[18].trim());
            this.maintenance_required = Integer.parseInt(arrayValues[19].trim());
        }
    }

    @Override
    public String toString() {
        return "Telemetry [ container_id=" + this.container_id + ", measurement_time=" + this.measurement_time
                + ", product_id=" + this.product_id + ", temperature=" + this.temperature + ", target_temperature="
                + this.target_temperature + ", oxygen_level=" + this.oxygen_level + ", carbon_dioxide_level="
                + this.carbon_dioxide_level + ", maintenance_required=" + this.maintenance_required + " ]";
    }
}
