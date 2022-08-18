package org.acme;

import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.types.Row;

public class CabRides {
    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);
        // load data from input file
        DataStream cabRides = env.readTextFile("/home/data/cab_rides.txt");
        //define processing based on SQL
        Table inputTable = tableEnv.fromDataStream(cabRides);
    
        // register the Table object as a view
        tableEnv.createTemporaryView("mycatalog.cabridesdb.cabRideView", inputTable);
        //  and query it
        Table resultTable = tableEnv.sqlQuery("SELECT * FROM mycatalog.cabridesdb.cabRideView");
    
        // interpret the insert-only Table as a DataStream again
        DataStream<Row> resultStream = tableEnv.toDataStream(resultTable);
    
        // add a printing sink and execute in DataStream API
        resultStream.print();
        env.execute("Taxi Rides Statistics");
    }
}
