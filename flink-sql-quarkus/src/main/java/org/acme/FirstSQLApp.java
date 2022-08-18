package org.acme;

import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.api.FormatDescriptor;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableDescriptor;
import org.apache.flink.table.api.TablePipeline;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.types.Row;

/**
 * count the number of time a name appears in a list
 */
public class FirstSQLApp {
 public static void main(String[] args) throws Exception {
    // Get environment
    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
    StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);
    // load data from input file
    DataStream<String> dataStream = env.fromElements("Alice", "Bob", "John", "Alice"); 
    //map stream to table with column name
    Table inputTable = tableEnv.fromDataStream(dataStream).as("name");

    // register the Table object in default catalog and database, as a view and query it
    tableEnv.createTemporaryView("clickStreamsView", inputTable);
    Table resultTable = tableEnv.sqlQuery("SELECT name, COUNT(name) as cnt FROM clickStreamsView GROUP BY name");

    // interpret the updating Table as a changelog DataStream
    DataStream<Row> resultStream = tableEnv.toChangelogStream(resultTable);

    // Emit table
    final Schema schema = Schema.newBuilder()
    .column("name", DataTypes.STRING())
    .column("cnt", DataTypes.BIGINT())
    .build();
    tableEnv.createTemporaryTable("CsvSinkTable", TableDescriptor.forConnector("filesystem")
    .schema(schema)
    .option("path", "/home/data/clickStream.csv")
    .format(FormatDescriptor.forFormat("csv")
        .option("field-delimiter", "|")
        .build())
    .build());

    //TablePipeline pipeline = resultStream.insertInto("CsvSinkTable");

    // Print explain details
    //pipeline.printExplain();
    // start the processing

    env.execute();
 }   

 public class MyFileSink implements SinkFunction<Row> {
    
 }
}
