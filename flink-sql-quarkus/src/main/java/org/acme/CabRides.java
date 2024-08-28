package org.acme;

import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.types.Row;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.connector.file.src.FileSource;
import org.apache.flink.connector.file.src.reader.TextLineInputFormat;

public class CabRides {
    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);
        // load data from input file
        FileSource<String> cabRides =
                        FileSource.forRecordStreamFormat(
                        new TextLineInputFormat(), new Path("/home/data/cab_rides.txt"))
                        .build();
        
        //define processing based on SQL
        Table inputTable = env.fromSource(cabRides, WatermarkStrategy.noWatermarks(), "FileSource");
    
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
